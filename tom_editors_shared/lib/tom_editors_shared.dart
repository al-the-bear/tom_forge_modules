/// Reusable Flutter widgets and utilities for tree-based structured editors.
///
/// Provides generic components with zero format-specific logic:
///
/// - **Validation**: [ValidationError], [ValidationBadge], [ValidationTooltip],
///   [ErrorPropagator]
/// - **Tree**: [TreeNode], [TreeController], [TreeView]
/// - **Controls**: [CollapseToggle], [ActionButton], [NodeActionRow]
/// - **Text Editing**: [SyntaxHighlighter], [TextMarker], [TextEditorCore]
/// - **Layout**: [DraggableSeparator], [SplitPanel]
/// - **Search**: [SearchBox]
/// - **Debug**: [EditorLogger]
/// - **Forge Bridge**: [ForgeShortcutKey], [ForgeAction], [ForgeMenuLocation]
/// - **Text Settings**: [ForgeTextSettings], [ForgeTextContext]
/// - **Editor Integration**: [ForgeEditorIntegration], [StandardEditingActions]
library;

// Validation
export 'src/validation/validation_error.dart';
export 'src/validation/validation_badge.dart';
export 'src/validation/validation_tooltip.dart';
export 'src/validation/error_propagator.dart';

// Tree
export 'src/tree/tree_node.dart';
export 'src/tree/tree_controller.dart';
export 'src/tree/tree_view.dart';
export 'src/tree/tree_theme.dart';

// Inline Controls
export 'src/controls/collapse_toggle.dart';
export 'src/controls/action_button.dart';
export 'src/controls/node_action_row.dart';

// Text Editor
export 'src/text_editor/syntax_highlighter.dart';
export 'src/text_editor/text_marker.dart';
export 'src/text_editor/text_editor_core.dart';
export 'src/text_editor/text_editor_theme.dart';

// Layout
export 'src/layout/draggable_separator.dart';
export 'src/layout/split_panel.dart';

// Search
export 'src/search/search_box.dart';

// Debug
export 'src/debug/editor_logger.dart';

// Forge Bridge
export 'src/forge_bridge/forge_shortcut_key.dart';
export 'src/forge_bridge/forge_action.dart';
export 'src/forge_bridge/editor_action_descriptor.dart';
export 'src/forge_bridge/editor_action_provider.dart';
export 'src/forge_bridge/editor_capabilities.dart';
export 'src/forge_bridge/editor_state_snapshot.dart';

// Text Editing (Forge Integration)
export 'src/text_editing/forge_text_settings.dart';
export 'src/text_editing/forge_text_context.dart';
export 'src/text_editing/forge_editor_integration.dart';
export 'src/text_editing/text_undo_entry.dart';
export 'src/text_editing/standard_editing_actions.dart';
export 'src/text_editing/editor_shortcut_map.dart';
export 'src/text_editing/forge_text_field.dart';
export 'src/text_editing/integrations/base_standalone_integration.dart';
export 'src/text_editing/integrations/dart_standalone_integration.dart';

// Dart Editor Actions
export 'src/text_editing/dart_editor_actions.dart';

// Markdown Editor Actions
export 'src/text_editing/md_editor_actions.dart';

// Markdown Standalone Integration
export 'src/text_editing/integrations/md_standalone_integration.dart';

// YAML Editor Actions
export 'src/text_editing/yaml_editor_actions.dart';

// Mermaid
export 'src/mermaid/mermaid_webview.dart';

// Forge Bridge
export 'src/forge_bridge/forge_document_adapter.dart';
export 'src/forge_bridge/forge_validation_bridge.dart';
export 'src/forge_bridge/position_converter.dart';
