import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;
import 'package:tom_editors_shared/tom_editors_shared.dart';

import 'svg_file_source.dart';

import '../../controller/md_editor_controller.dart';
import '../../debug/md_editor_debug.dart';
import '../../models/md_section.dart';
import '../../plugins/md_content_plugin.dart';
import '../../plugins/md_default_plugins.dart';
import '../../settings/md_editor_settings.dart';
import '../../theme/md_editor_theme.dart';
import '../../utils/md_code_highlighting.dart';
import '../../validation/schema_section_helper.dart';
import '../../validation/schema_template_helper.dart';
import '../dialogs/edit_section_dialog.dart';
import '../overlays/md_code_block_overlay.dart';
import '../schema/md_form_editor.dart';
import '../schema/md_validation_prompt_banner.dart';

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
  /// Track last selected section by value (level + headline) to avoid
  /// false-positive change detection after re-parsing.
  (int, String)? _lastSelectedKey;
  bool _suppressScroll = false;
  late MdPluginRegistry _registry;
  /// Debounce timer for preview rebuilds.
  Timer? _rebuildTimer;
  /// Cached markdown to skip rebuilds when content is unchanged.
  String _lastMarkdown = '';

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
    _rebuildTimer?.cancel();
    widget.controller.removeListener(_onChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final selected = widget.controller.selectedSection;
    final key = selected != null
        ? (selected.level, selected.headline)
        : null;
    final selectionChanged = key != null && key != _lastSelectedKey;
    if (selectionChanged) {
      _lastSelectedKey = key;
      if (!_suppressScroll) {
        // Schedule scroll after the rebuild so the heading widget exists.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSection(selected!);
        });
      }
    }
    _suppressScroll = false;

    final markdown = widget.controller.markdown;
    if (markdown == _lastMarkdown) {
      // Selection changes need an immediate rebuild even when the
      // markdown content is unchanged (e.g. clicking a heading).
      if (selectionChanged && mounted) setState(() {});
      return;
    }
    // Debounce content rebuilds to avoid re-rendering the full markdown
    // on every keystroke.
    _rebuildTimer?.cancel();
    _rebuildTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() {});
    });
  }

  /// Scroll the heading for [section] to the top of the preview viewport.
  void _scrollToSection(MdSection section) {
    try {
      // Compute ordinal: position of this section among all same-level
      // headings so the key matches the _HeadingBuilder ordinal counter.
      final allSections = widget.controller.document.allSections;
      var ordinal = 0;
      for (final s in allSections) {
        if (s.level == section.level) {
          if (identical(s, section) ||
              (s.headline.trim() == section.headline.trim() &&
               s.sourceLineStart == section.sourceLineStart)) {
            break;
          }
          ordinal++;
        }
      }
      final targetKey = ValueKey('${section.level}:$ordinal:${section.headline.trim()}');
      BuildContext? headingCtx;
      void search(Element element) {
        if (headingCtx != null) return;
        if (element.widget.key == targetKey) {
          headingCtx = element;
          return;
        }
        element.visitChildren(search);
      }
      (context as Element).visitChildren(search);
      if (headingCtx == null) return;
      Scrollable.ensureVisible(
        headingCtx!,
        alignment: 0.0,
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
    _lastMarkdown = markdown;

    return Container(
      color: basic.background,
      child: Column(
        children: [
          // Schema context widgets for selected section.
          _buildSchemaContextBar(basic),
          Expanded(
            child: markdown.isEmpty
                ? _buildEmptyState(basic)
                : _buildMarkdownView(basic, markdown),
          ),
        ],
      ),
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

  /// Build schema context bar shown above the preview when a section
  /// is selected and schema is active.
  ///
  /// Integrates: form editor (P2), tag selector (P3.2),
  /// character counter (P4.3), validation prompts (P6.3).
  Widget _buildSchemaContextBar(MdBasicTheme basic) {
    final section = widget.controller.selectedSection;
    final schema = widget.controller.schema;
    if (section == null || schema == null) return const SizedBox.shrink();

    final helper = SchemaSectionHelper(schema);
    final tmpl = SchemaTemplateHelper(schema);
    final typeName = helper.getSectionTypeName(
      section,
      document: widget.controller.document,
    );
    if (typeName == null) return const SizedBox.shrink();

    final typeDef = schema.sectionTypes[typeName];
    if (typeDef == null) return const SizedBox.shrink();

    final editorTheme = widget.theme;
    final widgets = <Widget>[];

    // Validation prompt banner (P6.3).
    if (widget.settings.showValidationPrompts) {
      // Find parent section ID for ${parent.id} interpolation.
      String? parentId;
      for (final topLevel in widget.controller.document.sections) {
        if (topLevel == section) break;
        for (final child in topLevel.subsections) {
          if (child == section) {
            parentId = topLevel.id;
            break;
          }
        }
        if (parentId != null) break;
      }

      final prompt = tmpl.getDocumentValidationPrompt(
        typeName: typeName,
        sectionId: section.id,
        parentSectionId: parentId,
      );
      if (prompt != null) {
        widgets.add(MdValidationPromptBanner(
          prompt: prompt,
          sectionId: section.id,
          sectionText: section.text,
          sectionLineNumber: section.sourceLineStart,
          sectionTags: section.commentMetadata['tags'],
          sectionFields: section.commentMetadata.isEmpty
              ? null
              : section.commentMetadata,
          parentId: parentId,
          theme: editorTheme,
        ));
      }
    }

    // Character counter (P4.3) — moved to raw editor title bar.

    // Form editor (P2) — now rendered inline in the markdown preview.
    // See _preprocessFormSections() and _CodeBlockBuilder.

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: basic.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: basic.border, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgets,
      ),
    );
  }

  Widget _buildMarkdownView(MdBasicTheme basic, String markdown) {
    try {
      var processed = markdown;
      final contentMap = <String, List<String>>{};
      var taskIndex = 0;

      // Replace form section body text with synthetic fenced blocks
      // BEFORE other preprocessors run (form text looks like list items).
      final formSections = <_FormSectionData>[];
      if (widget.settings.enableFormEditor && !widget.settings.readOnly) {
        processed = _preprocessFormSections(processed, formSections);
      }

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

      // Pre-process list blocks into synthetic fenced code blocks so we can
      // render them as draggable list widgets.
      final listBlockContents = <String>[];
      if (!widget.settings.readOnly) {
        processed = _preprocessListBlocks(processed, listBlockContents);
        if (listBlockContents.isNotEmpty) {
          contentMap['listblock'] = listBlockContents;
        }
      }

      return Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(basic.blockPadding * 2),
            child: SelectionArea(
              contextMenuBuilder: (ctx, selectableRegionState) {
                return _buildBodyContextMenu(
                  ctx,
                  selectableRegionState,
                );
              },
              child: MarkdownBody(
              data: processed,
              selectable: false,
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
              checkboxBuilder: (checked) {
                final index = taskIndex++;
                final enabled =
                    widget.settings.enableInteractiveTaskLists &&
                    !widget.settings.readOnly;
                return GestureDetector(
                  onTap: enabled ? () => _toggleTaskItem(index) : null,
                  child: Icon(
                    checked
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: checked ? basic.success : basic.textMuted,
                  ),
                );
              },
              builders: {
                'pre': _CodeBlockBuilder(
                  theme: basic,
                  settings: widget.settings,
                  onCopy: _copyCodeBlock,
                  onDefaultEdit: _editCodeBlock,
                  pluginRegistry: _registry,
                  contentMap: contentMap,
                  onPluginEdit: _onPluginEdit,
                  onListReorder: _onListReorder,
                  formSections: formSections,
                  editorTheme: widget.theme,
                  controller: widget.controller,
                ),
                'math-inline': _InlineMathBuilder(theme: basic),
                for (final level in [1, 2, 3, 4, 5, 6])
                  'h$level': _HeadingBuilder(
                    level: level,
                    theme: basic,
                    controller: widget.controller,
                    readOnly: widget.settings.readOnly,
                    onTap: _onHeadingTapped,
                    onEdit: _onHeadingEdit,
                    onContextMenu: _onHeadingContextMenu,
                    getValidationErrors: _getValidationErrorsForSection,
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
    if (newContent != null && newContent.trim() != editableContent.trim()) {
      final source = widget.controller.markdown;
      final newMarkdown = plugin.wrapForMarkdown(newContent);

      // Try exact replacement first, then fall back to pattern-based.
      final idx = source.indexOf(rawOriginal);
      if (idx >= 0) {
        widget.controller.markdown =
            source.replaceFirst(rawOriginal, newMarkdown);
      } else {
        // For fenced blocks, use robust replacement that handles whitespace
        // variations and special characters in the content.
        final lang = plugin.languages.isNotEmpty ? plugin.languages.first : '';
        if (lang.isNotEmpty) {
          final updated = _replaceFencedBlock(
            source,
            lang,
            editableContent,
            newMarkdown,
          );
          if (updated != null) {
            widget.controller.markdown = updated;
          } else {
            MdEditorDebug.logger.warn(
              'Could not find $lang block to replace',
            );
          }
        }
      }
    }
  }

  /// Find and replace a fenced code block by language and content match.
  ///
  /// This handles whitespace variations and special characters that would
  /// break simple regex-based matching.
  String? _replaceFencedBlock(
    String source,
    String language,
    String originalContent,
    String replacement,
  ) {
    // Pattern to find all fenced blocks of this language.
    // Captures: (1) opener with language, (2) content, (3) closer.
    final pattern = RegExp(
      r'(```' + RegExp.escape(language) + r'[ \t]*\n)([\s\S]*?)(\n```)',
      multiLine: true,
    );

    final normalizedOriginal = _normalizeContent(originalContent);

    for (final match in pattern.allMatches(source)) {
      final blockContent = match.group(2) ?? '';
      if (_normalizeContent(blockContent) == normalizedOriginal) {
        // Found the matching block — replace it.
        return source.replaceRange(match.start, match.end, replacement);
      }
    }
    return null;
  }

  /// Normalize content for comparison: trim and normalize line endings.
  String _normalizeContent(String content) {
    return content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
  }


  Widget _buildImage(
    MdBasicTheme basic,
    Uri uri,
    String? title,
    String? alt,
  ) {
    final uriString = uri.toString();
    final lower = uriString.toLowerCase();
    final isSvg = lower.endsWith('.svg');

    Widget brokenImage() {
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
                alt?.isNotEmpty == true ? alt! : 'Image failed to load',
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
    }

    Widget imageWidget;
    if (isSvg) {
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        imageWidget = SvgPicture.network(uriString);
      } else if (uri.hasScheme && uri.scheme == 'file' && !kIsWeb) {
        imageWidget = svgFromFileUri(uri);
      } else {
        final assetPath = uriString.startsWith('/') ? uriString.substring(1) : uriString;
        imageWidget = SvgPicture.asset(assetPath);
      }
    } else {
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        imageWidget = Image.network(uriString, errorBuilder: (context, error, stack) => brokenImage());
      } else if (uri.hasScheme && uri.scheme == 'file' && !kIsWeb) {
        imageWidget = Image.file(File.fromUri(uri), errorBuilder: (context, error, stack) => brokenImage());
      } else {
        final assetPath = uriString.startsWith('/') ? uriString.substring(1) : uriString;
        imageWidget = Image.asset(assetPath, errorBuilder: (context, error, stack) => brokenImage());
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: basic.paragraphSpacing / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(basic.borderRadius),
            child: imageWidget,
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
    // paragraphStyle uses the same font family as headings but with
    // a softer grey (textSecondary) to visually distinguish body text.
    return MarkdownStyleSheet(
      p: basic.paragraphStyle,
      h1: basic.headingStyle(1),
      h2: basic.headingStyle(2),
      h3: basic.headingStyle(3),
      h4: basic.headingStyle(4),
      h5: basic.headingStyle(5),
      h6: basic.headingStyle(6),
      code: basic.inlineCodeStyle,
      codeblockDecoration: basic.codeBlockDecoration,
      blockquoteDecoration: basic.blockquoteDecoration,
      blockquote: basic.paragraphStyle,
      a: TextStyle(
        color: basic.linkColor,
        decoration: basic.linkDecoration,
      ),
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
    () async {
      try {
        final currentLanguage = MdCodeHighlighting.normalizeLanguage(language);
        String? editedCode;
        String? editedLanguage = currentLanguage;

        await showDialog<void>(
          context: context,
          builder: (_) => MdCodeBlockOverlay(
            code: code,
            language: currentLanguage,
            theme: widget.theme,
            onSave: (newCode, newLanguage) {
              editedCode = newCode;
              editedLanguage = MdCodeHighlighting.normalizeLanguage(
                newLanguage,
              );
            },
          ),
        );

        if (editedCode == null) return;
        if (editedCode == code && editedLanguage == currentLanguage) return;

        final source = widget.controller.markdown;
        final oldFence = currentLanguage == null
            ? '```\n$code\n```'
            : '```$currentLanguage\n$code\n```';
        final newFence = editedLanguage == null
            ? '```\n${editedCode!}\n```'
            : '```$editedLanguage\n${editedCode!}\n```';

        final idx = source.indexOf(oldFence);
        if (idx >= 0) {
          widget.controller.markdown = source.replaceFirst(oldFence, newFence);
          return;
        }

        // Fallback: use robust replacement for whitespace variations.
        final lang = currentLanguage ?? '';
        if (lang.isNotEmpty) {
          final updated = _replaceFencedBlock(source, lang, code, newFence);
          if (updated != null) {
            widget.controller.markdown = updated;
            return;
          }
        }

        // Final fallback for blocks without language: match any unlabeled block.
        if (lang.isEmpty) {
          final updated = _replaceUnlabeledFencedBlock(source, code, newFence);
          if (updated != null) {
            widget.controller.markdown = updated;
          }
        }
      } catch (e, st) {
        MdEditorDebug.logger.error('Error opening code editor', e, st);
      }
    }();
  }

  /// Find and replace an unlabeled fenced code block by content match.
  String? _replaceUnlabeledFencedBlock(
    String source,
    String originalContent,
    String replacement,
  ) {
    // Pattern for unlabeled fenced blocks (``` with no language).
    final pattern = RegExp(
      r'(```[ \t]*\n)([\s\S]*?)(\n```)',
      multiLine: true,
    );

    final normalizedOriginal = _normalizeContent(originalContent);

    for (final match in pattern.allMatches(source)) {
      final blockContent = match.group(2) ?? '';
      if (_normalizeContent(blockContent) == normalizedOriginal) {
        return source.replaceRange(match.start, match.end, replacement);
      }
    }
    return null;
  }

  void _onHeadingTapped(int level, String text) {
    try {
      final sections = widget.controller.document.allSections;
      final match = sections.where(
        (s) => s.level == level && s.headline.trim() == text.trim(),
      );
      if (match.isNotEmpty) {
        final section = match.first;
        // Suppress preview scroll — clicking in the preview should only
        // sync the raw editor, not jump the preview around.
        _suppressScroll = true;
        widget.controller.selectSection(section);
        widget.onSectionTap?.call(section);

        // Set cursor offset to the heading's position in the source markdown.
        final markdown = widget.controller.markdown;
        final headingMd = section.toHeadlineMarkdown();
        final offset = markdown.indexOf(headingMd);
        if (offset >= 0) {
          widget.controller.setCursorOffset(offset);
        }
      }
    } catch (e, st) {
      MdEditorDebug.logger.error('Error handling heading tap', e, st);
    }
  }

  /// Handle heading edit icon tap.
  Future<void> _onHeadingEdit(int level, String text) async {
    try {
      final sections = widget.controller.document.allSections;
      final match = sections.where(
        (s) => s.level == level && s.headline.trim() == text.trim(),
      );
      if (match.isEmpty) return;
      final section = match.first;
      final headlineController = TextEditingController(text: section.headline);
      final idController = TextEditingController(text: section.id ?? '');

      // Build context-sensitive allowed section types.
      final schema = widget.controller.schema;
      final hasSchema = schema != null;
      var allowedSectionTypes = <SectionTypeInfo>[];
      List<String> schemaFields = const [];

      if (schema != null) {
        final schemaHelper = widget.controller.schemaHelper;
        final tmpl = SchemaTemplateHelper(schema);

        // Find parent section to get allowed child types.
        final parent = _findParentSection(section);
        
        // Check if parent has a known schema type.
        // If parent is the document title (no schema type), treat children
        // as effectively top-level sections for schema purposes.
        final parentHasSchemaType = parent != null &&
            schemaHelper?.getSectionTypeName(
              parent,
              document: widget.controller.document,
            ) != null;

        String applyPrefixCase(String value) {
          switch (widget.settings.prefixCaseStyle) {
            case PrefixCaseStyle.uppercase:
              return value.toUpperCase();
            case PrefixCaseStyle.lowercase:
              return value.toLowerCase();
            case PrefixCaseStyle.propercase:
              if (value.isEmpty) return value;
              return value[0].toUpperCase() + value.substring(1).toLowerCase();
          }
        }

        if (parent != null && parentHasSchemaType) {
          // Child of a schema-typed section - get allowed subsection types.
          final allowed = schemaHelper?.getAllowedSubsections(
            parent,
            document: widget.controller.document,
          );
          if (allowed != null && allowed.isNotEmpty) {
            allowedSectionTypes = allowed.map((sub) {
              final prefix = applyPrefixCase(sub.typeDef?.prefix ?? sub.typeName);
              final patternInfo = tmpl.getIdPatternInfo(sub.typeName);
              return (
                typeName: sub.typeName,
                prefix: prefix,
                idPattern: patternInfo?.pattern,
                idPatternErrorMessage: patternInfo?.errorMessage,
              );
            }).toList();
          }
        } else {
          // Top-level section OR child of untyped section (e.g., document title)
          // - get allowed top-level types from document structure.
          final topLevel = schemaHelper?.getAllowedTopLevelSections() ?? [];
          allowedSectionTypes = topLevel.map((top) {
            final prefix = applyPrefixCase(top.typeDef?.prefix ?? top.sectionType);
            final patternInfo = tmpl.getIdPatternInfo(top.sectionType);
            return (
              typeName: top.sectionType,
              prefix: prefix,
              idPattern: patternInfo?.pattern,
              idPatternErrorMessage: patternInfo?.errorMessage,
            );
          }).toList();
        }

        // Get required fields for current section type.
        if (schemaHelper != null) {
          final typeName = schemaHelper.getSectionTypeName(
            section,
            document: widget.controller.document,
          );
          if (typeName != null) {
            schemaFields = tmpl.getRequiredFields(typeName);
          }
        }
      }

      // Build metadata controllers from existing values + schema required fields.
      // Exclude 'tags' since it's handled separately in the dialog.
      final existingMeta = Map<String, String>.from(section.commentMetadata);
      final tagsStr = existingMeta.remove('tags') ?? '';
      final initialTags = tagsStr.isNotEmpty
          ? tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];

      final allKeys = <String>{...existingMeta.keys, ...schemaFields};
      allKeys.remove('tags'); // Ensure tags not in metadata controllers.
      final metaControllers = <String, TextEditingController>{};
      for (final key in allKeys) {
        metaControllers[key] =
            TextEditingController(text: existingMeta[key] ?? '');
      }

      // Get allowed tags from schema.
      final allowedTags = _getAllowedTagsForSection(section);

      final resultTags = await showDialog<List<String>>(
        context: context,
        builder: (ctx) => EditSectionDialog(
          headlineController: headlineController,
          idController: idController,
          metaControllers: metaControllers,
          allowedSectionTypes: allowedSectionTypes,
          hasSchema: hasSchema,
          schemaFields: schemaFields,
          allowedTags: allowedTags,
          initialTags: initialTags,
        ),
      );

      // Read controller values before disposal.
      final newHeadline = headlineController.text.trim();
      final newId = idController.text.trim();
      final newMeta = <String, String>{};
      for (final entry in metaControllers.entries) {
        final value = entry.value.text.trim();
        if (value.isNotEmpty) {
          newMeta[entry.key] = value;
        }
      }

      // Defer disposal to ensure dialog animation completes first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        headlineController.dispose();
        idController.dispose();
        for (final c in metaControllers.values) {
          c.dispose();
        }
      });

      if (resultTags == null) {
        // User cancelled.
        return;
      }

      if (newHeadline.isNotEmpty && newHeadline != section.headline) {
        widget.controller.updateSectionHeadline(section, newHeadline);
      }
      final effectiveId = newId.isEmpty ? null : newId;
      if (effectiveId != section.id) {
        widget.controller.updateSectionId(section, effectiveId);
      }
      // Add tags back to metadata if any.
      if (resultTags.isNotEmpty) {
        newMeta['tags'] = resultTags.join(',');
      }
      if (!_mapEquals(newMeta, section.commentMetadata)) {
        widget.controller.updateCommentMetadata(section, newMeta);
      }
    } catch (e, st) {
      MdEditorDebug.logger.error('Error handling heading edit', e, st);
    }
  }

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  /// Build a custom context menu for the selection area in the preview body.
  ///
  /// Includes standard selection buttons (Copy, Select All) plus
  /// "Insert Tags" / "Edit Tags" when the right-clicked section supports tags.
  Widget _buildBodyContextMenu(
    BuildContext ctx,
    SelectableRegionState selectableRegionState,
  ) {
    final standardItems = selectableRegionState.contextMenuButtonItems;
    final anchors = selectableRegionState.contextMenuAnchors;

    // Use the currently selected section from the controller.
    final section = widget.controller.selectedSection;

    // Build tag insertion item if the section's type has allowed-tags.
    final tagItems = <ContextMenuButtonItem>[];
    if (section != null && !widget.settings.readOnly) {
      final schema = widget.controller.schema;
      var allowedTags = <String>[];
      if (schema != null) {
        final helper = SchemaSectionHelper(schema);
        final tmpl = SchemaTemplateHelper(schema);
        final typeName = helper.getSectionTypeName(
          section,
          document: widget.controller.document,
        );
        if (typeName != null) {
          allowedTags = tmpl.getAllowedTags(typeName);
        }
      }
      // Check heading comment metadata for existing tags.
      final existingTagStr = section.commentMetadata['tags'] ?? '';
      final existingTags = existingTagStr.isNotEmpty
          ? existingTagStr
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList()
          : <String>[];
      if (allowedTags.isNotEmpty || existingTags.isNotEmpty) {
        tagItems.add(ContextMenuButtonItem(
          label: existingTags.isNotEmpty ? 'Edit Tags' : 'Insert Tags',
          onPressed: () {
            ContextMenuController.removeAny();
            _onHeadingEdit(section.level, section.headline);
          },
        ));
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: [...standardItems, ...tagItems],
    );
  }

  void _onHeadingContextMenu(Offset position, int level, String text) {
    try {
      final sections = widget.controller.document.allSections;
      final match = sections.where(
        (s) => s.level == level && s.headline.trim() == text,
      );
      if (match.isEmpty) return;
      final section = match.first;

      // Build schema-aware subsection items.
      final subsectionItems = _buildSchemaSubsectionItems(section);

      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: [
          const PopupMenuItem(
            value: 'add_above',
            child: Text('Add Section Above'),
          ),
          const PopupMenuItem(
            value: 'add_below',
            child: Text('Add Section Below'),
          ),
          ...subsectionItems,
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'edit',
            child: Text('Edit Headline & ID'),
          ),
        ],
      ).then((value) {
        if (value == null) return;
        _handlePreviewContextAction(value, section);
      });
    } catch (e, st) {
      MdEditorDebug.logger.error('Error showing heading context menu', e, st);
    }
  }

  /// Build schema-aware subsection menu items for the preview context menu.
  List<PopupMenuEntry<String>> _buildSchemaSubsectionItems(
    MdSection section,
  ) {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'add_child',
        child: Text('Add Subsection'),
      ),
    ];

    final schema = widget.controller.schema;
    if (schema != null) {
      final helper = SchemaSectionHelper(schema);
      final allowed = helper.getAllowedSubsections(
        section,
        document: widget.controller.document,
      );

      if (allowed.isNotEmpty) {
        items.add(const PopupMenuDivider());
        for (final sub in allowed) {
          items.add(
            PopupMenuItem(
              value: 'add_typed_child:${sub.typeName}',
              child: Tooltip(
                message: sub.description ?? '',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.subdirectory_arrow_right, size: 14),
                    const SizedBox(width: 6),
                    Text('Add ${sub.capitalizedName}'),
                  ],
                ),
              ),
            ),
          );
        }
      }
    }

    return items;
  }

  void _handlePreviewContextAction(String action, MdSection section) {
    try {
      // Handle schema-typed subsection insertion.
      if (action.startsWith('add_typed_child:')) {
        final typeName = action.substring('add_typed_child:'.length);
        _addTypedSubsection(section, typeName);
        return;
      }

      switch (action) {
        case 'add_above':
        case 'add_below':
          _addSectionRelative(section, above: action == 'add_above');
        case 'add_child':
          _addChildSection(section);
        case 'edit':
          _onHeadingEdit(section.level, section.headline);
      }
    } catch (e, st) {
      MdEditorDebug.logger.error('Error handling context action', e, st);
    }
  }

  void _addSectionRelative(MdSection section, {required bool above}) {
    final allTopLevel = widget.controller.document.sections;
    // Find parent to determine sibling list.
    MdSection? parent;
    List<MdSection> siblings = allTopLevel;
    for (final top in allTopLevel) {
      if (top == section) break;
      final found = _findParentOf(section, top);
      if (found != null) {
        parent = found;
        siblings = found.subsections;
        break;
      }
    }
    final idx = siblings.indexOf(section);
    if (idx < 0) return;
    final insertIdx = above ? idx : idx + 1;
    widget.controller.insertSection(
      parent: parent,
      index: insertIdx,
      level: section.level,
      headline: 'New Section',
    );
  }

  /// Find the parent of [target] within the subtree rooted at [root].
  MdSection? _findParentOf(MdSection target, MdSection root) {
    for (final child in root.subsections) {
      if (child == target) return root;
      final found = _findParentOf(target, child);
      if (found != null) return found;
    }
    return null;
  }

  /// Find the parent section of [target], or null if it's a top-level section.
  MdSection? _findParentSection(MdSection target) {
    final topLevel = widget.controller.document.sections;
    for (final top in topLevel) {
      // Use attribute comparison instead of object identity since sections
      // may have been recreated via allSections getter.
      if (_sectionsMatch(top, target)) return null; // Top-level section.
      final found = _findParentOf(target, top);
      if (found != null) return found;
    }
    return null;
  }

  /// Check if two sections match by attributes (not object identity).
  bool _sectionsMatch(MdSection a, MdSection b) {
    return a.level == b.level &&
        a.headline == b.headline &&
        a.id == b.id &&
        a.sourceLineStart == b.sourceLineStart;
  }

  void _addChildSection(MdSection section) {
    final childLevel = section.level + 1;
    if (childLevel > 6) return;
    widget.controller.insertSection(
      parent: section,
      index: section.subsections.length,
      level: childLevel,
      headline: 'New Subsection',
    );
  }

  void _addTypedSubsection(MdSection section, String typeName) {
    final schema = widget.controller.schema;
    if (schema == null) return;

    final helper = SchemaSectionHelper(schema);
    final allowed = helper.getAllowedSubsections(
      section,
      document: widget.controller.document,
    );
    final sub = allowed.where((s) => s.typeName == typeName).firstOrNull;
    if (sub == null) return;

    final headline = sub.capitalizedName;
    final id = sub.prefix;
    final childLevel = section.level + 1;
    if (childLevel > 6) return;
    widget.controller.insertSection(
      parent: section,
      index: section.subsections.length,
      level: childLevel,
      headline: headline,
      id: id,
    );
  }

  List<ValidationError> _getValidationErrorsForSection(MdSection section) {
    final allErrors = widget.controller.validationErrors;
    if (allErrors.isEmpty) return const [];

    final sectionId = section.id ?? '';
    final headline = section.headline.toLowerCase();

    return allErrors.where((error) {
      if (error.path.isEmpty) return false;
      final firstPath = error.path.first.toString().toLowerCase();
      if (sectionId.isNotEmpty && firstPath == sectionId) return true;
      if (firstPath == headline) return true;
      return false;
    }).toList();
  }

  /// Get allowed tags for a section from the schema.
  List<String> _getAllowedTagsForSection(MdSection section) {
    final schema = widget.controller.schema;
    if (schema == null) return const [];

    final helper = SchemaSectionHelper(schema);
    final tmpl = SchemaTemplateHelper(schema);
    final typeName = helper.getSectionTypeName(
      section,
      document: widget.controller.document,
    );
    if (typeName == null) return const [];
    return tmpl.getAllowedTags(typeName);
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

  // ── Form section preprocessing ──

  /// Replace form-type section body text with synthetic `formfield-N` fenced
  /// code blocks so [_CodeBlockBuilder] can render inline [MdFormEditor]
  /// widgets.  Must run **before** list-block and plugin preprocessors
  /// because form text is serialised as list items (`- Field: value`).
  String _preprocessFormSections(
    String markdown,
    List<_FormSectionData> formSections,
  ) {
    final schema = widget.controller.schema;
    if (schema == null) return markdown;

    final doc = widget.controller.document;
    final helper = SchemaSectionHelper(schema);
    final tmpl = SchemaTemplateHelper(schema);

    // Collect form sections in document order.
    void collect(MdSection section) {
      final typeName = helper.getSectionTypeName(
        section,
        document: doc,
      );
      if (typeName != null && section.text.isNotEmpty) {
        final formType = tmpl.getFormType(typeName);
        if (formType != null) {
          formSections.add(_FormSectionData(
            formType: formType,
            section: section,
            typeName: typeName,
            customTags: schema.customTags,
            requiredFields: tmpl.getRequiredFields(typeName),
            textPatternCheck: schema.sectionTypes[typeName]?.patternCheckText,
          ));
        }
      }
      for (final sub in section.subsections) {
        collect(sub);
      }
    }

    for (final s in doc.sections) {
      collect(s);
    }
    if (formSections.isEmpty) return markdown;

    // Replace each form section's body text with a synthetic fenced block.
    // Use line offsets from the section model (reliable) instead of text
    // matching via toHeadlineMarkdown() (fragile, may not match original).
    // Work backwards so earlier replacements don't shift line indices.
    final lines = markdown.split('\n');
    for (var i = formSections.length - 1; i >= 0; i--) {
      final data = formSections[i];
      final lineStart = data.section.sourceLineStart;
      if (lineStart == null) continue;

      final body = data.section.text;
      if (body.isEmpty) continue;

      // Skip heading line and blank lines to find where body text starts.
      var bodyLineStart = lineStart + 1;
      while (bodyLineStart < lines.length &&
          lines[bodyLineStart].trim().isEmpty) {
        bodyLineStart++;
      }

      // Verify the body content matches before replacing.
      final bodyLines = body.split('\n');
      final bodyLineEnd = bodyLineStart + bodyLines.length;
      if (bodyLineEnd > lines.length) continue;
      final actual = lines.sublist(bodyLineStart, bodyLineEnd).join('\n');
      if (actual != body) continue;

      // Replace body lines with synthetic fenced block.
      lines.replaceRange(bodyLineStart, bodyLineEnd, [
        '```formfield-$i',
        body,
        '```',
      ]);
    }
    return lines.join('\n');
  }

  // ── List block preprocessing ──

  static final _listItemLinePattern =
      RegExp(r'^[ \t]*(?:[-*+]|\d+\.)[ \t]', multiLine: true);

  /// Scan [processed] for contiguous list blocks and replace each with a
  /// synthetic fenced code block `listblock-N` so the code block builder can
  /// render them as draggable list widgets.
  String _preprocessListBlocks(
    String processed,
    List<String> listBlockContents,
  ) {
    final lines = processed.split('\n');
    final result = StringBuffer();
    var currentBlock = <String>[];
    var inFencedBlock = false;

    void emitBlock() {
      if (currentBlock.isEmpty) return;
      final raw = currentBlock.join('\n');
      final idx = listBlockContents.length;
      listBlockContents.add(raw);
      result.writeln('```listblock-$idx');
      result.writeln(raw);
      result.writeln('```');
      currentBlock = <String>[];
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Track fenced code blocks to avoid matching inside them.
      if (line.trimLeft().startsWith('```')) {
        if (inFencedBlock) {
          inFencedBlock = false;
          result.writeln(line);
          continue;
        }
        // Closing a list block before the code fence.
        emitBlock();
        inFencedBlock = true;
        result.writeln(line);
        continue;
      }
      if (inFencedBlock) {
        result.writeln(line);
        continue;
      }

      final isListItem = _listItemLinePattern.hasMatch(line);
      final isContinuation =
          currentBlock.isNotEmpty &&
          (line.startsWith('  ') || line.startsWith('\t'));
      final isBlankInList = currentBlock.isNotEmpty && line.trim().isEmpty;

      if (isListItem) {
        currentBlock.add(line);
      } else if (isContinuation || isBlankInList) {
        // Continuation or blank line inside a list block — include it, but
        // peek ahead: if the next non-empty line is not a list item, end the
        // block.
        if (isBlankInList) {
          var next = i + 1;
          while (next < lines.length && lines[next].trim().isEmpty) {
            next++;
          }
          if (next < lines.length &&
              _listItemLinePattern.hasMatch(lines[next])) {
            currentBlock.add(line);
          } else {
            emitBlock();
            result.writeln(line);
          }
        } else {
          currentBlock.add(line);
        }
      } else {
        emitBlock();
        result.writeln(line);
      }
    }
    emitBlock();

    return result.toString();
  }

  /// Called when a draggable list block is reordered.
  void _onListReorder(int blockIndex, String newBlock) {
    final source = widget.controller.markdown;
    final blocks = <String>[];
    _preprocessListBlocks(source, blocks);
    if (blockIndex < 0 || blockIndex >= blocks.length) return;

    var searchFrom = 0;
    for (var i = 0; i <= blockIndex; i++) {
      final block = blocks[i];
      final pos = source.indexOf(block, searchFrom);
      final idx = pos >= 0 ? pos : source.indexOf(block);
      if (idx < 0) return;
      if (i == blockIndex) {
        widget.controller.markdown =
            source.substring(0, idx) +
            newBlock +
            source.substring(idx + block.length);
        return;
      }
      searchFrom = idx + block.length;
    }
  }
}

// ── Custom markdown builders ──

/// Data collected during form-section preprocessing.
///
/// One entry per form section whose body text has been replaced with a
/// synthetic `formfield-N` fenced code block.
class _FormSectionData {
  _FormSectionData({
    required this.formType,
    required this.section,
    required this.typeName,
    required this.customTags,
    required this.requiredFields,
    this.textPatternCheck,
  });

  final specs.FormTypeDef formType;
  final MdSection section;
  final String typeName;
  final Map<String, dynamic> customTags;
  final List<String> requiredFields;
  final specs.PatternCheckDef? textPatternCheck;
}

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
    required this.onListReorder,
    required this.formSections,
    required this.editorTheme,
    required this.controller,
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
  final void Function(int blockIndex, String newBlock) onListReorder;
  final List<_FormSectionData> formSections;
  final MdEditorTheme editorTheme;
  final MdEditorController controller;

  String? _language;

  @override
  void visitElementBefore(md.Element element) {
    _language = null;
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
    final blockLanguage = _language;

    // Inline form fields for schema form-type sections.
    if (blockLanguage != null && blockLanguage.startsWith('formfield-')) {
      final formIdx =
          int.tryParse(blockLanguage.substring('formfield-'.length)) ?? 0;
      if (formIdx < formSections.length) {
        final data = formSections[formIdx];
        final currentValues = MdFormEditor.parseFormContent(data.section.text);
        // Detect whether original text uses list-prefix format (e.g., "- Field: value").
        final useListPrefix = data.section.text.trimLeft().startsWith('- ');
        return MdFormEditor(
          formType: data.formType,
          currentValues: currentValues,
          customTags: data.customTags,
          requiredFields: data.requiredFields,
          textPatternCheck: data.textPatternCheck,
          theme: editorTheme,
          useListPrefix: useListPrefix,
          onChanged: (values) {
            final newText = MdFormEditor.serializeFormContent(
              values,
              data.formType,
              useListPrefix: useListPrefix,
            );
            controller.updateSectionText(data.section, newText);
          },
        );
      }
    }

    // Draggable list blocks.
    if (blockLanguage != null && blockLanguage.startsWith('listblock-')) {
      final indexStr = blockLanguage.substring('listblock-'.length);
      final blockIdx = int.tryParse(indexStr) ?? 0;
      final list = contentMap['listblock'];
      final rawBlock =
          (list != null && blockIdx < list.length) ? list[blockIdx] : code;
      return _DraggableListBlock(
        rawContent: rawBlock,
        theme: theme,
        onReorder: (newContent) => onListReorder(blockIdx, newContent),
        onToggleTask: (itemIndex, checked) {
          // Toggle the task item's checked state in the raw block.
          final items = _parseListItems(rawBlock);
          if (itemIndex < 0 || itemIndex >= items.length) return;
          final item = items[itemIndex];
          if (item.checked == null) return;
          final oldMarker = checked ? '- [ ]' : '- [x]';
          final newMarker = checked ? '- [x]' : '- [ ]';
          final newLine = item.rawLine.replaceFirst(oldMarker, newMarker);
          final newLines = items.map((it) {
            return it == item ? newLine : it.rawLine;
          }).join('\n');
          onListReorder(blockIdx, newLines);
        },
      );
    }

    // Check if any plugin handles this language.
    if (blockLanguage != null) {
      final plugin = pluginRegistry.forLanguage(blockLanguage);
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
                final indexStr = blockLanguage.startsWith(expectedStart)
                  ? blockLanguage.substring(expectedStart.length)
                  : null;
              final idx = indexStr != null ? int.tryParse(indexStr) : null;
              final list = contentMap[prefix];
              rawOriginal =
                  (idx != null && list != null && idx < list.length)
                      ? list[idx]
                      : code;
            } else {
              // Native fenced block — construct the search string.
              rawOriginal = '```$blockLanguage\n$code\n```';
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
      language: blockLanguage,
      theme: theme,
      enableSyntaxHighlighting: settings.enableSyntaxHighlighting,
      showLanguage: settings.showCodeBlockLanguage,
      showCopy: settings.showCopyCodeButton,
      showEdit: settings.showCodeEditButton,
      onCopy: () => onCopy(code),
      onEdit: () => onDefaultEdit(code, blockLanguage),
    );
  }
}

class _CodeBlockWidget extends StatefulWidget {
  const _CodeBlockWidget({
    required this.code,
    this.language,
    required this.theme,
    this.enableSyntaxHighlighting = true,
    this.showLanguage = true,
    this.showCopy = true,
    this.showEdit = true,
    this.onCopy,
    this.onEdit,
  });

  final String code;
  final String? language;
  final MdBasicTheme theme;
  final bool enableSyntaxHighlighting;
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

  Widget _buildCodeText() {
    final normalizedLanguage = MdCodeHighlighting.normalizeLanguage(
      widget.language,
    );
    if (!widget.enableSyntaxHighlighting || normalizedLanguage == null) {
      return SelectableText(
        widget.code,
        style: widget.theme.codeStyle,
      );
    }

    final syntaxTheme = MdCodeHighlighting.buildTheme(widget.theme);

    try {
      return HighlightView(
        widget.code,
        language: normalizedLanguage,
        theme: syntaxTheme,
        padding: EdgeInsets.zero,
        textStyle: widget.theme.codeStyle,
      );
    } catch (_) {
      // Graceful fallback when a language key is unknown.
      return SelectableText(
        widget.code,
        style: widget.theme.codeStyle,
      );
    }
  }

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
                  if (widget.showLanguage &&
                      MdCodeHighlighting.normalizeLanguage(widget.language) !=
                          null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        MdCodeHighlighting.normalizeLanguage(widget.language)!,
                        style: TextStyle(
                          color: widget.theme.textMuted,
                          fontSize: 11,
                          fontFamily: widget.theme.monoFontFamily,
                        ),
                      ),
                    ),
                  _buildCodeText(),
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
    required this.controller,
    required this.readOnly,
    required this.onTap,
    required this.onEdit,
    required this.onContextMenu,
    required this.getValidationErrors,
  });

  final int level;
  final MdBasicTheme theme;
  final MdEditorController controller;
  final bool readOnly;
  final void Function(int level, String text) onTap;
  final void Function(int level, String text) onEdit;
  final void Function(Offset position, int level, String text) onContextMenu;
  final List<ValidationError> Function(MdSection section) getValidationErrors;

  /// Per-build ordinal counter to disambiguate headings with identical text.
  int _ordinal = 0;

  /// Regex to strip ALL HTML comments from rendered heading text.
  static final _htmlCommentRegex = RegExp(r'<!--[\s\S]*?-->');

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    // Return a non-null widget so flutter_markdown's _inlines list
    // has non-empty children and gets cleared after the heading block ends.
    // Without this, the heading's parent inline (with heading size/weight)
    // leaks into the next paragraph's text rendering.
    return const SizedBox.shrink();
  }

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // Strip any HTML comments from the rendered text for matching purposes.
    final rawText = element.textContent.trim();
    final strippedText = rawText.replaceAll(_htmlCommentRegex, '').trim();

    // Find the matching section in the document model.
    // Try exact match first, then fall back to contains-based matching.
    final sections = controller.document.allSections;
    final exactMatch = sections
        .where((s) => s.level == level && s.headline.trim() == strippedText)
        .toList();
    MdSection? section;
    if (exactMatch.isNotEmpty) {
      section = exactMatch.first;
    } else if (strippedText.isNotEmpty) {
      // Fallback: section headline is contained in the stripped text or vice versa.
      final fallback = sections.where((s) =>
          s.level == level &&
          (strippedText.contains(s.headline.trim()) ||
              s.headline.trim().contains(strippedText)));
      section = fallback.isNotEmpty ? fallback.first : null;
    }

    // Use section data for all display, keys, and callbacks.
    final headline = section?.headline ?? strippedText;
    final number =
        section != null ? controller.computeSectionNumber(section) : '';
    final sectionId = section?.id;

    final headingStyle = preferredStyle ?? theme.headingStyle(level);
    final currentOrdinal = _ordinal++;
    final headingKey = ValueKey('$level:$currentOrdinal:${headline.trim()}');
    final commentMeta = section?.commentMetadata ?? const {};

    // Use ValueKey (not GlobalKey) to avoid duplicate-key crashes
    // during MarkdownBody rebuilds. Scroll-to uses tree traversal.
    return KeyedSubtree(
      key: headingKey,
      child: SelectionContainer.disabled(
        child: GestureDetector(
          onTap: () => onTap(level, headline),
          onSecondaryTapDown: readOnly
              ? null
              : (details) => onContextMenu(
                    details.globalPosition,
                    level,
                    headline,
                  ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Heading row: number + headline + [id] + edit ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (number.isNotEmpty)
                              TextSpan(
                                text: '$number ',
                                style: headingStyle,
                              ),
                            TextSpan(
                              text: headline,
                              style: headingStyle,
                            ),
                            // Section ID shown in square brackets after headline
                            if (sectionId != null && sectionId.isNotEmpty)
                              TextSpan(
                                text: ' [$sectionId]',
                                style: headingStyle.copyWith(
                                  color: theme.textMuted,
                                  fontSize: (headingStyle.fontSize ?? 16) * 0.7,
                                  fontFamily: 'monospace',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Validation error indicator
                    if (section != null)
                      ..._buildValidationIndicator(section),
                    if (!readOnly)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: InkWell(
                          onTap: () => onEdit(level, headline),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: theme.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                // ── Comment metadata chips row ──
                if (commentMeta.isNotEmpty && section != null)
                  _buildMetadataRow(section, commentMeta, headline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the metadata row with tags rendered specially.
  Widget _buildMetadataRow(
    MdSection section,
    Map<String, String> commentMeta,
    String headline,
  ) {
    // Separate tags from other metadata.
    final tagsStr = commentMeta['tags'] ?? '';
    final tags = tagsStr.isNotEmpty
        ? tagsStr.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];
    final otherMeta = Map<String, String>.from(commentMeta)..remove('tags');

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tags chips (clickable to edit section including tags)
          if (tags.isNotEmpty)
            GestureDetector(
              onTap: readOnly ? null : () => onEdit(level, headline),
              child: MouseRegion(
                cursor: readOnly ? SystemMouseCursors.basic : SystemMouseCursors.click,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label, size: 12, color: theme.textMuted),
                    const SizedBox(width: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tags.map((tag) {
                        final color = _tagColor(tag);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: color.withAlpha(100), width: 1.0),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          // Other metadata (clickable to edit section)
          if (otherMeta.isNotEmpty)
            Flexible(
              child: GestureDetector(
                onTap: readOnly ? null : () => onEdit(level, headline),
                child: MouseRegion(
                  cursor: readOnly ? SystemMouseCursors.basic : SystemMouseCursors.click,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: otherMeta.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.accent.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: theme.accent.withAlpha(60), width: 0.5),
                        ),
                        child: Text(
                          '${e.key}: ${e.value}',
                          style: TextStyle(fontSize: 10, color: theme.textSecondary, fontFamily: 'monospace'),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Get semantic color for a tag based on its name.
  Color _tagColor(String tag) {
    final lower = tag.toLowerCase();
    if (lower == 'critical' || lower == 'error') return Colors.red;
    if (lower == 'high' || lower == 'warning') return Colors.orange;
    if (lower == 'medium' || lower == 'info') return Colors.blue;
    if (lower == 'low' || lower == 'minor') return Colors.green;
    return theme.accent;
  }

  /// Build validation error indicators for a section heading.
  List<Widget> _buildValidationIndicator(MdSection section) {
    final errors = getValidationErrors(section);
    if (errors.isEmpty) return const [];

    final worstSeverity = errors.fold<ValidationSeverity>(
      ValidationSeverity.info,
      (worst, error) =>
          error.severity.index < worst.index ? error.severity : worst,
    );

    final (icon, color) = switch (worstSeverity) {
      ValidationSeverity.error => (Icons.error, Colors.red[700]!),
      ValidationSeverity.warning => (Icons.warning_amber, Colors.orange[700]!),
      ValidationSeverity.info => (Icons.info_outline, theme.accent),
    };

    final tooltip = errors.map((e) => e.message).join('\n');

    return [
      Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    ];
  }
}

// ── Draggable list block ──

/// Parsed representation of a single list item.
class _ListItem {
  _ListItem({
    required this.rawLine,
    required this.text,
    required this.marker,
    required this.indent,
    this.checked,
  });

  /// The complete raw markdown line(s).
  final String rawLine;

  /// Visible text content (after marker).
  final String text;

  /// The marker string, e.g. `- `, `* `, `1. `, `- [ ] `.
  final String marker;

  /// Leading whitespace count.
  final int indent;

  /// For task items: `true` = checked, `false` = unchecked, `null` = not task.
  final bool? checked;
}

/// Regex that captures the components of a list item line:
/// group 1 = leading whitespace, group 2 = marker, group 3 = text.
/// Task list pattern must come first to avoid `[-*+]` consuming `- [`.
final _listItemRegex = RegExp(
  r'^([ \t]*)(- \[[xX ]\][ \t]+|[-*+][ \t]+|\d+\.[ \t]+)(.*)',
);

List<_ListItem> _parseListItems(String rawContent) {
  final items = <_ListItem>[];
  final lines = rawContent.split('\n');
  _ListItem? current;

  for (final line in lines) {
    final match = _listItemRegex.firstMatch(line);
    if (match != null) {
      // Start a new item.
      final indent = match.group(1)!;
      final marker = match.group(2)!;
      final text = match.group(3)!;
      bool? checked;
      if (marker.contains('[x]') || marker.contains('[X]')) {
        checked = true;
      } else if (marker.contains('[ ]')) {
        checked = false;
      }
      current = _ListItem(
        rawLine: line,
        text: text,
        marker: marker.trimRight(),
        indent: indent.length,
        checked: checked,
      );
      items.add(current);
    } else if (current != null && line.trim().isNotEmpty) {
      // Continuation line — merge into current item, preserving newlines
      // so multi-line content renders as separate lines.
      items[items.length - 1] = _ListItem(
        rawLine: '${current.rawLine}\n$line',
        text: '${current.text}\n${line.trim()}',
        marker: current.marker,
        indent: current.indent,
        checked: current.checked,
      );
      current = items.last;
    }
    // Blank lines are ignored (kept in rawLine of their owning item if
    // needed in future).
  }
  return items;
}

/// Renders a contiguous list block with drag handles for reordering items.
class _DraggableListBlock extends StatefulWidget {
  const _DraggableListBlock({
    required this.rawContent,
    required this.theme,
    required this.onReorder,
    this.onToggleTask,
  });

  final String rawContent;
  final MdBasicTheme theme;
  final ValueChanged<String> onReorder;
  /// Called when a task checkbox is tapped: (itemIndex, newChecked).
  final void Function(int itemIndex, bool newChecked)? onToggleTask;

  @override
  State<_DraggableListBlock> createState() => _DraggableListBlockState();
}

class _DraggableListBlockState extends State<_DraggableListBlock> {
  late List<_ListItem> _items;
  int _draggingIndex = -1;
  int _dropTargetIndex = -1;
  int _expandedIndex = -1;

  @override
  void initState() {
    super.initState();
    _items = _parseListItems(widget.rawContent);
  }

  @override
  void didUpdateWidget(_DraggableListBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawContent != widget.rawContent) {
      _items = _parseListItems(widget.rawContent);
    }
  }

  void _onReorder(int from, int to) {
    final item = _items.removeAt(from);
    _items.insert(to, item);
    final newContent = _items.map((i) => i.rawLine).join('\n');
    widget.onReorder(newContent);
  }

  /// Change indent level of item at [index] by [delta] steps (±1).
  /// Each indent step is 2 spaces in the raw markdown.
  void _changeIndent(int index, int delta) {
    final item = _items[index];
    final newIndent = (item.indent + delta * 2).clamp(0, 16);
    if (newIndent == item.indent) return;
    final spaces = ' ' * newIndent;
    // Rebuild rawLine: for multi-line items only adjust the first line's
    // leading whitespace; continuation lines stay as-is.
    final rawLines = item.rawLine.split('\n');
    final firstLine = rawLines.first.trimLeft();
    rawLines[0] = '$spaces$firstLine';
    final newRaw = rawLines.join('\n');
    _items[index] = _ListItem(
      rawLine: newRaw,
      text: item.text,
      marker: item.marker,
      indent: newIndent,
      checked: item.checked,
    );
    final newContent = _items.map((i) => i.rawLine).join('\n');
    widget.onReorder(newContent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_items.isEmpty) return const SizedBox.shrink();

    return SelectionContainer.disabled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isDragged = _draggingIndex == i;
          final isTargetAbove =
              _dropTargetIndex == i && _draggingIndex > i;
          final isTargetBelow =
              _dropTargetIndex == i && _draggingIndex < i;

          return DragTarget<int>(
            onWillAcceptWithDetails: (details) {
              if (details.data != i) {
                setState(() => _dropTargetIndex = i);
              }
              return details.data != i;
            },
            onLeave: (_) {
              if (_dropTargetIndex == i) {
                setState(() => _dropTargetIndex = -1);
              }
            },
            onAcceptWithDetails: (details) {
              final from = details.data;
              final to = _draggingIndex > i ? i : i;
              setState(() {
                _dropTargetIndex = -1;
                _draggingIndex = -1;
              });
              _onReorder(from, to);
            },
            builder: (context, candidateData, rejectedData) {
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: isTargetAbove
                        ? BorderSide(color: theme.accent, width: 2)
                        : BorderSide.none,
                    bottom: isTargetBelow
                        ? BorderSide(color: theme.accent, width: 2)
                        : BorderSide.none,
                  ),
                ),
                child: Opacity(
                  opacity: isDragged ? 0.35 : 1.0,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: item.indent.toDouble() * 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Drag handle + tap-revealed indent buttons.
                        TapRegion(
                          onTapOutside: (_) {
                            if (_expandedIndex == i) {
                              setState(() => _expandedIndex = -1);
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LongPressDraggable<int>(
                                data: i,
                                delay:
                                    const Duration(milliseconds: 150),
                                onDragStarted: () =>
                                    setState(() => _draggingIndex = i),
                                onDragEnd: (_) => setState(() {
                                  _draggingIndex = -1;
                                  _dropTargetIndex = -1;
                                }),
                                onDraggableCanceled:
                                    (velocity, offset) =>
                                        setState(() {
                                  _draggingIndex = -1;
                                  _dropTargetIndex = -1;
                                }),
                                feedback: Material(
                                  elevation: 4,
                                  borderRadius:
                                      BorderRadius.circular(4),
                                  color: theme.surface,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(
                                        maxWidth: 300,
                                      ),
                                      child: Text(
                                        '${_bulletDisplay(item)} ${item.text}',
                                        style: TextStyle(
                                          color: theme.text,
                                          fontSize:
                                              theme.baseFontSize,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _expandedIndex =
                                        _expandedIndex == i ? -1 : i;
                                  }),
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.grab,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(
                                        right: 2,
                                        top: 2,
                                      ),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        size: 16,
                                        color: theme.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_expandedIndex == i) ...[
                                if (item.indent > 0)
                                  _indentButton(
                                    icon: Icons.chevron_left,
                                    theme: theme,
                                    onTap: () =>
                                        _changeIndent(i, -1),
                                  ),
                                _indentButton(
                                  icon: Icons.chevron_right,
                                  theme: theme,
                                  onTap: () =>
                                      _changeIndent(i, 1),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Bullet / checkbox.
                        Padding(
                          padding: const EdgeInsets.only(right: 6, top: 2),
                          child: _buildBullet(item, theme, i),
                        ),
                        // Text content — rendered through MarkdownBody
                        // so inline formatting (bold, italic, code, links)
                        // is properly displayed.
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 2,
                            ),
                            child: MarkdownBody(
                              data: item.text,
                              shrinkWrap: true,
                              softLineBreak: true,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  color: theme.text,
                                  fontSize: theme.baseFontSize,
                                  height: theme.lineHeight,
                                  decoration: item.checked == true
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: theme.textMuted,
                                ),
                                strong: TextStyle(
                                  color: theme.text,
                                  fontSize: theme.baseFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                                em: TextStyle(
                                  color: theme.text,
                                  fontSize: theme.baseFontSize,
                                  fontStyle: FontStyle.italic,
                                ),
                                code: theme.inlineCodeStyle,
                                a: TextStyle(
                                  color: theme.linkColor,
                                  decoration: theme.linkDecoration,
                                ),
                                blockSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  String _bulletDisplay(_ListItem item) {
    if (item.checked != null) return item.checked! ? '☑' : '☐';
    final m = item.marker.trim();
    if (m == '-' || m == '*' || m == '+') return '•';
    // Ordered list — return the number.
    return m;
  }

  Widget _indentButton({
    required IconData icon,
    required MdBasicTheme theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: theme.textMuted),
        ),
      ),
    );
  }

  Widget _buildBullet(_ListItem item, MdBasicTheme theme, int index) {
    if (item.checked != null) {
      return GestureDetector(
        onTap: () => widget.onToggleTask?.call(index, !item.checked!),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Icon(
            item.checked! ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: item.checked! ? theme.success : theme.textMuted,
          ),
        ),
      );
    }
    final m = item.marker.trim();
    final isOrdered = RegExp(r'^\d+\.$').hasMatch(m);
    return Text(
      isOrdered ? m : '•',
      style: TextStyle(
        color: theme.textMuted,
        fontSize: theme.baseFontSize,
        fontWeight: isOrdered ? FontWeight.w500 : FontWeight.bold,
      ),
    );
  }
}
