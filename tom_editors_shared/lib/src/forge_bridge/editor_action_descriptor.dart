import 'package:flutter/widgets.dart';

import 'forge_shortcut_key.dart';

/// Context in which an editor action is available.
///
/// Used by the shell to evaluate enabled-state without calling the editor,
/// and to filter actions in the command palette and shortcut editor.
enum ActionContext {
  /// Always available regardless of focus.
  global,

  /// Available when any editor is focused.
  editorFocused,

  /// Available when a text editor (not tree editor) is focused.
  textEditorFocused,

  /// Available when the editor has a non-empty text selection.
  hasSelection,

  /// Available when the document is not read-only.
  editable,
}

/// Metadata-only description of an action an editor can perform.
///
/// No shortcut binding, no execution callback — pure metadata.
/// Editors expose a static list of these descriptors so that any host
/// (shell, standalone, custom embedder) can discover capabilities and
/// bind shortcuts as it sees fit.
///
/// See also:
/// - [ForgeShortcutKey] for the suggested shortcut representation
/// - [ActionContext] for context-based availability rules
class EditorActionDescriptor {
  /// Unique action ID (e.g., 'dart.triggerCompletion').
  final String id;

  /// Human-readable label (e.g., 'Trigger Completion').
  final String label;

  /// Optional icon for menus and command palette.
  final IconData? icon;

  /// Category for grouping in command palette and shortcut editor
  /// (e.g., 'Dart Editor', 'Markdown', 'YAML').
  final String category;

  /// One-line description for tooltip/shortcut editor.
  final String? description;

  /// When this action is conceptually available.
  /// Used by the shell to evaluate isEnabled without calling the editor.
  final ActionContext contextRule;

  /// Whether this action should appear in the editor's context menu.
  final bool showInContextMenu;

  /// The default shortcut the editor suggests for this action.
  /// The shell MAY use this as the initial binding, but is not required to.
  /// When shortcuts are disabled (shell mode), this is ignored.
  final ForgeShortcutKey? suggestedShortcut;

  /// Alternative shortcuts the editor suggests (e.g., Alt+Space for completion).
  final List<ForgeShortcutKey> suggestedAlternatives;

  const EditorActionDescriptor({
    required this.id,
    required this.label,
    this.icon,
    required this.category,
    this.description,
    this.contextRule = ActionContext.editorFocused,
    this.showInContextMenu = false,
    this.suggestedShortcut,
    this.suggestedAlternatives = const [],
  });

  @override
  String toString() => 'EditorActionDescriptor($id, category=$category, '
      'shortcut=${suggestedShortcut?.toDisplayString()})';
}
