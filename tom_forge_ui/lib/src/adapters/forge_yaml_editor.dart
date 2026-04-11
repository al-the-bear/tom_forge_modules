import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show TextEditingContextImpl, ValidationSeverity,
         YamlEditorActions, StandardEditingActions;
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import '../components/forge_schema_editor.dart';
import '../components/forge_component.dart';
import '../defaults/default_system_state.dart';
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
  ForgeTextEditorOptions _options;
  ForgeDiagnosticCollection? _diagnosticCollection;

  /// Tracks text-mode selection for action bar enablement.
  TextSelection _textModeSelection = const TextSelection.collapsed(offset: 0);

  /// Optional path to the directory containing JSON Schema files.
  ///
  /// When set, the adapter can resolve schemas from this location.
  /// Falls back to the editor-specific config map key `yamlSchemasPath`
  /// when not set via constructor.
  late final String? yamlSchemasPath;

  ForgeYamlEditor({
    required this.controller,
    required ForgeModule module,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(),
    String? yamlSchemasPath,
  }) : _module = module, _options = options {
    // Resolve schemas path: constructor arg > editor config.
    // Guard: shell may not be activated yet during tests.
    String? configPath;
    if (module case final TomForgeShellModule m when m.isActivated) {
      configPath = m.shellApi.getEditorSpecificConfig('yaml')['yamlSchemasPath']
          as String?;
    }
    this.yamlSchemasPath = yamlSchemasPath ?? configPath;
    controller.addListener(_onControllerChanged);

    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
    if (controller.schema != null) {
      _titleExtension.value = controller.schema!.root.title;
    }

    // Push initial diagnostics.
    _updateDiagnostics();
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
      )..descriptors = [
          ...YamlEditorActions.descriptors,
          ...StandardEditingActions.descriptors,
        ];
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
      theme: _buildThemeFromOptions(),
      onTextModeSelectionChanged: _onTextModeSelectionChanged,
    );
  }

  void _onTextModeSelectionChanged(TextSelection selection) {
    _textModeSelection = selection;
    // Push updated context so the shell fires onTextSelectionChanged.
    final integration = _integration;
    if (integration != null) {
      integration.onContextChanged(
        TextEditingContextImpl.withValues(
          text: controller.yamlText,
          selections: [selection],
          isDirty: controller.isDirtyNotifier.value,
          canUndo: controller.canUndo,
          canRedo: controller.canRedo,
        ),
      );
    }
    // Notify the system state so the scaffold rebuilds its action bar.
    if (_module case final TomForgeShellModule shellModule) {
      final systemState = shellModule.shellApi.systemState;
      if (systemState is DefaultSystemState) {
        systemState.notifyTextSelectionChanged(this);
      }
    }
  }

  ForgeTextEditorOptions get options => _options;

  void updateOptions(ForgeTextEditorOptions options) => _options = options;

  YamlEditorTheme _buildThemeFromOptions() {
    const base = YamlEditorTheme();
    final config = switch (_module) {
      final TomForgeShellModule m =>
        m.shellApi.getEditorSpecificConfig('yaml'),
      _ => const <String, dynamic>{},
    };
    return YamlEditorTheme(
      colors: base.colors,
      structureColors: base.structureColors,
      fonts: YamlEditorFontSettings(
        keyFontFamily: _options.fontFamily ?? base.fonts.keyFontFamily,
        valueFontFamily: _options.fontFamily ?? base.fonts.valueFontFamily,
        keyFontSize: _options.fontSize ?? base.fonts.keyFontSize,
        valueFontSize: _options.fontSize ?? base.fonts.valueFontSize,
        lineHeight: _options.lineHeight ?? base.fonts.lineHeight,
      ),
      embeddedEditorStyle: base.embeddedEditorStyle,
      editorPadding: base.editorPadding,
      indentWidth: (config['indentWidth'] as num?)?.toDouble() ?? base.indentWidth,
      showTreeLines: (config['showTreeLines'] as bool?) ?? base.showTreeLines,
      showCollapseToggles: (config['showCollapseToggles'] as bool?) ??
          base.showCollapseToggles,
      showAddButtons:
          (config['showAddButtons'] as bool?) ?? base.showAddButtons,
      showRemoveButtons:
          (config['showRemoveButtons'] as bool?) ?? base.showRemoveButtons,
      showInlineValidation: (config['showInlineValidation'] as bool?) ??
          base.showInlineValidation,
      collapsedPreviewLines:
          (config['collapsedPreviewLines'] as num?)?.toInt() ??
              base.collapsedPreviewLines,
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

  @override
  bool get hasTextSelection =>
      _textModeSelection.isValid && !_textModeSelection.isCollapsed;

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

    _updateDiagnostics();
  }

  /// Converts current validation/parse errors to [ForgeDiagnostic] and
  /// pushes them to the diagnostic manager via a named collection.
  void _updateDiagnostics() {
    final module = _module;
    final shell = module is TomForgeShellModule ? module.shellApi : null;
    if (shell == null) return;

    final fileUri = controller.uri;
    if (fileUri == null) return;

    _diagnosticCollection ??=
        shell.diagnostics.createCollection('yaml-editor');

    final yamlText = controller.yamlText;
    final diagnostics = <ForgeDiagnostic>[];

    // Parse errors — extract line/column from YamlException span.
    try {
      loadYamlNode(yamlText);
    } catch (error) {
      var line = 0;
      var column = 0;
      if (error is YamlException && error.span != null) {
        line = error.span!.start.line; // 0-based
        column = error.span!.start.column; // 0-based
      }
      diagnostics.add(ForgeDiagnostic(
        uri: fileUri,
        range: ForgeTextRange(
          start: ForgeTextPosition(line: line, column: column),
          end: ForgeTextPosition(line: line, column: column + 1),
        ),
        message: error.toString(),
        severity: ForgeSeverity.error,
        source: 'yaml',
      ));
      _diagnosticCollection!.set(fileUri, diagnostics);
      return;
    }

    // Schema validation errors — convert paths to line/column positions.
    final errors = controller.errors;
    if (errors.isNotEmpty) {
      final markers = SchemaMarkerGenerator.generate(
        yamlText: yamlText,
        errors: errors,
      );
      // Match markers back to errors by index (generated in same order).
      for (var i = 0; i < errors.length; i++) {
        final error = errors[i];
        final marker = i < markers.length ? markers[i] : null;
        final line = marker != null ? (marker.line ?? 1) - 1 : 0;
        final col = marker != null ? (marker.column ?? 1) - 1 : 0;
        diagnostics.add(ForgeDiagnostic(
          uri: fileUri,
          range: ForgeTextRange(
            start: ForgeTextPosition(line: line, column: col),
            end: ForgeTextPosition(line: line, column: col + 1),
          ),
          message: error.message,
          severity: _mapValidationSeverity(error.severity),
          source: 'yaml-schema',
          code: error.code,
        ));
      }
    }

    _diagnosticCollection!.set(fileUri, diagnostics);
  }

  static ForgeSeverity _mapValidationSeverity(ValidationSeverity s) {
    return switch (s) {
      ValidationSeverity.error => ForgeSeverity.error,
      ValidationSeverity.warning => ForgeSeverity.warning,
      ValidationSeverity.info => ForgeSeverity.info,
    };
  }

  /// Release listeners.
  void dispose() {
    _integration?.dispose();
    controller.removeListener(_onControllerChanged);
    // Clear diagnostics for this editor's file.
    final fileUri = controller.uri;
    if (fileUri != null) {
      _diagnosticCollection?.set(fileUri, const []);
    }
    _title.dispose();
    _titleExtension.dispose();
  }
}
