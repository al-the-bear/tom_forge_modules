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

/// Matches a §3 placeholder token: a bare `{name}` brace pair (no leading `$`),
/// where the name starts with a letter and may contain word chars plus the
/// `:` `.` `-` separators used by built-ins (e.g. `{websiteRoot}`, `{env:HOME}`,
/// `{date}`). The space-requiring forms of YAML flow maps (`{ a: 1 }`) do not
/// match, so structured values are not mistaken for placeholders.
final RegExp _placeholderPattern = RegExp(r'\{[A-Za-z][\w.:-]*\}');

/// Whether [value] contains a §3 `{placeholder}` token that the generator
/// resolves at build time. The browser uses this to flag a field's value as a
/// deferred-resolution hint rather than a literal.
bool valueHasPlaceholder(String value) => _placeholderPattern.hasMatch(value);

/// Renders a parsed YAML value as the display text the browser shows (§6a):
/// a list becomes its comma-joined items, a scalar its `toString`, and `null`
/// the empty string. Shared by the component-record parser and the copy-file
/// front-matter model so both stringify values identically.
String stringifyContentValue(Object? value) {
  if (value is List) return value.join(', ');
  return value?.toString() ?? '';
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
