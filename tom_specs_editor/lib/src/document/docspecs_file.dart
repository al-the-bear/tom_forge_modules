import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart';

import '../structure/review_store.dart';

/// The decoded contents of a `*.docspecs.yaml` file
/// (`tom_specs_editor_specification.md` §15.1): the `document:` pass as a live
/// [SpecDocument] (decoded tree-driven), plus the `review:` pass as
/// structural-review entries keyed by path.
class DocSpecsContents {
  DocSpecsContents({
    required this.document,
    required this.review,
    this.modelVersion,
  });

  /// The `document:` pass as a live [SpecDocument]. Transfer its state into a
  /// controller's fixed document via `restoreState(document.captureState())`.
  final SpecDocument document;

  /// The `review:` pass, ready for [ReviewStore.replaceEntries].
  final Map<String, ReviewEntry> review;

  /// The authoring object-model version (`major.minor`) this document was last
  /// written against, or `null` for an unstamped/hand-written file. Distinct
  /// from [DocSpecsFile.formatVersion] (the on-disk format version): this
  /// stamps *which model version* the content conforms to, and drives the
  /// document-vs-model compatibility check.
  final String? modelVersion;
}

/// Codec for the native `*.docspecs.yaml` document format
/// (`tom_specs_editor_specification.md` §15.1).
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
  ///
  /// Delegated to the generic runtime, which owns the `document:`-pass format
  /// (step 4 of the multi-platform spec-model plan).
  static const int formatVersion = SpecDocumentYaml.formatVersion;

  // --- Encode ----------------------------------------------------------------

  /// Serializes [document] + [review] to the two-pass `*.docspecs.yaml` text.
  ///
  /// The header + `version:`/`modelVersion:` stamp and the `document:` pass come
  /// from the generic [SpecDocumentYaml] codec — which walks [tree] (the
  /// document root's metadata tree) to place every value at its hierarchical
  /// section-id path. This method composes the editor-only `review:` pass
  /// through the same codec. [modelVersion] stamps the authoring object-model version
  /// (`major.minor`); an unstamped file (null) omits the key.
  static String encode({
    required SpecDocument document,
    required SomMetaTree tree,
    required Map<String, ReviewEntry> review,
    String? modelVersion,
  }) {
    // The `review:` pass is written by the runtime's pass-through writer
    // ([SpecDocumentYaml.writeReviewPass]); only the mapping onto the editor's
    // [ReviewEntry] type lives here. Empty entries carry nothing to persist.
    return SpecDocumentYaml.encode(
      document: document,
      tree: tree,
      modelVersion: modelVersion,
      review: {
        for (final e in review.entries)
          if (!e.value.isEmpty) e.key: e.value.toMap(),
      },
    );
  }

  // --- Decode ----------------------------------------------------------------

  /// Parses a `*.docspecs.yaml` document into its two passes. The generic codec
  /// walks [tree] to decode the `document:` pass into a live [SpecDocument]
  /// reads the `review:` pass + the model-version stamp; this maps the
  /// raw `review:` map onto the editor's [ReviewEntry] type. The codec
  /// throws [SpecYamlFormatException] on malformed input (non-mapping YAML,
  /// missing/unsupported `version:`, wrong root key), so a hand-written file
  /// must carry a valid header.
  static DocSpecsContents decode(String yaml, SomMetaTree tree) {
    final contents = SpecDocumentYaml.decode(yaml, tree);

    final review = <String, ReviewEntry>{};
    contents.review?.forEach((k, v) {
      if (v is Map) review['$k'] = ReviewEntry.fromMap(v);
    });

    return DocSpecsContents(
      document: contents.document,
      review: review,
      modelVersion: contents.modelVersion,
    );
  }

  // --- Session-id sidecar (A2) -----------------------------------------------

  /// The session-id sidecar of the document [uri] (`<file>.session`).
  static Uri sidecarFor(Uri uri) => uri.replace(path: '${uri.path}.session');

  /// Writes (or clears, on a null/empty id) the session-id sidecar of the
  /// document [uri] in [fileSystem].
  static Future<void> writeSessionId(
    TomFileSystem fileSystem,
    Uri uri,
    String? sessionId,
  ) async {
    final sidecar = sidecarFor(uri);
    if (sessionId == null || sessionId.isEmpty) {
      if (await fileSystem.exists(sidecar)) await fileSystem.delete(sidecar);
      return;
    }
    await fileSystem.writeTextMakingFolder(sidecar, sessionId);
  }

  /// Reads the session-id sidecar of the document [uri], or `null` when
  /// absent/empty.
  static Future<String?> readSessionId(
    TomFileSystem fileSystem,
    Uri uri,
  ) async {
    final text = (await fileSystem.readTextIfExists(sidecarFor(uri)))?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
