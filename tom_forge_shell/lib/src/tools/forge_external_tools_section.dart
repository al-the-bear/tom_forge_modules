import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../services/forge_preferences_service.dart';
import '../shell/forge_shell_components.dart';
import 'external_tools_trail.dart';
import 'forge_external_tool.dart';

/// The Configuration panel's *External Tools* section: one row per tool the
/// modules registered ([ForgeExternalTool]), ordered by
/// [ForgeExternalTool.order]: its path (`forge.tools.<id>.path`; empty means
/// the tool's detection searches), the detected version and state, *Check
/// again* and *Auto-detect* (every copy the wider search finds, to pick one).
class ForgeExternalToolsSection extends StatefulWidget {
  /// The section over [tools], keeping their paths in [preferencesService].
  const ForgeExternalToolsSection({
    super.key,
    required this.tools,
    required this.preferencesService,
    this.onChanged,
    this.pickPath,
    this.filePickers,
  });

  /// The registered tools.
  final List<ForgeExternalTool> tools;

  /// Where the paths are kept.
  final ForgePreferencesService preferencesService;

  /// Called after a path was saved.
  final VoidCallback? onChanged;

  /// Picks a path for a tool (default: [filePickers]' file or folder
  /// dialog); `null` when cancelled. Tests give their own.
  final Future<String?> Function(ForgeExternalTool tool)? pickPath;

  /// The pickers the default [pickPath] uses: the shell's, else the
  /// registered ones ([ForgeShellComponents]).
  final ForgeFilePickers? filePickers;

  @override
  State<ForgeExternalToolsSection> createState() =>
      _ForgeExternalToolsSectionState();
}

class _ForgeExternalToolsSectionState extends State<ForgeExternalToolsSection> {
  Timer? _heartbeat;
  FlutterExceptionHandler? _previousOnError;

  @override
  void initState() {
    super.initState();
    if (kForgeExternalToolsDebug) {
      _previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        externalToolsTrail('FlutterError: ${details.exceptionAsString()}');
        _previousOnError?.call(details);
      };
      _heartbeat = Timer.periodic(
        const Duration(seconds: 1),
        (_) => externalToolsTrail('heartbeat'),
      );
    }
    externalToolsTrail('section open, ${widget.tools.length} tool(s)');
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    if (kForgeExternalToolsDebug) FlutterError.onError = _previousOnError;
    externalToolsTrail('section closed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = [...widget.tools]
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'External Tools',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Programs Forge uses from outside. An empty path means Forge '
          'searches the usual places.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (tools.isEmpty)
          Text(
            'No external tools are registered.',
            style: theme.textTheme.bodySmall,
          )
        else
          for (final tool in tools)
            _ToolRow(
              key: ValueKey('forge-tool-${tool.id}'),
              tool: tool,
              preferencesService: widget.preferencesService,
              onChanged: widget.onChanged,
              pickPath: widget.pickPath,
              filePickers:
                  widget.filePickers ??
                  ForgeShellComponents.registered.pickers,
            ),
      ],
    );
  }
}

/// One tool's row.
class _ToolRow extends StatefulWidget {
  const _ToolRow({
    super.key,
    required this.tool,
    required this.preferencesService,
    this.onChanged,
    this.pickPath,
    required this.filePickers,
  });

  final ForgeExternalTool tool;
  final ForgePreferencesService preferencesService;
  final VoidCallback? onChanged;
  final Future<String?> Function(ForgeExternalTool tool)? pickPath;
  final ForgeFilePickers filePickers;

  @override
  State<_ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends State<_ToolRow> {
  late final TextEditingController _path = TextEditingController(
    text: widget.preferencesService.externalToolPath(widget.tool.id) ?? '',
  );
  ForgeToolCopy? _result;
  bool _checking = false;
  bool _detecting = false;
  List<ForgeToolCopy>? _detected;
  String? _error;

  ForgeExternalTool get _tool => widget.tool;
  String get _id => _tool.id;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  String? get _savedPath => widget.preferencesService.externalToolPath(_id);

  bool get _edited => _path.text.trim() != (_savedPath ?? '');

  /// Runs the tool's detection with the saved path.
  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    externalToolsTrail('$_id: check (${_savedPath ?? 'search'})');
    try {
      final result = await _tool.check(_savedPath);
      externalToolsTrail('$_id: ${result.state.name} ${result.version ?? ''}');
      if (mounted) setState(() => _result = result);
    } catch (e, s) {
      externalToolsReport(e, s, 'checking ${_tool.name}');
      if (mounted) setState(() => _error = 'The check failed: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Saves the path in the field (empty: search) and checks again.
  Future<void> _save([String? path]) async {
    final value = (path ?? _path.text).trim();
    _path.text = value;
    externalToolsTrail('$_id: save path ${value.isEmpty ? '(search)' : value}');
    await widget.preferencesService.setExternalToolPath(_id, value);
    widget.onChanged?.call();
    await _check();
  }

  Future<void> _autoDetect() async {
    setState(() {
      _detecting = true;
      _detected = null;
      _error = null;
    });
    externalToolsTrail('$_id: auto-detect');
    try {
      final copies = await _tool.autoDetect();
      externalToolsTrail('$_id: auto-detect found ${copies.length}');
      if (mounted) setState(() => _detected = copies);
    } catch (e, s) {
      externalToolsReport(e, s, 'auto-detecting ${_tool.name}');
      if (mounted) setState(() => _error = 'Auto-detect failed: $e');
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _choose() async {
    final pick = widget.pickPath;
    final String? path;
    if (pick != null) {
      path = await pick(_tool);
    } else if (_tool.pathIsDirectory) {
      path = await widget.filePickers.pickFolder(
        title: 'Choose ${_tool.name}',
      );
    } else {
      final result = await widget.filePickers.pickFiles(
        title: 'Choose ${_tool.name}',
      );
      path = result.isEmpty ? null : result.first;
    }
    if (path == null || !mounted) return;
    externalToolsTrail('$_id: chosen $path');
    await _save(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final busy = _checking || _detecting;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _tool.name,
                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                ),
                const SizedBox(width: 8),
                if (_checking)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (result != null)
                  _StateChip(
                    key: ValueKey('forge-tool-$_id-state'),
                    copy: result,
                  ),
                const Spacer(),
                if (result?.version != null)
                  Text(
                    result!.version!,
                    key: ValueKey('forge-tool-$_id-version'),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
            if (result != null && result.path.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _savedPath == null ? 'Found: ${result.path}' : result.path,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (result?.reason != null && !result!.usable)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  result.reason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (result != null &&
                (result.state == ForgeToolState.missing ||
                    result.state == ForgeToolState.tooOld) &&
                _tool.downloadUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SelectableText(
                  'Download: ${_tool.downloadUrl}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('forge-tool-$_id-path'),
                    controller: _path,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: 'Search (or the ${_tool.pathHint})',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => unawaited(_save()),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: ValueKey('forge-tool-$_id-save'),
                  onPressed: busy || !_edited ? null : () => unawaited(_save()),
                  child: const Text('Save'),
                ),
                TextButton(
                  key: ValueKey('forge-tool-$_id-choose'),
                  onPressed: busy ? null : () => unawaited(_choose()),
                  child: const Text('Choose…'),
                ),
              ],
            ),
            Row(
              children: [
                TextButton.icon(
                  key: ValueKey('forge-tool-$_id-check'),
                  onPressed: busy ? null : () => unawaited(_check()),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Check again'),
                ),
                TextButton.icon(
                  key: ValueKey('forge-tool-$_id-detect'),
                  onPressed: busy ? null : () => unawaited(_autoDetect()),
                  icon: const Icon(Icons.travel_explore, size: 16),
                  label: const Text('Auto-detect'),
                ),
                if (_detecting)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            if (_detected != null) _detectedList(theme, _detected!),
          ],
        ),
      ),
    );
  }

  Widget _detectedList(ThemeData theme, List<ForgeToolCopy> copies) {
    if (copies.isEmpty) {
      return Text(
        'No copy of ${_tool.name} was found.',
        key: ValueKey('forge-tool-$_id-none-found'),
        style: theme.textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Found:', style: theme.textTheme.bodySmall),
        for (final (i, copy) in copies.indexed)
          ListTile(
            key: ValueKey('forge-tool-$_id-found-$i'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              copy.path,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (copy.version != null) copy.version!,
                _stateLabel(copy.state),
                if (copy.reason != null && !copy.usable) copy.reason!,
              ].join(' · '),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: TextButton(
              key: ValueKey('forge-tool-$_id-use-$i'),
              onPressed: () {
                setState(() => _detected = null);
                unawaited(_save(copy.path));
              },
              child: const Text('Use'),
            ),
          ),
      ],
    );
  }
}

String _stateLabel(ForgeToolState state) => switch (state) {
  ForgeToolState.found => 'Found',
  ForgeToolState.missing => 'Not found',
  ForgeToolState.tooOld => 'Too old',
  ForgeToolState.damaged => 'Cannot be used',
  ForgeToolState.quarantined => 'Not opened yet',
};

class _StateChip extends StatelessWidget {
  const _StateChip({super.key, required this.copy});

  final ForgeToolCopy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = copy.usable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: ok ? scheme.primaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _stateLabel(copy.state),
        style: TextStyle(
          fontSize: 11,
          color: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
        ),
      ),
    );
  }
}
