import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:xterm/xterm.dart' as xterm;

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../defaults/pty_terminal.dart';
import '../widgets/forge_drag_data.dart';

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

/// View wrapper for a single terminal, used when dragging an individual
/// terminal out of the accordion into another panel.
class _SingleTerminalView extends ForgeView {
  final ForgeTerminal terminal;

  final _title = ValueNotifier<String>('');
  final _titleExtension = ValueNotifier<String?>(null);

  _SingleTerminalView({required this.terminal}) {
    _title.value = terminal.name;
  }

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
    return _TerminalSectionContent(terminal: terminal);
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _TerminalContentState extends State<_TerminalContent> {
  StreamSubscription<ForgeTerminal>? _openSub;
  StreamSubscription<ForgeTerminal>? _closeSub;
  StreamSubscription<ForgeTerminal?>? _activeSub;

  /// Set of expanded terminals (tracked by reference).
  final Set<ForgeTerminal> _expandedTerminals = {};

  /// Convert expanded terminals to index-based set for the accordion widget.
  Set<int> get _expandedIndices {
    final terminals = widget.terminalManager.terminals;
    return {
      for (var i = 0; i < terminals.length; i++)
        if (_expandedTerminals.contains(terminals[i])) i,
    };
  }

  @override
  void initState() {
    super.initState();
    // Expand the first terminal if available.
    final terminals = widget.terminalManager.terminals;
    if (terminals.isNotEmpty) _expandedTerminals.add(terminals.first);

    _openSub = widget.terminalManager.onDidOpen.listen((newTerminal) {
      if (mounted) {
        setState(() {
          // Collapse all existing terminals and expand only the new one.
          _expandedTerminals.clear();
          _expandedTerminals.add(newTerminal);
        });
      }
    });
    _closeSub = widget.terminalManager.onDidClose.listen((closed) {
      if (mounted) {
        setState(() {
          final wasExpanded = _expandedTerminals.remove(closed);
          if (wasExpanded && _expandedTerminals.isEmpty) {
            final terminals = widget.terminalManager.terminals;
            if (terminals.isNotEmpty) {
              // Find the neighbor: prefer left, then right.
              // The closed terminal is already removed from the list,
              // so we use the terminal count to pick a neighbor.
              // Since indices shifted, just pick the last one (nearest to
              // where the removed one was).
              _expandedTerminals.add(terminals.last);
            }
          }
        });
      }
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

    // Horizontal accordion layout: each terminal is a horizontal section.
    return _TerminalAccordion(
      terminals: terminals,
      activeTerminal: widget.terminalManager.activeTerminal,
      expanded: _expandedIndices,
      onToggle: (index) {
        setState(() {
          final terminal = terminals[index];
          if (_expandedTerminals.contains(terminal)) {
            if (_expandedTerminals.length > 1) {
              _expandedTerminals.remove(terminal);
            }
          } else {
            // Collapse all, expand the new one.
            _expandedTerminals.clear();
            _expandedTerminals.add(terminal);
          }
        });
        widget.terminalManager.setActive(terminals[index]);
      },
      onClose: (terminal) => terminal.close(),
      onAdd: () => widget.terminalManager.create(),
    );
  }
}

/// Horizontal accordion layout for terminals.
/// Each terminal is a horizontal section; collapsed terminals appear as
/// narrow vertical strips with rotated text (matching the bottom panel
/// accordion style).
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < terminals.length; i++) ...[
          if (expanded.contains(i))
            Expanded(
              child: Column(
                children: [
                  Draggable<SectionDragData>(
                    data: SectionDragData(
                      section: _SingleTerminalView(
                          terminal: terminals[i]),
                      sourceIndex: i,
                      sourceArea: PanelArea.bottom,
                      sourceTabIndex: 0,
                      onRemoved: () => onClose(terminals[i]),
                    ),
                    feedback: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.terminal, size: 12,
                                color: Theme.of(context)
                                    .colorScheme.onSurface),
                            const SizedBox(width: 4),
                            Text(terminals[i].name,
                                style: Theme.of(context)
                                    .textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _TerminalSectionHeader(
                        terminal: terminals[i],
                        index: i,
                        isExpanded: true,
                        isActive: false,
                        onToggle: () {},
                        onClose: () {},
                        onAdd: () {},
                        isLast: false,
                      ),
                    ),
                    child: _TerminalSectionHeader(
                      terminal: terminals[i],
                      index: i,
                      isExpanded: true,
                      isActive: terminals[i] == activeTerminal,
                      onToggle: () => onToggle(i),
                      onClose: () => onClose(terminals[i]),
                      onAdd: onAdd,
                      isLast: i == terminals.length - 1,
                    ),
                  ),
                  Expanded(
                    child: _TerminalSectionContent(terminal: terminals[i]),
                  ),
                ],
              ),
            )
          else
            Draggable<SectionDragData>(
              data: SectionDragData(
                section: _SingleTerminalView(terminal: terminals[i]),
                sourceIndex: i,
                sourceArea: PanelArea.bottom,
                sourceTabIndex: 0,
                onRemoved: () => onClose(terminals[i]),
              ),
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.terminal, size: 12,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: 4),
                      Text(terminals[i].name,
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: _CollapsedTerminalStrip(
                  terminal: terminals[i],
                  isActive: false,
                  onTap: () {},
                  onClose: () {},
                ),
              ),
              child: _CollapsedTerminalStrip(
                terminal: terminals[i],
                isActive: terminals[i] == activeTerminal,
                onTap: () => onToggle(i),
                onClose: () => onClose(terminals[i]),
              ),
            ),
        ],
      ],
    );
  }
}

/// Narrow vertical strip for a collapsed terminal in the horizontal accordion.
class _CollapsedTerminalStrip extends StatefulWidget {
  final ForgeTerminal terminal;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _CollapsedTerminalStrip({
    required this.terminal,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_CollapsedTerminalStrip> createState() =>
      _CollapsedTerminalStripState();
}

class _CollapsedTerminalStripState extends State<_CollapsedTerminalStrip> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          decoration: BoxDecoration(
            color: _isHovering
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerHigh,
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Terminal icon at top.
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  Icons.terminal,
                  size: 12,
                  color: widget.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              // Rotated title text.
              Expanded(
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Text(
                      widget.terminal.name.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: _isHovering
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              // Close button at bottom.
              if (_isHovering)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4),
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

/// Horizontal header bar for an expanded terminal section.
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
          ),
          child: Row(
            children: [
              Icon(
                Icons.arrow_drop_down,
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
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
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
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
class _TerminalSectionContent extends StatefulWidget {
  final ForgeTerminal terminal;

  const _TerminalSectionContent({required this.terminal});

  @override
  State<_TerminalSectionContent> createState() =>
      _TerminalSectionContentState();
}

class _TerminalSectionContentState extends State<_TerminalSectionContent> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Explicitly request focus after the first frame to ensure the terminal
    // can receive keyboard input even when another widget already has focus
    // (e.g. when dragged into the middle panel where the scaffold's
    // Focus(autofocus: true) already holds focus).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.terminal is PtyTerminal) {
      return xterm.TerminalView(
        (widget.terminal as PtyTerminal).terminalModel,
        focusNode: _focusNode,
        autofocus: true,
        textStyle: const xterm.TerminalStyle(
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      );
    }
    return _FallbackTerminalContent(terminal: widget.terminal);
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

