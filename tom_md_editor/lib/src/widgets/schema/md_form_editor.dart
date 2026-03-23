import 'package:flutter/material.dart';
import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;

import '../../theme/md_editor_theme.dart';

/// Widget that renders form-format section content as editable fields.
///
/// When a section has `format: form <form-type>`, this widget replaces
/// the raw text with structured input widgets: text fields, dropdowns
/// (for fields matching custom-tag values), and date pickers.
class MdFormEditor extends StatefulWidget {
  const MdFormEditor({
    super.key,
    required this.formType,
    required this.currentValues,
    required this.onChanged,
    required this.theme,
    this.customTags = const {},
    this.readOnly = false,
    this.requiredFields = const [],
    this.textPatternCheck,
    this.useListPrefix = false,
  });

  /// The form type definition from the schema.
  final specs.FormTypeDef formType;

  /// Current field values parsed from the section text.
  final Map<String, String> currentValues;

  /// Called when any field value changes, with the full map of values.
  final ValueChanged<Map<String, String>> onChanged;

  /// Editor theme.
  final MdEditorTheme theme;

  /// Custom tags from the schema for dropdown suggestions.
  final Map<String, dynamic> customTags;

  /// Field names that are required.
  final List<String> requiredFields;

  /// Whether the form is read-only.
  final bool readOnly;

  /// Whether to use `- ` prefix when serializing form content.
  ///
  /// Set to true if the original section text uses list-item format.
  final bool useListPrefix;

  /// Optional section-type-level text pattern check.
  ///
  /// When set, the serialized form text is validated against this pattern
  /// on every change and a banner error is shown if it does not match.
  final specs.PatternCheckDef? textPatternCheck;

  /// Parse form field values from raw section text.
  ///
  /// Expects lines like `- FieldName: value` or `FieldName: value`.
  /// Keys are normalized to lowercase for case-insensitive matching
  /// with schema field names.
  static Map<String, String> parseFormContent(String text) {
    final values = <String, String>{};
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trimLeft();
      // Strip leading "- " if present.
      final content = trimmed.startsWith('- ') ? trimmed.substring(2) : trimmed;
      final colonIdx = content.indexOf(':');
      if (colonIdx > 0) {
        final key = content.substring(0, colonIdx).trim().toLowerCase();
        final value = content.substring(colonIdx + 1).trim();
        if (key.isNotEmpty) {
          values[key] = value;
        }
      }
    }
    return values;
  }

  /// Serialize form field values back to markdown text.
  ///
  /// When [useListPrefix] is true, each line is prefixed with `- `.
  /// Default is false (plain `Key: value` lines).
  static String serializeFormContent(
    Map<String, String> values,
    specs.FormTypeDef formType, {
    bool useListPrefix = false,
  }) {
    final prefix = useListPrefix ? '- ' : '';
    final buffer = StringBuffer();
    for (final field in formType.fields) {
      final value = values[field.fieldname] ?? '';
      buffer.writeln('$prefix${field.fieldname}: $value');
    }
    return buffer.toString().trimRight();
  }

  @override
  State<MdFormEditor> createState() => _MdFormEditorState();
}

class _MdFormEditorState extends State<MdFormEditor> {
  late Map<String, TextEditingController> _controllers;
  final Map<String, String?> _fieldErrors = {};
  String? _textPatternError;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (final field in widget.formType.fields) {
      _controllers[field.fieldname] = TextEditingController(
        text: widget.currentValues[field.fieldname] ?? '',
      );
    }
  }

  @override
  void didUpdateWidget(MdFormEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentValues != oldWidget.currentValues) {
      for (final field in widget.formType.fields) {
        final newVal = widget.currentValues[field.fieldname] ?? '';
        if (_controllers[field.fieldname]?.text != newVal) {
          _controllers[field.fieldname]?.text = newVal;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() {
    final values = <String, String>{};
    for (final field in widget.formType.fields) {
      final text = _controllers[field.fieldname]?.text ?? '';
      if (text.isNotEmpty) {
        values[field.fieldname] = text;
      }
      _validateField(field, text);
    }
    _validateTextPattern(values);
    widget.onChanged(values);
  }

  /// Validate the serialized form text against the section-type pattern.
  void _validateTextPattern(Map<String, String> values) {
    final check = widget.textPatternCheck;
    if (check == null) {
      if (_textPatternError != null) {
        setState(() => _textPatternError = null);
      }
      return;
    }
    final serialized = MdFormEditor.serializeFormContent(
      values,
      widget.formType,
      useListPrefix: widget.useListPrefix,
    );
    String? error;
    try {
      final regex = RegExp(check.pattern);
      if (serialized.isNotEmpty && !regex.hasMatch(serialized)) {
        error = check.errorMessage;
      }
    } catch (_) {
      // Invalid regex — skip.
    }
    if (_textPatternError != error) {
      setState(() => _textPatternError = error);
    }
  }

  /// Validate a single field and set its error message in [_fieldErrors].
  void _validateField(specs.FormFieldDef field, String value) {
    String? error;
    final isRequired = (field.required ?? false) ||
        widget.requiredFields.contains(field.fieldname);

    if (isRequired && value.trim().isEmpty) {
      error = '${field.fieldname} is required';
    } else if (value.isNotEmpty && field.patternCheck != null) {
      final pattern = field.patternCheck!.pattern;
      try {
        final regex = RegExp(pattern);
        if (!regex.hasMatch(value)) {
          error = field.patternCheck!.errorMessage;
        }
      } catch (_) {
        // Invalid regex — skip validation.
      }
    }

    if (_fieldErrors[field.fieldname] != error) {
      setState(() {
        _fieldErrors[field.fieldname] = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: basic.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: basic.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Form type header
          Row(
            children: [
              Icon(Icons.description, size: 14, color: basic.textMuted),
              const SizedBox(width: 6),
              Text(
                widget.formType.name.replaceAll('-', ' '),
                style: TextStyle(
                  color: basic.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Text pattern error banner
          if (_textPatternError != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: basic.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 14, color: basic.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _textPatternError!,
                      style: TextStyle(color: basic.error, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          // Form fields
          ...widget.formType.fields.map(_buildField),
        ],
      ),
    );
  }

  Widget _buildField(specs.FormFieldDef field) {
    final basic = widget.theme.basic;
    final isRequired = (field.required ?? false) ||
        widget.requiredFields.contains(field.fieldname);
    final dropdownValues = _getDropdownValues(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Field label
          SizedBox(
            width: 120,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: field.fieldname,
                    style: TextStyle(
                      color: basic.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isRequired)
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                        color: basic.error,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Field input
          Expanded(
            child: dropdownValues != null
                ? _buildDropdown(field, dropdownValues)
                : _buildTextField(field),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(specs.FormFieldDef field) {
    final basic = widget.theme.basic;
    final controller = _controllers[field.fieldname];
    final error = _fieldErrors[field.fieldname];
    final hasError = error != null;
    final borderColor = hasError ? basic.error : basic.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 32,
          child: TextField(
            controller: controller,
            readOnly: widget.readOnly,
            onChanged: (_) => _onFieldChanged(),
            style: TextStyle(color: basic.text, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(
                  color: hasError ? basic.error : basic.accent,
                ),
              ),
              hintText: _getHintForField(field),
              hintStyle: TextStyle(color: basic.textMuted, fontSize: 12),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Text(
              error,
              style: TextStyle(color: basic.error, fontSize: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown(
    specs.FormFieldDef field,
    List<String> values,
  ) {
    final basic = widget.theme.basic;
    final controller = _controllers[field.fieldname];
    final currentValue = controller?.text ?? '';
    final effectiveValue =
        values.contains(currentValue) ? currentValue : null;

    return SizedBox(
      height: 32,
      child: DropdownButtonFormField<String>(
        initialValue: effectiveValue,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: basic.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: basic.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: basic.accent),
          ),
        ),
        dropdownColor: basic.surface,
        style: TextStyle(color: basic.text, fontSize: 13),
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: widget.readOnly
            ? null
            : (value) {
                if (value != null) {
                  controller?.text = value;
                  _onFieldChanged();
                }
              },
      ),
    );
  }

  /// Determine dropdown values for a field by matching against custom tags.
  List<String>? _getDropdownValues(specs.FormFieldDef field) {
    // Check if the field's pattern references a custom tag group.
    final pattern = field.patternCheck?.pattern;
    if (pattern != null) {
      // Try to find a custom-tag list that matches the pattern alternatives.
      for (final entry in widget.customTags.entries) {
        if (entry.value is List) {
          final tagValues =
              (entry.value as List).map((e) => e.toString()).toList();
          // If the pattern is an alternation of the tag values, use them.
          final alternatives = tagValues.join('|');
          if (pattern.contains(alternatives) ||
              pattern == '^($alternatives)\$') {
            return tagValues;
          }
        }
      }
    }

    // Check field name heuristics for common patterns.
    final name = field.fieldname.toLowerCase();
    for (final entry in widget.customTags.entries) {
      if (entry.value is List) {
        final tagName = entry.key.toLowerCase();
        if (name.contains(tagName) || tagName.contains(name)) {
          return (entry.value as List).map((e) => e.toString()).toList();
        }
      }
    }

    return null;
  }

  String? _getHintForField(specs.FormFieldDef field) {
    final name = field.fieldname.toLowerCase();
    if (name.contains('date')) return 'YYYY-MM-DD';
    if (name.contains('path') || name.contains('url')) return '/api/...';
    if (name.contains('version')) return 'e.g. 1.0.0';
    return null;
  }
}
