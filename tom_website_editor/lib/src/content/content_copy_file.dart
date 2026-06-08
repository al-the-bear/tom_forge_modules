import 'package:yaml/yaml.dart';

import 'content_field.dart';
import 'content_page.dart';
import 'content_parser.dart' show setFieldLineValue;

/// One editable front-matter field of a copy file (§16): its YAML [name], the
/// current [value] as display text, and its zero-based [sourceLine] within the
/// front-matter block (for line-precise edits).
class CopyFrontMatterField {
  const CopyFrontMatterField({
    required this.name,
    required this.value,
    required this.sourceLine,
  });

  /// The front-matter key (e.g. `summary-md`).
  final String name;

  /// The current value as text (scalars stringified; flow lists comma-joined).
  final String value;

  /// Zero-based line of the key within the front-matter block.
  final int sourceLine;

  /// The inline editor this field routes to, by its typed suffix (`-md` →
  /// Markdown, `-json` → JSON, otherwise a plain string).
  ContentEditorKind get editorKind => contentEditorKindForField(name);
}

/// An external editorial copy file `content/copy/<…>.md` (website §16): YAML
/// front-matter delimited by `---` lines, followed by a Markdown [body].
///
/// The front-matter carries the curated copy fields (`tagline`, `summary-md`,
/// `enables`, …) and the body is the overview — the §6a editable surface,
/// living in the file rather than as inline YAML `-md` on a record. The body is
/// a region-aware [ContentPage], so the §6.2 `@tom:override` / `@tom:managed`
/// insert markers and the managed regions they protect round-trip untouched
/// when an override region is edited.
///
/// [serialize] reproduces the source byte-for-byte, so a hand edit to a
/// front-matter field or an override region survives the next `generateContent`
/// (the generator only rewrites managed regions; everything else is preserved).
class ContentCopyFile {
  const ContentCopyFile._({
    required String frontMatterText,
    required this.body,
    required this.hasFrontMatter,
    required List<CopyFrontMatterField> frontMatter,
  })  : _frontMatterText = frontMatterText,
        _frontMatter = frontMatter;

  /// The raw YAML between the `---` delimiters (no delimiters), kept verbatim so
  /// edits are line-precise and untouched lines round-trip exactly.
  final String _frontMatterText;

  /// The Markdown body, split into managed/override regions (§6.2).
  final ContentPage body;

  /// `true` when the file opens with a `---` front-matter block.
  final bool hasFrontMatter;

  final List<CopyFrontMatterField> _frontMatter;

  /// The front-matter fields in document order (empty without front-matter).
  List<CopyFrontMatterField> get frontMatter => List.unmodifiable(_frontMatter);

  /// Parses [raw] into front-matter + body, classifying body regions with
  /// [classify] (defaults to [defaultPageMarker]). A file that does not open
  /// with a `---` delimiter line has no front-matter; the whole file is body.
  factory ContentCopyFile.parse(String raw,
      {PageMarkerClassifier classify = defaultPageMarker}) {
    final lines = raw.split('\n');
    if (lines.isNotEmpty && lines.first.trim() == '---') {
      final close = _closingDelimiter(lines);
      if (close > 0) {
        final frontMatterText = lines.sublist(1, close).join('\n');
        final bodyText = lines.sublist(close + 1).join('\n');
        return ContentCopyFile._(
          frontMatterText: frontMatterText,
          body: ContentPage.parse(bodyText, classify: classify),
          hasFrontMatter: true,
          frontMatter: _parseFrontMatter(frontMatterText),
        );
      }
    }
    return ContentCopyFile._(
      frontMatterText: '',
      body: ContentPage.parse(raw, classify: classify),
      hasFrontMatter: false,
      frontMatter: const [],
    );
  }

  /// The index of the closing `---` line, or `-1` when the block is unterminated.
  static int _closingDelimiter(List<String> lines) {
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') return i;
    }
    return -1;
  }

  /// Parses the front-matter YAML into display fields with their source lines.
  /// A non-mapping (or empty) front-matter yields no editable fields.
  static List<CopyFrontMatterField> _parseFrontMatter(String text) {
    if (text.trim().isEmpty) return const [];
    final doc = loadYaml(text);
    if (doc is! YamlMap) return const [];
    return [
      for (final entry in doc.nodes.entries)
        CopyFrontMatterField(
          name: (entry.key as YamlNode).value.toString(),
          value: stringifyContentValue(entry.value.value),
          sourceLine: (entry.key as YamlNode).span.start.line,
        ),
    ];
  }

  /// The current value of the front-matter field named [name], or `null` when no
  /// such field exists.
  String? frontMatterValue(String name) {
    for (final field in _frontMatter) {
      if (field.name == name) return field.value;
    }
    return null;
  }

  /// The source line of the front-matter field named [name], or `null` when no
  /// such field exists.
  int? _sourceLineOf(String name) {
    for (final field in _frontMatter) {
      if (field.name == name) return field.sourceLine;
    }
    return null;
  }

  /// Returns a copy with front-matter field [name]'s scalar value replaced by
  /// [value]; all other front-matter lines and the body are preserved verbatim.
  /// An unknown field name is a no-op (returns an equivalent file).
  ContentCopyFile withFrontMatterValue(String name, String value) {
    final line = _sourceLineOf(name);
    if (line == null) return this;
    final updated = setFieldLineValue(_frontMatterText, line, value);
    if (updated == _frontMatterText) return this;
    return ContentCopyFile._(
      frontMatterText: updated,
      body: body,
      hasFrontMatter: hasFrontMatter,
      frontMatter: _parseFrontMatter(updated),
    );
  }

  /// Returns a copy with the body replaced by [newBody] (front-matter intact).
  /// Pair with [ContentPage.withRegionBody] to edit a single override region.
  ContentCopyFile withBody(ContentPage newBody) => ContentCopyFile._(
        frontMatterText: _frontMatterText,
        body: newBody,
        hasFrontMatter: hasFrontMatter,
        frontMatter: _frontMatter,
      );

  /// Re-joins the front-matter (between `---` delimiters) and the body back into
  /// source text — a faithful round-trip of the parsed file.
  String serialize() {
    final bodyText = body.serialize();
    if (!hasFrontMatter) return bodyText;
    return '---\n$_frontMatterText\n---\n$bodyText';
  }
}
