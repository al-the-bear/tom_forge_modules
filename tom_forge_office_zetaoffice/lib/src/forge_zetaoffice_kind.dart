import 'package:flutter/material.dart';

/// The kind of an office file ZetaOffice opens, from its extension: it picks
/// the tab icon. The same table as the LibreOfficeKit adapter's
/// (`ForgeOfficeKind`), kept here so neither adapter depends on the other
/// (R6).
enum ForgeZetaOfficeKind {
  /// A text document (`.docx`, `.odt`, `.doc`, `.rtf`).
  document,

  /// A spreadsheet (`.xlsx`, `.ods`, `.xls`, `.csv`).
  spreadsheet,

  /// A presentation (`.pptx`, `.odp`, `.ppt`).
  presentation;

  /// The tab icon.
  IconData get icon => switch (this) {
    document => Icons.description_outlined,
    spreadsheet => Icons.table_chart_outlined,
    presentation => Icons.slideshow_outlined,
  };

  /// The extensions (lower case, without the dot) and their kinds: the six
  /// office formats and the older ones of DPOE-2.
  static const extensions = <String, ForgeZetaOfficeKind>{
    'docx': document,
    'odt': document,
    'doc': document,
    'rtf': document,
    'xlsx': spreadsheet,
    'ods': spreadsheet,
    'xls': spreadsheet,
    'csv': spreadsheet,
    'pptx': presentation,
    'odp': presentation,
    'ppt': presentation,
  };

  /// The extensions only offered under *Open With*, never opened by the
  /// module itself: `.csv` is text and keeps the plain-text editor.
  static const openWithOnly = {'csv'};

  /// The lower-case extension of [uri]'s last segment, or `''`.
  static String extensionOf(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// The kind of [uri] (any case), or null for another file.
  static ForgeZetaOfficeKind? of(Uri uri) => extensions[extensionOf(uri)];
}
