import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart' show ForgeTextScopeWidget;

import '../configuration_ui_trail.dart';
import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';

/// Drives [session] (a `ForgeSettingFlow`'s run: signing in, a one-time
/// code) in a dialog until it is done or the user cancels it, and answers
/// how it ended.
///
/// The dialog shows each step the session answers: its title and message,
/// a link and a code to copy, the fields of an input step (text, secret,
/// one-time code), its choices (default *Continue*) and *Cancel*; a waiting
/// step shows a spinner and asks the session again after its `pollAfter`;
/// a refused answer's error is shown with the step it comes back with.
Future<ForgeActionResult> showForgeFlowDialog(
  BuildContext context,
  ForgeFlowSession session, {
  String? title,
  String trailName = 'flow',
}) async {
  final result = await showDialog<ForgeActionResult>(
    context: context,
    barrierDismissible: false,
    builder: ForgeTextScopeWidget.keep(
      context,
      (context) =>
          ForgeFlowDialog(session: session, title: title, trailName: trailName),
    ),
  );
  return result ?? const ForgeActionResult.cancelled();
}

/// The dialog [showForgeFlowDialog] shows.
class ForgeFlowDialog extends StatefulWidget {
  const ForgeFlowDialog({
    super.key,
    required this.session,
    this.title,
    this.trailName = 'flow',
  });

  final ForgeFlowSession session;
  final String? title;
  final String trailName;

  @override
  State<ForgeFlowDialog> createState() => _ForgeFlowDialogState();
}

class _ForgeFlowDialogState extends State<ForgeFlowDialog> {
  ForgeFlowStep? _step;
  bool _busy = true;
  bool _closed = false;
  Timer? _poll;
  String? _fieldError;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _advance(widget.session.start);
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _advance(Future<ForgeFlowStep> Function() next) async {
    _poll?.cancel();
    setState(() => _busy = true);
    ForgeFlowStep step;
    try {
      step = await next();
    } on Object catch (error) {
      step = ForgeFlowStep.done(
        ForgeActionResult.failure(ForgeConfigurationTexts.hookFailed('$error')),
      );
    }
    if (!mounted || _closed) return;
    configurationUiTrail('${widget.trailName}: step ${step.kind.name}');
    if (step.kind == ForgeFlowStepKind.done) {
      _close(step.result ?? const ForgeActionResult.success());
      return;
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers
      ..clear()
      ..addAll({
        for (final field in step.fields) field.id: TextEditingController(),
      });
    setState(() {
      _step = step;
      _busy = false;
      _fieldError = null;
    });
    if (step.kind == ForgeFlowStepKind.waiting) {
      _poll = Timer(
        step.pollAfter ?? const Duration(seconds: 2),
        () => _advance(widget.session.poll),
      );
    }
  }

  void _close(ForgeActionResult result) {
    if (_closed) return;
    _closed = true;
    _poll?.cancel();
    Navigator.of(context).pop(result);
  }

  void _cancel() {
    configurationUiTrail('${widget.trailName}: cancelled');
    widget.session.cancel();
    _close(const ForgeActionResult.cancelled());
  }

  void _respond(String? choice) {
    final step = _step;
    if (step == null) return;
    final values = {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };
    for (final field in step.fields) {
      final value = values[field.id] ?? '';
      final missing = field.required && value.isEmpty;
      final wrongLength =
          field.length != null &&
          value.isNotEmpty &&
          value.length != field.length;
      if (missing || wrongLength) {
        setState(
          () => _fieldError = ForgeConfigurationLabels.resolveIn(
            context,
            missing
                ? ForgeConfigurationTexts.item(
                    ForgeConfigurationLabels.resolveIn(context, field.label),
                    ForgeConfigurationTexts.required,
                  )
                : ForgeConfigurationTexts.item(
                    ForgeConfigurationLabels.resolveIn(context, field.label),
                    ForgeConfigurationTexts.wrongType,
                  ),
          ),
        );
        return;
      }
    }
    _advance(
      () => widget.session.respond(
        ForgeFlowResponse(choice: choice, values: values),
      ),
    );
  }

  Widget _copyable(BuildContext context, String text, {bool large = false}) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            text,
            style: large
                ? theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2)
                : theme.textTheme.bodyMedium,
          ),
        ),
        IconButton(
          tooltip: ForgeConfigurationLabels.resolveIn(
            context,
            ForgeConfigurationUiTexts.copy,
          ),
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
        ),
      ],
    );
  }

  Widget _field(ForgeFlowField field) {
    final controller = _controllers[field.id]!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        key: ValueKey('forge.configuration.flow.field.${field.id}'),
        controller: controller,
        enabled: !_busy,
        obscureText: field.kind == ForgeFlowFieldKind.secret,
        keyboardType: field.kind == ForgeFlowFieldKind.oneTimeCode
            ? TextInputType.number
            : TextInputType.text,
        inputFormatters: [
          if (field.kind == ForgeFlowFieldKind.oneTimeCode)
            FilteringTextInputFormatter.digitsOnly,
          if (field.length != null)
            LengthLimitingTextInputFormatter(field.length),
        ],
        decoration: InputDecoration(
          labelText: ForgeConfigurationLabels.resolveIn(context, field.label),
          hintText: ForgeConfigurationLabels.resolveOrNullIn(
            context,
            field.hint,
          ),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _respond(null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _step;
    final title =
        ForgeConfigurationLabels.resolveOrNullIn(context, step?.title) ??
        widget.title;
    final waiting = step?.kind == ForgeFlowStepKind.waiting;
    final error =
        _fieldError ??
        ForgeConfigurationLabels.resolveOrNullIn(context, step?.error);
    final choices = step == null || waiting
        ? const <ForgeFlowChoice>[]
        : step.choices.isEmpty
        ? const [
            ForgeFlowChoice(
              '',
              ForgeConfigurationUiTexts.continueLabel,
              primary: true,
            ),
          ]
        : step.choices;
    return AlertDialog(
      title: title == null ? null : Text(title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (step == null || (_busy && !waiting))
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (step != null) ...[
              if (step.message != null)
                Text(
                  ForgeConfigurationLabels.resolveIn(context, step.message!),
                  style: theme.textTheme.bodyMedium,
                ),
              if (step.url != null) ...[
                const SizedBox(height: 8),
                _copyable(context, step.url!),
              ],
              if (step.code != null) ...[
                const SizedBox(height: 8),
                _copyable(context, step.code!, large: true),
              ],
              for (final field in step.fields) _field(field),
              if (waiting)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: Text(
            ForgeConfigurationLabels.resolveIn(
              context,
              ForgeConfigurationUiTexts.cancel,
            ),
          ),
        ),
        for (final choice in choices)
          choice.primary
              ? FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _respond(choice.id.isEmpty ? null : choice.id),
                  child: Text(
                    ForgeConfigurationLabels.resolveIn(context, choice.label),
                  ),
                )
              : TextButton(
                  onPressed: _busy
                      ? null
                      : () => _respond(choice.id.isEmpty ? null : choice.id),
                  child: Text(
                    ForgeConfigurationLabels.resolveIn(context, choice.label),
                  ),
                ),
      ],
    );
  }
}
