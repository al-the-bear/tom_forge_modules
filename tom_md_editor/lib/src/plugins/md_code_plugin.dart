import 'package:flutter/material.dart';

import '../theme/md_editor_theme.dart';
import '../widgets/overlays/md_code_block_overlay.dart';
import 'md_content_plugin.dart';

/// Built-in plugin for inserting code blocks via the context menu.
///
/// This plugin does not provide custom rendering (code blocks use the default
/// code block widget). It only provides the "Insert Code Block" action and
/// wires the code block overlay editor for the edit flow.
class MdCodePlugin extends MdContentPlugin {
  @override
  String get id => 'code';

  @override
  String get displayName => 'Code Block';

  @override
  IconData get icon => Icons.code;

  @override
  String get insertTemplate => '```\n// code here\n```';

  @override
  List<String> get languages => [];

  /// Does not claim any language — code blocks use default rendering.
  @override
  bool matchesLanguage(String language) => false;

  /// Returns `null` — code blocks use the default code block widget.
  @override
  Widget? buildPreview(
    String content,
    MdBasicTheme theme, {
    required VoidCallback onEdit,
  }) {
    return null;
  }

  @override
  Future<String?> openEditor(
    BuildContext context,
    String currentContent,
    MdEditorTheme theme,
  ) async {
    String? resultCode;
    await showDialog<void>(
      context: context,
      builder: (_) => MdCodeBlockOverlay(
        code: currentContent,
        theme: theme,
        onSave: (code, _) => resultCode = code,
      ),
    );
    return resultCode;
  }

  @override
  String wrapForMarkdown(String content) => '```\n$content\n```';
}
