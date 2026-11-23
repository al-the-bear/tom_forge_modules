import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../defaults/default_layout_controller.dart';
import '../defaults/default_system_state.dart';
import 'forge_layout_controller.dart';
import 'forge_system_state.dart';

/// The panel shell's [ForgeEditorHost]: editors are tabs of the middle
/// panels, placed by the shell's [ForgeLayoutController].
///
/// [showEditor] adds an editor as a tab of the active middle panel (or
/// activates its tab when it is open already), [closeEditor] closes its tab,
/// [bringToFront] activates its tab, and [openEditorFor] lets the layout
/// controller choose the editor for a resource as **Open** does.
class ForgeTabEditorHost implements ForgeEditorHost {
  ForgeTabEditorHost({
    required ForgeLayoutController layout,
    required ForgeSystemState systemState,
  }) : _layout = layout,
       _systemState = systemState;

  final ForgeLayoutController _layout;
  final ForgeSystemState _systemState;

  @override
  Future<void> showEditor(ForgeEditor editor, {bool focus = true}) async {
    final active = _systemState.activeEditor;
    _layout.openEditor(editor, editor.uri);
    if (!focus && active != null && !identical(active, editor)) {
      // The tab is added (or kept); the editor the user works in stays.
      final state = _systemState;
      if (state is DefaultSystemState) {
        state.setActiveEditor(active);
      } else {
        _layout.focusComponent(active);
      }
    }
  }

  @override
  Future<bool> closeEditor(ForgeEditor editor) async {
    if (!_systemState.openEditors.contains(editor)) return false;
    _layout.closeEditor(editor);
    return true;
  }

  @override
  void bringToFront(ForgeEditor editor) {
    if (!_systemState.openEditors.contains(editor)) return;
    _layout.openEditor(editor, editor.uri);
  }

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri) async {
    final layout = _layout;
    if (layout is DefaultLayoutController) {
      final editor = await layout.createEditorForUri(uri);
      if (editor == null) return null;
      await showEditor(editor);
      return editor;
    }
    _layout.openFile(uri);
    for (final editor in _systemState.openEditors) {
      if (editor.uri == uri) return editor;
    }
    return null;
  }
}
