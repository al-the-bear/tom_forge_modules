import 'package:flutter/foundation.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The example's [ForgeEditorHost]: one window with room for one editor.
///
/// The window shows [current]; showing another editor replaces it (the one
/// shown before leaves the kit's state, as an editor the panel shell closes
/// does). The host
/// opens a file with the first of [editorTypes] that opens it by default,
/// through the kit ([DefaultKitApi.openWithEditorType], which reads the file
/// and hands the new editor back to [showEditor]). Placement hints are not
/// read: there is one place.
class SingleWindowEditorHost implements ForgeEditorHost {
  SingleWindowEditorHost({required this.editorTypes});

  /// The editor types the window opens files with, asked in order.
  final List<ForgeKitEditorType> editorTypes;

  /// The kit this host shows editors for; set once by the application
  /// ([attach]) — the kit is made with its host, so it comes second.
  DefaultKitApi get api => _api!;
  DefaultKitApi? _api;

  /// Binds the host to [api].
  void attach(DefaultKitApi api) {
    assert(_api == null, 'The host is attached once.');
    _api = api;
  }

  /// The editor the window shows; null before a file is open.
  final ValueNotifier<ForgeEditor?> current = ValueNotifier(null);

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {
    final previous = current.value;
    if (!identical(previous, editor)) {
      current.value = editor;
      if (previous != null) _release(previous);
    }
    if (focus) api.state.setActiveEditor(editor);
  }

  @override
  Future<bool> closeEditor(ForgeEditor editor) async {
    // Unsaved work stays: the window has no dialog to ask about it.
    if (!identical(current.value, editor) || editor.isDirty.value) {
      return false;
    }
    current.value = null;
    _release(editor);
    return true;
  }

  @override
  void bringToFront(ForgeEditor editor) {
    if (identical(current.value, editor)) api.state.setActiveEditor(editor);
  }

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async {
    final shown = current.value;
    if (shown != null && shown.uri == uri) {
      bringToFront(shown);
      return shown;
    }
    for (final type in editorTypes) {
      if (type.opensByDefault(uri)) {
        return api.openWithEditorType(uri, type);
      }
    }
    return null;
  }

  /// Takes [editor] out of the kit's state.
  void _release(ForgeEditor editor) {
    final state = api.state;
    if (identical(state.activeEditor, editor)) state.setActiveEditor(null);
    state.removeOpenEditor(editor);
  }

  /// Lets go of the window's editor.
  void dispose() => current.dispose();
}
