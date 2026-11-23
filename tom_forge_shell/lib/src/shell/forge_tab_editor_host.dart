import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../defaults/default_layout_controller.dart';
import '../defaults/default_system_state.dart';
import 'forge_layout_controller.dart';
import 'forge_system_state.dart';

/// The panel shell's [ForgeEditorHost]: editors are tabs of the middle
/// panels, placed by the shell's [ForgeLayoutController].
///
/// [showEditor] adds an editor as a tab of the middle panel its placement
/// hint names, else of the active one (or activates its tab when it is open
/// already), [closeEditor] closes its tab, [bringToFront] activates its tab,
/// and [openEditorFor] lets the layout controller choose the editor for a
/// resource as **Open** does and shows it where the hint says.
///
/// **The placement hint** is the index of a middle panel (an `int`, 0 the
/// first), as the shell records it in a [ForgeNavigationLocation.placement];
/// a hint that is no index of an existing middle panel places the editor in
/// the active one ([middlePanelIndexOf]).
class ForgeTabEditorHost implements ForgeEditorHost {
  ForgeTabEditorHost({
    required ForgeLayoutController layout,
    required ForgeSystemState systemState,
  }) : _layout = layout,
       _systemState = systemState;

  final ForgeLayoutController _layout;
  final ForgeSystemState _systemState;

  /// The middle panel a placement hint names: [placement] when it is the
  /// index of one of the [middlePanelCount] middle panels (when known), else
  /// null (the active one).
  static int? middlePanelIndexOf(Object? placement, {int? middlePanelCount}) {
    if (placement is! int || placement < 0) return null;
    if (middlePanelCount != null && placement >= middlePanelCount) return null;
    return placement;
  }

  int? _middlePanelOf(Object? placement) {
    final layout = _layout;
    return middlePanelIndexOf(
      placement,
      middlePanelCount: layout is DefaultLayoutController
          ? layout.middlePanels.value.length
          : null,
    );
  }

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {
    final active = _systemState.activeEditor;
    _layout.openEditor(
      editor,
      editor.uri,
      middlePanelIndex: _middlePanelOf(placement),
    );
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
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async {
    final layout = _layout;
    if (layout is DefaultLayoutController) {
      final editor = await layout.createEditorForUri(uri);
      if (editor == null) return null;
      await showEditor(editor, placement: placement);
      return editor;
    }
    _layout.openFile(uri, middlePanelIndex: _middlePanelOf(placement));
    for (final editor in _systemState.openEditors) {
      if (editor.uri == uri) return editor;
    }
    return null;
  }
}
