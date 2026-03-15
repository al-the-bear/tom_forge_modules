import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../debug/md_editor_debug.dart';
import '../../theme/md_editor_theme.dart';

/// Overlay dialog for editing LaTeX math expressions with live preview.
class MdMathOverlay extends StatefulWidget {
  const MdMathOverlay({
    super.key,
    required this.initialLatex,
    required this.theme,
    this.isBlock = false,
  });

  final String initialLatex;
  final MdEditorTheme theme;
  final bool isBlock;

  /// Shows the math overlay as a dialog and returns the edited LaTeX
  /// string, or null if cancelled.
  static Future<String?> show({
    required BuildContext context,
    required MdEditorTheme theme,
    String initialLatex = '',
    bool isBlock = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => MdMathOverlay(
        initialLatex: initialLatex,
        theme: theme,
        isBlock: isBlock,
      ),
    );
  }

  @override
  State<MdMathOverlay> createState() => _MdMathOverlayState();
}

class _MdMathOverlayState extends State<MdMathOverlay> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialLatex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;
    return Dialog(
      backgroundColor: basic.surface,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isBlock ? 'Edit Block Math' : 'Edit Inline Math',
              style: TextStyle(
                color: basic.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: widget.isBlock ? 5 : 1,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Enter LaTeX expression...',
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
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: basic.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: basic.border),
              ),
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              child: _buildPreview(basic),
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
                  onPressed: () => Navigator.pop(context, _controller.text),
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
  }

  Widget _buildPreview(MdBasicTheme basic) {
    try {
      final text = _controller.text;
      if (text.isEmpty) {
        return Text(
          'Preview will appear here...',
          style: TextStyle(color: basic.textMuted, fontStyle: FontStyle.italic),
        );
      }
      return Math.tex(
        text,
        textStyle: TextStyle(color: basic.text, fontSize: basic.baseFontSize),
        onErrorFallback: (err) => Text(
          err.message,
          style: TextStyle(color: basic.error, fontSize: 12),
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error in math preview', e, st);
      return Text('Preview error', style: TextStyle(color: basic.error));
    }
  }
}
