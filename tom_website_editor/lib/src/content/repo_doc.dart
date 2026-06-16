/// Repo-sourced documents the data-model view surfaces read-only (§9 item 5).
///
/// A component's / module's `README`, `LICENSE`, and `release.md` live in the
/// upstream repository's source tree — resolved server-side from `sourceRoot`
/// (mirroring the website's `repo_docs_loader`), **not** in `content/`. The
/// content browser shows them as repo-sourced provenance: visible, badged
/// read-only, and never offered for inline edit or pinning (they are owned by
/// the upstream repo, not the editor).
library;

/// Which repo-sourced document a [RepoDocRef] is (§9 item 5). The order is the
/// display order the browser renders: README, then LICENSE, then release.md.
enum RepoDocKind { readme, license, release }

/// Display / matching metadata for a [RepoDocKind].
extension RepoDocKindInfo on RepoDocKind {
  /// The lowercase base-name stem matched (case-insensitively, extension
  /// stripped) against the files in a repo root — `readme` matches `README.md`,
  /// `README`, `readme.txt`, etc.
  String get stem => switch (this) {
        RepoDocKind.readme => 'readme',
        RepoDocKind.license => 'license',
        RepoDocKind.release => 'release',
      };

  /// The label shown on the read-only badge row.
  String get label => switch (this) {
        RepoDocKind.readme => 'README',
        RepoDocKind.license => 'LICENSE',
        RepoDocKind.release => 'release.md',
      };
}

/// One discovered repo-sourced document for a record (§9 item 5): which [kind]
/// it is and the [uri] of the file found in the source tree.
class RepoDocRef {
  const RepoDocRef({required this.kind, required this.uri});

  /// README / LICENSE / release.
  final RepoDocKind kind;

  /// Location of the discovered file in the source tree (read-only).
  final Uri uri;

  /// The discovered file's last path segment (e.g. `README.md`, `LICENSE`).
  String get fileName => uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
}

/// Text-file extensions a `README` / `LICENSE` / `release` may carry, in the
/// priority order used to pick a winner when a directory holds more than one
/// match (e.g. both `README.md` and a bare `README`). The empty string matches
/// an extension-less `LICENSE`. Mirrors the website's `repo_docs_loader`.
const List<String> _repoDocExtensions = ['.md', '.markdown', '.txt', ''];

/// The best [files] entry whose base name (case-insensitive, extension stripped)
/// equals [stem], or `null` when none match. Among matches the one with the
/// earliest [_repoDocExtensions] extension wins, so the choice is deterministic
/// regardless of directory-listing order. A non-text extension (e.g. a
/// `README.png`) never matches.
Uri? pickRepoDocFile(List<Uri> files, String stem) {
  Uri? best;
  var bestRank = _repoDocExtensions.length;
  for (final uri in files) {
    final segment = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final dot = segment.lastIndexOf('.');
    // A leading dot (e.g. `.gitignore`) is part of the name, not an extension.
    final base = (dot <= 0 ? segment : segment.substring(0, dot)).toLowerCase();
    if (base != stem) continue;
    final ext = (dot <= 0 ? '' : segment.substring(dot)).toLowerCase();
    final rank = _repoDocExtensions.indexOf(ext);
    if (rank == -1) continue; // a non-text extension — skip.
    if (rank < bestRank) {
      best = uri;
      bestRank = rank;
    }
  }
  return best;
}
