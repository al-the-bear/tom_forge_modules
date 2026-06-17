import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../structure/review_store.dart';
import 'spec_document.dart';

/// The decoded contents of a `*.docspecs.yaml` file (§15.1): the `document:`
/// pass as a [SpecDocument.loadJson]-shaped map, plus the `review:` pass as
/// structural-review entries keyed by path.
class DocSpecsContents {
  DocSpecsContents({required this.document, required this.review});

  /// The `document:` pass, ready for [SpecDocument.loadJson].
  final Map<dynamic, dynamic> document;

  /// The `review:` pass, ready for [ReviewStore.replaceEntries].
  final Map<String, ReviewEntry> review;
}

/// Codec for the native `*.docspecs.yaml` document format (§15.1).
///
/// The file has **two top-level passes** — `document:` (the live object-model
/// values, sorted by full section id) and `review:` (structural-review state
/// keyed by path) — so a save→load restores the full UI state. Two deliberate
/// exclusions keep the YAML diff-clean:
///   * the **agent change log is not serialized** — it resets on save (M2);
///   * the **SDK session id lives in a `<file>.session` sidecar** (A2), never
///     in the document YAML.
///
/// **All text values are written as literal block scalars (`|2-`)** so
/// multi-line content round-trips verbatim and the file reads cleanly without
/// the editor (IO2/N4). The emitter is **self-verifying**: it re-parses each
/// block it produces and falls back to a JSON-quoted scalar (always valid YAML,
/// guaranteed to round-trip) for any value a clean block can't represent —
/// values with two or more trailing newlines, or anything the parser doesn't
/// reproduce exactly. Because the live [SpecDocument] keys every value by a
/// globally-unique section path with no projection copies, each section is
/// emitted exactly once (no duplicate subtrees).
class DocSpecsFile {
  /// The on-disk format version (independent of the model version stamp).
  static const int formatVersion = 1;

  // --- Encode -------------------------------------------------------------

  /// Serializes [document] + [review] to the two-pass `*.docspecs.yaml` text.
  static String encode({
    required SpecDocument document,
    required Map<String, ReviewEntry> review,
  }) {
    final b = StringBuffer()
      ..writeln('# TomSpecs document (*.docspecs.yaml).')
      ..writeln('# Two passes: `document:` (object-model values, sorted by '
          'section id) and')
      ..writeln('# `review:` (structural review, keyed by path). Text values '
          'use block')
      ..writeln('# scalars so multi-line content round-trips verbatim (§15.1).')
      ..writeln('# The agent change log is not persisted; the SDK session id '
          'lives in a')
      ..writeln('# `<file>.session` sidecar, never here.')
      ..writeln('version: $formatVersion');
    _writeDocument(b, document.toJson());
    _writeReview(b, review);
    return b.toString();
  }

  static void _writeDocument(StringBuffer b, Map<String, Object?> doc) {
    final content = doc['content'];
    final forms = doc['forms'];
    final lists = doc['lists'];
    if (content == null && forms == null && lists == null) {
      b.writeln('document: {}');
      return;
    }
    b.writeln('document:');

    if (content is Map && content.isNotEmpty) {
      b.writeln('  content:');
      for (final k in _sortedStringKeys(content)) {
        _writeScalar(b, 4, k, '${content[k]}');
      }
    }

    if (forms is Map && forms.isNotEmpty) {
      b.writeln('  forms:');
      for (final k in _sortedStringKeys(forms)) {
        final fields = forms[k];
        if (fields is! Map || fields.isEmpty) continue;
        b.writeln('    ${_key(k)}:');
        for (final f in _sortedStringKeys(fields)) {
          _writeScalar(b, 6, f, '${fields[f]}');
        }
      }
    }

    if (lists is Map && lists.isNotEmpty) {
      b.writeln('  lists:');
      for (final k in _sortedStringKeys(lists)) {
        final spec = lists[k];
        if (spec is! Map) continue;
        b.writeln('    ${_key(k)}:');
        b.writeln('      seq: ${spec['seq'] ?? 0}');
        final items = spec['items'];
        if (items is List && items.isNotEmpty) {
          b.writeln('      items:');
          for (final it in items) {
            b.writeln('        - ${_key('$it')}');
          }
        } else {
          b.writeln('      items: []');
        }
      }
    }
  }

  static void _writeReview(StringBuffer b, Map<String, ReviewEntry> review) {
    final keys = review.keys.where((k) => !review[k]!.isEmpty).toList()..sort();
    if (keys.isEmpty) {
      b.writeln('review: {}');
      return;
    }
    b.writeln('review:');
    for (final key in keys) {
      final e = review[key]!;
      b.writeln('  ${_key(key)}:');
      b.writeln('    scope: ${e.scope.token}');
      if (e.stopHere) b.writeln('    stop_here: true');
      if (e.addDetails) b.writeln('    add_details: true');
      if (e.mustBeList) b.writeln('    must_be_list: true');
      if (e.singleEntry) b.writeln('    single_entry: true');
      if (e.mustBeContentString) b.writeln('    must_be_content_string: true');
      if (e.convertFormToContent) {
        b.writeln('    convert_form_to_content: true');
      }
      if (e.reviewed) b.writeln('    reviewed: true');
      if (e.comment.trim().isNotEmpty) {
        _writeScalar(b, 4, 'comment', e.comment.trim());
      }
    }
  }

  /// Writes `<indent><key>: <scalar>` where the scalar is a self-verified block
  /// scalar (or a JSON-quoted fallback). Block body lines, which the builder
  /// emits at a relative indent of 2, are re-indented to [keyIndent] + 2.
  static void _writeScalar(
      StringBuffer b, int keyIndent, String key, String value) {
    final pad = ' ' * keyIndent;
    final repr = _scalar(value);
    final lines = repr.split('\n');
    b.writeln('$pad${_key(key)}: ${lines.first}');
    for (final line in lines.skip(1)) {
      if (line.isEmpty) {
        b.writeln('');
      } else {
        b.writeln('$pad$line');
      }
    }
  }

  /// The scalar representation of [value]: a literal block at relative indent 2
  /// when that round-trips, else a JSON-quoted scalar.
  static String _scalar(String value) {
    final block = _literalBlock(value);
    if (block != null && _roundTrips(block, value)) return block;
    return jsonEncode(value);
  }

  /// Builds a literal block scalar (`|2<chomp>`) with body at relative indent
  /// 2, or `null` when chomping can't reproduce the value's trailing newlines
  /// (two or more) — those fall back to JSON quoting.
  static String? _literalBlock(String value) {
    final trailing = _trailingNewlines(value);
    final String chomp;
    final String core;
    if (trailing == 0) {
      chomp = '-';
      core = value;
    } else if (trailing == 1) {
      chomp = '';
      core = value.substring(0, value.length - 1);
    } else {
      return null;
    }
    final sb = StringBuffer('|2$chomp');
    for (final line in core.split('\n')) {
      sb.write('\n');
      if (line.isNotEmpty) sb.write('  $line');
    }
    return sb.toString();
  }

  /// Whether re-parsing `_v: <block>` yields exactly [value] (the emitter's
  /// correctness guard).
  static bool _roundTrips(String block, String value) {
    try {
      final parsed = loadYaml('_v: $block\n');
      return parsed is Map && parsed['_v'] == value;
    } catch (_) {
      return false;
    }
  }

  static int _trailingNewlines(String value) {
    var n = 0;
    var i = value.length;
    while (i > 0 && value.codeUnitAt(i - 1) == 0x0a) {
      n++;
      i--;
    }
    return n;
  }

  /// A safely-quoted mapping key. JSON strings are valid YAML flow scalars, so
  /// this both quotes and escapes any path/field name unambiguously.
  static String _key(String key) => jsonEncode(key);

  static List<String> _sortedStringKeys(Map map) =>
      map.keys.map((k) => '$k').toList()..sort();

  // --- Decode -------------------------------------------------------------

  /// Parses a `*.docspecs.yaml` document into its two passes. A missing pass
  /// decodes as empty rather than failing, so a partial/hand-written file still
  /// loads what it has.
  static DocSpecsContents decode(String yaml) {
    final root = yaml.trim().isEmpty ? null : loadYaml(yaml);
    final doc = (root is Map ? root['document'] : null);
    final rev = (root is Map ? root['review'] : null);

    final review = <String, ReviewEntry>{};
    if (rev is Map) {
      rev.forEach((k, v) {
        if (v is Map) review['$k'] = ReviewEntry.fromMap(v);
      });
    }

    return DocSpecsContents(
      document: doc is Map ? doc : const {},
      review: review,
    );
  }

  // --- Session-id sidecar (A2) --------------------------------------------

  /// The session-id sidecar path for a document [file] (`<path>.session`).
  static File sidecarFor(File file) => File('${file.path}.session');

  /// Writes (or clears, on a null/empty id) the session-id sidecar.
  static Future<void> writeSessionId(File file, String? sessionId) async {
    final sidecar = sidecarFor(file);
    if (sessionId == null || sessionId.isEmpty) {
      if (await sidecar.exists()) await sidecar.delete();
      return;
    }
    await sidecar.writeAsString(sessionId);
  }

  /// Reads the session-id sidecar, or `null` when absent/empty.
  static Future<String?> readSessionId(File file) async {
    final sidecar = sidecarFor(file);
    if (!await sidecar.exists()) return null;
    final text = (await sidecar.readAsString()).trim();
    return text.isEmpty ? null : text;
  }
}
