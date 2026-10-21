import 'dart:async';

import '../components/forge_editor.dart';
import 'package:tom_forge_core/files.dart' show ForgeFileSystem;
import 'default_system_state.dart';
import 'editor_save.dart';

/// Uniform autosave controller for all open editors.
///
/// Listens to dirty-state changes on all open editors and schedules
/// a debounced save after [debounce] of inactivity. Also saves on
/// window focus loss when [saveOnFocusLoss] is true.
///
/// This replaces per-editor autosave logic with a single shell-level
/// controller that applies the same debounce uniformly.
class ShellAutosaveController {
  final DefaultSystemState systemState;
  final ForgeFileSystem fileSystem;
  final Duration debounce;
  final bool saveOnFocusLoss;

  Timer? _saveTimer;
  StreamSubscription<dynamic>? _dirtySubscription;
  StreamSubscription<dynamic>? _focusSubscription;

  ShellAutosaveController({
    required this.systemState,
    required this.fileSystem,
    this.debounce = const Duration(milliseconds: 1000),
    this.saveOnFocusLoss = true,
  }) {
    _dirtySubscription =
        systemState.onDirtyStateChanged.listen((_) => _scheduleSave());

    if (saveOnFocusLoss) {
      _focusSubscription =
          systemState.onWindowFocusChanged.listen((event) {
        if (!event.focused && systemState.hasUnsavedChanges) {
          _saveAllDirty();
        }
      });
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(debounce, _saveAllDirty);
  }

  void _saveAllDirty() {
    for (final editor in systemState.dirtyEditors) {
      _saveEditor(editor);
    }
  }

  void _saveEditor(ForgeEditor editor) {
    if (saveOwnedEditor(editor, trigger: ForgeSaveTrigger.automatic) != null) {
      return;
    }
    final content = editor.getContent();
    if (content == null) return;
    fileSystem.writeText(editor.uri, content).then((_) {
      editor.markClean();
    }).catchError((Object e) {
      // Autosave failure is non-fatal; next cycle will retry.
    });
  }

  void dispose() {
    _saveTimer?.cancel();
    _dirtySubscription?.cancel();
    _focusSubscription?.cancel();
  }
}
