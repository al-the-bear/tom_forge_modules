import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'website_control_controller.dart';
import 'website_control_log.dart';

/// Forge view for the control panel (§5): one action button per configured
/// command, a levelled + filterable message log, and a status line.
///
/// All state lives in the [WebsiteControlController]; this view only renders it
/// and drives it on tap. The controller is owned by the module (created in
/// `activate`, disposed in `deactivate`) — the view does not dispose it.
class WebsiteControlView extends ForgeView {
  WebsiteControlView({required this.controller});

  /// Drives command dispatch, the message log, and the status line.
  final WebsiteControlController controller;

  final _title = ValueNotifier<String>('Control');
  final _titleExtension = ValueNotifier<String?>(null);

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.play_circle_outline;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        minSize: Size(420, 320),
        preferredSize: Size(560, 640),
      );

  @override
  Widget buildMain(BuildContext context) =>
      _ControlContent(controller: controller, title: _title);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// Stateful body that rebuilds on controller changes, keeps the [title] in sync,
/// and owns the (view-local) log level filter.
class _ControlContent extends StatefulWidget {
  const _ControlContent({required this.controller, required this.title});

  final WebsiteControlController controller;
  final ValueNotifier<String> title;

  @override
  State<_ControlContent> createState() => _ControlContentState();
}

class _ControlContentState extends State<_ControlContent> {
  final Set<WebsiteLogLevel> _visibleLevels = {...WebsiteLogLevel.values};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _syncTitle();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _syncTitle();
    setState(() {});
  }

  void _syncTitle() {
    final id = widget.controller.activeWebsiteId;
    widget.title.value = id == null ? 'Control' : 'Control: $id';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(context),
        _buildButtons(context),
        const Divider(height: 1),
        _buildFilters(context),
        Expanded(child: _buildLog(context)),
        const Divider(height: 1),
        _buildStatusLine(context),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          if (controller.websites.isNotEmpty)
            DropdownButton<String>(
              value: controller.activeWebsiteId,
              isDense: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final website in controller.websites)
                  DropdownMenuItem(
                    value: website.id,
                    child: Text(website.label ?? website.id),
                  ),
              ],
              onChanged: (id) {
                if (id != null) controller.selectWebsite(id);
              },
            ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            tooltip: 'Copy log',
            onPressed: _visibleEntries().isEmpty ? null : _copyLog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            tooltip: 'Clear log',
            onPressed: controller.log.isEmpty ? null : controller.clearLog,
          ),
        ],
      ),
    );
  }

  /// Copies the currently visible log entries (one per line) to the clipboard.
  /// Drag-selection across lines is also possible via the [SelectionArea] around
  /// the log; this button is the quick "copy everything shown" affordance.
  Future<void> _copyLog() async {
    final text = _visibleEntries().map((e) => e.message).join('\n');
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
  }

  Widget _buildButtons(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final button in controller.buttons)
            if (button.name == WebsiteControlController.serveCommand)
              ..._buildServerControls(button)
            else
              _buildCommandButton(button),
        ],
      ),
    );
  }

  Widget _buildCommandButton(WebsiteCommandButton button) {
    final controller = widget.controller;
    return ElevatedButton.icon(
      icon: button.isRunning
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow, size: 16),
      label: Text(button.label),
      onPressed: button.isAvailable && !button.isRunning
          ? () => controller.runCommand(button.name)
          : null,
    );
  }

  /// The dev-server (`serveStart`) controls: a start/stop toggle and, while
  /// running, a restart button. Unlike one-shot commands the server is a
  /// long-lived child, so it is driven by [WebsiteControlController.startServer]
  /// / `stopServer` / `restartServer` rather than `runCommand`.
  List<Widget> _buildServerControls(WebsiteCommandButton button) {
    final controller = widget.controller;
    final running = controller.isServerRunning;
    return [
      ElevatedButton.icon(
        icon: Icon(running ? Icons.stop : Icons.play_arrow, size: 16),
        label: Text(running ? 'Stop dev server' : 'Start dev server'),
        onPressed: !button.isAvailable
            ? null
            : (running ? controller.stopServer : controller.startServer),
      ),
      if (running)
        IconButton(
          icon: const Icon(Icons.restart_alt, size: 18),
          tooltip: 'Restart dev server',
          onPressed: controller.restartServer,
        ),
    ];
  }

  Widget _buildFilters(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (final level in WebsiteLogLevel.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_levelLabel(level)),
                selected: _visibleLevels.contains(level),
                onSelected: (selected) => setState(() {
                  if (selected) {
                    _visibleLevels.add(level);
                  } else {
                    _visibleLevels.remove(level);
                  }
                }),
              ),
            ),
        ],
      ),
    );
  }

  /// The log entries currently shown, after the level filter (pinned errors
  /// always survive). Shared by the log view and the "Copy log" action.
  List<WebsiteLogEntry> _visibleEntries() => widget.controller.log
      // Pinned errors stay visible even when their level is filtered out.
      .where((e) => e.pinned || _visibleLevels.contains(e.level))
      .toList();

  Widget _buildLog(BuildContext context) {
    final entries = _visibleEntries();
    if (entries.isEmpty) {
      return const Center(child: Text('No output yet.'));
    }
    // SelectionArea lets the user drag-select across multiple log lines (and
    // copy with the platform shortcut); each line renders plain Text so the
    // selection spans them instead of being trapped per-line.
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: entries.length,
        itemBuilder: (context, index) => _LogLine(entry: entries[index]),
      ),
    );
  }

  Widget _buildStatusLine(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final id = controller.activeWebsiteId ?? '—';
    final errors = controller.errorCount;
    final warnings = controller.warningCount;
    final parts = <String>[
      id,
      'server: ${controller.isServerRunning ? 'running' : 'stopped'}',
      '$errors error${errors == 1 ? '' : 's'}',
      '$warnings warning${warnings == 1 ? '' : 's'}',
    ];
    final last = controller.lastRunAt;
    if (last != null) {
      parts.add('last run ${_formatTime(last)}');
    }
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        parts.join('  ·  '),
        style: theme.textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static String _levelLabel(WebsiteLogLevel level) => switch (level) {
        WebsiteLogLevel.info => 'Info',
        WebsiteLogLevel.warning => 'Warning',
        WebsiteLogLevel.error => 'Error',
      };

  static String _formatTime(DateTime t) =>
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// Renders a single log entry, coloured by level and marked when pinned.
class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry});

  final WebsiteLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (entry.level) {
      WebsiteLogLevel.info => theme.colorScheme.onSurface,
      WebsiteLogLevel.warning => theme.colorScheme.tertiary,
      WebsiteLogLevel.error => theme.colorScheme.error,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.pinned)
            Padding(
              padding: const EdgeInsets.only(right: 4, top: 2),
              child: Icon(Icons.push_pin, size: 12, color: color),
            ),
          Expanded(
            child: Text(
              entry.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
