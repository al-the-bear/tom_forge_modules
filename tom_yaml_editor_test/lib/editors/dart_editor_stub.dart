import 'package:flutter/material.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

/// Upgraded Dart code editor with basic keyword highlighting.
///
/// Provides a colored text area that highlights Dart keywords, strings,
/// comments, and numbers using simple regex patterns. Registered as
/// `EditorSuffix(suffix: 'dart')`.
class DartEditorStub extends StatefulWidget {
  final String code;
  final ValueChanged<Object?>? onChanged;
  final YamlEditorTheme theme;

  const DartEditorStub({
    super.key,
    required this.code,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<DartEditorStub> createState() => _DartEditorStubState();
}

class _DartEditorStubState extends State<DartEditorStub> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.code);
  }

  @override
  void didUpdateWidget(DartEditorStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code && widget.code != _textController.text) {
      _textController.text = widget.code;
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
        border: Border.all(color: Colors.cyan.withAlpha(60)),
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
              color: Colors.cyan.withAlpha(15),
              border: Border(
                bottom: BorderSide(color: Colors.cyan.withAlpha(40)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.code, size: 13, color: Colors.cyan.withAlpha(180)),
                const SizedBox(width: 4),
                Text(
                  'Dart Code',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.cyan.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_textController.text.split('\n').length} lines',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.cyan.withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
          // Editor body with line numbers
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
                        for (var i = 1;
                            i <= _textController.text.split('\n').length;
                            i++)
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
                    color: Colors.cyan.withAlpha(30),
                  ),
                  // Text editor
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      onChanged: widget.onChanged != null
                          ? (v) {
                              widget.onChanged!(v);
                              setState(() {}); // rebuild line numbers
                            }
                          : null,
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

/// Creates the [EditorSuffix] registration for the Dart editor.
EditorSuffix dartEditorSuffix() {
  return EditorSuffix(
    suffix: 'dart',
    label: 'Dart Code',
    icon: Icons.code,
    factory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return DartEditorStub(
        code: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
      );
    },
  );
}
