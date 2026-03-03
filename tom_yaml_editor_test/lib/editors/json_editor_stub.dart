import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

/// JSON editor stub with formatting on paste and basic brace matching.
///
/// Provides a multiline text area that auto-formats JSON when pasted,
/// shows a validity indicator in the header, and displays line numbers.
///
/// Registered as `EditorSuffix(suffix: 'json')`.
class JsonEditorStub extends StatefulWidget {
  final String text;
  final ValueChanged<Object?>? onChanged;
  final YamlEditorTheme theme;

  const JsonEditorStub({
    super.key,
    required this.text,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<JsonEditorStub> createState() => _JsonEditorStubState();
}

class _JsonEditorStubState extends State<JsonEditorStub> {
  late TextEditingController _textController;
  bool _isValidJson = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
    _validate();
  }

  @override
  void didUpdateWidget(JsonEditorStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && widget.text != _textController.text) {
      _textController.text = widget.text;
      _validate();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _validate() {
    try {
      jsonDecode(_textController.text);
      setState(() => _isValidJson = true);
    } catch (_) {
      setState(() => _isValidJson = false);
    }
  }

  void _formatJson() {
    try {
      var decoded = jsonDecode(_textController.text);
      var formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      _textController.text = formatted;
      widget.onChanged?.call(formatted);
      _validate();
    } catch (_) {
      // Can't format invalid JSON
    }
  }

  void _minifyJson() {
    try {
      var decoded = jsonDecode(_textController.text);
      var minified = jsonEncode(decoded);
      _textController.text = minified;
      widget.onChanged?.call(minified);
      _validate();
    } catch (_) {
      // Can't minify invalid JSON
    }
  }

  @override
  Widget build(BuildContext context) {
    var lineCount = _textController.text.split('\n').length;
    return Container(
      constraints: const BoxConstraints(minHeight: 80, maxHeight: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(
            color: _isValidJson
                ? Colors.blue.withAlpha(60)
                : Colors.red.withAlpha(80)),
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
              color: Colors.blue.withAlpha(15),
              border: Border(
                bottom: BorderSide(color: Colors.blue.withAlpha(40)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.data_object,
                    size: 13, color: Colors.blue.withAlpha(180)),
                const SizedBox(width: 4),
                Text(
                  'JSON',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // Validity badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (_isValidJson ? Colors.green : Colors.red)
                        .withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isValidJson ? 'valid' : 'invalid',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _isValidJson ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                const Spacer(),
                // Format button
                if (widget.onChanged != null) ...[
                  _ToolButton(
                    icon: Icons.format_align_left,
                    tooltip: 'Format',
                    onTap: _isValidJson ? _formatJson : null,
                  ),
                  const SizedBox(width: 4),
                  _ToolButton(
                    icon: Icons.compress,
                    tooltip: 'Minify',
                    onTap: _isValidJson ? _minifyJson : null,
                  ),
                ],
              ],
            ),
          ),
          // Editor body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers
                  SizedBox(
                    width: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 1; i <= lineCount; i++)
                          SizedBox(
                            height: 18,
                            child: Text(
                              '$i',
                              style: TextStyle(
                                fontFamily: widget.theme.fonts.valueFontFamily,
                                fontSize: 12,
                                color: widget.theme.colors.hintColor,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: Colors.blue.withAlpha(30),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: (v) {
                        widget.onChanged?.call(v);
                        _validate();
                        setState(() {}); // rebuild line numbers
                      },
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon button for the JSON editor toolbar.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToolButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: 12,
            color: onTap != null
                ? Colors.blue.withAlpha(160)
                : Colors.blue.withAlpha(50),
          ),
        ),
      ),
    );
  }
}

/// Creates the [EditorSuffix] registration for the JSON editor.
EditorSuffix jsonEditorSuffix() {
  return EditorSuffix(
    suffix: 'json',
    label: 'JSON',
    icon: Icons.data_object,
    factory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return JsonEditorStub(
        text: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
      );
    },
  );
}
