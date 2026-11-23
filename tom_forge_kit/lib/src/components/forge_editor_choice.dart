import 'package:flutter/widgets.dart';

/// One editor a file can be opened in, as **Open With** offers it: a module
/// names the editors it has for a file (`ForgeKitModule.editorChoicesFor`),
/// and the application lets the user pick among every module's.
///
/// `ForgeKitEditorChoice(...)` makes one that opens the file with [open]; a
/// host whose choices take more (the panel shell's `ForgeEditorChoice`)
/// extends [ForgeKitEditorChoice.base].
@immutable
abstract class ForgeKitEditorChoice {
  /// A choice that opens the file with [open].
  const factory ForgeKitEditorChoice({
    required String id,
    required String label,
    required IconData icon,
    required void Function(Uri uri) open,
    String? description,
  }) = _ForgeKitEditorChoice;

  /// For a subclass that provides [open] itself.
  const ForgeKitEditorChoice.base({
    required this.id,
    required this.label,
    required this.icon,
    this.description,
  });

  /// Which editor this is, stable across files: the key a file-type default
  /// names (`setFileTypeDefault('.yaml', 'yaml')`).
  final String id;

  /// The editor's name in the choice (e.g. "YAML editor").
  final String label;

  /// One line on what it is for, or null.
  final String? description;

  final IconData icon;

  /// Opens the file in this editor, where the application places it.
  void Function(Uri uri) get open;
}

class _ForgeKitEditorChoice extends ForgeKitEditorChoice {
  const _ForgeKitEditorChoice({
    required super.id,
    required super.label,
    required super.icon,
    required this.open,
    super.description,
  }) : super.base();

  @override
  final void Function(Uri uri) open;
}
