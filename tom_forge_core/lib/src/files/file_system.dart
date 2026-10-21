/// The one file-system contract of the Forge shell and of every application
/// built on it.
///
/// Every read and write of a file goes through a [ForgeFileSystem], so no
/// editor, explorer or browser touches `dart:io` directly, and a second kind
/// of folder — in memory, or a repository — attaches by implementing it.
/// Its guarantees:
///
/// - A **write is atomic**: a crash leaves the old bytes or the new ones,
///   never half of either.
/// - A write may name the **revision** it was read at, and is then refused
///   with a [ForgeFileConflict] when the file changed since — nothing is
///   written over somebody else's change.
/// - A **delete goes to the platform's trash** where there is one; deleting
///   for good is a separate call.
/// - A **link that leaves the root** is listed and never expanded.
/// - Results are **values**, not `dart:io` objects, so the contract links
///   into a browser build.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../types/forge_events.dart';
import '../types/workspace_edit.dart';

/// What an entry of a directory is.
enum ForgeFileEntryKind { file, directory, link }

/// One entry of a listed directory.
class ForgeFileEntry {
  /// The entry's own name.
  final String name;

  /// Its path relative to the file system's root, with `/` separators; `''`
  /// for the root itself.
  final String path;

  /// Its absolute URI.
  final Uri uri;

  final ForgeFileEntryKind kind;

  /// The size in bytes; 0 for a directory.
  final int size;

  final DateTime modified;

  /// For a link: whether it leads to a directory.
  final bool linksToDirectory;

  /// For a link: whether its target lies outside the root, or leads back into
  /// its own ancestors — such a link is shown and never expanded, so a cycle
  /// cannot make listing endless.
  final bool linkLeavesRoot;

  /// Whether the process may read it.
  final bool readable;

  const ForgeFileEntry({
    required this.name,
    required this.path,
    required this.uri,
    required this.kind,
    this.size = 0,
    required this.modified,
    this.linksToDirectory = false,
    this.linkLeavesRoot = false,
    this.readable = true,
  });

  /// Whether a tree shows it as a folder.
  bool get isDirectory =>
      kind == ForgeFileEntryKind.directory ||
      (kind == ForgeFileEntryKind.link && linksToDirectory);

  /// Whether a tree may expand it.
  bool get expandable => isDirectory && !linkLeavesRoot && readable;
}

/// The version of a file as it was read: what a write is checked against.
class ForgeFileRevision {
  final DateTime modified;
  final int size;

  /// SHA-256 of the bytes read, hex.
  final String sha256;

  const ForgeFileRevision({
    required this.modified,
    required this.size,
    required this.sha256,
  });

  /// The revision of [bytes] last modified at [modified].
  factory ForgeFileRevision.of(Uint8List bytes, DateTime modified) =>
      ForgeFileRevision(
        modified: modified,
        size: bytes.length,
        sha256: crypto.sha256.convert(bytes).toString(),
      );

  /// Two revisions are the same file content; the time is not compared, so
  /// a write of identical bytes is not a change.
  @override
  bool operator ==(Object other) =>
      other is ForgeFileRevision &&
      other.size == size &&
      other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(size, sha256);
}

/// A file's bytes and the revision they were read at.
class ForgeFileContent {
  final Uint8List bytes;
  final ForgeFileRevision revision;

  const ForgeFileContent(this.bytes, this.revision);
}

/// A write refused because the file is no longer the revision it was read
/// at — someone else changed it.
class ForgeFileConflict implements Exception {
  final Uri uri;

  /// The revision there now, or null when the file is gone.
  final ForgeFileRevision? current;

  const ForgeFileConflict(this.uri, this.current);

  @override
  String toString() => current == null
      ? '"${uri.path}" was deleted since it was read'
      : '"${uri.path}" changed on disk since it was read';
}

/// A change under a watched root. Advisory: a watch may miss a change, and
/// a caller that must know compares revisions.
class ForgeFileChange {
  /// The changed entry's path relative to the root.
  final String path;

  /// Its absolute URI.
  final Uri uri;

  const ForgeFileChange(this.path, this.uri);
}

/// The contract. A file system has a [root]; a relative URI resolves against
/// it, and [path]s in entries and changes are relative to it.
abstract interface class ForgeFileSystem {
  /// The root directory, as an absolute directory URI (trailing `/`).
  Uri get root;

  /// The absolute URI of [path], relative to [root] with `/` separators.
  Uri uriOf(String path);

  /// [uri]'s path relative to [root], or null when it lies outside it.
  String? pathOf(Uri uri);

  /// The entries of the directory [directory] — one level, unsorted.
  Future<List<ForgeFileEntry>> list(Uri directory);

  /// [uri]'s entry without reading it, or null when it does not exist.
  Future<ForgeFileEntry?> stat(Uri uri);

  /// The bytes of [uri] and the revision they were read at.
  Future<ForgeFileContent> read(Uri uri);

  /// The text of [uri], decoded as UTF-8.
  Future<String> readText(Uri uri);

  /// At most [maxBytes] of [uri] as text, from its end when [fromEnd] and
  /// from its start otherwise — or null when it does not exist.
  ///
  /// A cut slice drops the partial line at the cut, so the first (or last)
  /// line is whole; a slice with no line break is kept as it is. Bytes that
  /// are not UTF-8 are replaced rather than refused: a log is read to be
  /// looked at.
  Future<String?> readSlice(
    Uri uri, {
    required int maxBytes,
    required bool fromEnd,
  });

  /// Writes [bytes] to [uri] **atomically**. With [expected], refuses with a
  /// [ForgeFileConflict] when the file is no longer that revision. Answers
  /// the revision written.
  Future<ForgeFileRevision> write(
    Uri uri,
    Uint8List bytes, {
    ForgeFileRevision? expected,
  });

  /// [write] of [text] as UTF-8.
  Future<ForgeFileRevision> writeText(
    Uri uri,
    String text, {
    ForgeFileRevision? expected,
  });

  /// Creates an empty file, or with [directory] a folder with its parents.
  /// A file that already exists is refused.
  Future<void> create(Uri uri, {bool directory = false});

  /// Renames or moves [from] to [to]; an existing [to] is refused.
  Future<void> rename(Uri from, Uri to);

  /// Deletes [uri] by moving it to the platform's trash. Answers false when
  /// there is no trash to move it to — the caller then asks before [delete]:
  /// nothing is unlinked without a way back unless somebody said so.
  Future<bool> trash(Uri uri);

  /// Deletes [uri] for good — a folder with everything in it.
  Future<void> delete(Uri uri);

  /// Whether [uri] exists.
  Future<bool> exists(Uri uri);

  /// Changes under [root], or null when the platform refuses to watch.
  ///
  /// [descend] is asked, with a folder's path relative to the root, whether
  /// changes inside it are wanted, so a folder a tree does not enter need not
  /// be watched. An implementation may watch more than it is asked to — a
  /// native recursive watch costs the same either way — but never less.
  Stream<ForgeFileChange>? watch({bool Function(String path)? descend});

  /// Announces that [uri] is saved: [onWillSave] with its text, then
  /// [onDidSave].
  Future<void> save(Uri uri);

  /// Applies a multi-file edit as one unit: every change, or — when one
  /// fails — none of them. Answers whether it was applied.
  Future<bool> applyWorkspaceEdit(ForgeWorkspaceEdit edit);

  /// Every create, write, rename and delete made through this file system.
  Stream<FileChangeEvent> get onDidChange;

  Stream<Uri> get onDidSave;

  Stream<WillSaveEvent> get onWillSave;

  /// Ends the event streams.
  Future<void> dispose();
}

/// [text] without its first, partial line — a tail slice's cut. Text with no
/// line break is returned whole: there is nothing to snap to.
String forgeTrimToLineStart(String text) {
  final nl = text.indexOf('\n');
  return nl < 0 ? text : text.substring(nl + 1);
}

/// [text] without its last, partial line — a head slice's cut.
String forgeTrimToLineEnd(String text) {
  final nl = text.lastIndexOf('\n');
  return nl < 0 ? text : text.substring(0, nl + 1);
}
