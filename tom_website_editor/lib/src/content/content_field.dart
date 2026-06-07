/// Which inline editor a content field routes to (§6a). The website's data uses
/// typed name suffixes (enterprise spec §4.1): a `-md` field is Markdown, a
/// `-json` field is JSON, everything else is a plain string.
enum ContentEditorKind { markdown, json, string }

/// Returns the [ContentEditorKind] for a field named [fieldName], by its typed
/// suffix. `summary-md` → [ContentEditorKind.markdown]; `links-json` →
/// [ContentEditorKind.json]; `tagline` → [ContentEditorKind.string].
ContentEditorKind contentEditorKindForField(String fieldName) {
  if (fieldName.endsWith('-md')) return ContentEditorKind.markdown;
  if (fieldName.endsWith('-json')) return ContentEditorKind.json;
  return ContentEditorKind.string;
}

/// One field of a content record (§6a), classified for the browser.
///
/// A field is [isEditable] when its name is in the website's
/// `content.editableFields` **or** it carries the `# @manual` pin
/// ([isPinned]); otherwise it is generator-managed and shown read-only.
class ContentField {
  const ContentField({
    required this.name,
    required this.value,
    required this.isEditable,
    required this.isPinned,
    required this.sourceLine,
  });

  /// The YAML key (e.g. `summary-md`).
  final String name;

  /// The current value as text (scalars stringified; structured values kept as
  /// their YAML form for display).
  final String value;

  /// `true` when the field is hand-editable (curated or pinned).
  final bool isEditable;

  /// `true` when the field carries the configured manual pin.
  final bool isPinned;

  /// Zero-based source line of the field's key, for pin read/write.
  final int sourceLine;

  /// The inline editor this field routes to.
  ContentEditorKind get editorKind => contentEditorKindForField(name);
}
