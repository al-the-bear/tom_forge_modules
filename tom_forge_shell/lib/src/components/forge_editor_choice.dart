import 'package:tom_forge_kit/tom_forge_kit.dart';

/// One editor a file can be opened in, as **Open With** offers it: a module
/// names the editors it has for a file (`ForgeModule.editorChoicesFor`), and
/// the shell lets the user pick among every module's.
///
/// The kit's [ForgeKitEditorChoice], whose [open] also takes the middle
/// panel the shell opens the file in.
class ForgeEditorChoice extends ForgeKitEditorChoice {
  const ForgeEditorChoice({
    required super.id,
    required super.label,
    required super.icon,
    required this.open,
    super.description,
    super.contentTypes,
  }) : super.base();

  /// Opens the file in this editor, in the middle panel [middlePanelIndex]
  /// (null: the active one).
  @override
  final void Function(Uri uri, {int? middlePanelIndex}) open;
}
