import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import 'editors/editor_registry.dart';
import 'inspector/subtree_inspector.dart';
import 'schema/yaml_schema.dart';
import 'validation/validation_error_list.dart';
import 'yaml_editor_controller.dart';
import 'yaml_editor_theme.dart';
import 'yaml_schema_editor.dart';

/// Easy-to-embed YAML schema editor with internal controller lifecycle.
///
/// Use this when you want simple embedding and do not need direct access
/// to [YamlEditorController].
class SimpleYamlSchemaEditor extends StatefulWidget {
  final String initialYaml;
  final YamlSchema? schema;
  final Map<String, dynamic>? schemaJson;

  final YamlEditorTheme theme;
  final EditorRegistry? editorRegistry;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final ValueChanged<List<ValidationError>>? onValidationChanged;
  final SubtreeInspectorMode inspectorMode;
  final ErrorListPosition? errorListPosition;
  final bool highlightErrorRows;

  const SimpleYamlSchemaEditor({
    super.key,
    this.initialYaml = '',
    this.schema,
    this.schemaJson,
    this.theme = const YamlEditorTheme(),
    this.editorRegistry,
    this.readOnly = false,
    this.onChanged,
    this.onValidationChanged,
    this.inspectorMode = SubtreeInspectorMode.bottomSheet,
    this.errorListPosition,
    this.highlightErrorRows = false,
  }) : assert(
          schema == null || schemaJson == null,
          'Pass either schema or schemaJson, not both.',
        );

  @override
  State<SimpleYamlSchemaEditor> createState() => _SimpleYamlSchemaEditorState();
}

class _SimpleYamlSchemaEditorState extends State<SimpleYamlSchemaEditor> {
  late YamlEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController(widget);
  }

  @override
  void didUpdateWidget(SimpleYamlSchemaEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final schemaChanged = oldWidget.schema != widget.schema ||
        !_mapEquals(oldWidget.schemaJson, widget.schemaJson);
    final yamlChanged = oldWidget.initialYaml != widget.initialYaml;

    if (schemaChanged || yamlChanged) {
      _controller.dispose();
      _controller = _createController(widget);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  YamlEditorController _createController(SimpleYamlSchemaEditor widget) {
    final resolvedSchema = widget.schema ??
        (widget.schemaJson == null
            ? null
            : YamlSchema.fromJson(widget.schemaJson!));
    return YamlEditorController(
      initialYaml: widget.initialYaml,
      schema: resolvedSchema,
    );
  }

  @override
  Widget build(BuildContext context) {
    return YamlSchemaEditor(
      controller: _controller,
      theme: widget.theme,
      editorRegistry: widget.editorRegistry,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      onValidationChanged: widget.onValidationChanged,
      inspectorMode: widget.inspectorMode,
      errorListPosition: widget.errorListPosition,
      highlightErrorRows: widget.highlightErrorRows,
    );
  }

  bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
