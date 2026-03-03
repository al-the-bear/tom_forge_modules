import 'package:flutter/material.dart';

import '../yaml_editor_controller.dart';
import '../yaml_editor_theme.dart';
import 'subtree_inspector.dart';

/// Shows the subtree inspector as a modal dialog overlay.
///
/// Use [showInspectorDialog] to open the dialog. The dialog contains a
/// full [SubtreeInspector] widget and automatically closes on Apply or Cancel.
///
/// ```dart
/// var applied = await showInspectorDialog(
///   context: context,
///   controller: controller,
///   path: ['prompt', 'meta-data'],
///   theme: YamlEditorTheme.dark(),
/// );
/// if (applied) print('Changes applied!');
/// ```
Future<bool> showInspectorDialog({
  required BuildContext context,
  required YamlEditorController controller,
  required List<String> path,
  YamlEditorTheme theme = const YamlEditorTheme(),
  bool readOnly = false,
  double widthFraction = 0.75,
  double heightFraction = 0.75,
}) async {
  var result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _InspectorDialog(
        controller: controller,
        path: path,
        theme: theme,
        readOnly: readOnly,
        widthFraction: widthFraction,
        heightFraction: heightFraction,
      );
    },
  );
  return result ?? false;
}

class _InspectorDialog extends StatelessWidget {
  final YamlEditorController controller;
  final List<String> path;
  final YamlEditorTheme theme;
  final bool readOnly;
  final double widthFraction;
  final double heightFraction;

  const _InspectorDialog({
    required this.controller,
    required this.path,
    required this.theme,
    required this.readOnly,
    required this.widthFraction,
    required this.heightFraction,
  });

  @override
  Widget build(BuildContext context) {
    var screen = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: screen.width * widthFraction,
        height: screen.height * heightFraction,
        decoration: BoxDecoration(
          color: theme.colors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colors.separatorColor.withAlpha(100),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(80),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SubtreeInspector(
          controller: controller,
          path: path,
          theme: theme,
          readOnly: readOnly,
          onApply: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        ),
      ),
    );
  }
}
