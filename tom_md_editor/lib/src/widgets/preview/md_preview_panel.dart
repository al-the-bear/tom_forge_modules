import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../../controller/md_editor_controller.dart';
import '../../debug/md_editor_debug.dart';
import '../../models/md_section.dart';
import '../../plugins/md_content_plugin.dart';
import '../../plugins/md_default_plugins.dart';
import '../../settings/md_editor_settings.dart';
import '../../theme/md_editor_theme.dart';

/// Preview panel that renders markdown as formatted content.
///
/// Supports click-to-edit, hover overlays, and task list interaction.
class MdPreviewPanel extends StatefulWidget {
  const MdPreviewPanel({
    super.key,
    required this.controller,
    required this.theme,
    required this.settings,
    this.pluginRegistry,
    this.onSectionTap,
    this.onEditSection,
    this.onLinkTap,
  });

  final MdEditorController controller;
  final MdEditorTheme theme;
  final MdEditorSettings settings;

  /// Registry of content editor plugins. If null, a default registry with
  /// built-in plugins is created based on [settings].
  final MdPluginRegistry? pluginRegistry;

  final ValueChanged<MdSection>? onSectionTap;
  final ValueChanged<MdSection>? onEditSection;
  final ValueChanged<String>? onLinkTap;

  @override
  State<MdPreviewPanel> createState() => _MdPreviewPanelState();
}

class _MdPreviewPanelState extends State<MdPreviewPanel> {
  final ScrollController _scrollController = ScrollController();
  MdSection? _lastSelectedSection;
  late MdPluginRegistry _registry;

  @override
  void initState() {
    super.initState();
    _registry = widget.pluginRegistry ??
        createDefaultPluginRegistry(settings: widget.settings);
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(MdPreviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
    if (widget.pluginRegistry != oldWidget.pluginRegistry) {
      _registry = widget.pluginRegistry ??
          createDefaultPluginRegistry(settings: widget.settings);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final selected = widget.controller.selectedSection;
    if (selected != null && selected != _lastSelectedSection) {
      _lastSelectedSection = selected;
      // Schedule scroll after the rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSection(selected);
      });
    }
    setState(() {});
  }

  void _scrollToSection(MdSection section) {
    try {
      if (!_scrollController.hasClients) return;
      final markdown = widget.controller.markdown;
      if (markdown.isEmpty) return;

      // Find the heading line in the source markdown.
      final headingPrefix = '${'#' * section.level} ${section.headline}';
      final offset = markdown.indexOf(headingPrefix);
      if (offset < 0) return;

      // Estimate scroll position as a fraction of the document.
      final fraction = offset / markdown.length;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final target = (fraction * maxScroll).clamp(0.0, maxScroll);

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error scrolling to section', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;
    final markdown = widget.controller.markdown;

    return Container(
      color: basic.background,
      child: markdown.isEmpty
          ? _buildEmptyState(basic)
          : _buildMarkdownView(basic, markdown),
    );
  }

  Widget _buildEmptyState(MdBasicTheme basic) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 48, color: basic.textMuted),
          const SizedBox(height: 12),
          Text(
            'No content',
            style: TextStyle(color: basic.textMuted, fontSize: 16),
          ),
          if (!widget.settings.readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Start typing or load a document',
                style: TextStyle(color: basic.textMuted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarkdownView(MdBasicTheme basic, String markdown) {
    try {
      var processed = markdown;
      final contentMap = <String, List<String>>{};

      // Run all plugin preprocessors to convert non-fenced content
      // (like tables and $$..$$) into fenced code blocks with synthetic tags.
      for (final plugin in _registry.all) {
        final preprocessor = plugin.preprocessor;
        if (preprocessor == null) continue;

        final rawContent = <String>[];
        var index = 0;
        processed = processed.replaceAllMapped(preprocessor.pattern, (m) {
          final raw = m.group(0)!;
          rawContent.add(raw);
          final content = preprocessor.contentExtractor?.call(m) ?? raw;
          final tag = '${preprocessor.tagPrefix}-${index++}';
          return '\n```$tag\n$content\n```\n';
        });
        if (rawContent.isNotEmpty) {
          contentMap[preprocessor.tagPrefix] = rawContent;
        }
      }

      return GestureDetector(
        onSecondaryTapUp: !widget.settings.readOnly
            ? (details) => _showInsertMenu(details.globalPosition)
            : null,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(basic.blockPadding * 2),
            child: MarkdownBody(
              data: processed,
              selectable: true,
              extensionSet: md.ExtensionSet(
                md.ExtensionSet.gitHubWeb.blockSyntaxes,
                [
                  if (widget.settings.enableMath) _InlineMathSyntax(),
                  ...md.ExtensionSet.gitHubWeb.inlineSyntaxes,
                ],
              ),
              styleSheet: _buildStyleSheet(basic),
              onTapLink: (text, href, title) {
                _handleLinkTap(href);
              },
              sizedImageBuilder: (config) =>
                  _buildImage(basic, config.uri, config.title, config.alt),
              builders: {
                'pre': _CodeBlockBuilder(
                  theme: basic,
                  settings: widget.settings,
                  onCopy: _copyCodeBlock,
                  onDefaultEdit: _editCodeBlock,
                  pluginRegistry: _registry,
                  contentMap: contentMap,
                  onPluginEdit: _onPluginEdit,
                ),
                'input': _TaskListBuilder(
                  enabled: widget.settings.enableInteractiveTaskLists &&
                      !widget.settings.readOnly,
                  onToggle: _toggleTaskItem,
                  theme: basic,
                ),
                'math-inline': _InlineMathBuilder(theme: basic),
                for (final level in [1, 2, 3, 4, 5, 6])
                  'h$level': _HeadingBuilder(
                    level: level,
                    theme: basic,
                    onTap: _onHeadingTapped,
                  ),
              },
            ),
          ),
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error building markdown view', e, st);
      return Center(
        child: Text(
          'Error rendering markdown',
          style: TextStyle(color: basic.error),
        ),
      );
    }
  }

  // ── Plugin interaction ──

  /// Open a plugin's editor for the given content and replace in source.
  void _onPluginEdit(
    MdContentPlugin plugin,
    String rawOriginal,
    String editableContent,
  ) async {
    final newContent = await plugin.openEditor(
      context,
      editableContent,
      widget.theme,
    );
    if (newContent != null && newContent != editableContent) {
      final source = widget.controller.markdown;
      final newMarkdown = plugin.wrapForMarkdown(newContent);
      widget.controller.markdown =
          source.replaceFirst(rawOriginal, newMarkdown);
    }
  }

  /// Show a context menu for inserting content blocks.
  void _showInsertMenu(Offset position) {
    final insertable = _registry.insertable;
    if (insertable.isEmpty) return;

    final basic = widget.theme.basic;
    showMenu<MdContentPlugin>(
      context: context,
      color: basic.surface,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: insertable.map((plugin) {
        return PopupMenuItem<MdContentPlugin>(
          value: plugin,
          child: Row(
            children: [
              Icon(plugin.icon, size: 18, color: basic.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Insert ${plugin.displayName}',
                style: TextStyle(color: basic.text),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((plugin) {
      if (plugin != null) {
        _insertContent(plugin.insertTemplate);
      }
    });
  }

  /// Insert markdown content at the end of the selected section or document.
  void _insertContent(String template) {
    final section = widget.controller.selectedSection;
    if (section != null) {
      final currentText = section.text;
      final separator = currentText.endsWith('\n') ? '\n' : '\n\n';
      widget.controller.updateSectionText(
        section,
        '$currentText$separator$template\n',
      );
    } else {
      final source = widget.controller.markdown;
      widget.controller.markdown = '$source\n\n$template\n';
    }
  }

  Widget _buildImage(
    MdBasicTheme basic,
    Uri uri,
    String? title,
    String? alt,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: basic.paragraphSpacing / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(basic.borderRadius),
            child: Image.network(
              uri.toString(),
              errorBuilder: (context, error, stack) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: basic.surfaceVariant,
                    borderRadius: BorderRadius.circular(basic.borderRadius),
                    border: Border.all(color: basic.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 20, color: basic.textMuted),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          alt?.isNotEmpty == true
                              ? alt!
                              : 'Image failed to load',
                          style: TextStyle(
                            color: basic.textMuted,
                            fontStyle: FontStyle.italic,
                            fontSize: basic.baseFontSize * 0.9,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (alt != null && alt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                alt,
                style: TextStyle(
                  color: basic.textMuted,
                  fontSize: basic.baseFontSize * 0.85,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet(MdBasicTheme basic) {
    return MarkdownStyleSheet(
      h1: basic.headingStyle(1),
      h2: basic.headingStyle(2),
      h3: basic.headingStyle(3),
      h4: basic.headingStyle(4),
      h5: basic.headingStyle(5),
      h6: basic.headingStyle(6),
      p: basic.paragraphStyle,
      code: basic.inlineCodeStyle,
      codeblockDecoration: basic.codeBlockDecoration,
      blockquoteDecoration: basic.blockquoteDecoration,
      a: TextStyle(
        color: basic.linkColor,
        decoration: basic.linkDecoration,
      ),
      listBullet: TextStyle(color: basic.text),
      tableHead: TextStyle(
        color: basic.text,
        fontWeight: FontWeight.w600,
      ),
      tableBody: TextStyle(color: basic.text),
      tableBorder: TableBorder.all(color: basic.tableBorder),
      blockSpacing: basic.paragraphSpacing,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: basic.border, width: 1),
        ),
      ),
    );
  }

  void _handleLinkTap(String? href) {
    try {
      if (href == null || href.isEmpty) return;
      MdEditorDebug.logger.info('Link tapped: $href');
      widget.onLinkTap?.call(href);
    } catch (e, st) {
      MdEditorDebug.logger.error('Error handling link tap', e, st);
    }
  }

  void _copyCodeBlock(String code) {
    try {
      Clipboard.setData(ClipboardData(text: code));
      MdEditorDebug.logger.info('Code block copied (${code.length} chars)');
    } catch (e, st) {
      MdEditorDebug.logger.error('Error copying code block', e, st);
    }
  }

  void _editCodeBlock(String code, String? language) {
    try {
      MdEditorDebug.logger.info('Edit code block (lang=$language)');
      // Overlay editor would be shown here in full implementation.
    } catch (e, st) {
      MdEditorDebug.logger.error('Error opening code editor', e, st);
    }
  }

  void _onHeadingTapped(int level, String text) {
    try {
      final sections = widget.controller.document.allSections;
      final match = sections.where(
        (s) => s.level == level && s.headline.trim() == text.trim(),
      );
      if (match.isNotEmpty) {
        final section = match.first;
        widget.controller.selectSection(section);
        widget.onSectionTap?.call(section);
      }
    } catch (e, st) {
      MdEditorDebug.logger.error('Error handling heading tap', e, st);
    }
  }

  void _toggleTaskItem(int index) {
    try {
      MdEditorDebug.logger.info('Toggle task item at index $index');
      final md = widget.controller.markdown;
      final taskPattern = RegExp(r'- \[([ xX])\]');
      final matches = taskPattern.allMatches(md).toList();
      if (index >= 0 && index < matches.length) {
        final match = matches[index];
        final isChecked = match.group(1) != ' ';
        final replacement = isChecked ? '- [ ]' : '- [x]';
        final newMd =
            md.substring(0, match.start) +
            replacement +
            md.substring(match.end);
        widget.controller.markdown = newMd;
      }
    } catch (e, st) {
      MdEditorDebug.logger.error('Error toggling task item', e, st);
    }
  }
}

// ── Custom markdown builders ──

/// Renders code blocks, delegating to plugins for recognized languages.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder({
    required this.theme,
    required this.settings,
    required this.onCopy,
    required this.onDefaultEdit,
    required this.pluginRegistry,
    required this.contentMap,
    required this.onPluginEdit,
  });

  final MdBasicTheme theme;
  final MdEditorSettings settings;
  final ValueChanged<String> onCopy;
  final void Function(String code, String? language) onDefaultEdit;
  final MdPluginRegistry pluginRegistry;
  final Map<String, List<String>> contentMap;
  final void Function(
    MdContentPlugin plugin,
    String rawOriginal,
    String editableContent,
  ) onPluginEdit;

  String? _language;

  @override
  void visitElementBefore(md.Element element) {
    // Extract language from class attribute on <code> inside <pre>.
    final codeChild = element.children
        ?.whereType<md.Element>()
        .where((e) => e.tag == 'code')
        .firstOrNull;
    if (codeChild != null) {
      final cls = codeChild.attributes['class'] ?? '';
      if (cls.startsWith('language-')) {
        _language = cls.substring('language-'.length);
      }
    }
  }

  @override
  Widget visitText(md.Text text, TextStyle? preferredStyle) {
    final code = text.text;

    // Check if any plugin handles this language.
    if (_language != null) {
      final plugin = pluginRegistry.forLanguage(_language!);
      if (plugin != null) {
        final preview = plugin.buildPreview(
          code,
          theme,
          onEdit: () {
            // Determine the raw original content for replacement.
            String rawOriginal;
            final preprocessor = plugin.preprocessor;
            if (preprocessor != null) {
              final prefix = preprocessor.tagPrefix;
              final expectedStart = '$prefix-';
              final indexStr = _language!.startsWith(expectedStart)
                  ? _language!.substring(expectedStart.length)
                  : null;
              final idx = indexStr != null ? int.tryParse(indexStr) : null;
              final list = contentMap[prefix];
              rawOriginal =
                  (idx != null && list != null && idx < list.length)
                      ? list[idx]
                      : code;
            } else {
              // Native fenced block — construct the search string.
              rawOriginal = '```$_language\n$code\n```';
            }
            onPluginEdit(plugin, rawOriginal, code);
          },
        );
        if (preview != null) return preview;
      }
    }

    // Default: render as code block with copy/edit buttons.
    return _CodeBlockWidget(
      code: code,
      language: _language,
      theme: theme,
      showLanguage: settings.showCodeBlockLanguage,
      showCopy: settings.showCopyCodeButton,
      showEdit: settings.showCodeEditButton,
      onCopy: () => onCopy(code),
      onEdit: () => onDefaultEdit(code, _language),
    );
  }
}

class _CodeBlockWidget extends StatefulWidget {
  const _CodeBlockWidget({
    required this.code,
    this.language,
    required this.theme,
    this.showLanguage = true,
    this.showCopy = true,
    this.showEdit = true,
    this.onCopy,
    this.onEdit,
  });

  final String code;
  final String? language;
  final MdBasicTheme theme;
  final bool showLanguage;
  final bool showCopy;
  final bool showEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        width: double.infinity,
        decoration: widget.theme.codeBlockDecoration,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(widget.theme.blockPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showLanguage && widget.language != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        widget.language!,
                        style: TextStyle(
                          color: widget.theme.textMuted,
                          fontSize: 11,
                          fontFamily: widget.theme.monoFontFamily,
                        ),
                      ),
                    ),
                  SelectableText(
                    widget.code,
                    style: widget.theme.codeStyle,
                  ),
                ],
              ),
            ),
            if (_hovering)
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showCopy)
                      MdOverlayButton(
                        icon: Icons.copy,
                        tooltip: 'Copy',
                        onTap: widget.onCopy,
                        theme: widget.theme,
                      ),
                    if (widget.showEdit) ...[
                      const SizedBox(width: 4),
                      MdOverlayButton(
                        icon: Icons.edit,
                        tooltip: 'Edit',
                        onTap: widget.onEdit,
                        theme: widget.theme,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Renders task list checkboxes as interactive widgets.
class _TaskListBuilder extends MarkdownElementBuilder {
  _TaskListBuilder({
    required this.enabled,
    required this.onToggle,
    required this.theme,
  });

  final bool enabled;
  final ValueChanged<int> onToggle;
  final MdBasicTheme theme;
  int _taskIndex = 0;

  @override
  Widget visitElementBefore(md.Element element) {
    if (element.tag == 'input' &&
        element.attributes['type'] == 'checkbox') {
      final isChecked = element.attributes.containsKey('checked');
      final index = _taskIndex++;
      return InkWell(
        onTap: enabled ? () => onToggle(index) : null,
        child: Icon(
          isChecked ? Icons.check_box : Icons.check_box_outline_blank,
          size: 18,
          color: isChecked ? theme.success : theme.textMuted,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ── Inline math syntax ──

/// Matches `$...$` but not `$$`.
class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax() : super(r'\$([^\$]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final expression = match.group(1)!;
    final el = md.Element.text('math-inline', expression);
    parser.addNode(el);
    return true;
  }
}

// ── Math builders ──

class _InlineMathBuilder extends MarkdownElementBuilder {
  _InlineMathBuilder({required this.theme});

  final MdBasicTheme theme;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final expression = element.textContent;
    return Math.tex(
      expression,
      mathStyle: MathStyle.text,
      textStyle: TextStyle(
        fontSize: theme.baseFontSize,
        color: theme.text,
      ),
      onErrorFallback: (err) => Text(
        '\$$expression\$',
        style: TextStyle(
          color: theme.error,
          fontFamily: theme.monoFontFamily,
          fontSize: theme.baseFontSize,
        ),
      ),
    );
  }
}

// ── Heading builder for click-to-select ──

class _HeadingBuilder extends MarkdownElementBuilder {
  _HeadingBuilder({
    required this.level,
    required this.theme,
    required this.onTap,
  });

  final int level;
  final MdBasicTheme theme;
  final void Function(int level, String text) onTap;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent.trim();
    return SelectionContainer.disabled(
      child: GestureDetector(
        onTap: () => onTap(level, text),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Text(text, style: preferredStyle ?? theme.headingStyle(level)),
        ),
      ),
    );
  }
}
