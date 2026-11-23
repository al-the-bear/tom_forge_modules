import '../components/forge_editor.dart';

/// Where editors appear: the port through which the kit asks the application
/// to show, close or bring forward an editor.
///
/// The kit never decides where an editor appears. The application implements
/// this port with whatever arrangement it has (the panel shell implements it
/// with its editor groups; an application with a single editor area shows one
/// editor at a time) and decides, in [openEditorFor], which editor a resource
/// gets.
///
/// **Placement hints.** [showEditor] and [openEditorFor] take an optional
/// `placement`: an opaque value the application recorded or understands, such
/// as the `placement` a `ForgeNavigationLocation` carries (where the
/// application showed the editor before). The kit never reads it; the
/// application interprets it (the panel shell: the index of a middle panel)
/// and places the editor as it decides when the hint is null or one it does
/// not understand.
abstract class ForgeEditorHost {
  /// Shows [editor] — adds it when it is not shown yet — and gives it the
  /// focus unless [focus] is false; [placement] is the application's hint
  /// where it goes (null: where the application decides).
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  });

  /// Closes [editor]; answers false when it stays open (the user kept it, or
  /// the host does not show it).
  Future<bool> closeEditor(ForgeEditor editor);

  /// Makes [editor] the one the user sees and works in, without moving it.
  void bringToFront(ForgeEditor editor);

  /// Opens [uri] in the editor the application chooses for it, wherever the
  /// application places it — by [placement] when it gives one it understands
  /// — and answers that editor; null when nothing can show it.
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement});
}
