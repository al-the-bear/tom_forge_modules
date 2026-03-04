import 'package:flutter/material.dart';

import '../yaml_editor_theme.dart';

/// Wraps an embedded editor with a small pop-out button.
///
/// The button opens a large editor surface that overlays most of the app area.
class EditorPopoutShell extends StatelessWidget {
  final Widget embeddedEditor;
  final WidgetBuilder popoutBuilder;
  final YamlEditorTheme theme;
  final String? title;

  const EditorPopoutShell({
    super.key,
    required this.embeddedEditor,
    required this.popoutBuilder,
    required this.theme,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: embeddedEditor),
        const SizedBox(width: 4),
        SizedBox(
          width: 22,
          height: 22,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: 'Open editor',
            onPressed: () => _openPopout(context),
            icon: Icon(
              Icons.open_in_full,
              size: 14,
              color: theme.colors.hintColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPopout(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: size.width * 0.05,
            vertical: size.height * 0.05,
          ),
          child: SizedBox(
            width: size.width * 0.9,
            height: size.height * 0.9,
            child: Column(
              children: [
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colors.hintColor.withAlpha(60),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        title ?? 'Editor',
                        style: TextStyle(
                          color: theme.colors.keyColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(child: popoutBuilder(dialogContext)),
              ],
            ),
          ),
        );
      },
    );
  }
}
