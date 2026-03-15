import 'package:flutter/material.dart';

import '../../debug/md_editor_debug.dart';
import '../../theme/md_editor_theme.dart';
import '../renderers/md_mermaid_renderer.dart';

/// Overlay dialog for editing Mermaid diagram source.
class MdMermaidOverlay extends StatefulWidget {
  const MdMermaidOverlay({
    super.key,
    required this.initialSource,
    required this.theme,
  });

  final String initialSource;
  final MdEditorTheme theme;

  /// Shows the Mermaid overlay as a dialog and returns the edited
  /// source string, or null if cancelled.
  static Future<String?> show({
    required BuildContext context,
    required MdEditorTheme theme,
    String initialSource = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => MdMermaidOverlay(
        initialSource: initialSource,
        theme: theme,
      ),
    );
  }

  @override
  State<MdMermaidOverlay> createState() => _MdMermaidOverlayState();
}

class _MdMermaidOverlayState extends State<MdMermaidOverlay> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialSource);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      final basic = widget.theme.basic;
      return Dialog(
        backgroundColor: basic.surface,
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.schema, size: 18, color: basic.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Mermaid Diagram',
                    style: TextStyle(
                      color: basic.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                maxLines: 12,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Enter Mermaid diagram source...',
                  hintStyle: TextStyle(color: basic.textMuted),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: basic.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: basic.border),
                  ),
                ),
                style: TextStyle(
                  fontFamily: basic.monoFontFamily,
                  fontSize: basic.baseFontSize,
                  color: basic.text,
                  height: basic.lineHeight,
                ),
              ),
              const SizedBox(height: 12),
              // Hint about supported types
              Text(
                'Supported: ${kMermaidDiagramTypes.join(', ')}',
                style: TextStyle(
                  color: basic.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: basic.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, _controller.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: basic.accent,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error building Mermaid overlay', e, st);
      return const SizedBox.shrink();
    }
  }
}
