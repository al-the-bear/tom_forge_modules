import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart'
    show MarkdownElementBuilder;
import 'package:markdown/markdown.dart' as md;

import '../settings/md_editor_settings.dart';
import '../theme/md_editor_theme.dart';

/// Describes how to preprocess non-fenced markdown content into fenced code
/// blocks so the code block builder can render and edit them.
///
/// Some content types (like markdown tables or `$$..$$` math blocks) are not
/// natively fenced code blocks. A preprocessor transforms them into fenced
/// blocks with a synthetic language tag, enabling the plugin system to
/// intercept rendering and provide custom editors.
class MdPreprocessor {
  const MdPreprocessor({
    required this.pattern,
    required this.tagPrefix,
    this.contentExtractor,
  });

  /// Regex to match the content in raw markdown.
  final RegExp pattern;

  /// Prefix for the synthetic language tag (e.g., `table-edit`).
  /// The full tag will be `{tagPrefix}-{index}`.
  final String tagPrefix;

  /// Extracts the renderable content from a regex match.
  ///
  /// If `null`, uses `m.group(0)` (the full match) as fenced block content.
  /// For example, the math preprocessor extracts the LaTeX expression from
  /// within `$$..$$` delimiters: `(m) => m.group(1)!.trim()`.
  final String Function(Match m)? contentExtractor;
}

/// Abstract plugin for rendering and editing content blocks in the markdown
/// preview.
///
/// Implement this to add support for custom content types. Register the plugin
/// with [MdPluginRegistry] to make it available in the editor.
///
/// Each plugin defines:
/// - How to **detect** its content (via [languages] or [preprocessor])
/// - How to **render** its content in the preview ([buildPreview])
/// - How to **edit** its content ([openEditor])
/// - How to **insert** new content ([insertTemplate])
/// - How to **wrap** edited content back into markdown ([wrapForMarkdown])
/// - Optionally, inline Markdown it renders inside paragraphs
///   ([inlineSyntaxes] with their [inlineBuilders]), and whether the editor
///   settings switch it off ([isEnabledBy])
///
/// The plugin packages (`tom_md_mermaid`, `tom_md_math`) are plugins of this
/// kind; the core registers none of them ([createDefaultPluginRegistry]).
///
/// Example:
/// ```dart
/// class MyDiagramPlugin extends MdContentPlugin {
///   @override String get id => 'my-diagram';
///   @override String get displayName => 'My Diagram';
///   @override IconData get icon => Icons.schema;
///   @override List<String> get languages => ['my-diagram'];
///   @override String get insertTemplate => '```my-diagram\n...\n```';
///
///   @override
///   Widget? buildPreview(String content, MdBasicTheme theme,
///       {required VoidCallback onEdit}) {
///     return MyDiagramWidget(source: content, onEdit: onEdit);
///   }
///
///   @override
///   Future<String?> openEditor(
///       BuildContext context, String content, MdEditorTheme theme) {
///     return showDialog<String>(...);
///   }
///
///   @override
///   String wrapForMarkdown(String content) => '```my-diagram\n$content\n```';
/// }
/// ```
abstract class MdContentPlugin {
  /// Unique identifier for this content type (e.g., `'table'`, `'mermaid'`).
  String get id;

  /// Display name shown in context menus and UI.
  String get displayName;

  /// Icon shown in context menus and overlay buttons.
  IconData get icon;

  /// Whether this plugin appears in the insert context menu.
  bool get canInsert => true;

  /// Default markdown template inserted via the context menu.
  String get insertTemplate;

  /// Languages this plugin handles in fenced code blocks.
  ///
  /// For example, `['mermaid']` for the mermaid plugin. Leave empty if the
  /// plugin only uses preprocessing (e.g., tables, math).
  List<String> get languages;

  /// Optional preprocessor for non-fenced content.
  ///
  /// Return `null` if this plugin only handles native fenced code blocks.
  MdPreprocessor? get preprocessor => null;

  /// Whether this plugin handles the given language tag.
  ///
  /// Override for dynamic matching (e.g., prefix-based matching for
  /// preprocessed tags like `table-edit-0`). The default checks [languages]
  /// for an exact match.
  bool matchesLanguage(String language) => languages.contains(language);

  /// Build the preview widget for this content.
  ///
  /// Return `null` to fall through to the default code block rendering.
  /// The [onEdit] callback should be wired to trigger [openEditor].
  Widget? buildPreview(
    String content,
    MdBasicTheme theme, {
    required VoidCallback onEdit,
  });

  /// Open the editor dialog.
  ///
  /// Receives the current content (without fences/delimiters) and returns
  /// the edited content, or `null` if the user cancelled.
  Future<String?> openEditor(
    BuildContext context,
    String currentContent,
    MdEditorTheme theme,
  );

  /// Wrap edited content into its full markdown syntax for storage.
  ///
  /// For native fenced blocks: `` ```language\ncontent\n``` ``
  /// For preprocessed content: the original markdown pattern
  /// (e.g., `$$\ncontent\n$$` for math, raw table for tables).
  String wrapForMarkdown(String content);

  /// Whether the plugin is used under [settings] when the default registry
  /// is built ([createDefaultPluginRegistry]). Default: always.
  bool isEnabledBy(MdEditorSettings settings) => true;

  /// Inline syntaxes the preview parses with, e.g. `$…$` math. Each turns
  /// its match into an element whose tag [inlineBuilders] renders.
  List<md.InlineSyntax> get inlineSyntaxes => const [];

  /// The builders of the elements [inlineSyntaxes] produce, by element tag.
  Map<String, MarkdownElementBuilder> inlineBuilders(MdBasicTheme theme) =>
      const {};
}

/// Registry of content editor plugins.
///
/// Plugins are looked up by language tag (from fenced code blocks) or
/// iterated for context menu insert actions.
class MdPluginRegistry {
  MdPluginRegistry([List<MdContentPlugin>? plugins]) {
    if (plugins != null) {
      for (final p in plugins) {
        register(p);
      }
    }
  }

  final List<MdContentPlugin> _plugins = [];
  final Map<String, MdContentPlugin> _byId = {};

  /// Register a content plugin.
  void register(MdContentPlugin plugin) {
    _plugins.add(plugin);
    _byId[plugin.id] = plugin;
  }

  /// Find the plugin that handles the given language tag.
  ///
  /// Checks [MdContentPlugin.matchesLanguage] on each registered plugin.
  /// Returns `null` if no plugin handles the language.
  MdContentPlugin? forLanguage(String language) {
    for (final plugin in _plugins) {
      if (plugin.matchesLanguage(language)) return plugin;
    }
    return null;
  }

  /// Find a plugin by its unique ID.
  MdContentPlugin? forId(String id) => _byId[id];

  /// All plugins that can be inserted via the context menu.
  List<MdContentPlugin> get insertable =>
      _plugins.where((p) => p.canInsert).toList();

  /// All registered plugins.
  List<MdContentPlugin> get all => List.unmodifiable(_plugins);
}

/// Compact overlay button used by plugins for hover actions (edit, copy, etc.).
///
/// Provides a small icon button with tooltip, styled to match the editor theme.
class MdOverlayButton extends StatelessWidget {
  const MdOverlayButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.theme,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final MdBasicTheme theme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.border, width: 0.5),
          ),
          child: Icon(icon, size: 14, color: theme.textSecondary),
        ),
      ),
    );
  }
}
