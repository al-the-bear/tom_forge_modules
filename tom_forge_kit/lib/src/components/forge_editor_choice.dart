import 'package:flutter/widgets.dart';

import '../files/forge_content_item.dart';

/// One editor a file can be opened in, as **Open With** offers it: a module
/// names the editors it has for a file (`ForgeKitModule.editorChoicesFor`),
/// and the application lets the user pick among every module's.
///
/// `ForgeKitEditorChoice(...)` makes one that opens the file with [open]; a
/// host whose choices take more (the panel shell's `ForgeEditorChoice`)
/// extends [ForgeKitEditorChoice.base].
///
/// A choice may also name the content types (MIME types) it opens
/// ([contentTypes]): a module declares such choices as
/// `ForgeKitModule.contentTypeEditorChoices`, and the editor picker
/// (`ForgeEditorPicker`) offers them for a content item of that type, file or
/// not.
@immutable
abstract class ForgeKitEditorChoice {
  /// A choice that opens the file with [open].
  const factory ForgeKitEditorChoice({
    required String id,
    required String label,
    required IconData icon,
    required void Function(Uri uri) open,
    String? description,
    List<String> contentTypes,
  }) = _ForgeKitEditorChoice;

  /// For a subclass that provides [open] itself.
  const ForgeKitEditorChoice.base({
    required this.id,
    required this.label,
    required this.icon,
    this.description,
    this.contentTypes = const [],
  });

  /// Which editor this is, stable across files: the key a file-type default
  /// names (`setFileTypeDefault('.yaml', 'yaml')`).
  final String id;

  /// The editor's name in the choice (e.g. "YAML editor").
  final String label;

  /// One line on what it is for, or null.
  final String? description;

  final IconData icon;

  /// The content types (MIME types, e.g. `text/markdown`, `application/pdf`,
  /// or a family as `text/*`) this editor opens; empty for a choice offered
  /// by file only.
  final List<String> contentTypes;

  /// Whether this choice opens content of [contentType] (one of
  /// [contentTypes] names it, parameters and case ignored).
  bool acceptsContentType(String? contentType) =>
      forgeContentTypeAccepted(contentTypes, contentType);

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
    super.contentTypes,
  }) : super.base();

  @override
  final void Function(Uri uri) open;
}
