import 'package:flutter/foundation.dart';
import 'package:tom_editors_shared/text_types.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import 'component_history_manager.dart';
import 'forge_component.dart';

/// An editor of one of the shell's editor types: `'md'`, `'dart'`,
/// `'yaml'`, `'plaintext'`, or the id of another [ForgeEditorType]. The shell
/// keys the text settings, the action bar and **Open With** by it.
abstract interface class ForgeEditorOfType {
  /// The id of the editor type this editor is.
  String get editorTypeId;
}

/// The editor type of [editor] ([ForgeEditorOfType.editorTypeId]), or null
/// for an editor of none.
String? forgeEditorTypeIdOf(ForgeEditor editor) => editor is ForgeEditorOfType
    ? (editor as ForgeEditorOfType).editorTypeId
    : null;

/// An editor component bound to a document URI.
///
/// Editors are closable, track dirty state, and participate in the
/// shell's file-handling resolution protocol (canHandle/canHandleContent).
///
/// Implements [EditorActionProvider] so the shell can route standard
/// editing actions (cut, copy, paste, undo, redo, etc.) to the active
/// editor without stale closures or single-slot registry problems.
abstract class ForgeEditor extends ForgeComponent
    implements EditorActionProvider {
  @override
  bool get isEditor => true;

  /// The URI this editor is associated with.
  Uri get uri;

  /// Phase 1: Whether this editor can handle the given URI.
  FileHandlingResult canHandle(Uri uri);

  /// Phase 2: Called only when canHandle returned [FileHandlingResult.inspect].
  FileHandlingResult canHandleContent(Uri uri, List<int> bytes) =>
      FileHandlingResult.accept;

  /// Whether this editor has unsaved changes: the document differs from the
  /// saved state. Measured against a saved marker ([ForgeSavedMarker]),
  /// never as "can undo" or "anything changed", so undoing back to the saved
  /// state shows clean (the history contract, tom_forge_ui's
  /// `_copilot_guidelines/editor_history_contract.md`).
  ValueListenable<bool> get isDirty;

  /// The document as it is now is the saved state (after a save): moves the
  /// saved marker. It does not touch the history.
  void markClean();

  /// Get the current content of the editor for saving.
  ///
  /// Returns null if this editor type doesn't support content retrieval.
  String? getContent() => null;

  /// Serialize editor state (cursor position, scroll, selections, etc.)
  /// for persistence to `.forge/state/editors/`.
  ///
  /// Returns a JSON-encodable map, or `null` if the editor doesn't support
  /// state persistence.
  Map<String, dynamic>? saveState() => null;

  /// Restore previously persisted editor state.
  ///
  /// Called after the editor is opened with state loaded from
  /// `.forge/state/editors/`.
  void restoreState(Map<String, dynamic> state) {}

  /// Content arrived from outside the editor's history — a reload, an
  /// external change taken, a revision restore: replace the document with
  /// [content] in place, make it the saved state and clear the history (an
  /// entry made against the old text would apply to text it was not made
  /// on). Every view of the document shows it.
  ///
  /// Returns false when this editor cannot replace its content in place; the
  /// shell then closes it and opens the file again, so no editor stays on the
  /// old text.
  bool replaceContent(String content) => false;

  /// Undo-history persistence: reserved, not used. The shell writes what
  /// this returns to `.forge/undo/{uri-hash}.json` on close and hands it back
  /// to [restoreUndoHistoryMetadata] on the next open; every editor returns
  /// null, so no history outlives its session. A persisted history is a
  /// second record of the document's past that diverges from the file the
  /// first time the file changes elsewhere; the hook stays so an editor can
  /// implement it later, against the file's saved revision.
  List<Map<String, dynamic>>? getUndoHistoryMetadata() => null;

  /// Restores what [getUndoHistoryMetadata] wrote. Reserved, like it.
  void restoreUndoHistoryMetadata(List<Map<String, dynamic>> entries) {}

  /// Back/forward navigation within the editor (not undo). Reserved: no
  /// editor supplies one yet and the shell shows none.
  ComponentHistoryManager? get historyManager => null;

  // -- EditorActionProvider defaults --
  // Subclasses override these to provide real implementations.

  @override
  Set<String> get supportedActionIds => const {};

  @override
  bool isActionEnabled(String actionId) {
    if (!supportedActionIds.contains(actionId)) return false;
    return StandardEditingActions.enablementRule(actionId)(stateSnapshot);
  }

  @override
  bool executeAction(String actionId) => false;

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
    hasTextBuffer: false,
    supportsUndoRedo: false,
    supportsClipboard: false,
    supportsLineEditing: false,
    supportsSelection: false,
  );

  @override
  EditorStateSnapshot get stateSnapshot => const EditorStateSnapshot();

  /// Stream that fires when [stateSnapshot] has changed.
  ///
  /// The shell subscribes to this for the active editor. A rebuild of
  /// the action bar is triggered on every event.
  Stream<void> get onStateChanged => const Stream.empty();
}
