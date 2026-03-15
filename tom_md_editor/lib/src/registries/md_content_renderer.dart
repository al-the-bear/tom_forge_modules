import 'package:flutter/widgets.dart';

import '../controller/md_editor_controller.dart';
import '../models/md_section.dart';
import '../theme/md_editor_theme.dart';

/// Context data provided to content renderers.
class MdContentContext {
  const MdContentContext({
    required this.content,
    this.language,
    required this.theme,
    required this.controller,
    this.containingSection,
  });

  /// The raw content string to render.
  final String content;

  /// Optional language tag (for code blocks).
  final String? language;

  /// Current theme for styling.
  final MdBasicTheme theme;

  /// Editor controller for interactions.
  final MdEditorController controller;

  /// Section containing this content, if known.
  final MdSection? containingSection;
}

/// Interface for custom content renderers in the markdown preview.
///
/// Implementations can render specialized content types (e.g. Mermaid
/// diagrams, LaTeX math) and optionally provide an overlay editor.
abstract class MdContentRenderer {
  /// Content types this renderer handles (e.g. `['mermaid', 'math']`).
  List<String> get contentTypes;

  /// Build the display widget for the content.
  Widget build(MdContentContext context);

  /// Build an optional editor widget for the content.
  /// Return `null` if no editor is available.
  Widget? buildEditor(
    MdContentContext context,
    ValueChanged<String> onChanged,
  );

  /// Whether this renderer provides an overlay editor.
  bool get hasOverlayEditor;
}
