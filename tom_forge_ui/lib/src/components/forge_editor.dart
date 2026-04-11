import 'package:flutter/foundation.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import 'component_history_manager.dart';
import 'forge_component.dart';

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

  /// Whether this editor has unsaved changes.
  ValueListenable<bool> get isDirty;

  /// Reset the dirty state to clean (e.g., after save).
  ///
  /// Called by the save lifecycle to mark the editor as saved.
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

  /// Set the content of this editor programmatically.
  ///
  /// Used for non-destructive file restore from revisions.
  void setContent(String content) {}

  /// Returns serializable undo history metadata for persistence
  /// to `.forge/undo/{uri-hash}.json`.
  ///
  /// Each entry is a JSON-encodable map with at least a `label` key.
  /// Returns null if this editor doesn't support undo persistence.
  List<Map<String, dynamic>>? getUndoHistoryMetadata() => null;

  /// Restores undo history metadata loaded from `.forge/undo/`.
  void restoreUndoHistoryMetadata(List<Map<String, dynamic>> entries) {}

  /// History manager for back/forward navigation. Null if unsupported.
  ComponentHistoryManager? get historyManager => null;

  /// Whether this editor currently has a non-empty text selection.
  ///
  /// Subclasses override this to report selection state.  Used by the
  /// shell to decide enablement of cut/copy actions.
  bool get hasTextSelection => false;

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
