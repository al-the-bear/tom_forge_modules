import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../defaults/pty_terminal.dart';

/// Terminal view with tab selector and monospace output display.
///
/// Takes [ForgeTerminalManager] and shows the active terminal's output.
class ForgeTerminalView extends ForgeView {
  final ForgeTerminalManager terminalManager;

  final _title = ValueNotifier<String>('Terminal');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeTerminalView({required this.terminalManager});

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.terminal;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(400, 200),
      );

  @override
  Widget buildMain(BuildContext context) {
    return _TerminalContent(terminalManager: terminalManager);
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _TerminalContent extends StatefulWidget {
  final ForgeTerminalManager terminalManager;

  const _TerminalContent({required this.terminalManager});

  @override
  State<_TerminalContent> createState() => _TerminalContentState();
}

class _TerminalContentState extends State<_TerminalContent> {
  StreamSubscription<ForgeTerminal>? _openSub;
  StreamSubscription<ForgeTerminal>? _closeSub;
  StreamSubscription<ForgeTerminal?>? _activeSub;

  /// Set of expanded terminal indices.
  final Set<int> _expanded = {0};

  @override
  void initState() {
    super.initState();
    _openSub = widget.terminalManager.onDidOpen.listen((_) {
      if (mounted) {
        setState(() {
          // Auto-expand newly added terminal.
          final idx = widget.terminalManager.terminals.length - 1;
          if (idx >= 0) _expanded.add(idx);
        });
      }
    });
    _closeSub = widget.terminalManager.onDidClose.listen((_) {
      if (mounted) setState(() {});
    });
    _activeSub = widget.terminalManager.onDidChangeActive.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _openSub?.cancel();
    _closeSub?.cancel();
    _activeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terminals = widget.terminalManager.terminals;

    if (terminals.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No terminals',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Terminal'),
              onPressed: () => widget.terminalManager.create(),
            ),
          ],
        ),
      );
    }

    // Accordion layout: each terminal is an expandable section.
    return Column(
      children: [
        Expanded(
          child: _TerminalAccordion(
            terminals: terminals,
            activeTerminal: widget.terminalManager.activeTerminal,
            expanded: _expanded,
            onToggle: (index) {
              setState(() {
                if (_expanded.contains(index)) {
                  _expanded.remove(index);
                } else {
                  _expanded.add(index);
                }
              });
              widget.terminalManager.setActive(terminals[index]);
            },
            onClose: (terminal) => terminal.close(),
            onAdd: () => widget.terminalManager.create(),
          ),
        ),
      ],
    );
  }
}

/// Accordion layout for terminals.
/// Each terminal has a collapsible header and an expanded content area.
class _TerminalAccordion extends StatelessWidget {
  final List<ForgeTerminal> terminals;
  final ForgeTerminal? activeTerminal;
  final Set<int> expanded;
  final void Function(int index) onToggle;
  final void Function(ForgeTerminal terminal) onClose;
  final VoidCallback onAdd;

  const _TerminalAccordion({
    required this.terminals,
    required this.activeTerminal,
    required this.expanded,
    required this.onToggle,
    required this.onClose,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasExpanded = expanded.isNotEmpty;

    return Column(
      children: [
        for (var i = 0; i < terminals.length; i++) ...[
          _TerminalSectionHeader(
            terminal: terminals[i],
            index: i,
            isExpanded: expanded.contains(i),
            isActive: terminals[i] == activeTerminal,
            onToggle: () => onToggle(i),
            onClose: () => onClose(terminals[i]),
            onAdd: onAdd,
            isLast: i == terminals.length - 1,
          ),
          if (expanded.contains(i))
            Expanded(
              child: _TerminalSectionContent(terminal: terminals[i]),
            ),
        ],
        // If nothing is expanded, fill remaining space.
        if (!hasExpanded) const Spacer(),
        // Add button row at bottom if no terminals are expanded.
        if (!hasExpanded)
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: onAdd,
                  tooltip: 'New Terminal',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Accordion section header for a single terminal.
class _TerminalSectionHeader extends StatelessWidget {
  final ForgeTerminal terminal;
  final int index;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onToggle;
  final VoidCallback onClose;
  final VoidCallback onAdd;
  final bool isLast;

  const _TerminalSectionHeader({
    required this.terminal,
    required this.index,
    required this.isExpanded,
    required this.isActive,
    required this.onToggle,
    required this.onClose,
    required this.onAdd,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Draggable<_TerminalDragData>(
      data: _TerminalDragData(terminal: terminal, index: index),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF252526),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.terminal, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(terminal.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildHeader(context, theme),
      ),
      child: _buildHeader(context, theme),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return GestureDetector(
      onTap: onToggle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.terminal,
                size: 12,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  terminal.name,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Add terminal button (only show on last header or when expanded)
              if (isLast)
                GestureDetector(
                  onTap: onAdd,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.add,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onTap: onClose,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Content area for a single terminal section.
class _TerminalSectionContent extends StatelessWidget {
  final ForgeTerminal terminal;

  const _TerminalSectionContent({required this.terminal});

  @override
  Widget build(BuildContext context) {
    if (terminal is PtyTerminal) {
      return xterm.TerminalView(
        (terminal as PtyTerminal).terminalModel,
        autofocus: true,
        textStyle: const xterm.TerminalStyle(
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      );
    }
    return _FallbackTerminalContent(terminal: terminal);
  }
}

/// Text-based fallback terminal for non-PTY implementations.
class _FallbackTerminalContent extends StatefulWidget {
  final ForgeTerminal terminal;

  const _FallbackTerminalContent({required this.terminal});

  @override
  State<_FallbackTerminalContent> createState() =>
      _FallbackTerminalContentState();
}

class _FallbackTerminalContentState extends State<_FallbackTerminalContent> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _lines = [];
  StreamSubscription<String>? _outputSub;

  @override
  void initState() {
    super.initState();
    _outputSub = widget.terminal.onOutput.listen((line) {
      if (mounted) {
        setState(() => _lines.add(line));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _outputSub?.cancel();
    super.dispose();
  }

  void _sendCommand() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    widget.terminal.sendText(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.all(4),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _lines.length,
              itemBuilder: (context, index) => Text(
                _lines[index],
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Text(
                '\$ ',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: (_) => _sendCommand(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Internal drag data for dragging a terminal to another panel.
class _TerminalDragData {
  final ForgeTerminal terminal;
  final int index;
  const _TerminalDragData({required this.terminal, required this.index});
}
