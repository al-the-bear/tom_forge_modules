/// A [ForgeWorkspaceEdit] applied to a file system as one unit.
///
/// The edit is Forge's vocabulary — text edits by position and file
/// operations, as an editor or a refactoring produces them — so applying it
/// is Forge's too. The file system only has to read, write, rename and
/// delete; it does not know what a workspace edit is.
library;

import 'dart:typed_data';

import 'package:tom_file_system/tom_file_system.dart';

import '../types/workspace_edit.dart';

/// Applies [edit] to [fs]: every file operation, then every text edit — or,
/// when one fails, none of them. Answers whether it was applied.
///
/// A text edit naming a file that does not exist is skipped. The rollback is
/// best effort: renames go back, created files are removed, deleted and edited
/// files are restored, and a failure during the rollback leaves what is left
/// while the call still answers false.
Future<bool> forgeApplyWorkspaceEdit(
  TomFileSystem fs,
  ForgeWorkspaceEdit edit,
) async {
  final backups = <Uri, Uint8List>{};
  final created = <Uri>[];
  final deleted = <Uri, Uint8List>{};
  final renamed = <(Uri, Uri)>[];
  try {
    for (final uri in edit.textEdits.keys) {
      if (await fs.exists(uri)) backups[uri] = (await fs.read(uri)).bytes;
    }
    for (final op in edit.fileOperations) {
      switch (op) {
        case ForgeCreateFileOperation(
          :final uri,
          :final content,
          :final overwrite,
        ):
          if (await fs.exists(uri) && !overwrite) {
            throw StateError('File already exists: ${uri.path}');
          }
          await fs.writeText(uri, content ?? '');
          created.add(uri);
        case ForgeDeleteFileOperation(:final uri):
          final entry = await fs.stat(uri);
          if (entry != null) {
            if (!entry.isDirectory) deleted[uri] = (await fs.read(uri)).bytes;
            await fs.delete(uri);
          }
        case ForgeRenameFileOperation(
          :final oldUri,
          :final newUri,
          :final overwrite,
        ):
          if (!await fs.exists(oldUri)) {
            throw StateError('Source file not found: ${oldUri.path}');
          }
          if (await fs.exists(newUri)) {
            if (!overwrite) {
              throw StateError('Target file already exists: ${newUri.path}');
            }
            await fs.delete(newUri);
          }
          await fs.rename(oldUri, newUri);
          renamed.add((oldUri, newUri));
      }
    }
    for (final entry in edit.textEdits.entries) {
      if (!await fs.exists(entry.key)) continue;
      final text = await fs.readText(entry.key);
      await fs.writeText(entry.key, _applyTextEdits(text, entry.value));
    }
    return true;
  } on Object {
    for (final (from, to) in renamed.reversed) {
      await _quietly(() => fs.rename(to, from));
    }
    for (final uri in created) {
      await _quietly(() => fs.delete(uri));
    }
    for (final entry in {...deleted, ...backups}.entries) {
      await _quietly(() => fs.write(entry.key, entry.value));
    }
    return false;
  }
}

Future<void> _quietly(Future<void> Function() step) async {
  try {
    await step();
  } on Object {
    // Rollback is best effort.
  }
}

/// [edits] applied to [text], the last position first so earlier offsets
/// stay valid.
String _applyTextEdits(String text, List<ForgeTextEdit> edits) {
  final lines = text.split('\n');
  final sorted = List.of(edits)
    ..sort((a, b) {
      final byLine = b.range.start.line.compareTo(a.range.start.line);
      return byLine != 0
          ? byLine
          : b.range.start.column.compareTo(a.range.start.column);
    });
  for (final edit in sorted) {
    final start = edit.range.start;
    final end = edit.range.end;
    final head = lines[start.line].substring(0, start.column);
    final tail = lines[end.line].substring(end.column);
    final inserted = '$head${edit.newText}$tail'.split('\n');
    lines.replaceRange(start.line, end.line + 1, inserted);
  }
  return lines.join('\n');
}
