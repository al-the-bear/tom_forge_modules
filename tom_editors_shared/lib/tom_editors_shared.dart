/// Reusable Flutter widgets and utilities for tree-based structured editors.
///
/// Provides generic components with zero format-specific logic:
///
/// - From `tom_ui_controls`, re-exported: **Validation** ([ValidationError],
///   [ValidationBadge], [ValidationTooltip], [ErrorPropagator]), **Tree**
///   ([TreeNode], [TreeController], [TreeView]), **Controls**
///   ([CollapseToggle], [ActionButton], [NodeActionRow]), **Layout**
///   ([DraggableSeparator], [SplitPanel]), **Search** ([SearchBox])
/// - **Text Editing**: [SyntaxHighlighter], [TextMarker], [TextEditorCore]
/// - **Debug**: [EditorLogger]
/// - **Forge Bridge**: [ForgeShortcutKey], [ForgeAction], [ForgeMenuLocation]
/// - **Text Settings**: [ForgeTextSettings], [ForgeTextContext]
/// - **Editor Integration**: [ForgeEditorIntegration], [StandardEditingActions]
library;

// Validation
// The tree view, split panels, search box, small controls and validation
// markers: tom_ui_controls (tom_ai/modules), re-exported so every editor and
// application built on the editor kit keeps its imports.
export 'package:tom_ui_controls/tom_ui_controls.dart';

// Tree

// Inline Controls

// Text Editor
// The highlighter interface lives in tom_text_highlight (tom_ai/modules);
// re-exported here for one release so existing imports keep working.
export 'package:tom_text_highlight/tom_text_highlight.dart'
    show SyntaxHighlighter, HighlightSpan;
export 'src/text_editor/text_marker.dart';
export 'src/text_editor/text_editor_core.dart';
export 'src/text_editor/text_editor_theme.dart';

// Layout

// Search

// Debug
export 'src/debug/editor_logger.dart';

// Forge Bridge
// The webview-free text and editor-contract types (text_types.dart).
export 'text_types.dart';

// Text Editing (Forge Integration)
export 'src/text_editing/forge_editor_integration.dart';
export 'src/text_editing/text_undo_entry.dart';
export 'src/text_editing/history/forge_caret_at_change.dart';
export 'src/text_editing/history/forge_editor_owns_undo.dart';
export 'src/text_editing/history/forge_text_history.dart';
export 'src/text_editing/history/forge_undo_depth.dart';
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

// Mermaid diagrams (MermaidWebView) are in package:tom_mermaid_view
// (tom_ai/modules), with the mermaid.js asset and the webview.

// Forge Bridge
export 'src/forge_bridge/forge_document_adapter.dart';
export 'src/forge_bridge/forge_validation_bridge.dart';
export 'src/forge_bridge/position_converter.dart';
