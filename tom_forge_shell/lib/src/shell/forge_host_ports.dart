import '../services/forge_dialog_manager.dart' show FileFilter;

/// The host's file pickers: the native dialogs that choose a folder, files to
/// open, or where to save. `tom_forge_desktop_host` provides them
/// (file_picker, file_selector); without it ([ForgeNoFilePickers]) nothing is
/// picked, so Open Folder, Open File and Save As do nothing.
abstract class ForgeFilePickers {
  const ForgeFilePickers();

  /// Whether this host can show the pickers at all.
  bool get available => true;

  /// A folder the user chooses, or null.
  Future<String?> pickFolder({String? title, String? initialDirectory});

  /// Files the user chooses to open — one unless [allowMultiple] — limited to
  /// [extensions] (without the dot) when given; empty when none.
  Future<List<String>> pickFiles({
    String? title,
    bool allowMultiple = false,
    List<String>? extensions,
  });

  /// Where the user chooses to save, or null: the caller writes the file.
  Future<String?> pickSaveLocation({
    String? title,
    String? suggestedName,
    List<FileFilter> filters = const [],
  });
}

/// File pickers of a host without them: nothing is picked.
class ForgeNoFilePickers extends ForgeFilePickers {
  const ForgeNoFilePickers();

  @override
  bool get available => false;

  @override
  Future<String?> pickFolder({String? title, String? initialDirectory}) async =>
      null;

  @override
  Future<List<String>> pickFiles({
    String? title,
    bool allowMultiple = false,
    List<String>? extensions,
  }) async => const [];

  @override
  Future<String?> pickSaveLocation({
    String? title,
    String? suggestedName,
    List<FileFilter> filters = const [],
  }) async => null;
}

/// What the shell asks of the host machine beyond its file system: the
/// shells installed for the terminal, and folders outside the workspace (the
/// central configuration folder). `tom_forge_desktop_host` provides it
/// (dart:io); without it ([ForgeNoHostEnvironment]) there are none.
abstract class ForgeHostEnvironment {
  const ForgeHostEnvironment();

  /// The shells installed on this machine, as paths, for the terminal's
  /// default shell; empty when unknown.
  List<String> installedShells();

  /// Makes the folder [path] when it does not exist; throws when it cannot.
  void ensureFolder(String path);
}

/// The host environment of a host without one: no shells known, and no
/// folders outside the workspace.
class ForgeNoHostEnvironment extends ForgeHostEnvironment {
  const ForgeNoHostEnvironment();

  @override
  List<String> installedShells() => const [];

  @override
  void ensureFolder(String path) => throw UnsupportedError(
    'This shell cannot make folders outside its workspace '
    '(tom_forge_desktop_host is not registered).',
  );
}
