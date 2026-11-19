import 'package:flutter/widgets.dart';

/// One editor a file can be opened in, as **Open With** offers it: a module
/// names the editors it has for a file (`ForgeModule.editorChoicesFor`), and
/// the shell lets the user pick among every module's.
@immutable
class ForgeEditorChoice {
  const ForgeEditorChoice({
    required this.id,
    required this.label,
    required this.icon,
    required this.open,
    this.description,
  });

  /// Which editor this is, stable across files: the key a file-type default
  /// names (`DefaultShellApi.setFileTypeDefault('.yaml', 'yaml')`).
  final String id;

  /// The editor's name in the choice (e.g. "YAML editor").
  final String label;

  /// One line on what it is for, or null.
  final String? description;

  final IconData icon;

  /// Opens the file in this editor.
  final void Function(Uri uri, {int? middlePanelIndex}) open;
}
