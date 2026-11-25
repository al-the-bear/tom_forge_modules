import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../configuration_ui_trail.dart';
import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';
import '../forge_setting_editor_registry.dart';
import 'hook_widgets.dart';

// The editors of the kinds that are behaviour more than a value: an action
// button, a status line and an external tool's path.

/// An action entry (`ForgeActionSetting`): the button of its action (run
/// through the values service's `runAction`) or its flow (driven in a
/// dialog), with progress and result ([forgeHookButtonFor]).
class ForgeActionEditor extends StatelessWidget {
  const ForgeActionEditor({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  Widget build(BuildContext context) {
    final setting = request.setting as ForgeActionSetting;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: forgeHookButtonFor(
        context,
        request,
        setting.action ?? setting.flow!,
        labelOverride: setting.buttonLabel,
      ),
    );
  }
}

/// A status entry (`ForgeStatusSetting`): what its status provider answers
/// (`statusOf`), followed while shown when the provider streams it
/// (`watchStatus`), read again when a refresh is asked for.
class ForgeStatusEditor extends StatefulWidget {
  const ForgeStatusEditor({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  State<ForgeStatusEditor> createState() => _ForgeStatusEditorState();
}

class _ForgeStatusEditorState extends State<ForgeStatusEditor>
    with ForgeRefreshListener<ForgeStatusEditor> {
  final ForgeLatestLoad _load = ForgeLatestLoad();
  final ForgeSubscriptionSlot _watch = ForgeSubscriptionSlot();
  ForgeStatusInfo _status = ForgeStatusInfo.busy;

  ForgeStatusSetting get _setting =>
      widget.request.setting as ForgeStatusSetting;

  @override
  Listenable? get refreshListenable => widget.request.refresh;

  @override
  void initState() {
    super.initState();
    followRefresh();
    final values = widget.request.values;
    final stream = values?.watchStatus(_setting);
    if (stream != null) {
      configurationUiTrail('status ${_setting.status}: watch');
      _watch.listen<ForgeStatusInfo>(stream, (status) {
        configurationUiTrail(
          'status ${_setting.status}: ${status.level.name} (stream)',
        );
        _load.cancel();
        if (mounted) setState(() => _status = status);
      });
    }
    _read();
  }

  @override
  void didUpdateWidget(covariant ForgeStatusEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    followRefresh();
  }

  @override
  void onRefresh() => _read();

  @override
  void dispose() {
    _watch.cancel();
    _load.cancel();
    super.dispose();
  }

  Future<void> _read() async {
    final values = widget.request.values;
    if (values == null) {
      setState(() => _status = ForgeStatusInfo.unknown);
      return;
    }
    configurationUiTrail('status ${_setting.status}: read');
    await _load.run(() => values.statusOf(_setting), (status) {
      configurationUiTrail('status ${_setting.status}: ${status.level.name}');
      if (mounted) setState(() => _status = status);
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.request.label,
    child: ForgeStatusView(
      status: _status,
      showItems: _setting.showItems,
      maxItems: _setting.maxItems,
    ),
  );
}

/// An external tool's path (`ForgeToolPathSetting`): the path in a text
/// field (empty: found automatically), *Browse…* (the application's path
/// picker), *Detect* (the detector's wide search with the setting's hints,
/// its progress and a *Stop*; the candidates listed with their state,
/// version and source, each with *Use*), *Check again*, and a status line —
/// the detector's check of the path in effect (or what the usual search
/// finds while it is empty), read when shown (`checkWhenShown`), after the
/// path changed and when a refresh is asked for. While the tool is not
/// usable the application's help panel (`helpPanel`) is shown under it.
class ForgeToolPathEditor extends StatefulWidget {
  const ForgeToolPathEditor({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  State<ForgeToolPathEditor> createState() => _ForgeToolPathEditorState();
}

class _ForgeToolPathEditorState extends State<ForgeToolPathEditor>
    with ForgeRefreshListener<ForgeToolPathEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.request.value as String,
  );
  final ForgeLatestLoad _checks = ForgeLatestLoad();
  Timer? _debounce;
  ForgeDetectedCandidate? _state;
  bool _checking = false;
  List<ForgeDetectedCandidate>? _candidates;

  ForgeToolPathSetting get _setting =>
      widget.request.setting as ForgeToolPathSetting;

  @override
  Listenable? get refreshListenable => widget.request.refresh;

  @override
  void initState() {
    super.initState();
    followRefresh();
    if (_setting.checkWhenShown) _check();
  }

  @override
  void didUpdateWidget(covariant ForgeToolPathEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    followRefresh();
    final value = widget.request.value as String;
    if (value != oldWidget.request.value) {
      if (value != _controller.text.trim()) _controller.text = value;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _check);
    }
  }

  @override
  void onRefresh() => _check();

  @override
  void dispose() {
    _debounce?.cancel();
    _checks.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final values = widget.request.values;
    if (values == null || !mounted) return;
    setState(() => _checking = true);
    final value = widget.request.value as String;
    configurationUiTrail('check ${_setting.detector} "$value"');
    await _checks.run(() => values.checkToolPath(_setting, value: value), (
      found,
    ) {
      configurationUiTrail('check ${_setting.detector}: ${found.level.name}');
      if (mounted) {
        setState(() {
          _state = found;
          _checking = false;
        });
      }
    });
  }

  void _use(String path) {
    configurationUiTrail('use candidate "$path" for ${_setting.id}');
    _controller.text = path;
    setState(() => _candidates = null);
    widget.request.onChanged(path);
  }

  Future<void> _browse() async {
    final pick = widget.request.pickPath;
    if (pick == null) return;
    final setting = _setting;
    final chosen = await pick(
      ForgePathSetting(
        id: setting.id,
        storage: setting.storage,
        label: setting.label,
        pathKind: setting.pathKind,
        hint: setting.hint,
      ),
      _controller.text,
    );
    if (chosen != null && mounted) _use(chosen);
  }

  Widget _stateLine(BuildContext context) {
    final theme = Theme.of(context);
    final state = _state;
    if (_checking && state == null) {
      return const ForgeStatusView(status: ForgeStatusInfo.busy);
    }
    if (state == null) return const SizedBox.shrink();
    final value = (widget.request.value as String).trim();
    final parts = <String>[
      if (state.message != null)
        ForgeConfigurationLabels.resolve(state.message!)
      else if (state.reason != null)
        state.reason!,
      if (state.version != null)
        ForgeConfigurationLabels.resolve(
          ForgeConfigurationUiTexts.version(state.version!),
        ),
    ];
    return Row(
      key: ValueKey('forge.configuration.toolPath.state.${_setting.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: ForgeStatusLevelIcon(
            _checking ? ForgeStatusLevel.busy : state.level,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (parts.isNotEmpty)
                Text(parts.join(' · '), style: theme.textTheme.bodySmall),
              if (!state.isMissing && state.value != value)
                SelectableText(
                  state.source == null
                      ? state.value
                      : '${state.value} (${state.source})',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _candidateList(BuildContext context) {
    final theme = Theme.of(context);
    final candidates = _candidates!;
    if (candidates.isEmpty) {
      return Text(
        ForgeConfigurationLabels.resolve(
          ForgeConfigurationUiTexts.noCandidates,
        ),
        style: theme.textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, candidate) in candidates.indexed)
          Container(
            key: ValueKey('forge.configuration.toolPath.candidate.$i'),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                ForgeStatusLevelIcon(candidate.level),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        candidate.isMissing
                            ? (candidate.reason ?? '')
                            : candidate.value,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        [
                          if (candidate.version != null)
                            ForgeConfigurationLabels.resolve(
                              ForgeConfigurationUiTexts.version(
                                candidate.version!,
                              ),
                            ),
                          if (candidate.source != null) candidate.source!,
                          if (candidate.message != null)
                            ForgeConfigurationLabels.resolve(
                              candidate.message!,
                            ),
                          if (!candidate.isMissing && candidate.reason != null)
                            candidate.reason!,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!candidate.isMissing)
                  TextButton(
                    onPressed: widget.request.enabled
                        ? () => _use(candidate.value)
                        : null,
                    child: Text(
                      ForgeConfigurationLabels.resolve(
                        ForgeConfigurationUiTexts.use,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final setting = _setting;
    final values = r.values;
    final state = _state;
    final helpPanel = setting.helpPanel;
    final help =
        state != null &&
            !state.usable &&
            !_checking &&
            helpPanel != null &&
            r.buildHelpPanel != null
        ? r.buildHelpPanel!(
            context,
            helpPanel,
            setting,
            r.requestRefresh ?? () {},
          )
        : null;
    return Semantics(
      label: r.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: r.enabled,
                  decoration: InputDecoration(
                    isDense: r.style.dense,
                    hintText: ForgeConfigurationLabels.resolveOrNull(
                      setting.hint,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: r.onChanged,
                ),
              ),
              if (r.pickPath != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: r.enabled ? _browse : null,
                  child: Text(
                    ForgeConfigurationLabels.resolve(
                      ForgeConfigurationUiTexts.browse,
                    ),
                  ),
                ),
              ],
              IconButton(
                key: ValueKey(
                  'forge.configuration.toolPath.check.${setting.id}',
                ),
                tooltip: ForgeConfigurationLabels.resolve(
                  ForgeConfigurationUiTexts.checkAgain,
                ),
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: values == null || _checking ? null : _check,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _stateLine(context),
          if (help != null) ...[const SizedBox(height: 4), help],
          const SizedBox(height: 4),
          if (values != null)
            ForgeHookButton(
              key: ValueKey(
                'forge.configuration.toolPath.detect.${setting.id}',
              ),
              label: ForgeConfigurationLabels.resolve(
                ForgeConfigurationUiTexts.detect,
              ),
              icon: Icons.search,
              emphasis: ForgeActionEmphasis.subtle,
              enabled: r.enabled,
              showResult: false,
              trailName: 'detect ${setting.detector}',
              run: (cancellation, onProgress) async {
                setState(() => _candidates = null);
                final found = await values.detectToolPath(
                  setting,
                  cancellation: cancellation,
                  onProgress: onProgress,
                );
                configurationUiTrail(
                  'detect ${setting.detector}: ${found.length} candidates',
                );
                if (cancellation.isCancelled) {
                  return const ForgeActionResult.cancelled();
                }
                if (mounted) setState(() => _candidates = found);
                return const ForgeActionResult.success();
              },
            ),
          if (_candidates != null) ...[
            const SizedBox(height: 4),
            _candidateList(context),
          ],
        ],
      ),
    );
  }
}
