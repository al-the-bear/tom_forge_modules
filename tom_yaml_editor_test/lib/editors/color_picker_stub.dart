import 'package:flutter/material.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

/// Color picker stub with hex input and color swatch preview.
///
/// Shows a hex color input field with a live swatch preview beside it.
/// Supports 3, 4, 6, and 8 digit hex values (with or without `#` prefix).
///
/// Registered as `EditorSuffix(suffix: 'color')` and also via an
/// [EditorResolver] to match any key containing "color".
class ColorPickerStub extends StatefulWidget {
  final String value;
  final ValueChanged<Object?>? onChanged;
  final YamlEditorTheme theme;

  const ColorPickerStub({
    super.key,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  State<ColorPickerStub> createState() => _ColorPickerStubState();
}

class _ColorPickerStubState extends State<ColorPickerStub> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(ColorPickerStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        widget.value != _textController.text) {
      _textController.text = widget.value;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Color? _parseColor(String text) {
    var hex = text.trim().replaceFirst('#', '');
    if (hex.isEmpty) return null;

    try {
      switch (hex.length) {
        case 3:
          // RGB shorthand → RRGGBB
          hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
          return Color(int.parse('FF$hex', radix: 16));
        case 4:
          // ARGB shorthand
          hex =
              '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}';
          return Color(int.parse(hex, radix: 16));
        case 6:
          return Color(int.parse('FF$hex', radix: 16));
        case 8:
          return Color(int.parse(hex, radix: 16));
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    var parsedColor = _parseColor(_textController.text);
    var isValid = parsedColor != null;
    var accentColor = Colors.purple;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: accentColor.withAlpha(60)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(15),
              border: Border(
                bottom: BorderSide(color: accentColor.withAlpha(40)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.palette,
                    size: 11, color: accentColor.withAlpha(180)),
                const SizedBox(width: 3),
                Text(
                  'Color',
                  style: TextStyle(
                    fontSize: 10,
                    color: accentColor.withAlpha(180),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isValid)
                  Text(
                    'rgba(${(parsedColor.r * 255).round()}, ${(parsedColor.g * 255).round()}, '
                    '${(parsedColor.b * 255).round()}, ${parsedColor.a.toStringAsFixed(2)})',
                    style: TextStyle(
                      fontSize: 9,
                      color: widget.theme.colors.hintColor,
                      fontFamily: widget.theme.fonts.valueFontFamily,
                    ),
                  ),
              ],
            ),
          ),
          // Input row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Color swatch
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: parsedColor ?? Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isValid
                          ? parsedColor.withAlpha(200)
                          : Colors.grey.withAlpha(60),
                    ),
                  ),
                  child: isValid
                      ? null
                      : Icon(Icons.block,
                          size: 10, color: Colors.grey.withAlpha(80)),
                ),
                const SizedBox(width: 6),
                // Hex input
                Text(
                  '#',
                  style: TextStyle(
                    fontFamily: widget.theme.fonts.valueFontFamily,
                    fontSize: 12,
                    color: accentColor.withAlpha(180),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onChanged: (v) {
                      widget.onChanged?.call(v);
                      setState(() {});
                    },
                    readOnly: widget.onChanged == null,
                    style: TextStyle(
                      fontFamily: widget.theme.fonts.valueFontFamily,
                      fontSize: 12,
                      color: isValid
                          ? widget.theme.colors.valueColor
                          : Colors.red.shade300,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'FF5733',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: widget.theme.colors.hintColor.withAlpha(80),
                        fontFamily: widget.theme.fonts.valueFontFamily,
                      ),
                    ),
                  ),
                ),
                // Quick presets
                if (widget.onChanged != null) ...[
                  _SwatchButton(
                      color: Colors.red, onTap: () => _setColor('FF0000')),
                  _SwatchButton(
                      color: Colors.green, onTap: () => _setColor('00FF00')),
                  _SwatchButton(
                      color: Colors.blue, onTap: () => _setColor('0000FF')),
                  _SwatchButton(
                      color: Colors.amber, onTap: () => _setColor('FFC107')),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setColor(String hex) {
    _textController.text = hex;
    widget.onChanged?.call(hex);
    setState(() {});
  }
}

/// Small circular color swatch button.
class _SwatchButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _SwatchButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
        ),
      ),
    );
  }
}

/// Creates the [EditorSuffix] registration for the Color editor.
EditorSuffix colorEditorSuffix() {
  return EditorSuffix(
    suffix: 'color',
    label: 'Color',
    icon: Icons.palette,
    factory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return ColorPickerStub(
        value: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
      );
    },
  );
}

/// Creates an [EditorResolver] that matches any key containing "color"
/// regardless of suffix convention.
EditorResolver colorEditorResolver(EditorSuffix colorEditor) {
  return (String key, List<String> path, String? schemaEditorType) {
    if (key.toLowerCase().contains('color')) return colorEditor;
    return null;
  };
}
