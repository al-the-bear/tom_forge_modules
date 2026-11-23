import '../components/forge_editor.dart';

/// Where editors appear: the port through which the kit asks the application
/// to show, close or bring forward an editor.
///
/// The kit never decides where an editor appears. The application implements
/// this port with whatever arrangement it has (the panel shell implements it
/// with its editor groups; an application with a single editor area shows one
/// editor at a time) and decides, in [openEditorFor], which editor a resource
/// gets.
abstract class ForgeEditorHost {
  /// Shows [editor] — adds it when it is not shown yet — and gives it the
  /// focus unless [focus] is false.
  Future<void> showEditor(ForgeEditor editor, {bool focus = true});

  /// Closes [editor]; answers false when it stays open (the user kept it, or
  /// the host does not show it).
  Future<bool> closeEditor(ForgeEditor editor);

  /// Makes [editor] the one the user sees and works in, without moving it.
  void bringToFront(ForgeEditor editor);

  /// Opens [uri] in the editor the application chooses for it, wherever the
  /// application places it, and answers that editor; null when nothing can
  /// show it.
  Future<ForgeEditor?> openEditorFor(Uri uri);
}
