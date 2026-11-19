import 'package:flutter/material.dart';

/// Result of an error recovery prompt.
enum ErrorRecoveryAction { retry, cancel, overwrite }

/// A save-conflict / error-recovery dialog.
///
/// Shown as a modal dialog when file operations encounter errors
/// such as save conflicts or I/O failures. Provides retry, cancel,
/// and overwrite options appropriate to the error type.
class ForgeErrorRecoveryDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool showOverwrite;

  const ForgeErrorRecoveryDialog({
    super.key,
    required this.title,
    required this.message,
    this.showOverwrite = false,
  });

  /// Shows the error recovery dialog and returns the user's choice.
  static Future<ErrorRecoveryAction?> show(
    BuildContext context, {
    required String title,
    required String message,
    bool showOverwrite = false,
  }) {
    return showDialog<ErrorRecoveryAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForgeErrorRecoveryDialog(
        title: title,
        message: message,
        showOverwrite: showOverwrite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(
        Icons.error_outline,
        color: theme.colorScheme.error,
        size: 28,
      ),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Text(message),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, ErrorRecoveryAction.cancel),
          child: const Text('Cancel'),
        ),
        if (showOverwrite)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, ErrorRecoveryAction.overwrite),
            child: Text(
              'Overwrite',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, ErrorRecoveryAction.retry),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
