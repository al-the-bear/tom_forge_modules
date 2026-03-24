import 'package:tom_forge_core/src/types/text_range.dart';

/// An atomic multi-file edit operation. All changes are applied as a
/// single undo step and either all succeed or all are rolled back.
class ForgeWorkspaceEdit {
  /// Text edits grouped by URI.
  final Map<Uri, List<ForgeTextEdit>> textEdits;

  /// File operations (create, delete, rename).
  final List<ForgeFileOperation> fileOperations;

  const ForgeWorkspaceEdit({
    this.textEdits = const {},
    this.fileOperations = const [],
  });
}

/// A single text edit within a document.
class ForgeTextEdit {
  final ForgeTextRange range;
  final String newText;

  const ForgeTextEdit({required this.range, required this.newText});
}

/// Base class for file operations in a workspace edit.
abstract class ForgeFileOperation {
  const ForgeFileOperation();
}

/// Create a new file.
class ForgeCreateFileOperation extends ForgeFileOperation {
  final Uri uri;
  final String? content;
  final bool overwrite;

  const ForgeCreateFileOperation({
    required this.uri,
    this.content,
    this.overwrite = false,
  });
}

/// Delete a file.
class ForgeDeleteFileOperation extends ForgeFileOperation {
  final Uri uri;
  final bool recursive;

  const ForgeDeleteFileOperation({required this.uri, this.recursive = false});
}

/// Rename a file.
class ForgeRenameFileOperation extends ForgeFileOperation {
  final Uri oldUri;
  final Uri newUri;
  final bool overwrite;

  const ForgeRenameFileOperation({
    required this.oldUri,
    required this.newUri,
    this.overwrite = false,
  });
}
