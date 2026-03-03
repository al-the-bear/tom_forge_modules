import 'package:flutter/material.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

/// Upgraded Markdown editor with preview/edit toggle.
///
/// In **edit mode**, shows a multiline text area with monospace font.
/// In **preview mode**, renders a simplified markdown view with support for
/// headers, bold, italic, code blocks, and bullet lists.
///
/// Registered as `EditorSuffix(suffix: 'markdown')`.
class MarkdownEditorStub extends StatefulWidget {
  final String text;
  final ValueChanged<Object?>? onChanged;
  final YamlEditorTheme theme;

  const MarkdownEditorStub({
    super.key,
    required this.text,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<MarkdownEditorStub> createState() => _MarkdownEditorStubState();
}

class _MarkdownEditorStubState extends State<MarkdownEditorStub> {
  late TextEditingController _textController;
  bool _isPreview = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
  }

  @override
  void didUpdateWidget(MarkdownEditorStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && widget.text != _textController.text) {
      _textController.text = widget.text;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: Colors.amber.withAlpha(60)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(15),
              border: Border(
                bottom: BorderSide(color: Colors.amber.withAlpha(40)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_note,
                    size: 13, color: Colors.amber.withAlpha(180)),
                const SizedBox(width: 4),
                Text(
                  'Markdown',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Toggle button
                InkWell(
                  onTap: () => setState(() => _isPreview = !_isPreview),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _isPreview
                          ? Colors.amber.withAlpha(30)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPreview ? Icons.edit : Icons.visibility,
                          size: 12,
                          color: Colors.amber.withAlpha(140),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _isPreview ? 'Edit' : 'Preview',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber.withAlpha(140),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Flexible(
            child: _isPreview ? _buildPreview() : _buildEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _textController,
        onChanged:
            widget.onChanged != null ? (v) => widget.onChanged!(v) : null,
        readOnly: widget.onChanged == null,
        maxLines: null,
        style: TextStyle(
          fontFamily: widget.theme.fonts.valueFontFamily,
          fontSize: 12,
          color: widget.theme.colors.valueColor,
          height: 1.5,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    var lines = _textController.text.split('\n');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map(_renderLine).toList(),
      ),
    );
  }

  Widget _renderLine(String line) {
    var trimmed = line.trimLeft();

    // Headers
    if (trimmed.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          trimmed.substring(4),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.amber.shade200,
          ),
        ),
      );
    }
    if (trimmed.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          trimmed.substring(3),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.amber.shade100,
          ),
        ),
      );
    }
    if (trimmed.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(
          trimmed.substring(2),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.amber.shade50,
          ),
        ),
      );
    }

    // Bullet list
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ',
                style: TextStyle(
                    color: Colors.amber.shade300, fontWeight: FontWeight.bold)),
            Expanded(child: _renderInline(trimmed.substring(2))),
          ],
        ),
      );
    }

    // Empty line
    if (trimmed.isEmpty) return const SizedBox(height: 8);

    // Normal paragraph
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: _renderInline(trimmed),
    );
  }

  /// Very simple inline markdown: **bold**, *italic*, `code`.
  Widget _renderInline(String text) {
    var spans = <InlineSpan>[];
    var buffer = StringBuffer();
    var i = 0;

    while (i < text.length) {
      // Bold **text**
      if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
        if (buffer.isNotEmpty) {
          spans.add(InlineSpan(buffer.toString()));
          buffer.clear();
        }
        var end = text.indexOf('**', i + 2);
        if (end != -1) {
          spans.add(InlineSpan(text.substring(i + 2, end), bold: true));
          i = end + 2;
          continue;
        }
      }
      // Inline code `code`
      if (text[i] == '`') {
        if (buffer.isNotEmpty) {
          spans.add(InlineSpan(buffer.toString()));
          buffer.clear();
        }
        var end = text.indexOf('`', i + 1);
        if (end != -1) {
          spans.add(InlineSpan(text.substring(i + 1, end), code: true));
          i = end + 1;
          continue;
        }
      }
      // Italic *text*
      if (text[i] == '*' && (i + 1 >= text.length || text[i + 1] != '*')) {
        if (buffer.isNotEmpty) {
          spans.add(InlineSpan(buffer.toString()));
          buffer.clear();
        }
        var end = text.indexOf('*', i + 1);
        if (end != -1) {
          spans.add(InlineSpan(text.substring(i + 1, end), italic: true));
          i = end + 1;
          continue;
        }
      }
      buffer.write(text[i]);
      i++;
    }
    if (buffer.isNotEmpty) spans.add(InlineSpan(buffer.toString()));

    return RichText(
      text: TextSpan(
        children: spans.map((s) {
          return TextSpan(
            text: s.text,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: s.code
                  ? Colors.amber.shade200
                  : widget.theme.colors.valueColor,
              fontWeight: s.bold ? FontWeight.w700 : FontWeight.normal,
              fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
              fontFamily: s.code ? widget.theme.fonts.valueFontFamily : null,
              backgroundColor: s.code ? Colors.amber.withAlpha(15) : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Simple inline span data for rendering.
class InlineSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  const InlineSpan(this.text,
      {this.bold = false, this.italic = false, this.code = false});
}

/// Creates the [EditorSuffix] registration for the Markdown editor.
EditorSuffix markdownEditorSuffix() {
  return EditorSuffix(
    suffix: 'markdown',
    label: 'Markdown',
    icon: Icons.edit_note,
    factory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return MarkdownEditorStub(
        text: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
      );
    },
  );
}
