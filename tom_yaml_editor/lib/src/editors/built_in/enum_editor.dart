import 'package:flutter/material.dart';

import '../../schema/yaml_schema.dart';
import '../../yaml_editor_theme.dart';

/// Inline editor for enum-constrained values.
///
/// Adapts its rendering to the number of choices:
/// - **≤4 values**: Segmented buttons (all visible at once).
/// - **5–8 values**: Dropdown menu.
/// - **>8 values**: Searchable dropdown with type-ahead filtering.
///
/// ```dart
/// EnumEditor(
///   value: 'info',
///   schemaNode: SchemaNode(
///     type: SchemaType.string,
///     enumValues: ['debug', 'info', 'warning', 'error'],
///   ),
///   onChanged: (v) => controller.setValue(path, v),
///   theme: YamlEditorTheme.dark(),
/// )
/// ```
class EnumEditor extends StatefulWidget {
  /// Current value.
  final Object? value;

  /// Schema node containing `enumValues`.
  final SchemaNode? schemaNode;

  /// Callback when the value changes.
  final ValueChanged<Object?>? onChanged;

  /// Whether the editor is read-only.
  final bool readOnly;

  /// Theme for styling.
  final YamlEditorTheme theme;

  const EnumEditor({
    super.key,
    this.value,
    this.schemaNode,
    this.onChanged,
    this.readOnly = false,
    this.theme = const YamlEditorTheme(),
  });

  @override
  State<EnumEditor> createState() => _EnumEditorState();
}

class _EnumEditorState extends State<EnumEditor> {
  String _searchQuery = '';

  List<Object> get _enumValues =>
      widget.schemaNode?.enumValues ?? const <Object>[];

  @override
  Widget build(BuildContext context) {
    var values = _enumValues;
    if (values.isEmpty) {
      return Text(
        widget.value?.toString() ?? 'null',
        style: TextStyle(color: widget.theme.colors.valueColor),
      );
    }

    if (values.length <= 4) {
      return _buildSegmentedButtons(values);
    } else if (values.length <= 8) {
      return _buildDropdown(values);
    } else {
      return _buildSearchableDropdown(values);
    }
  }

  Widget _buildSegmentedButtons(List<Object> values) {
    var colors = widget.theme.colors;
    var fonts = widget.theme.fonts;
    var currentStr = widget.value?.toString();

    return Wrap(
      spacing: 4,
      children: values.map((v) {
        var label = v.toString();
        var isSelected = label == currentStr;

        return GestureDetector(
          onTap: widget.readOnly ? null : () => widget.onChanged?.call(v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isSelected ? colors.keyColor.withAlpha(40) : colors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? colors.keyColor : colors.surface,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: fonts.valueFontFamily,
                fontSize: fonts.valueFontSize,
                fontWeight:
                    isSelected ? FontWeight.w600 : fonts.valueFontWeight,
                color: isSelected ? colors.keyColor : colors.valueColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdown(List<Object> values) {
    var colors = widget.theme.colors;
    var fonts = widget.theme.fonts;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.surface, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _findMatchingValue(values),
          isDense: true,
          isExpanded: false,
          dropdownColor: colors.surface,
          style: TextStyle(
            fontFamily: fonts.valueFontFamily,
            fontSize: fonts.valueFontSize,
            color: colors.valueColor,
          ),
          onChanged: widget.readOnly
              ? null
              : (v) {
                  if (v == null) return;
                  // Try to preserve type from enum values
                  var original = values.firstWhere(
                    (e) => e.toString() == v,
                    orElse: () => v,
                  );
                  widget.onChanged?.call(original);
                },
          items: values.map((v) {
            return DropdownMenuItem<String>(
              value: v.toString(),
              child: Text(v.toString()),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchableDropdown(List<Object> values) {
    var colors = widget.theme.colors;
    var fonts = widget.theme.fonts;

    var filtered = _searchQuery.isEmpty
        ? values
        : values
            .where((v) =>
                v.toString().toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (q) => setState(() => _searchQuery = q),
          style: TextStyle(
            fontFamily: fonts.valueFontFamily,
            fontSize: fonts.valueFontSize,
            color: colors.valueColor,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            hintText: 'Search ${values.length} options…',
            hintStyle: TextStyle(
              fontSize: fonts.valueFontSize,
              color: colors.hintColor,
            ),
            prefixIcon: Icon(Icons.search, size: 16, color: colors.hintColor),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 28, minHeight: 0),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colors.surface, width: 1),
            ),
          ),
        ),
        if (filtered.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemExtent: 28,
              itemBuilder: (context, index) {
                var v = filtered[index];
                var label = v.toString();
                var isSelected = label == widget.value?.toString();

                return GestureDetector(
                  onTap:
                      widget.readOnly ? null : () => widget.onChanged?.call(v),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: isSelected
                        ? colors.keyColor.withAlpha(30)
                        : Colors.transparent,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: fonts.valueFontFamily,
                        fontSize: fonts.valueFontSize,
                        color: isSelected ? colors.keyColor : colors.valueColor,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : fonts.valueFontWeight,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Find the matching dropdown value, or null if the current value isn't
  /// in the enum list.
  String? _findMatchingValue(List<Object> values) {
    var currentStr = widget.value?.toString();
    if (currentStr == null) return null;
    for (var v in values) {
      if (v.toString() == currentStr) return currentStr;
    }
    return null;
  }
}
