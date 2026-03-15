import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../controller/md_editor_controller.dart';
import '../debug/md_editor_debug.dart';
import '../events/md_events.dart';
import '../models/md_section.dart';
import '../providers/md_document_provider.dart';
import '../registries/md_code_editor_registry.dart';
import '../registries/md_content_renderer.dart';
import '../registries/md_language_renderer_registry.dart';
import '../settings/md_editor_settings.dart';
import '../theme/md_editor_theme.dart';
import 'preview/md_preview_panel.dart';
import 'raw_editor/md_raw_text_editor.dart';
import 'status_bar/md_editor_status_bar.dart';
import 'toolbar/md_editor_toolbar.dart';
import 'tree/md_search_panel.dart';
import 'tree/md_tree_view.dart';

/// The primary markdown editor widget providing tree navigation,
/// formatted preview, and raw text editing in a configurable layout.
///
/// Minimal usage with just content:
/// ```dart
/// MdEditor(markdown: '# Hello World')
/// ```
///
/// Full usage with controller and registries:
/// ```dart
/// MdEditor(
///   controller: myController,
///   theme: MdEditorTheme.dark(),
///   settings: MdEditorSettings.standard(),
///   onChanged: (md) => print('Changed'),
/// )
/// ```
class MdEditor extends StatefulWidget {
  const MdEditor({
    super.key,
    this.markdown,
    this.controller,
    this.theme,
    this.settings,
    this.eventHandlers,
    this.onSectionSelected,
    this.onLinkTap,
    this.onSave,
    this.onChanged,
    this.onValidationChanged,
    this.documentProvider,
    this.readOnly = false,
    this.autofocus = false,
    this.autoSave = false,
    this.autoSaveDebounce = const Duration(seconds: 2),
    this.schemaId,
    this.codeEditorRegistry,
    this.languageRenderers,
    this.contentRenderers,
  }) : assert(
         markdown == null || controller == null,
         'Provide either markdown or controller, not both.',
       );

  /// Direct markdown content source. Creates an internal controller.
  final String? markdown;

  /// Controller managing document state. If null, one is created internally.
  final MdEditorController? controller;

  /// Visual theme. Defaults to [MdEditorTheme.dark].
  final MdEditorTheme? theme;

  /// Editor behaviour settings. Defaults to [MdEditorSettings.standard].
  final MdEditorSettings? settings;

  /// Before/after event handlers for document operations.
  final MdEditorEventHandlers? eventHandlers;

  /// Called when a section is selected in the tree or preview.
  final ValueChanged<MdSection>? onSectionSelected;

  /// Called when a link is tapped in the preview.
  final ValueChanged<String>? onLinkTap;

  /// Called when save is triggered (Ctrl+S / Cmd+S).
  final VoidCallback? onSave;

  /// Called when markdown content changes.
  final ValueChanged<String>? onChanged;

  /// Called when validation errors change.
  final ValueChanged<List<ValidationError>>? onValidationChanged;

  /// Optional document source for load/save operations.
  final MdDocumentProvider? documentProvider;

  /// Direct read-only flag. Overrides settings if `true`.
  final bool readOnly;

  /// Auto-focus the editor on mount.
  final bool autofocus;

  /// Auto-save to provider on content change.
  final bool autoSave;

  /// Debounce duration for auto-save.
  final Duration autoSaveDebounce;

  /// Schema ID for validation.
  final String? schemaId;

  /// Registry of custom code editors by language.
  final MdCodeEditorRegistry? codeEditorRegistry;

  /// Registry of custom language renderers for code blocks.
  final MdLanguageRendererRegistry? languageRenderers;

  /// Custom content renderers for special block types.
  final List<MdContentRenderer>? contentRenderers;

  @override
  State<MdEditor> createState() => _MdEditorState();
}

class _MdEditorState extends State<MdEditor> {
  late MdEditorTheme _theme;
  late MdEditorSettings _settings;
  bool _showSearch = false;
  late RawEditorPosition _rawPosition;

  MdEditorController? _internalController;
  Timer? _autoSaveTimer;

  MdEditorController get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme ?? MdEditorTheme.dark();
    _settings = _resolveSettings();
    _rawPosition = _settings.rawEditorPosition;
    _initController();
    _controller.addListener(_onControllerChanged);
    _loadDocument();
  }

  @override
  void didUpdateWidget(MdEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme != oldWidget.theme) {
      _theme = widget.theme ?? MdEditorTheme.dark();
    }
    if (widget.settings != oldWidget.settings || widget.readOnly != oldWidget.readOnly) {
      _settings = _resolveSettings();
    }
    if (widget.eventHandlers != null &&
        widget.eventHandlers != oldWidget.eventHandlers) {
      _controller.eventHandlers = widget.eventHandlers!;
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      _internalController?.removeListener(_onControllerChanged);
      _disposeInternalController();
      _initController();
      _controller.addListener(_onControllerChanged);
    }
    if (widget.markdown != oldWidget.markdown &&
        widget.markdown != null &&
        widget.controller == null) {
      _controller.markdown = widget.markdown!;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _autoSaveTimer?.cancel();
    _disposeInternalController();
    super.dispose();
  }

  MdEditorSettings _resolveSettings() {
    final base = widget.settings ?? MdEditorSettings.standard();
    if (widget.readOnly && !base.readOnly) {
      return base.copyWith(readOnly: true);
    }
    return base;
  }

  void _initController() {
    if (widget.controller == null) {
      _internalController = MdEditorController(
        initialMarkdown: widget.markdown ?? '',
      );
    }
    if (widget.eventHandlers != null) {
      _controller.eventHandlers = widget.eventHandlers!;
    }
  }

  void _disposeInternalController() {
    _internalController?.dispose();
    _internalController = null;
  }

  void _onControllerChanged() {
    widget.onChanged?.call(_controller.markdown);
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    if (!widget.autoSave || widget.documentProvider == null) return;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(widget.autoSaveDebounce, () {
      _controller.saveToProvider(widget.documentProvider!);
    });
  }

  Future<void> _loadDocument() async {
    try {
      if (widget.documentProvider != null) {
        await _controller.loadFromProvider(widget.documentProvider!);
      }
    } catch (e, st) {
      MdEditorDebug.logger.error('Error loading document', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            const _UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            const _RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            const _SaveIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const _SearchIntent(),
        // Linux/Windows: use control instead of meta
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            const _UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            const _RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const _SaveIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _SearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _UndoIntent: CallbackAction<_UndoIntent>(
            onInvoke: (_) {
              if (_controller.canUndo) _controller.undo();
              return null;
            },
          ),
          _RedoIntent: CallbackAction<_RedoIntent>(
            onInvoke: (_) {
              if (_controller.canRedo) _controller.redo();
              return null;
            },
          ),
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) {
              _save();
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              setState(() => _showSearch = !_showSearch);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: widget.autofocus,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _buildLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(BuildContext context) {
    try {
      final hasTree = _settings.showTree;
      final hasRaw = !_settings.autoHideEditor;

      // Build preview area, optionally with raw editor attached.
      Widget previewArea = _buildPreviewPanel();

      if (hasRaw) {
        final rawDirection =
            _rawPosition == RawEditorPosition.below
                ? Axis.vertical
                : Axis.horizontal;
        final ratio = _rawPosition == RawEditorPosition.below
            ? _settings.rawEditorHeightRatio
            : _settings.rawEditorWidthRatio;
        previewArea = SplitPanel(
          direction: rawDirection,
          initialRatio: ratio,
          minRatio: 0.1,
          maxRatio: 0.9,
          first: previewArea,
          second: _buildRawEditor(),
        );
      }

      // Main content is tree + preview area, or just preview area.
      Widget mainContent;
      if (hasTree) {
        mainContent = SplitPanel(
          direction: Axis.horizontal,
          initialRatio: _settings.treePanelWidthRatio,
          minRatio: 0.1,
          maxRatio: 0.5,
          first: _buildTreePanel(),
          second: previewArea,
        );
      } else {
        mainContent = previewArea;
      }

      return Container(
        color: _theme.basic.background,
        child: Column(
          children: [
            if (_settings.showToolbar) _buildToolbar(),
            Expanded(child: mainContent),
            if (_showSearch) _buildSearchBar(),
            if (_settings.showStatusBar) _buildStatusBar(),
          ],
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error building editor layout', e, st);
      return Center(
        child: Text(
          'Editor layout error',
          style: TextStyle(color: _theme.basic.error),
        ),
      );
    }
  }

  Widget _buildTreePanel() {
    return Column(
      children: [
        Expanded(
          child: MdTreeView(
            controller: _controller,
            theme: _theme,
            settings: _settings,
            onSectionSelected: (section) {
              _controller.selectSection(section);
              widget.onSectionSelected?.call(section);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return MdPreviewPanel(
      controller: _controller,
      theme: _theme,
      settings: _settings,
      onSectionTap: (section) {
        _controller.selectSection(section);
        widget.onSectionSelected?.call(section);
      },
      onEditSection: (section) {
        _controller.selectSection(section);
      },
      onLinkTap: widget.onLinkTap,
    );
  }

  Widget _buildRawEditor() {
    return MdRawTextEditor(
      controller: _controller,
      theme: _theme,
      settings: _settings,
      rawPosition: _rawPosition,
      onTogglePosition: _settings.allowEditorPositionChange
          ? () {
              setState(() {
                _rawPosition =
                    _rawPosition == RawEditorPosition.below
                        ? RawEditorPosition.right
                        : RawEditorPosition.below;
              });
            }
          : null,
      onShowFullDocument: () {
        _controller.selectSection(null);
      },
    );
  }

  Widget _buildToolbar() {
    return MdEditorToolbar(
      controller: _controller,
      theme: _theme,
      settings: _settings,
      onSave: widget.documentProvider != null ? _save : null,
      onToggleSearch: () => setState(() => _showSearch = !_showSearch),
      showSearch: _showSearch,
    );
  }

  Widget _buildStatusBar() {
    return MdEditorStatusBar(
      controller: _controller,
      theme: _theme,
      readOnly: _settings.readOnly,
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 180,
      child: MdSearchPanel(
        controller: _controller,
        theme: _theme,
        showReplace: !_settings.readOnly,
      ),
    );
  }

  Future<void> _save() async {
    try {
      if (widget.documentProvider != null) {
        await _controller.saveToProvider(widget.documentProvider!);
      }
      widget.onSave?.call();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error saving document', e, st);
    }
  }
}

/// A read-only markdown viewer convenience widget.
///
/// Wraps [MdEditor] with [MdEditorSettings.viewer] defaults.
///
/// ```dart
/// MdViewer(markdown: '# Hello\n\nSome content.')
/// ```
class MdViewer extends StatelessWidget {
  const MdViewer({
    super.key,
    this.markdown,
    this.controller,
    this.theme,
    this.settings,
    this.onLinkTap,
    this.onSectionSelected,
  }) : assert(
         markdown != null || controller != null,
         'Provide either markdown or controller.',
       );

  /// Direct markdown string to display.
  final String? markdown;

  /// Optional controller for external management.
  final MdEditorController? controller;
  final MdEditorTheme? theme;
  final MdEditorSettings? settings;
  final ValueChanged<String>? onLinkTap;
  final ValueChanged<MdSection>? onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return MdEditor(
      markdown: controller == null ? markdown : null,
      controller: controller,
      theme: theme,
      settings: settings ?? MdEditorSettings.viewer(),
      onLinkTap: onLinkTap,
      onSectionSelected: onSectionSelected,
      readOnly: true,
    );
  }
}

// ── Keyboard shortcut intents ──

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}
