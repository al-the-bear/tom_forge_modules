import 'dart:async';
import 'dart:convert';

import 'package:tom_forge_core/src/types/text_range.dart';

/// An event fired when a document's content changes.
class DocumentChangeEvent {
  /// The ranges that were changed.
  final List<ForgeTextRange> changes;

  /// The document after the change.
  final ForgeDocument document;

  const DocumentChangeEvent({required this.changes, required this.document});
}

/// Abstract document model backing an editor.
///
/// Represents a file's content with line-based access, versioning,
/// and dirty-state tracking.
abstract class ForgeDocument {
  /// The document's URI.
  Uri get uri;

  /// The full text content.
  String get text;

  /// The number of lines.
  int get lineCount;

  /// Get the text of a specific line (0-based).
  String lineAt(int line);

  /// Get the text in a range.
  String textInRange(ForgeTextRange range);

  /// The language or file type identifier (e.g., 'dart', 'yaml').
  String get languageId;

  /// The file's encoding.
  Encoding get encoding;

  /// Document version counter. Increments on each edit.
  int get version;

  /// Whether this document has never been saved to disk ("untitled").
  bool get isUntitled;

  /// Fires when the document content changes.
  Stream<DocumentChangeEvent> get onDidChange;
}
