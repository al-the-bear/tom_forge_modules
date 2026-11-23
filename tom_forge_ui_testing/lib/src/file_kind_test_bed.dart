import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';

/// A file kind's editors made as a file module of the panel shell makes
/// them (`tom_forge_file_editors`' `ForgeFileEditorsModule`): over a
/// [ForgeFileSession] of an in-memory shell, with the shell's own module and
/// its API — for the suite of the package that exports the kind (an editor
/// adapter's), which then needs no module of the file editors.
class ForgeFileKindTestBed {
  ForgeFileKindTestBed({Map<String, String> files = const {}})
    : shell = DefaultShellApi.withDefaults(
        fileSystemSeed: files,
        appName: 'File kind',
        navigatorKey: GlobalKey<NavigatorState>(),
      ) {
    shellModule = TomForgeShellModule()..activate(shell);
    (shell.modules as DefaultModuleRegistry).register(shellModule);
  }

  /// The shell the editors run in.
  final DefaultShellApi shell;

  /// The shell's own module, the module the editors belong to.
  late final TomForgeShellModule shellModule;

  /// The shell's in-memory file system.
  TomFileSystem get fileSystem => shell.fileSystem;

  /// Writes [bytes] to [path].
  Future<void> write(String path, List<int> bytes) =>
      fileSystem.write(fileSystem.uriOf(path), Uint8List.fromList(bytes));

  /// The bytes at [path].
  Future<List<int>> read(String path) async =>
      (await fileSystem.read(fileSystem.uriOf(path))).bytes;

  /// The editor [kind] makes for the file at [path], its session loading
  /// (pump until it is read).
  T open<T extends ForgeEditor>(ForgeKitFileKind kind, String path) {
    final session = ForgeFileSession(fileSystem: fileSystem, path: path);
    final editor = _create(kind, session);
    session.load();
    return editor as T;
  }

  /// A session of the file at [path] holding [saved], ready at once (it
  /// adopts the text instead of reading it) — what the undo conformance
  /// harness starts from.
  ForgeFileSession sessionWithText(String path, String saved) =>
      ForgeFileSession(fileSystem: fileSystem, path: path)..adoptText(saved);

  /// The editor [kind] makes for a file at [path] holding [saved], ready at
  /// once ([sessionWithText]).
  T withText<T extends ForgeEditor>(
    ForgeKitFileKind kind,
    String path,
    String saved,
  ) => _create(kind, sessionWithText(path, saved)) as T;

  ForgeEditor _create(ForgeKitFileKind kind, ForgeFileSession session) =>
      kind.create(
        ForgeFileKindRequest(session: session, module: shellModule, api: shell),
      );

  void dispose() => shell.dispose();
}
