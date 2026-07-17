import 'dart:io';

import 'package:tom_forge_core/tom_forge_core.dart';

/// File system access for the forge shell.
///
/// All file operations are routed through the shell's revisioning layer.
abstract class ForgeFileSystem {
  Future<String> read(Uri uri);
  Future<List<int>> readBytes(Uri uri);
  Future<void> write(Uri uri, String content);
  Future<void> save(Uri uri);

  /// Creates the directory at [uri] (and any missing parents).
  ///
  /// Routing directory creation through the abstraction keeps the explorer
  /// view free of raw `dart:io` calls, so an in-memory file system can back it
  /// in tests.
  Future<void> createDirectory(Uri uri);

  Future<void> delete(Uri uri);
  Future<bool> exists(Uri uri);
  Future<FileStat> stat(Uri uri);
  Future<List<FileSystemEntity>> list(
    Uri directoryUri, {
    bool recursive = false,
  });
  Stream<FileSystemEvent> watch(Uri uri, {bool recursive = false});
  Future<bool> applyWorkspaceEdit(ForgeWorkspaceEdit edit);

  Stream<FileChangeEvent> get onDidChange;
  Stream<Uri> get onDidSave;
  Stream<WillSaveEvent> get onWillSave;
}
