import 'dart:io';

import 'package:tom_basics/utilities.dart' show TomGitignore, TomGitignoreSet;

/// Reads every `.gitignore` under [rootPath] into one [TomGitignoreSet].
///
/// The rules are `tom_basics`' (`TomGitignore`); this is only the walk that
/// finds the files. The root's file comes first and each folder's files
/// before its subfolders', in name order, so a file deeper in the tree is
/// added later and decides inside its folder. Paths in the set are relative
/// to [rootPath], with `/` separators.
///
/// Two folders are never entered: `.git`, and any folder the rules read so
/// far ignore — a `.gitignore` inside an ignored folder cannot re-include
/// anything, because git itself never looks there. A `.gitignore` or folder
/// that cannot be read is passed over; the walk reports what it could read.
Future<TomGitignoreSet> forgeLoadGitignores(String rootPath) async {
  final rules = TomGitignoreSet();
  var root = rootPath;
  while (root.length > 1 && (root.endsWith('/') || root.endsWith(r'\'))) {
    root = root.substring(0, root.length - 1);
  }
  await _load(Directory(root), '', rules);
  return rules;
}

Future<void> _load(Directory dir, String base, TomGitignoreSet rules) async {
  final file = File('${dir.path}/.gitignore');
  if (file.existsSync()) {
    try {
      rules.add(TomGitignore.parse(base, await file.readAsString()));
    } on FileSystemException {
      // Unreadable: its rules are not applied.
    } on FormatException {
      // Not UTF-8: its rules are not applied.
    }
  }
  final List<FileSystemEntity> children;
  try {
    children = await dir.list(followLinks: false).toList();
  } on FileSystemException {
    return;
  }
  final folders = children.whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final folder in folders) {
    final name = folder.uri.pathSegments.lastWhere(
      (s) => s.isNotEmpty,
      orElse: () => '',
    );
    if (name == '.git') continue;
    final path = base.isEmpty ? name : '$base/$name';
    if (rules.isIgnored(path, isDirectory: true)) continue;
    await _load(folder, path, rules);
  }
}
