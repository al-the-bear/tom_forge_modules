import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

export 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show ForgeQuickPickItem;

/// Filter for file open/save dialogs.
class FileFilter {
  final String name;
  final List<String> extensions;

  const FileFilter({required this.name, required this.extensions});
}

/// Programmatic dialog management (quick pick, input, file dialogs).
abstract class ForgeDialogManager {
  Future<T?> showQuickPick<T>(
    List<ForgeQuickPickItem<T>> items, {
    String? placeholder,
    bool canSelectMany = false,
  });

  Future<String?> showInputBox({
    String? prompt,
    String? value,
    String? placeholder,
    String? Function(String)? validateInput,
  });

  Future<List<Uri>?> showOpenDialog({
    String? title,
    bool canSelectMany = false,
    bool canSelectFolders = false,
    List<FileFilter>? filters,
  });

  Future<Uri?> showSaveDialog({
    String? title,
    Uri? defaultUri,
    List<FileFilter>? filters,
  });
}
