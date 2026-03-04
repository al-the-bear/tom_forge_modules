import 'package:flutter/material.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

/// Dummy Java editor used for `-java` keys.
///
/// Supports compact embedded mode and larger pop-out mode.
class JavaEditorStub extends StatefulWidget {
  final String code;
  final ValueChanged<Object?>? onChanged;
  final YamlEditorTheme theme;
  final bool fullUi;

  const JavaEditorStub({
    super.key,
    required this.code,
    required this.onChanged,
    required this.theme,
    this.fullUi = false,
  });

  @override
  State<JavaEditorStub> createState() => _JavaEditorStubState();
}

class _JavaEditorStubState extends State<JavaEditorStub> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.code);
  }

  @override
  void didUpdateWidget(JavaEditorStub oldWidget) {
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
      constraints: widget.fullUi
          ? const BoxConstraints(minHeight: 220)
          : const BoxConstraints(minHeight: 80, maxHeight: 220),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: Colors.orange.withAlpha(60)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: _textController,
          onChanged:
              widget.onChanged != null ? (v) => widget.onChanged!(v) : null,
          readOnly: widget.onChanged == null,
          maxLines: null,
          style: TextStyle(
            fontFamily: widget.theme.fonts.valueFontFamily,
            fontSize: widget.fullUi ? 13 : 12,
            color: widget.theme.colors.valueColor,
            height: 1.5,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText:
                'class Example {\n  public static void main(String[] args) {}\n}',
            hintStyle: TextStyle(color: widget.theme.colors.hintColor),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

/// Creates the [EditorSuffix] registration for the Java editor.
EditorSuffix javaEditorSuffix() {
  return EditorSuffix(
    suffix: 'java',
    label: 'Java Code',
    icon: Icons.coffee,
    factory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return JavaEditorStub(
        code: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
      );
    },
    supportsPopout: true,
    popoutTitle: 'Java Editor',
    popoutFactory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return JavaEditorStub(
        code: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
        fullUi: true,
      );
    },
  );
}
