import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart' show ForgeTextScopeWidget;

import '../configuration_ui_trail.dart';
import '../forge_configuration_icons.dart';
import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';
import '../forge_setting_editor_registry.dart';
import 'flow_runner.dart';

// The widgets the editors of the kinds with behaviour share: a button that
// runs a hook with its progress and result, a status line, and the bar of a
// setting's own actions (`ForgeSetting.actions`).

/// Runs a hook: given the run's cancellation and a progress sink, answers how
/// it ended.
typedef ForgeHookRun =
    Future<ForgeActionResult> Function(
      ForgeHookCancellation cancellation,
      void Function(ForgeHookProgress progress) onProgress,
    );

/// The colour [level] is drawn in.
Color forgeStatusColor(BuildContext context, ForgeStatusLevel level) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (level) {
    ForgeStatusLevel.ok =>
      dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
    ForgeStatusLevel.info => scheme.primary,
    ForgeStatusLevel.warning =>
      dark ? const Color(0xFFFFB74D) : const Color(0xFF9A5B00),
    ForgeStatusLevel.error => scheme.error,
    ForgeStatusLevel.busy => scheme.onSurfaceVariant,
    ForgeStatusLevel.unknown => scheme.onSurfaceVariant,
  };
}

/// The icon of [level] (a small spinner while busy).
class ForgeStatusLevelIcon extends StatelessWidget {
  const ForgeStatusLevelIcon(this.level, {super.key, this.size = 16});

  final ForgeStatusLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = forgeStatusColor(context, level);
    if (level == ForgeStatusLevel.busy) {
      return SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }
    final icon = switch (level) {
      ForgeStatusLevel.ok => Icons.check_circle,
      ForgeStatusLevel.info => Icons.info_outline,
      ForgeStatusLevel.warning => Icons.warning_amber,
      ForgeStatusLevel.error => Icons.error_outline,
      ForgeStatusLevel.busy => Icons.hourglass_empty,
      ForgeStatusLevel.unknown => Icons.help_outline,
    };
    return Icon(icon, size: size, color: color);
  }
}

/// A status as a line — its level's icon, its message and detail — and its
/// items below it (at most [maxItems], the rest counted).
class ForgeStatusView extends StatelessWidget {
  const ForgeStatusView({
    super.key,
    required this.status,
    this.showItems = true,
    this.maxItems = 20,
  });

  final ForgeStatusInfo status;
  final bool showItems;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = status.message == null
        ? (status.level == ForgeStatusLevel.busy
              ? ForgeConfigurationLabels.resolveIn(
                  context,
                  ForgeConfigurationUiTexts.loading,
                )
              : null)
        : ForgeConfigurationLabels.resolveIn(context, status.message!);
    final items = showItems ? status.items : const <ForgeStatusItem>[];
    final shown = items.take(maxItems).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ForgeStatusLevelIcon(status.level),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message != null)
                    Text(message, style: theme.textTheme.bodyMedium),
                  if (status.detail != null)
                    SelectableText(
                      status.detail!,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        for (final item in shown)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ForgeStatusLevelIcon(item.level, size: 14),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.detail == null
                        ? item.text
                        : '${item.text} — ${item.detail}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (items.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.moreItems(
                  items.length - shown.length,
                ),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Asks [question] with *Cancel* and *OK*; answers whether the user
/// confirmed.
Future<bool> forgeConfirm(BuildContext context, String question) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: ForgeTextScopeWidget.keep(
      context,
      (context) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.cancel,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.ok,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return answer ?? false;
}

/// A button that runs a hook: while it runs, its progress (a bar when the
/// hook reports how far it is, else a spinner), its message and a *Stop*
/// button; when it ended, the result (its message, or *Done.* / *Failed.* /
/// *Cancelled.*). With [confirmation] the user is asked first.
class ForgeHookButton extends StatefulWidget {
  const ForgeHookButton({
    super.key,
    required this.label,
    required this.run,
    this.icon,
    this.emphasis = ForgeActionEmphasis.normal,
    this.confirmation,
    this.enabled = true,
    this.onResult,
    this.trailName = 'hook',
    this.showResult = true,
  });

  final String label;
  final ForgeHookRun run;
  final IconData? icon;
  final ForgeActionEmphasis emphasis;

  /// A question asked before it runs, or null.
  final String? confirmation;
  final bool enabled;

  /// Takes the result (to refresh what depends on it).
  final ValueChanged<ForgeActionResult>? onResult;

  /// How the trail names the run.
  final String trailName;

  /// Whether the result is shown under the button (off when the caller
  /// shows what the run found itself).
  final bool showResult;

  @override
  State<ForgeHookButton> createState() => ForgeHookButtonState();
}

/// The state of a [ForgeHookButton]: whether it runs, its progress and its
/// last result.
class ForgeHookButtonState extends State<ForgeHookButton> {
  ForgeHookCancellation? _cancellation;
  ForgeHookProgress? _progress;
  ForgeActionResult? _result;

  /// Whether the hook runs now.
  bool get running => _cancellation != null;

  /// The last result, or null.
  ForgeActionResult? get result => _result;

  Future<void> _start() async {
    final confirmation = widget.confirmation;
    if (confirmation != null && !await forgeConfirm(context, confirmation)) {
      return;
    }
    if (!mounted) return;
    final cancellation = ForgeHookCancellation();
    setState(() {
      _cancellation = cancellation;
      _progress = null;
      _result = null;
    });
    configurationUiTrail('${widget.trailName}: run');
    ForgeActionResult result;
    try {
      result = await widget.run(cancellation, (progress) {
        if (mounted) setState(() => _progress = progress);
      });
    } on Object catch (error) {
      result = ForgeActionResult.failure(
        ForgeConfigurationTexts.hookFailed('$error'),
      );
    }
    if (cancellation.isCancelled &&
        result.outcome != ForgeActionOutcome.failure) {
      result = const ForgeActionResult.cancelled();
    }
    configurationUiTrail('${widget.trailName}: ${result.outcome.name}');
    if (!mounted) return;
    setState(() {
      _cancellation = null;
      _result = result;
    });
    widget.onResult?.call(result);
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }

  Widget _button() {
    final onPressed = widget.enabled && !running ? _start : null;
    final label = Text(widget.label);
    final icon = widget.icon == null ? null : Icon(widget.icon, size: 18);
    return switch (widget.emphasis) {
      ForgeActionEmphasis.primary =>
        icon == null
            ? FilledButton(onPressed: onPressed, child: label)
            : FilledButton.icon(onPressed: onPressed, icon: icon, label: label),
      ForgeActionEmphasis.normal =>
        icon == null
            ? OutlinedButton(onPressed: onPressed, child: label)
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: icon,
                label: label,
              ),
      ForgeActionEmphasis.subtle =>
        icon == null
            ? TextButton(onPressed: onPressed, child: label)
            : TextButton.icon(onPressed: onPressed, icon: icon, label: label),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final progress = _progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _button(),
            if (running)
              TextButton(
                onPressed: () => _cancellation?.cancel(),
                child: Text(
                  ForgeConfigurationLabels.resolveIn(
                    context,
                    ForgeConfigurationUiTexts.stop,
                  ),
                ),
              ),
          ],
        ),
        if (running)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                if (progress?.fraction != null)
                  SizedBox(
                    width: 120,
                    child: LinearProgressIndicator(value: progress!.fraction),
                  )
                else
                  const ForgeStatusLevelIcon(ForgeStatusLevel.busy, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ForgeConfigurationLabels.resolveIn(
                      context,
                      progress?.message ?? ForgeConfigurationUiTexts.running,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (!running && result != null && widget.showResult)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                ForgeStatusLevelIcon(switch (result.outcome) {
                  ForgeActionOutcome.success => ForgeStatusLevel.ok,
                  ForgeActionOutcome.failure => ForgeStatusLevel.error,
                  ForgeActionOutcome.cancelled => ForgeStatusLevel.unknown,
                }, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ForgeConfigurationLabels.resolveIn(
                      context,
                      result.message ??
                          switch (result.outcome) {
                            ForgeActionOutcome.success =>
                              ForgeConfigurationUiTexts.succeeded,
                            ForgeActionOutcome.failure =>
                              ForgeConfigurationUiTexts.failed,
                            ForgeActionOutcome.cancelled =>
                              ForgeConfigurationUiTexts.cancelled,
                          },
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: result.outcome == ForgeActionOutcome.failure
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The button of the action or flow [hookId] for [request]'s setting: an
/// action runs through the values service (`runAction`), a flow is driven in
/// a dialog (`startFlow`, [showForgeFlowDialog]); a result asking for a
/// refresh refreshes the setting's editors. A hook the registry lacks is
/// shown as a disabled button with the reason.
Widget forgeHookButtonFor(
  BuildContext context,
  ForgeSettingEditorRequest request,
  String hookId, {
  ForgeText? labelOverride,
  Key? key,
}) {
  final values = request.values;
  final setting = request.setting;
  final hooks = values?.hooks;
  final action = hooks?.action(hookId);
  final flow = action == null ? hooks?.flow(hookId) : null;
  void onResult(ForgeActionResult result) {
    if (result.refresh) request.requestRefresh?.call();
  }

  if (values != null && action != null) {
    final context0 = values.contextFor(setting);
    return ForgeHookButton(
      key: key ?? ValueKey('forge.configuration.hook.${setting.id}.$hookId'),
      label: ForgeConfigurationLabels.resolveIn(
        context,
        labelOverride ?? action.label,
      ),
      icon: action.icon == null ? null : forgeMaterialIconFor(action.icon!),
      emphasis: action.emphasis,
      confirmation: ForgeConfigurationLabels.resolveOrNullIn(
        context,
        action.confirmation,
      ),
      enabled: request.enabled && action.isEnabled(context0),
      trailName: 'action $hookId for ${setting.id}',
      run: (cancellation, onProgress) => values.runAction(
        setting,
        hookId,
        cancellation: cancellation,
        onProgress: onProgress,
      ),
      onResult: onResult,
    );
  }
  if (values != null && flow != null) {
    return ForgeHookButton(
      key: key ?? ValueKey('forge.configuration.hook.${setting.id}.$hookId'),
      label: ForgeConfigurationLabels.resolveIn(
        context,
        labelOverride ?? flow.label,
      ),
      icon: flow.icon == null ? null : forgeMaterialIconFor(flow.icon!),
      enabled: request.enabled,
      trailName: 'flow $hookId for ${setting.id}',
      run: (cancellation, onProgress) async {
        final session = values.startFlow(
          setting,
          hookId,
          cancellation: cancellation,
          onProgress: onProgress,
        );
        if (session == null) {
          return ForgeActionResult.failure(
            ForgeConfigurationTexts.hookMissing(hookId),
          );
        }
        return showForgeFlowDialog(
          context,
          session,
          title: ForgeConfigurationLabels.resolveIn(context, flow.label),
          trailName: 'flow $hookId',
        );
      },
      onResult: onResult,
    );
  }
  final theme = Theme.of(context);
  return Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton(
        onPressed: null,
        child: Text(
          labelOverride == null
              ? hookId
              : ForgeConfigurationLabels.resolveIn(context, labelOverride),
        ),
      ),
      Text(
        ForgeConfigurationLabels.resolveIn(
          context,
          ForgeConfigurationTexts.hookMissing(hookId),
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    ],
  );
}

/// The buttons of a setting's own actions (`ForgeSetting.actions`: actions
/// or flows), in order; nothing when it names none.
class ForgeSettingActionsBar extends StatelessWidget {
  const ForgeSettingActionsBar({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  Widget build(BuildContext context) {
    final ids = request.setting.actions;
    if (ids.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final id in ids) forgeHookButtonFor(context, request, id),
      ],
    );
  }
}

/// Calls [onRefresh] whenever [listenable] fires, for as long as the widget
/// using it lives: the editors' way to follow `ForgeSettingEditorRequest.refresh`.
mixin ForgeRefreshListener<T extends StatefulWidget> on State<T> {
  Listenable? _listened;

  /// The listenable followed now.
  Listenable? get refreshListenable;

  /// Reads the hooks again.
  void onRefresh();

  void _fire() {
    if (mounted) onRefresh();
  }

  /// Follows [refreshListenable] (call from `initState` and
  /// `didUpdateWidget`).
  void followRefresh() {
    final next = refreshListenable;
    if (identical(next, _listened)) return;
    _listened?.removeListener(_fire);
    _listened = next;
    _listened?.addListener(_fire);
  }

  @override
  void dispose() {
    _listened?.removeListener(_fire);
    super.dispose();
  }
}

/// Holds the latest of a sequence of asynchronous loads: a load started
/// after another makes the older one's answer be dropped.
class ForgeLatestLoad {
  int _generation = 0;

  /// Runs [load] and hands its answer to [onDone] unless a later load
  /// started meanwhile.
  Future<void> run<R>(
    Future<R> Function() load,
    void Function(R) onDone,
  ) async {
    final generation = ++_generation;
    final answer = await load();
    if (generation == _generation) onDone(answer);
  }

  /// Drops every load still running.
  void cancel() => _generation++;
}

/// A subscription kept while a widget lives, replaced by [listen].
class ForgeSubscriptionSlot {
  StreamSubscription<Object?>? _subscription;

  void listen<E>(Stream<E>? stream, void Function(E) onData) {
    _subscription?.cancel();
    _subscription = stream?.listen(onData);
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }
}
