import 'package:flutter/material.dart';

import '../components/forge_editor_choice.dart';


/// The **Open With** choice: the editors offered for a file
/// (`DefaultLayoutController.openFileWith`), each with its name and what it
/// is for; picking one opens the file in it.
class ForgeOpenWithDialog extends StatelessWidget {
  /// The URI of the file being opened.
  final Uri uri;

  /// The editors offered for the file.
  final List<ForgeEditorChoice> choices;

  /// Called with the editor picked.
  final void Function(ForgeEditorChoice choice) onChoiceSelected;

  /// Called when the dialog is dismissed without a pick.
  final VoidCallback onCancel;

  const ForgeOpenWithDialog({
    super.key,
    required this.uri,
    required this.choices,
    required this.onChoiceSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : uri.toString();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open With',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose an editor to open "$fileName"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: choices.length,
                itemBuilder: (context, index) {
                  final choice = choices[index];
                  return _ChoiceTile(
                    key: ValueKey('forge-open-with-${choice.id}'),
                    choice: choice,
                    onTap: () => onChoiceSelected(choice),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the dialog and answers the editor picked, or null if cancelled.
  static Future<ForgeEditorChoice?> show({
    required BuildContext context,
    required Uri uri,
    required List<ForgeEditorChoice> choices,
  }) {
    return showDialog<ForgeEditorChoice>(
      context: context,
      builder: (ctx) => ForgeOpenWithDialog(
        uri: uri,
        choices: choices,
        onChoiceSelected: (choice) => Navigator.of(ctx).pop(choice),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

/// One editor offered.
class _ChoiceTile extends StatelessWidget {
  final ForgeEditorChoice choice;
  final VoidCallback onTap;

  const _ChoiceTile({super.key, required this.choice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                choice.icon,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choice.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (choice.description case final description?)
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
