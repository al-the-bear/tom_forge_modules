import 'package:tom_basics/utilities.dart' show TomGitignore, TomGitignoreSet;
import 'package:tom_file_system/tom_file_system.dart';

/// Reads every `.gitignore` under [root] (default: [fileSystem]'s root) into
/// one [TomGitignoreSet], through the file system — on disk, in memory or on
/// the web alike.
///
/// The rules are `tom_basics`' (`TomGitignore`); this is only the walk that
/// finds the files. The root's file comes first and each folder's files
/// before its subfolders', in name order, so a file deeper in the tree is
/// added later and decides inside its folder. Paths in the set are relative
/// to [root], with `/` separators.
///
/// Folders not entered: `.git`, a link (git does not follow one), and any
/// folder the rules read so far ignore — a `.gitignore` inside an ignored
/// folder cannot re-include anything, because git itself never looks there.
/// A `.gitignore` or folder that cannot be read is passed over; the walk
/// reports what it could read.
Future<TomGitignoreSet> forgeLoadGitignores(
  TomFileSystem fileSystem, {
  Uri? root,
}) async {
  final rules = TomGitignoreSet();
  await _load(fileSystem, root ?? fileSystem.root, '', rules);
  return rules;
}

Future<void> _load(
  TomFileSystem fs,
  Uri dir,
  String base,
  TomGitignoreSet rules,
) async {
  final List<TomFileEntry> children;
  try {
    children = await fs.list(dir);
  } on Exception {
    return; // Unreadable folder: nothing under it is read.
  }
  final ignoreFile = children.where(
    (e) => e.name == '.gitignore' && e.kind == TomFileEntryKind.file,
  );
  if (ignoreFile.isNotEmpty) {
    try {
      rules.add(
        TomGitignore.parse(base, await fs.readText(ignoreFile.first.uri)),
      );
    } on Exception {
      // Unreadable or not UTF-8: its rules are not applied.
    }
  }
  final folders =
      children.where((e) => e.kind == TomFileEntryKind.directory).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  for (final folder in folders) {
    if (folder.name == '.git') continue;
    final path = base.isEmpty ? folder.name : '$base/${folder.name}';
    if (rules.isIgnored(path, isDirectory: true)) continue;
    await _load(fs, folder.uri, path, rules);
  }
}
