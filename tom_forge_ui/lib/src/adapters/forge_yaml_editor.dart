import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
  show TextEditingContextImpl;
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import '../components/forge_schema_editor.dart';
import '../components/forge_component.dart';
import '../integrations/shell_editor_integration.dart';
import '../module/forge_module.dart';
import 'tom_forge_shell_module.dart';

/// Adapter that wraps [YamlEditorController] + [YamlSchemaEditor] as a
/// [ForgeSchemaEditor].
class ForgeYamlEditor extends ForgeSchemaEditor {
  final YamlEditorController controller;
  final ForgeModule _module;
  final _title = ValueNotifier<String>('YAML');
  final _titleExtension = ValueNotifier<String?>(null);
  ShellEditorIntegration? _integration;

  ForgeYamlEditor({
    required this.controller,
    required ForgeModule module,
  }) : _module = module {
    controller.addListener(_onControllerChanged);

    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
    if (controller.schema != null) {
      _titleExtension.value = controller.schema!.root.title;
    }
  }

  // ── ForgeComponent ──

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon =>
      const IconData(0xf037b, fontFamily: 'MaterialIcons'); // data_object

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  ForgeModule get module => _module;

  @override
  Widget buildMain(BuildContext context) {
    if (_module case final TomForgeShellModule shellModule) {
      _integration ??= ShellEditorIntegration(
        shellApi: shellModule.shellApi,
        editorId: 'yaml-editor-${uri.hashCode}',
        editorTypeId: 'yaml',
      );
      _integration!.onContextChanged(
        TextEditingContextImpl.withValues(
          text: controller.yamlText,
          selections: const [TextSelection.collapsed(offset: 0)],
          isDirty: controller.isDirtyNotifier.value,
          canUndo: false,
          canRedo: false,
        ),
      );
    }

    return YamlSchemaEditor(
      controller: controller,
      integration: _integration,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  // ── ForgeEditor ──

  @override
  Uri get uri => controller.uri ?? Uri.parse('untitled:yaml');

  @override
  ValueListenable<bool> get isDirty => controller.isDirtyNotifier;

  @override
  void markClean() {
    controller.markClean();
  }

  @override
  String? getContent() => controller.yamlText;

  @override
  Map<String, dynamic>? saveState() {
    return {
      'schemaLabel': schemaLabel,
    };
  }

  // ── ForgeSchemaEditor ──

  @override
  FileHandlingResult canHandleContent(Uri uri, List<int> bytes) {
    // Check if the content looks like YAML and optionally has a schema
    // that this editor can handle.
    try {
      final content = utf8.decode(bytes);
      // Accept any .yaml/.yml file.
      final ext = uri.path.split('.').last.toLowerCase();
      if (ext == 'yaml' || ext == 'yml') {
        // If we have a schema, check if the content is compatible.
        if (controller.schema != null) {
          return content.isNotEmpty
              ? FileHandlingResult.accept
              : FileHandlingResult.reject;
        }
        return FileHandlingResult.accept;
      }
      return FileHandlingResult.reject;
    } catch (_) {
      return FileHandlingResult.reject;
    }
  }

  @override
  String get schemaLabel =>
      controller.schema?.root.title ?? 'YAML Schema Editor';

  // ── Internal ──

  void _onControllerChanged() {
    final integration = _integration;
    if (integration != null) {
      integration.onContextChanged(
        TextEditingContextImpl.withValues(
          text: controller.yamlText,
          selections: const [TextSelection.collapsed(offset: 0)],
          isDirty: controller.isDirtyNotifier.value,
          canUndo: false,
          canRedo: false,
        ),
      );
    }

    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
    if (controller.schema != null) {
      _titleExtension.value = controller.schema!.root.title;
    }
  }

  /// Release listeners.
  void dispose() {
    _integration?.dispose();
    controller.removeListener(_onControllerChanged);
    _title.dispose();
    _titleExtension.dispose();
  }
}
