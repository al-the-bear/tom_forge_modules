import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';

import '../../debug/md_editor_debug.dart';
import '../../theme/md_editor_theme.dart';
import '../../utils/md_code_highlighting.dart';

/// Overlay dialog for editing code blocks with syntax-aware controls.
class MdCodeBlockOverlay extends StatefulWidget {
  const MdCodeBlockOverlay({
    super.key,
    required this.code,
    this.language,
    required this.theme,
    required this.onSave,
    this.onCancel,
  });

  final String code;
  final String? language;
  final MdEditorTheme theme;
  final void Function(String code, String? language) onSave;
  final VoidCallback? onCancel;

  @override
  State<MdCodeBlockOverlay> createState() => _MdCodeBlockOverlayState();
}

class _MdCodeBlockOverlayState extends State<MdCodeBlockOverlay> {
  late TextEditingController _codeController;
  late TextEditingController _langController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.code);
    _langController = TextEditingController(text: widget.language ?? '');
    _codeController.addListener(_onChanged);
    _langController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _codeController.removeListener(_onChanged);
    _langController.removeListener(_onChanged);
    _codeController.dispose();
    _langController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;

    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        decoration: BoxDecoration(
          color: basic.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: basic.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(basic),
            Expanded(child: _buildCodeArea(basic)),
            _buildFooter(basic),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(MdBasicTheme basic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: basic.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Icon(Icons.code, size: 18, color: basic.accent),
          const SizedBox(width: 8),
          const Text('Edit Code Block'),
          const Spacer(),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _langController,
              decoration: InputDecoration(
                labelText: 'Language',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                labelStyle: TextStyle(
                  color: basic.textSecondary,
                  fontSize: 12,
                ),
              ),
              style: TextStyle(fontSize: 13, color: basic.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeArea(MdBasicTheme basic) {
    final normalized = MdCodeHighlighting.normalizeLanguage(
      _langController.text,
    );
    final syntaxTheme = MdCodeHighlighting.buildTheme(basic);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _codeController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontFamily: basic.monoFontFamily,
                fontSize: basic.baseFontSize,
                color: basic.text,
                height: basic.lineHeight,
              ),
              decoration: InputDecoration(
                labelText: 'Code',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: basic.border),
                ),
                contentPadding: EdgeInsets.all(basic.blockPadding),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: basic.codeBackground,
                borderRadius: BorderRadius.circular(basic.borderRadius),
                border: Border.all(color: basic.codeBorder),
              ),
              child: Padding(
                padding: EdgeInsets.all(basic.blockPadding),
                child: SingleChildScrollView(
                  child: normalized == null
                      ? SelectableText(
                          _codeController.text,
                          style: basic.codeStyle,
                        )
                      : HighlightView(
                          _codeController.text,
                          language: normalized,
                          theme: syntaxTheme,
                          padding: EdgeInsets.zero,
                          textStyle: basic.codeStyle,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(MdBasicTheme basic) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: basic.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _save() {
    try {
      final lang =
          _langController.text.trim().isEmpty
              ? null
              : _langController.text.trim();
      widget.onSave(_codeController.text, lang);
      Navigator.of(context).pop();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error saving code block', e, st);
    }
  }
}
