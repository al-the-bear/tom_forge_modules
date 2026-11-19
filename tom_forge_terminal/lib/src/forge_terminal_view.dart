import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:xterm/src/ui/input_map.dart' show keyToTerminalKey;
import 'package:xterm/xterm.dart' as xterm;

import 'package:tom_forge_shell/tom_forge_shell.dart';

import 'pty_terminal.dart';

/// View wrapper for a single terminal, used as a top-level section
/// in the bottom panel's accordion layout.
class SingleTerminalView extends ForgeView {
  final ForgeTerminal terminal;

  final _title = ValueNotifier<String>('');
  final _titleExtension = ValueNotifier<String?>(null);

  SingleTerminalView({required this.terminal}) {
    _title.value = terminal.name;
  }

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.terminal;

  @override
  bool get isDraggable => false;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(400, 200),
      );

  @override
  List<ForgeAction> get headerActions => [
    ForgeAction(
      id: 'terminal.clear',
      label: 'Clear Terminal',
      icon: Icons.delete_sweep,
      execute: (_) async {
        if (terminal is PtyTerminal) {
          (terminal as PtyTerminal).terminalModel.buffer.clear();
          (terminal as PtyTerminal).terminalModel.buffer.setCursor(0, 0);
        }
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    ),
    ForgeAction(
      id: 'terminal.kill',
      label: 'Kill Terminal',
      icon: Icons.stop_circle_outlined,
      execute: (_) async {
        terminal.close();
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    ),
  ];

  @override
  Widget buildMain(BuildContext context) {
    return _TerminalSectionContent(terminal: terminal);
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
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
  /// Outer focus node that we fully control.  This sits above xterm's
  /// internal Focus so that we can guarantee keyboard input reaches the
  /// terminal even when the widget is rendered inside the middle editor
  /// panel (where the scaffold's focus hierarchy may compete).
  final FocusNode _focusNode = FocusNode(debugLabel: 'TerminalSection');

  @override
  void initState() {
    super.initState();
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

  /// Forward a key event directly to the terminal model, replicating
  /// what xterm's `CustomKeyboardListener` does internally.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.terminal is! PtyTerminal) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final terminal = (widget.terminal as PtyTerminal).terminalModel;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    // Let copy / paste / select-all shortcuts fall through to xterm's
    // Shortcuts/Actions (they live below this Focus in the tree).
    if (isCtrl && !isAlt) {
      if ((isShift && event.logicalKey == LogicalKeyboardKey.keyC) ||
          event.logicalKey == LogicalKeyboardKey.keyV ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        return KeyEventResult.ignored;
      }
    }

    // Map the logical key to a terminal key.
    final key = keyToTerminalKey(event.logicalKey);
    if (key != null) {
      final handled = terminal.keyInput(
        key,
        ctrl: isCtrl,
        alt: isAlt,
        shift: isShift,
      );
      if (handled) return KeyEventResult.handled;
    }

    // Fallback: insert the key's character if available.
    if (event.character != null && event.character!.isNotEmpty) {
      terminal.textInput(event.character!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.terminal is PtyTerminal) {
      // Outer Focus that we control: receives all key events first and
      // forwards them to the terminal model directly.  This bypasses
      // xterm's internal Focus, which may fail to become primaryFocus
      // when the terminal is embedded in the middle editor panel.
      return Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (!_focusNode.hasFocus) _focusNode.requestFocus();
          },
          child: xterm.TerminalView(
            (widget.terminal as PtyTerminal).terminalModel,
            // Do NOT pass focusNode — let xterm create its own internal
            // node so there is no conflict with our outer Focus.
            autofocus: false,
            textStyle: const xterm.TerminalStyle(
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
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

