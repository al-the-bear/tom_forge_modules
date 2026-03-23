import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;
import 'package:tom_editors_shared/tom_editors_shared.dart';

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
import '../schema/md_tag_selector.dart';
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
  /// Key for the markdown content subtree, used to traverse heading elements
  /// from the context menu builder (which runs in an overlay context).
  final _markdownBodyKey = GlobalKey();
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
      final targetKey = ValueKey(_headingKeyFor(section.level, section.headline));
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

  String _headingKeyFor(int level, String headline) =>
      '$level:${headline.trim()}';

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

    // Tag selector (P3.2).
    // Tag selector (P3.2) — moved to inline preview rendering.
    // See _preprocessTagComments() and _CodeBlockBuilder.

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

      // Replace <!-- tags: ... --> comments with synthetic fenced blocks
      // so they render as interactive tag chips in the preview.
      final tagChipSections = <_TagChipData>[];
      processed = _preprocessTagComments(processed, tagChipSections);

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
              child: KeyedSubtree(
              key: _markdownBodyKey,
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
                  tagChipSections: tagChipSections,
                  editorTheme: widget.theme,
                  controller: widget.controller,
                  onTagEdit: _showTagEditorPopup,
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
        // For fenced blocks, the constructed rawOriginal may have whitespace
        // differences vs the actual source. Use regex to find the block.
        final escaped = RegExp.escape(editableContent.trim());
        final lang = plugin.languages.isNotEmpty ? plugin.languages.first : '';
        if (lang.isNotEmpty) {
          final pattern = RegExp(
            '```$lang\\s*\\n\\s*$escaped\\s*\\n\\s*```',
            dotAll: true,
          );
          final match = pattern.firstMatch(source);
          if (match != null) {
            widget.controller.markdown = source.replaceFirst(
              match.group(0)!,
              newMarkdown,
            );
          }
        }
      }
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

        // Fallback for whitespace variations in fenced blocks.
        final escaped = RegExp.escape(code.trim());
        final langPart = currentLanguage == null
            ? r'[ \t]*'
            : '${RegExp.escape(currentLanguage)}[ \\t]*';
        final pattern = RegExp(
          '```$langPart\\n\\s*$escaped\\s*\\n```',
          dotAll: true,
        );
        final match = pattern.firstMatch(source);
        if (match != null) {
          widget.controller.markdown = source.replaceFirst(match.group(0)!, newFence);
        }
      } catch (e, st) {
        MdEditorDebug.logger.error('Error opening code editor', e, st);
      }
    }();
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
  void _onHeadingEdit(int level, String text) {
    try {
      final sections = widget.controller.document.allSections;
      final match = sections.where(
        (s) => s.level == level && s.headline.trim() == text.trim(),
      );
      if (match.isEmpty) return;
      final section = match.first;
      final headlineController = TextEditingController(text: section.headline);
      final idController = TextEditingController(text: section.id ?? '');

      // Collect prefix suggestions from schema section types.
      final schema = widget.controller.schema;
      final prefixSuggestions = <String>[];
      String? patternHint;
      List<String> schemaFields = const [];
      if (schema != null) {
        for (final entry in schema.sectionTypes.entries) {
          final prefix = entry.value.prefix;
          if (prefix != null && prefix.isNotEmpty) {
            prefixSuggestions.add(prefix);
          }
        }
        // Resolve current type for pattern hint and required fields.
        final schemaHelper = widget.controller.schemaHelper;
        if (schemaHelper != null) {
          final typeName = schemaHelper.getSectionTypeName(
            section,
            document: widget.controller.document,
          );
          if (typeName != null) {
            final tmpl = SchemaTemplateHelper(schema);
            patternHint = tmpl.getIdPattern(typeName);
            schemaFields = tmpl.getRequiredFields(typeName);
          }
        }
      }

      // Build metadata controllers from existing values + schema required fields.
      final existingMeta = Map<String, String>.from(section.commentMetadata);
      final allKeys = <String>{...existingMeta.keys, ...schemaFields};
      final metaControllers = <String, TextEditingController>{};
      for (final key in allKeys) {
        metaControllers[key] =
            TextEditingController(text: existingMeta[key] ?? '');
      }

      showDialog<bool>(
        context: context,
        builder: (ctx) => EditSectionDialog(
          headlineController: headlineController,
          idController: idController,
          metaControllers: metaControllers,
          prefixSuggestions: prefixSuggestions,
          patternHint: patternHint,
          schemaFields: schemaFields,
        ),
      ).then((confirmed) {
        if (confirmed != true) {
          headlineController.dispose();
          idController.dispose();
          for (final c in metaControllers.values) {
            c.dispose();
          }
          return;
        }
        final newHeadline = headlineController.text.trim();
        final newId = idController.text.trim();
        headlineController.dispose();
        idController.dispose();
        if (newHeadline.isNotEmpty && newHeadline != section.headline) {
          widget.controller.updateSectionHeadline(section, newHeadline);
        }
        final effectiveId = newId.isEmpty ? null : newId;
        if (effectiveId != section.id) {
          widget.controller.updateSectionId(section, effectiveId);
        }
        // Collect updated metadata, dropping empty values.
        final newMeta = <String, String>{};
        for (final entry in metaControllers.entries) {
          final value = entry.value.text.trim();
          if (value.isNotEmpty) {
            newMeta[entry.key] = value;
          }
          entry.value.dispose();
        }
        if (!_mapEquals(newMeta, section.commentMetadata)) {
          widget.controller.updateCommentMetadata(section, newMeta);
        }
      });
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

    // Determine which section was right-clicked using the anchor position.
    final anchors = selectableRegionState.contextMenuAnchors;
    final clickPosition = anchors.primaryAnchor;
    final section = _findSectionAtPosition(clickPosition);

    // Build tag insertion item if the section supports tags.
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
      final existingTags = MdTagSelector.parseTags(section.text);
      if (allowedTags.isNotEmpty || existingTags.isNotEmpty) {
        tagItems.add(ContextMenuButtonItem(
          label: existingTags.isNotEmpty ? 'Edit Tags' : 'Insert Tags',
          onPressed: () {
            ContextMenuController.removeAny();
            _onInsertOrEditTags(section);
          },
        ));
      }
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: [...standardItems, ...tagItems],
    );
  }

  /// Find the section whose heading is closest above [globalPosition].
  MdSection? _findSectionAtPosition(Offset globalPosition) {
    final allSections = widget.controller.document.allSections;
    MdSection? bestMatch;
    double bestY = double.negativeInfinity;

    void searchElement(Element element) {
      final key = element.widget.key;
      if (key is ValueKey<String>) {
        final keyStr = key.value;
        // Heading keys are formatted as '$level:$headline'.
        final colonIdx = keyStr.indexOf(':');
        if (colonIdx > 0) {
          final level = int.tryParse(keyStr.substring(0, colonIdx));
          if (level != null) {
            final renderBox = element.findRenderObject();
            if (renderBox is RenderBox && renderBox.hasSize) {
              final pos = renderBox.localToGlobal(Offset.zero);
              if (pos.dy <= globalPosition.dy && pos.dy > bestY) {
                bestY = pos.dy;
                final headline = keyStr.substring(colonIdx + 1);
                final match = allSections.where(
                  (s) =>
                      s.level == level && s.headline.trim() == headline,
                );
                if (match.isNotEmpty) bestMatch = match.first;
              }
            }
          }
        }
      }
      element.visitChildren(searchElement);
    }

    final element = _markdownBodyKey.currentContext;
    if (element != null) {
      element.visitChildElements(searchElement);
    }
    return bestMatch;
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

  /// Insert a new `<!-- tags: -->` comment or open the tag editor for an
  /// existing one.
  void _onInsertOrEditTags(MdSection section) {
    final existingTags = MdTagSelector.parseTags(section.text);

    // Look up allowed-tags from schema.
    var allowedTags = <String>[];
    final schema = widget.controller.schema;
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

    if (existingTags.isEmpty && allowedTags.isEmpty) {
      // No schema tags and none existing — insert a blank tag comment
      // placeholder so the user can see it in the raw editor.
      final trimmed = section.text.trimRight();
      widget.controller.updateSectionText(
        section,
        '$trimmed\n\n<!-- tags: -->',
      );
      return;
    }

    _showTagEditorPopup(_TagChipData(
      section: section,
      selectedTags: existingTags,
      allowedTags: allowedTags,
    ));
  }

  /// Show a popup dialog to edit tags for a section.
  void _showTagEditorPopup(_TagChipData data) {
    final section = data.section;
    var selectedTags = List<String>.from(data.selectedTags);
    final allowedTags = data.allowedTags;
    final newTagController = TextEditingController();

    showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final theme = widget.theme.basic;
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.label, size: 18, color: theme.accent),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Edit Tags')),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (allowedTags.isNotEmpty) ...[
                      Text(
                        'Allowed tags:',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: allowedTags.map((tag) {
                          final isSelected = selectedTags.contains(tag);
                          return FilterChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedTags.add(tag);
                                } else {
                                  selectedTags.remove(tag);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Show current custom tags (not in allowedTags).
                    if (selectedTags
                        .where((t) => !allowedTags.contains(t))
                        .isNotEmpty) ...[
                      Text(
                        'Custom tags:',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: selectedTags
                            .where((t) => !allowedTags.contains(t))
                            .map((tag) {
                          return Chip(
                            label: Text(tag),
                            onDeleted: () {
                              setDialogState(() {
                                selectedTags.remove(tag);
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Text field to add new tags.
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newTagController,
                            decoration: const InputDecoration(
                              hintText: 'Add tag...',
                              isDense: true,
                            ),
                            onSubmitted: (value) {
                              final tag = value.trim();
                              if (tag.isNotEmpty &&
                                  !selectedTags.contains(tag)) {
                                setDialogState(() {
                                  selectedTags.add(tag);
                                  newTagController.clear();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () {
                            final tag = newTagController.text.trim();
                            if (tag.isNotEmpty &&
                                !selectedTags.contains(tag)) {
                              setDialogState(() {
                                selectedTags.add(tag);
                                newTagController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selectedTags),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result == null) return;
      // Re-link section in case document was re-parsed while dialog was open.
      final doc = widget.controller.document;
      final current = doc.allSections
          .where(
            (s) => s.headline == section.headline && s.level == section.level,
          )
          .firstOrNull;
      final target = current ?? section;
      final newText = MdTagSelector.updateTags(target.text, result);
      widget.controller.updateSectionText(target, newText);
    });
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

  // ── Tag comment preprocessing ──

  static final _tagCommentPattern =
      RegExp(r'<!--\s*tags:\s*(.+?)\s*-->', multiLine: true);

  /// Replace `<!-- tags: tag1, tag2 -->` HTML comments with synthetic fenced
  /// blocks so they render as inline tag chips in the preview.
  ///
  /// Uses a two-pass approach: forward pass identifies tag comments (skipping
  /// those inside code blocks) and finds owner sections via text matching;
  /// backward pass replaces lines without index shifting.
  String _preprocessTagComments(
    String markdown,
    List<_TagChipData> tagChipSections,
  ) {
    final schema = widget.controller.schema;
    final doc = widget.controller.document;
    final helper = schema != null ? SchemaSectionHelper(schema) : null;
    final tmpl = schema != null ? SchemaTemplateHelper(schema) : null;
    final allSections = doc.allSections;

    final lines = markdown.split('\n');

    // Forward pass: find tag comments, skipping those inside code blocks.
    // Track owner sections via text content matching (robust against line
    // shifts from prior preprocessing like form sections).
    final entries = <({int line, String tagsStr, String tagComment})>[];
    var inCodeBlock = false;
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }
      if (inCodeBlock) continue;

      final match = _tagCommentPattern.firstMatch(lines[i]);
      if (match == null) continue;
      entries.add((
        line: i,
        tagsStr: match.group(1)!,
        tagComment: match.group(0)!,
      ));
    }

    if (entries.isEmpty) return markdown;

    // Match each tag comment to its owner section by text content.
    final claimedIndices = <int>{};
    final entryData = <({int line, String tagsStr, MdSection? owner})>[];
    for (final e in entries) {
      MdSection? owner;
      for (var j = 0; j < allSections.length; j++) {
        if (claimedIndices.contains(j)) continue;
        if (allSections[j].text.contains(e.tagComment)) {
          owner = allSections[j];
          claimedIndices.add(j);
          break;
        }
      }
      entryData.add((line: e.line, tagsStr: e.tagsStr, owner: owner));
    }

    // Backward pass: replace tag comment lines with synthetic fenced blocks.
    for (var k = entryData.length - 1; k >= 0; k--) {
      final e = entryData[k];
      final selectedTags = e.tagsStr
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      var allowedTags = <String>[];
      if (e.owner != null && helper != null && tmpl != null) {
        final typeName = helper.getSectionTypeName(
          e.owner!,
          document: doc,
        );
        if (typeName != null) {
          allowedTags = tmpl.getAllowedTags(typeName);
        }
      }

      final idx = tagChipSections.length;
      tagChipSections.add(_TagChipData(
        section: e.owner ?? doc.sections.first,
        selectedTags: selectedTags,
        allowedTags: allowedTags,
      ));

      lines.replaceRange(e.line, e.line + 1, [
        '```tagchips-$idx',
        e.tagsStr,
        '```',
      ]);
    }

    return lines.join('\n');
  }

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

/// Data for a tag comment found in section body text.
class _TagChipData {
  _TagChipData({
    required this.section,
    required this.selectedTags,
    required this.allowedTags,
  });

  final MdSection section;
  final List<String> selectedTags;
  final List<String> allowedTags;
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
    required this.tagChipSections,
    required this.editorTheme,
    required this.controller,
    required this.onTagEdit,
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
  final List<_TagChipData> tagChipSections;
  final MdEditorTheme editorTheme;
  final MdEditorController controller;
  final void Function(_TagChipData data) onTagEdit;

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
        return MdFormEditor(
          formType: data.formType,
          currentValues: currentValues,
          customTags: data.customTags,
          requiredFields: data.requiredFields,
          textPatternCheck: data.textPatternCheck,
          theme: editorTheme,
          onChanged: (values) {
            final newText = MdFormEditor.serializeFormContent(
              values,
              data.formType,
            );
            controller.updateSectionText(data.section, newText);
          },
        );
      }
    }

    // Inline tag chips for <!-- tags: ... --> comments.
    if (blockLanguage != null && blockLanguage.startsWith('tagchips-')) {
      final tagIdx =
          int.tryParse(blockLanguage.substring('tagchips-'.length)) ?? 0;
      if (tagIdx < tagChipSections.length) {
        final data = tagChipSections[tagIdx];
        return _InlineTagChips(
          data: data,
          theme: editorTheme,
          onTap: () => onTagEdit(data),
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
    final headingKey = ValueKey('$level:${headline.trim()}');
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
                if (commentMeta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: GestureDetector(
                      onTap: readOnly
                          ? null
                          : () => onEdit(level, headline),
                      child: MouseRegion(
                        cursor: readOnly
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: commentMeta.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.accent.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: theme.accent.withAlpha(60),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                '${e.key}: ${e.value}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.textSecondary,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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

// ── Inline tag chips widget ──

/// Renders tag chips inline in the preview at the position where a
/// `<!-- tags: ... -->` comment was in the source markdown.
class _InlineTagChips extends StatelessWidget {
  const _InlineTagChips({
    required this.data,
    required this.theme,
    required this.onTap,
  });

  final _TagChipData data;
  final MdEditorTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final basic = theme.basic;
    final tags = data.selectedTags;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label, size: 14, color: basic.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tags.isEmpty
                      ? [
                          Text(
                            'Click to add tags',
                            style: TextStyle(
                              color: basic.textMuted,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ]
                      : tags.map((tag) {
                          final color = _tagColor(tag, basic);
                          final isAllowed = data.allowedTags.isEmpty ||
                              data.allowedTags.contains(tag);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.withAlpha(120),
                                width: isAllowed ? 1.0 : 0.5,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _tagColor(String tag, MdBasicTheme basic) {
    final lower = tag.toLowerCase();
    if (lower == 'critical' || lower == 'error') return Colors.red;
    if (lower == 'high' || lower == 'warning') return Colors.orange;
    if (lower == 'medium' || lower == 'info') return Colors.blue;
    if (lower == 'low' || lower == 'minor') return Colors.green;
    return basic.accent;
  }
}
