import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';

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
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _lines = [];
  StreamSubscription<ForgeTerminal>? _openSub;
  StreamSubscription<ForgeTerminal>? _closeSub;
  StreamSubscription<ForgeTerminal?>? _activeSub;
  StreamSubscription<String>? _outputSub;

  @override
  void initState() {
    super.initState();
    _openSub = widget.terminalManager.onDidOpen.listen((_) {
      _rebindOutput();
      if (mounted) setState(() {});
    });
    _closeSub = widget.terminalManager.onDidClose.listen((_) {
      _rebindOutput();
      if (mounted) setState(() {});
    });
    _activeSub = widget.terminalManager.onDidChangeActive.listen((_) {
      _rebindOutput();
      if (mounted) setState(() {});
    });
    _rebindOutput();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _openSub?.cancel();
    _closeSub?.cancel();
    _activeSub?.cancel();
    _outputSub?.cancel();
    super.dispose();
  }

  void _rebindOutput() {
    _outputSub?.cancel();
    _outputSub = null;
    final active = widget.terminalManager.activeTerminal;
    if (active != null) {
      _outputSub = active.onOutput.listen((line) {
        if (mounted) {
          setState(() {
            _lines.add(line);
          });
          _scrollToBottom();
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sendCommand() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final terminal = widget.terminalManager.activeTerminal;
    if (terminal == null) return;
    terminal.sendText(text);
    _inputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final terminals = widget.terminalManager.terminals;
    final active = widget.terminalManager.activeTerminal;

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

    return Column(
      children: [
        // Terminal tab bar
        Container(
          height: 28,
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (final t in terminals)
                GestureDetector(
                  onTap: () => widget.terminalManager.setActive(t),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: t == active
                            ? Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.terminal,
                            size: 12,
                            color: t == active
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            t.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: t == active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: t == active
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => t.close(),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 14),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () => widget.terminalManager.create(),
                tooltip: 'New Terminal',
              ),
            ],
          ),
        ),
        // Output area
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
        // Input field
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
