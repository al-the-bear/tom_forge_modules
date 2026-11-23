import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../controller/md_editor_controller.dart';
import '../debug/md_editor_debug.dart';
import '../events/md_events.dart';
import '../integration/editor_trail.dart';
import '../integration/md_editor_actions.dart';
import '../integration/md_standalone_integration.dart';
import '../integration/md_text_context.dart';
import '../models/md_section.dart';
import '../plugins/md_content_plugin.dart';
import '../plugins/md_default_plugins.dart';
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
    this.integration,
    this.handleShortcuts = true,
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
    this.pluginRegistry,
    this.plugins = const [],
  }) : assert(
         markdown == null || controller == null,
         'Provide either markdown or controller, not both.',
       );

  /// Direct markdown content source. Creates an internal controller.
  final String? markdown;

  /// Controller managing document state. If null, one is created internally.
  final MdEditorController? controller;

  /// Optional Forge editor integration for unified action handling.
  ///
  /// When provided (e.g. [ShellEditorIntegration] from the shell), the editor
  /// delegates action registration, shortcut resolution, and context reporting
  /// to this integration.
  ///
  /// When `null`, a [MdStandaloneIntegration] is created automatically in
  /// [initState] with sensible defaults.
  final ForgeEditorIntegration? integration;

  /// Whether this editor should handle keyboard shortcuts internally.
  ///
  /// When `true` (default, standalone mode), the editor wraps its content
  /// in `Shortcuts`/`Actions` widgets.
  /// When `false` (shell-integrated mode), all shortcut-to-action routing
  /// comes from the host — the editor only registers action handlers for
  /// execution.
  final bool handleShortcuts;

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

  /// Registry of content editor plugins for the preview panel.
  ///
  /// If null, the default registry is created from [settings]: the core
  /// plugins (table, code) and [plugins] ([createDefaultPluginRegistry]).
  final MdPluginRegistry? pluginRegistry;

  /// Plugins added to the default registry when [pluginRegistry] is null,
  /// e.g. `mdMermaidPlugin()` (`tom_md_mermaid`) and `mdMathPlugin()`
  /// (`tom_md_math`); each is used while the settings enable it
  /// ([MdContentPlugin.isEnabledBy]). None by default: the editor then shows
  /// diagrams and math as their Markdown source.
  final List<MdContentPlugin> plugins;

  @override
  State<MdEditor> createState() => _MdEditorState();
}

class _MdEditorState extends State<MdEditor> {
  late MdEditorTheme _theme;
  late MdEditorSettings _settings;
  bool _showSearch = false;
  late RawEditorPosition _rawPosition;
  late MdPluginRegistry _pluginRegistry;

  MdEditorController? _internalController;
  Timer? _autoSaveTimer;

  // Forge integration
  late final ForgeEditorIntegration _integration;

  /// Stops following the host's undo depth setting.
  VoidCallback? _stopFollowingDepth;
  late final MdTextContext _textContext;
  late final bool _ownsIntegration;
  Map<ShortcutActivator, Intent> _shortcuts = {};

  MdEditorController get _controller =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    trailEvent('initState start');
    _theme = widget.theme ?? MdEditorTheme.dark();
    _settings = _resolveSettings();
    _rawPosition = _settings.rawEditorPosition;
    _pluginRegistry = widget.pluginRegistry ??
        createDefaultPluginRegistry(
          settings: _settings,
          plugins: widget.plugins,
        );
    _initController();
    _controller.addListener(_onControllerChanged);
    _setupIntegration();
    _loadDocument();
    trailEvent('initState complete');
  }

  @override
  void didUpdateWidget(MdEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme != oldWidget.theme) {
      _theme = widget.theme ?? MdEditorTheme.dark();
    }
    if (widget.settings != oldWidget.settings || widget.readOnly != oldWidget.readOnly) {
      _settings = _resolveSettings();
      if (widget.pluginRegistry == null) {
        _pluginRegistry = createDefaultPluginRegistry(
          settings: _settings,
          plugins: widget.plugins,
        );
      }
    } else if (widget.pluginRegistry == null &&
        !identical(widget.plugins, oldWidget.plugins)) {
      _pluginRegistry = createDefaultPluginRegistry(
        settings: _settings,
        plugins: widget.plugins,
      );
    }
    if (widget.pluginRegistry != oldWidget.pluginRegistry &&
        widget.pluginRegistry != null) {
      _pluginRegistry = widget.pluginRegistry!;
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
      // New content from the host: saved, with nothing to undo.
      _controller.replaceContent(widget.markdown!);
    }
  }

  @override
  void dispose() {
    trailEvent('dispose start');
    _integration.shortcutBindings.removeListener(_onBindingsChanged);
    _stopFollowingDepth?.call();
    _controller.removeListener(_onControllerChanged);
    _autoSaveTimer?.cancel();
    _textContext.dispose();
    if (_ownsIntegration) {
      _integration.dispose();
    }
    _disposeInternalController();
    trailEvent('dispose complete');
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

  // ── Forge integration setup ──

  /// Set up the Forge editor integration and register all actions.
  void _setupIntegration() {
    trailEvent('_setupIntegration start');
    try {
      if (widget.integration != null) {
        _integration = widget.integration!;
        _ownsIntegration = false;
      } else {
        // Map the current theme's typography to ForgeTextSettings
        final textSettings = _theme.basic.toForgeTextSettings();
        _integration = MdStandaloneIntegration(
          controller: TextEditingController(),
          focusNode: FocusNode(),
          textSettings: textSettings,
        );
        _ownsIntegration = true;
      }

      // Create text context for state discovery
      _textContext = MdTextContext(
        controller: _controller,
        isDirtyFn: () => _controller.isDirty.value,
      );

      // Register editor actions with the integration
      _registerActions();

      // Build the keyboard shortcut map, and again whenever the user
      // rebinds a key.
      _buildShortcutMap();
      _integration.shortcutBindings.addListener(_onBindingsChanged);
      _stopFollowingDepth = forgeFollowUndoDepth(
        _integration,
        (depth) => _controller.maxUndoHistory = depth,
      );

      trailEvent('_setupIntegration complete: '
          '${_integration.supportedActions.length} actions, '
          '${_shortcuts.length} shortcuts');
    } catch (e) {
      trailEvent('_setupIntegration error: $e');
      rethrow;
    }
  }

  /// Register standard editing and markdown-specific actions with the
  /// integration.
  void _registerActions() {
    // Override standard undo/redo to use the controller's undo mechanism
    _integration.registerAction(
      StandardEditingActions.undoActionId,
      () {
        if (_controller.canUndo) _controller.undo();
      },
      isEnabled: () => _controller.canUndo,
    );
    _integration.registerAction(
      StandardEditingActions.redoActionId,
      () {
        if (_controller.canRedo) _controller.redo();
      },
      isEnabled: () => _controller.canRedo,
    );

    // Save action — only register when the editor can save directly via
    // documentProvider.  When omitted, the parent scaffold's Ctrl+S shortcut
    // takes over and triggers the shell's file.save action instead.
    if (widget.documentProvider != null) {
      _integration.registerAction(
        MdEditorActions.saveActionId,
        _save,
      );
    }

    // Search action
    _integration.registerAction(
      MdEditorActions.searchActionId,
      () => setState(() => _showSearch = !_showSearch),
    );
  }

  void _onBindingsChanged() {
    if (mounted) setState(_buildShortcutMap);
  }

  /// Build the keyboard shortcut map from the integration's bindings
  /// ([buildEditorShortcutMap]) and the markdown-specific shortcuts.
  void _buildShortcutMap() {
    if (!widget.handleShortcuts) {
      _shortcuts = {};
      return;
    }
    // The Markdown-specific keys join the map through the same helper, so a
    // key is taken once and keeps one meaning. Actions without a handler
    // (save without a documentProvider) are left out, so their key reaches
    // the shell's handler instead.
    _shortcuts = <ShortcutActivator, Intent>{
      for (final entry in buildEditorShortcutMap(
        _integration,
        alternates: {
          ...MdEditorActions.alternativeShortcuts,
          for (final entry in MdEditorActions.primaryShortcuts.entries)
            if (_integration.isActionEnabled(entry.key))
              entry.key: [entry.value],
        },
      ).entries)
        entry.key: _MdEditorActionIntent(entry.value),
    };
  }

  @override
  Widget build(BuildContext context) {
    final innerContent = Focus(
      autofocus: widget.autofocus,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildLayout(context),
      ),
    );

    if (!widget.handleShortcuts) return innerContent;

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _MdEditorActionIntent: CallbackAction<_MdEditorActionIntent>(
            onInvoke: (intent) {
              _integration.executeAction(intent.actionId);
              return null;
            },
          ),
        },
        child: innerContent,
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
    final schema = _controller.schemaSupport;
    final header = schema?.buildOutlineHeader(context, _controller, _theme);
    final footer = schema?.buildOutlineFooter(
      context,
      _controller,
      _theme,
      _settings,
    );
    return Column(
      children: [
        // What the schema shows above the outline (e.g. for-each sync).
        ?header,
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
        // What the schema shows below the outline (e.g. its info panel).
        ?footer,
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return MdPreviewPanel(
      controller: _controller,
      theme: _theme,
      settings: _settings,
      pluginRegistry: _pluginRegistry,
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
      pluginRegistry: _pluginRegistry,
      integration: _integration,
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

  /// The search panel's fields are not the document: the undo and redo
  /// keys there undo the field's own typing ([UndoTextIntent] reaches the
  /// field's own history), not the document's — this map sits between the
  /// field and the editor's.
  Widget _buildSearchBar() {
    return SizedBox(
      height: 180,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          for (final entry in _shortcuts.entries)
            if (entry.value case _MdEditorActionIntent(:final actionId))
              if (actionId == StandardEditingActions.undoActionId)
                entry.key: const UndoTextIntent(SelectionChangedCause.keyboard)
              else if (actionId == StandardEditingActions.redoActionId)
                entry.key: const RedoTextIntent(SelectionChangedCause.keyboard),
        },
        child: MdSearchPanel(
          controller: _controller,
          theme: _theme,
          showReplace: !_settings.readOnly,
        ),
      ),
    );
  }

  Future<void> _save() async {
    try {
      if (widget.documentProvider != null) {
        await _controller.saveToProvider(widget.documentProvider!);
      }
      _textContext.notifyExternalChange();
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

// ── Keyboard shortcut intent ──

/// Intent carrying a [ForgeAction] ID for the [Shortcuts]/[Actions] bridge.
class _MdEditorActionIntent extends Intent {
  final String actionId;
  const _MdEditorActionIntent(this.actionId);
}
