import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_terminal_view/tom_terminal_view.dart';

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
  ForgeComponentSizeHints get sizeHints =>
      const ForgeComponentSizeHints(preferredSize: Size(400, 200));

  @override
  List<ForgeAction> get headerActions => [
    ForgeAction(
      id: 'terminal.clear',
      label: 'Clear Terminal',
      icon: Icons.delete_sweep,
      execute: (_) async {
        final terminal = this.terminal;
        if (terminal is PtyTerminal) terminal.session.clear();
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

/// Content area for a single terminal section: a PTY terminal's session in
/// a [TomTerminalView], any other terminal as lines of text.
class _TerminalSectionContent extends StatelessWidget {
  final ForgeTerminal terminal;

  const _TerminalSectionContent({required this.terminal});

  static const TomTerminalStyle _style = TomTerminalStyle(
    fontSize: 13,
    fontFamily: 'monospace',
  );

  @override
  Widget build(BuildContext context) {
    final terminal = this.terminal;
    if (terminal is PtyTerminal) {
      return TomTerminalView(session: terminal.session, style: _style);
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
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
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
