import 'package:flutter/foundation.dart' show immutable;

/// One piece of content an editor can open: a URI and, when the application
/// knows it, its content type (a MIME type such as `text/markdown`,
/// `application/pdf` or `application/vnd.tom.webwork.spreadsheet+yaml`).
///
/// A file is an item whose URI names it (its extension is read off the last
/// path segment); content that is not a file — a section of a document, say —
/// is an item with a URI of the application's own and its body type as
/// [contentType]. The editor picker (`ForgeEditorPicker`) offers the editors
/// of an item by both.
@immutable
class ForgeContentItem {
  /// An item at [uri] of [contentType] (null: unknown, the item is chosen
  /// for by its extension only).
  ForgeContentItem(this.uri, {String? contentType})
    : contentType = forgeNormalizeContentType(contentType);

  /// Where the content is.
  final Uri uri;

  /// The content type, lower case and without parameters (`text/markdown`),
  /// or null when unknown.
  final String? contentType;

  /// The extension of [uri]'s last path segment, lower case with its dot
  /// (`.md`), or the empty string when it has none.
  String get extension => forgeExtensionOf(uri);

  @override
  bool operator ==(Object other) =>
      other is ForgeContentItem &&
      other.uri == uri &&
      other.contentType == contentType;

  @override
  int get hashCode => Object.hash(uri, contentType);

  @override
  String toString() =>
      'ForgeContentItem($uri${contentType == null ? '' : ', $contentType'})';
}

/// [contentType] lower case, trimmed and without parameters
/// (`Text/Markdown; charset=utf-8` → `text/markdown`); null for null or
/// empty.
String? forgeNormalizeContentType(String? contentType) {
  if (contentType == null) return null;
  final semicolon = contentType.indexOf(';');
  final bare =
      (semicolon < 0 ? contentType : contentType.substring(0, semicolon))
          .trim()
          .toLowerCase();
  return bare.isEmpty ? null : bare;
}

/// Whether one of [declared] names [contentType]: the same type, or a family
/// (`text/*`) it belongs to, or `*/*`. Parameters and case are ignored; a null
/// [contentType] is never accepted.
bool forgeContentTypeAccepted(List<String> declared, String? contentType) {
  final actual = forgeNormalizeContentType(contentType);
  if (actual == null || declared.isEmpty) return false;
  final slash = actual.indexOf('/');
  final family = slash < 0 ? null : '${actual.substring(0, slash)}/*';
  for (final entry in declared) {
    final type = forgeNormalizeContentType(entry);
    if (type == null) continue;
    if (type == actual || type == '*/*' || type == family) return true;
  }
  return false;
}

/// The extension of [uri]'s last path segment, lower case with its dot
/// (`.md`; `.env` for a file named `.env`), or the empty string when it has
/// none — as the file-type defaults key it.
String forgeExtensionOf(Uri uri) {
  final segments = uri.pathSegments;
  if (segments.isEmpty) return '';
  final name = segments.last;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return '.${name.substring(dot + 1).toLowerCase()}';
}
