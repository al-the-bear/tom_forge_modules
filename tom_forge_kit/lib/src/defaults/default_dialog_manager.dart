import 'dart:async';

import '../services/forge_dialog_manager.dart';

/// Default implementation of [ForgeDialogManager].
///
/// Provides programmatic dialog resolution using completer-based callbacks.
/// In a real shell, the widget layer connects these to actual UI dialogs.
class DefaultDialogManager implements ForgeDialogManager {
  static bool debugEnabled = false;

  /// Callback for handling quick pick requests.
  /// Set by the shell widget layer.
  Future<T?> Function<T>(
    List<ForgeQuickPickItem<T>> items, {
    String? placeholder,
    bool canSelectMany,
  })? onQuickPick;

  /// Callback for input box requests.
  Future<String?> Function({
    String? prompt,
    String? value,
    String? placeholder,
    String? Function(String)? validateInput,
  })? onInputBox;

  /// Callback for open dialog requests.
  Future<List<Uri>?> Function({
    String? title,
    bool canSelectMany,
    bool canSelectFolders,
    List<FileFilter>? filters,
  })? onOpenDialog;

  /// Callback for save dialog requests.
  Future<Uri?> Function({
    String? title,
    Uri? defaultUri,
    List<FileFilter>? filters,
  })? onSaveDialog;

  @override
  Future<T?> showQuickPick<T>(
    List<ForgeQuickPickItem<T>> items, {
    String? placeholder,
    bool canSelectMany = false,
  }) async {
    try {
      if (onQuickPick != null) {
        return await onQuickPick!<T>(
          items,
          placeholder: placeholder,
          canSelectMany: canSelectMany,
        );
      }
      // If no callback, return the first item for testing.
      return items.isNotEmpty ? items.first.value : null;
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultDialogManager] showQuickPick error: $e');
      }
      return null;
    }
  }

  @override
  Future<String?> showInputBox({
    String? prompt,
    String? value,
    String? placeholder,
    String? Function(String)? validateInput,
  }) async {
    try {
      if (onInputBox != null) {
        return await onInputBox!(
          prompt: prompt,
          value: value,
          placeholder: placeholder,
          validateInput: validateInput,
        );
      }
      return value;
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultDialogManager] showInputBox error: $e');
      }
      return null;
    }
  }

  @override
  Future<List<Uri>?> showOpenDialog({
    String? title,
    bool canSelectMany = false,
    bool canSelectFolders = false,
    List<FileFilter>? filters,
  }) async {
    try {
      if (onOpenDialog != null) {
        return await onOpenDialog!(
          title: title,
          canSelectMany: canSelectMany,
          canSelectFolders: canSelectFolders,
          filters: filters,
        );
      }
      return null;
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultDialogManager] showOpenDialog error: $e');
      }
      return null;
    }
  }

  @override
  Future<Uri?> showSaveDialog({
    String? title,
    Uri? defaultUri,
    List<FileFilter>? filters,
  }) async {
    try {
      if (onSaveDialog != null) {
        return await onSaveDialog!(
          title: title,
          defaultUri: defaultUri,
          filters: filters,
        );
      }
      return null;
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultDialogManager] showSaveDialog error: $e');
      }
      return null;
    }
  }
}
