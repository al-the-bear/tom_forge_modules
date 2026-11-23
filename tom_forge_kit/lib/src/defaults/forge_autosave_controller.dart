import 'dart:async';

import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;

import '../components/forge_editor.dart';
import '../kit/forge_kit_state.dart';
import 'editor_save.dart';

/// Uniform autosave for every open editor.
///
/// Listens to the unsaved-state changes of the open editors ([state]) and
/// saves every unsaved editor after [debounce] of inactivity. [saveNow], when
/// given, is the host saying "save now": every event saves every unsaved
/// editor at once (the panel shell feeds it from the loss of its focus).
///
/// An editor that owns its saving is left to it ([saveOwnedEditor]); any
/// other is written through [fileSystem] and marked clean once the write
/// lands. A failed write is not fatal: the next round tries again.
class ForgeAutosaveController {
  ForgeAutosaveController({
    required this.state,
    required this.fileSystem,
    this.debounce = const Duration(milliseconds: 1000),
    Stream<void>? saveNow,
  }) {
    _dirtySubscription = state.onDirtyStateChanged.listen(
      (_) => _scheduleSave(),
    );
    _saveNowSubscription = saveNow?.listen((_) {
      if (state.hasUnsavedChanges) saveAllDirty();
    });
  }

  final ForgeKitState state;
  final TomFileSystem fileSystem;
  final Duration debounce;

  Timer? _saveTimer;
  StreamSubscription<Object?>? _dirtySubscription;
  StreamSubscription<void>? _saveNowSubscription;

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(debounce, saveAllDirty);
  }

  /// Saves every editor with unsaved changes now.
  void saveAllDirty() {
    for (final editor in state.dirtyEditors) {
      _saveEditor(editor);
    }
  }

  void _saveEditor(ForgeEditor editor) {
    if (saveOwnedEditor(editor, trigger: ForgeSaveTrigger.automatic) != null) {
      return;
    }
    final content = editor.getContent();
    if (content == null) return;
    fileSystem
        .writeText(editor.uri, content)
        .then((_) {
          editor.markClean();
        })
        .catchError((Object e) {
          // Autosave failure is non-fatal; next cycle will retry.
        });
  }

  /// Stops listening and cancels a pending save.
  void dispose() {
    _saveTimer?.cancel();
    _dirtySubscription?.cancel();
    _saveNowSubscription?.cancel();
  }
}
