import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The widget key of the command list's row for [actionId]:
/// `forge.commandList.<actionId>`.
Key forgeCommandListEntryKey(String actionId) =>
    ValueKey('forge.commandList.$actionId');

/// The kit's actions as a list to choose from ([ForgeCommandListModel]): a
/// filter field on top, the visible actions below with their keys, the
/// first one highlighted. Typing narrows the list; arrow up and down move
/// the highlight; Enter or a click runs the action through
/// `api.executeAction` and then calls [onRun]; a disabled action is shown
/// but not run.
///
/// A body without a frame of its own: a palette, a dialog or a side area
/// hosts it.
class ForgeCommandList extends StatefulWidget {
  const ForgeCommandList({
    super.key,
    required this.api,
    this.onRun,
    this.placeholder = 'Type a command',
    this.autofocus = true,
    this.maxHeight = 320,
  });

  final ForgeKitApi api;

  /// Called with the id of an action after it ran (the host closes its
  /// palette, say).
  final void Function(String actionId)? onRun;

  /// The filter field's hint.
  final String placeholder;

  /// Whether the filter field takes the focus when shown.
  final bool autofocus;

  /// The list's height at most.
  final double maxHeight;

  @override
  State<ForgeCommandList> createState() => _ForgeCommandListState();
}

class _ForgeCommandListState extends State<ForgeCommandList> {
  final TextEditingController _query = TextEditingController();
  late ForgeCommandListModel _model = ForgeCommandListModel.of(widget.api);
  int _highlight = 0;

  @override
  void didUpdateWidget(ForgeCommandList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _model = ForgeCommandListModel.of(widget.api, query: _query.text);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filter(String query) => setState(() {
    _model = ForgeCommandListModel.of(widget.api, query: query);
    _highlight = 0;
  });

  void _run(ForgeActionState command) {
    if (!command.enabled) return;
    widget.api.executeAction(command.id);
    widget.onRun?.call(command.id);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final count = _model.commands.length;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && count > 0) {
      setState(() => _highlight = (_highlight + 1).clamp(0, count - 1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && count > 0) {
      setState(() => _highlight = (_highlight - 1).clamp(0, count - 1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commands = _model.commands;
    return Focus(
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              key: const ValueKey('forge.commandList.filter'),
              controller: _query,
              autofocus: widget.autofocus,
              onChanged: _filter,
              onSubmitted: (_) {
                if (commands.isNotEmpty) _run(commands[_highlight]);
              },
              decoration: InputDecoration(
                hintText: widget.placeholder,
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: commands.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No matching commands',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: commands.length,
                    itemBuilder: (context, index) =>
                        _buildRow(context, commands[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, ForgeActionState command, int index) {
    final theme = Theme.of(context);
    final highlighted = index == _highlight;
    final color = command.enabled
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurface.withValues(alpha: 0.4);
    return InkWell(
      key: forgeCommandListEntryKey(command.id),
      onTap: command.enabled ? () => _run(command) : null,
      child: Container(
        color: highlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            if (command.icon != null) ...[
              Icon(command.icon, size: 16, color: color),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                command.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: highlighted ? FontWeight.w600 : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (command.shortcut != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  command.shortcut!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
