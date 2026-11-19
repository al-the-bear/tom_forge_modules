import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart'
    show XTypeGroup, getSaveLocation;
import 'package:tom_forge_shell/tom_forge_shell.dart';

/// The desktop's native file dialogs: folders and files to open through
/// file_picker, the save location through file_selector (file_picker 12's
/// `saveFile` writes the bytes itself; the shell's caller writes the file).
class DesktopFilePickers extends ForgeFilePickers {
  const DesktopFilePickers();

  @override
  Future<String?> pickFolder({String? title, String? initialDirectory}) =>
      FilePicker.getDirectoryPath(
        dialogTitle: title,
        initialDirectory: initialDirectory,
      );

  @override
  Future<List<String>> pickFiles({
    String? title,
    bool allowMultiple = false,
    List<String>? extensions,
  }) async {
    final type = extensions != null && extensions.isNotEmpty
        ? FileType.custom
        : FileType.any;
    final List<PlatformFile> files;
    if (allowMultiple) {
      files = await FilePicker.pickFiles(
        dialogTitle: title,
        type: type,
        allowedExtensions: type == FileType.custom ? extensions : null,
      );
    } else {
      final file = await FilePicker.pickFile(
        dialogTitle: title,
        type: type,
        allowedExtensions: type == FileType.custom ? extensions : null,
      );
      files = file == null ? const [] : [file];
    }
    return [
      for (final f in files)
        if (f.path != null) f.path!,
    ];
  }

  @override
  Future<String?> pickSaveLocation({
    String? title,
    String? suggestedName,
    List<FileFilter> filters = const [],
  }) async {
    final location = await getSaveLocation(
      confirmButtonText: title,
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        for (final f in filters)
          XTypeGroup(label: f.name, extensions: f.extensions),
      ],
    );
    return location?.path;
  }
}

/// The desktop machine the shell runs on: its installed shells, and folders
/// outside the workspace, through `dart:io`.
class DesktopHostEnvironment extends ForgeHostEnvironment {
  const DesktopHostEnvironment();

  @override
  List<String> installedShells() {
    if (Platform.isWindows) {
      return [
        r'C:\Windows\System32\cmd.exe',
        r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
      ];
    }
    const candidates = [
      '/bin/bash',
      '/bin/zsh',
      '/bin/sh',
      '/bin/fish',
      '/usr/bin/fish',
    ];
    return candidates.where((p) => File(p).existsSync()).toList();
  }

  @override
  void ensureFolder(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
  }
}

/// The desktop host as [ForgeShellComponents]: [DesktopFilePickers] and
/// [DesktopHostEnvironment].
const ForgeShellComponents forgeDesktopHostComponents = ForgeShellComponents(
  filePickers: DesktopFilePickers(),
  hostEnvironment: DesktopHostEnvironment(),
);
