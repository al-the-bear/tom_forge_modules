/// The workspace on the host, outside its file system: finding the folder a
/// workspace lives in above a picked folder, and keeping its `.forge/` state
/// out of git. Both are platform services — they walk host folders and run
/// git — so they use `dart:io` and run on desktop only (platform_architecture.md
/// §2.6); the state itself is kept through the workspace's file system
/// ([ForgeWorkspaceStateManager]).
library;

import 'dart:io';

/// The nearest folder at [startPath] or above it (at most 20 levels) that
/// holds a `.forge/` directory, or null.
Future<String?> detectForgeWorkspaceRoot(String startPath) async {
  var current = Directory(startPath);
  for (var i = 0; i < 20; i++) {
    if (await Directory('${current.path}/.forge').exists()) return current.path;
    final parent = current.parent;
    if (parent.path == current.path) break; // reached the file system root
    current = parent;
  }
  return null;
}

/// Keeps the workspace's `.forge/` out of git without editing a file the
/// workspace tracks: when [workspaceRootPath] lies in a git work tree whose
/// rules do not ignore `.forge/` yet — git itself answers, so every
/// `.gitignore` up to the repository root, `.git/info/exclude` and the
/// global excludes count — `.forge/` is added to that clone's
/// `.git/info/exclude` (the state is per machine). Answers what it found or
/// did.
Future<ForgeStateIgnore> keepForgeStateOutOfGit(
  String workspaceRootPath,
) async {
  Future<ProcessResult?> git(List<String> args) async {
    try {
      return await Process.run('git', ['-C', workspaceRootPath, ...args]);
    } on ProcessException {
      return null; // git is not installed
    }
  }

  final inside = await git(['rev-parse', '--is-inside-work-tree']);
  if (inside == null ||
      inside.exitCode != 0 ||
      '${inside.stdout}'.trim() != 'true') {
    return ForgeStateIgnore.notInGit;
  }
  final ignored = await git(['check-ignore', '-q', '.forge/']);
  if (ignored?.exitCode == 0) return ForgeStateIgnore.alreadyIgnored;

  // The workspace's place in the repository, for an anchored pattern, and
  // the clone's exclude file (also for a worktree or a submodule).
  final prefix = await git(['rev-parse', '--show-prefix']);
  final excludePath = await git(['rev-parse', '--git-path', 'info/exclude']);
  if (prefix == null || excludePath == null) return ForgeStateIgnore.notInGit;
  final relative = '${excludePath.stdout}'.trim();
  final asGiven = File(relative);
  final exclude = asGiven.isAbsolute
      ? asGiven
      : File('$workspaceRootPath${Platform.pathSeparator}$relative');
  await exclude.parent.create(recursive: true);
  var content = await exclude.exists() ? await exclude.readAsString() : '';
  if (content.isNotEmpty && !content.endsWith('\n')) content += '\n';
  content +=
      '# Tom Forge workspace state (per machine)\n'
      '/${'${prefix.stdout}'.trim()}.forge/\n';
  await exclude.writeAsString(content);
  return ForgeStateIgnore.addedToLocalExclude;
}

/// What [keepForgeStateOutOfGit] found or did.
enum ForgeStateIgnore {
  /// The workspace is not in a git work tree (or git is not installed):
  /// nothing to keep out.
  notInGit,

  /// git already ignores `.forge/`: nothing written.
  alreadyIgnored,

  /// `.forge/` was added to the clone's `.git/info/exclude`.
  addedToLocalExclude,
}
