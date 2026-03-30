import 'package:flutter/material.dart';

import '../components/forge_editor.dart';

/// A dialog that allows users to choose which editor to use for opening a file.
///
/// This dialog is shown when multiple editors can handle the same file type,
/// allowing the user to select their preferred editor.
class ForgeOpenWithDialog extends StatelessWidget {
  /// The URI of the file being opened.
  final Uri uri;

  /// The list of editors that can handle this file.
  final List<ForgeEditor> editors;

  /// Callback invoked when an editor is selected.
  final void Function(ForgeEditor editor) onEditorSelected;

  /// Callback invoked when the dialog is dismissed without selection.
  final VoidCallback onCancel;

  const ForgeOpenWithDialog({
    super.key,
    required this.uri,
    required this.editors,
    required this.onEditorSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.toString();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
            // Editor list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: editors.length,
                itemBuilder: (context, index) {
                  final editor = editors[index];
                  return _EditorTile(
                    editor: editor,
                    onTap: () => onEditorSelected(editor),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the dialog and returns the selected editor, or null if cancelled.
  static Future<ForgeEditor?> show({
    required BuildContext context,
    required Uri uri,
    required List<ForgeEditor> editors,
  }) {
    return showDialog<ForgeEditor>(
      context: context,
      builder: (ctx) => ForgeOpenWithDialog(
        uri: uri,
        editors: editors,
        onEditorSelected: (editor) => Navigator.of(ctx).pop(editor),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

/// A tile representing a single editor option.
class _EditorTile extends StatelessWidget {
  final ForgeEditor editor;
  final VoidCallback onTap;

  const _EditorTile({
    required this.editor,
    required this.onTap,
  });

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
                editor.icon,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: editor.title,
                    builder: (context, title, _) => Text(
                      _getEditorDisplayName(editor),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    _getEditorDescription(editor),
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

  String _getEditorDisplayName(ForgeEditor editor) {
    final type = editor.runtimeType.toString();
    // Convert class name to display name.
    if (type.contains('Md')) return 'Markdown Editor';
    if (type.contains('Dart')) return 'Dart Code Editor';
    if (type.contains('Yaml')) return 'YAML Editor';
    if (type.contains('PlainText')) return 'Plain Text Editor';
    return type.replaceAll('Forge', '').replaceAll('Editor', ' Editor');
  }

  String _getEditorDescription(ForgeEditor editor) {
    final type = editor.runtimeType.toString();
    if (type.contains('Md')) return 'Edit with rich markdown preview';
    if (type.contains('Dart')) return 'Edit with Dart syntax highlighting';
    if (type.contains('Yaml')) return 'Edit with YAML structure view';
    if (type.contains('PlainText')) return 'Basic text editing';
    return 'Open with this editor';
  }
}
