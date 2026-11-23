/// A non-destructive, schema-aware YAML editor widget for Flutter.
///
/// Provides a structured editor for YAML documents that:
/// - Preserves comments, formatting, and key ordering (non-destructive)
/// - Uses JSON Schema for validation, construction help, and structure guidance
/// - Embeds specialized editors based on key naming conventions (`key-<type>:`)
/// - Supports full theming and feature customization
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:tom_yaml_editor/tom_yaml_editor.dart';
///
/// final controller = YamlEditorController(
///   initialYaml: '''
///   prompt:
///     meta-data:
///       name: My Prompt
///       id: prompt-001
///     script-dart: |
///       void main() {
///         print('Hello');
///       }
///     execution-count: 0
///   ''',
///   schema: myJsonSchema,
/// );
///
/// YamlSchemaEditor(
///   controller: controller,
///   theme: YamlEditorTheme.dark(),
///   editorRegistry: EditorRegistry.defaults(),
/// )
/// ```
///
/// ## Convention-Based Editors
///
/// Keys ending with a type suffix trigger specialized inline editors:
///
/// | Suffix | Editor | Example Key |
/// |--------|--------|-------------|
/// | `-dart` | Dart code editor | `script-dart` |
/// | `-markdown` | Markdown editor | `description-markdown` |
/// | `-regex` | Regex editor | `pattern-regex` |
/// | `-json` | JSON editor | `payload-json` |
///
/// Register custom editors via [EditorRegistry.register].
///
/// ## Theming
///
/// Every visual aspect is customizable via [YamlEditorTheme]:
///
/// ```dart
/// YamlSchemaEditor(
///   theme: YamlEditorTheme(
///     colors: YamlEditorColors(
///       background: Colors.grey[900]!,
///       keyColor: Colors.cyan,
///       valueColor: Colors.white,
///     ),
///   ),
/// )
/// ```
library;

// Core editor widget and controller
export 'src/yaml_schema_editor.dart' show YamlSchemaEditor;
export 'src/yaml_editor_controller.dart' show YamlEditorController;
export 'src/tree/editor_trail.dart' show kYamlEditorDebug;
export 'src/simple_yaml_schema_editor.dart' show SimpleYamlSchemaEditor;

// Theme system
export 'src/yaml_editor_theme.dart'
    show
        YamlEditorTheme,
        YamlEditorColors,
        YamlStructureColors,
        YamlEditorFontSettings,
        EmbeddedEditorStyle;

// Schema support
export 'src/schema/yaml_schema.dart' show YamlSchema, SchemaNode, SchemaType;
export 'src/schema/schema_walker.dart' show SchemaWalker;
export 'src/schema/schema_marker_generator.dart' show SchemaMarkerGenerator;

// Editor registry for convention-based embedded editors
export 'src/editors/editor_registry.dart'
    show EditorRegistry, EditorFactory, EditorResolver, EditorSuffix;
export 'src/editors/embedded_editor.dart'
    show EmbeddedEditor, EmbeddedEditorState;

// YAML document model (non-destructive, backed by yaml_edit)
export 'src/model/yaml_document_model.dart' show YamlDocumentModel;
export 'src/model/yaml_edit_operation.dart'
    show YamlEditOperation, YamlEditKind;

// Built-in type editors (Phase 3)
export 'src/editors/built_in/string_editor.dart' show StringEditor;
export 'src/editors/built_in/integer_editor.dart' show IntegerEditor;
export 'src/editors/built_in/number_editor.dart' show NumberEditor;
export 'src/editors/built_in/boolean_editor.dart' show BooleanEditor;

// Editor integration (Phase 4)
export 'src/integration/yaml_standalone_integration.dart'
    show YamlStandaloneIntegration, YamlEditorDefaults;
// The YAML editor's own actions (ids, keys, descriptors).
export 'src/integration/yaml_editor_actions.dart';
export 'src/editors/built_in/null_editor.dart' show NullEditor;
export 'src/editors/built_in/enum_editor.dart' show EnumEditor;
export 'src/editors/built_in/built_in_editor_factory.dart'
    show BuiltInEditorFactory;

// Tree rendering (Phase 4)
export 'src/tree/yaml_tree_node_builder.dart'
    show YamlTreeNodeBuilder, YamlTreeData, YamlNodeKind;
export 'src/tree/map_node_row.dart' show MapNodeRow;
export 'src/tree/list_node_row.dart' show ListNodeRow;
export 'src/tree/key_label.dart' show KeyLabel;
export 'src/tree/node_actions.dart' show YamlNodeActions;

// Subtree Inspector (Phase 5)
export 'src/inspector/subtree_inspector.dart'
    show SubtreeInspector, SubtreeInspectorState, SubtreeInspectorMode;
export 'src/inspector/inspector_layouts.dart'
    show InspectorSidePanel, InspectorBottomSheet;
export 'src/inspector/inspector_dialog.dart' show showInspectorDialog;

// Validation Error List (Phase 6)
export 'src/validation/validation_error_list.dart'
    show ValidationErrorList, ErrorListPosition;

// YAML-specific text editing
export 'src/text_editor/yaml_syntax_highlighter.dart'
    show YamlSyntaxHighlighter, YamlHighlightColors;

// Re-export key yaml/yaml_edit types for convenience
export 'package:yaml/yaml.dart'
    show YamlMap, YamlList, YamlNode, YamlScalar, YamlException, loadYamlNode;
export 'package:yaml_edit/yaml_edit.dart' show wrapAsYamlNode;

// Re-export shared editor foundation types used in the public API
export 'package:tom_editors_shared/tom_editors_shared.dart'
    show
        ValidationError,
        ValidationSeverity,
        ValidationBadge,
        ValidationTooltip,
        ErrorPropagator;
