/// Metadata associated with a document provider.
class MdDocumentMetadata {
  const MdDocumentMetadata({
    this.title,
    this.path,
    this.lastModified,
    this.schemaId,
    this.custom,
  });

  final String? title;
  final String? path;
  final DateTime? lastModified;
  final String? schemaId;
  final Map<String, dynamic>? custom;
}

/// Interface for loading and saving markdown documents.
///
/// Implementations provide flexible document sources beyond simple strings.
abstract class MdDocumentProvider {
  /// Load the document content.
  Future<String> load();

  /// Save the document content (optional — check [canSave] first).
  Future<void> save(String markdown);

  /// Whether this provider supports saving.
  bool get canSave;

  /// Stream of external changes for live reload (optional).
  Stream<String>? get externalChanges;

  /// Document metadata (optional).
  MdDocumentMetadata? get metadata;
}

/// Provider backed by a simple in-memory string.
class StringDocumentProvider implements MdDocumentProvider {
  StringDocumentProvider({required String markdown}) : _markdown = markdown;

  String _markdown;

  @override
  Future<String> load() async => _markdown;

  @override
  Future<void> save(String markdown) async => _markdown = markdown;

  @override
  bool get canSave => true;

  @override
  Stream<String>? get externalChanges => null;

  @override
  MdDocumentMetadata? get metadata => null;
}
