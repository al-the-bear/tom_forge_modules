import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:xterm/src/ui/input_map.dart' show keyToTerminalKey;
import 'package:xterm/xterm.dart' as xterm;

import 'terminal_session.dart';
import 'terminal_style.dart';

/// Shows a [TomTerminalSession] and sends what the user types to its shell.
///
/// The view takes the keyboard focus when it appears ([autofocus]) and on a
/// tap, and forwards every key to the terminal itself, so typing reaches the
/// shell wherever the view is placed — also inside a host whose own focus
/// handling competes for the keys. Copy (Ctrl+Shift+C), paste (Ctrl+V) and
/// select all (Ctrl+A) stay xterm's. The view resizes the session's
/// pseudo-terminal to its size.
class TomTerminalView extends StatefulWidget {
  const TomTerminalView({
    super.key,
    required this.session,
    this.style = const TomTerminalStyle(),
    this.autofocus = true,
    this.padding,
    this.focusNode,
  });

  /// The session shown.
  final TomTerminalSession session;

  /// The font and colours.
  final TomTerminalStyle style;

  /// Whether the view takes the focus when it appears.
  final bool autofocus;

  /// Space around the text; null: xterm's default.
  final EdgeInsets? padding;

  /// The focus node the view's keys arrive at; null: the view's own.
  final FocusNode? focusNode;

  @override
  State<TomTerminalView> createState() => _TomTerminalViewState();
}

class _TomTerminalViewState extends State<TomTerminalView> {
  /// Outer focus node that we fully control. It sits above xterm's internal
  /// Focus so that keyboard input reaches the terminal even when the widget
  /// is placed where the host's focus hierarchy competes for it.
  FocusNode? _ownFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'TomTerminalView'));

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    super.dispose();
  }

  /// Forwards a key event directly to the terminal model, as xterm's
  /// `CustomKeyboardListener` does internally.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final terminal = widget.session.terminal;
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
    // Outer Focus that we control: receives all key events first and
    // forwards them to the terminal model directly. This bypasses xterm's
    // internal Focus, which may fail to become primaryFocus when the
    // terminal is embedded in a host's panel.
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (!_focusNode.hasFocus) _focusNode.requestFocus();
        },
        child: xterm.TerminalView(
          widget.session.terminal,
          // Do NOT pass focusNode — let xterm create its own internal node
          // so there is no conflict with our outer Focus.
          autofocus: false,
          padding: widget.padding,
          theme: widget.style.toXtermTheme(),
          textStyle: widget.style.toXtermTextStyle(),
        ),
      ),
    );
  }
}
