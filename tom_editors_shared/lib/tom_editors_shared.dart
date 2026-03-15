/// Reusable Flutter widgets and utilities for tree-based structured editors.
///
/// Provides generic components with zero format-specific logic:
///
/// - **Undo/Redo**: [UndoHistory] — typed undo/redo stack
/// - **Validation**: [ValidationError], [ValidationBadge], [ValidationTooltip],
///   [ErrorPropagator]
/// - **Tree**: [TreeNode], [TreeController], [TreeView]
/// - **Controls**: [CollapseToggle], [ActionButton], [NodeActionRow]
/// - **Text Editing**: [SyntaxHighlighter], [TextMarker], [TextEditorCore]
/// - **Layout**: [DraggableSeparator], [SplitPanel]
/// - **Search**: [SearchBox]
/// - **Debug**: [EditorLogger]
library;

// Undo/Redo
export 'src/undo_history.dart';

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
