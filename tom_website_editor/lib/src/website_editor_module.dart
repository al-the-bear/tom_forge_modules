import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import 'content/website_content_browser.dart';
import 'content/website_content_controller.dart';
import 'content/website_content_fs.dart';
import 'structure/website_structure_controller.dart';
import 'structure/website_structure_explorer.dart';
import 'website_config_editor.dart';
import 'website_config_panel.dart';
import 'website_control_controller.dart';
import 'website_control_view.dart';
import 'website_editor_controller.dart';
import 'website_process_runner.dart';
import 'website_preview_controller.dart';
import 'website_preview_view.dart';

/// Forge module that loads `tom.website-editor.yaml` and contributes the
/// website selection / reload config panel (§9.2).
///
/// The module is intentionally thin: the registry semantics live in
/// `tom_website_editor_core` and the reload/selection state lives in
/// [WebsiteEditorController]. On [activate] the module resolves the config file
/// at the workspace root, wires the controller's reader to the shell file
/// system, and kicks off the initial load.
///
/// The preview view (§9.3), control view (§9.4), content/structure browsers
/// (§6a/§6b), and the dedicated [WebsiteConfigEditor] (§6) are all contributed
/// here on the shared [controller].
class WebsiteEditorModule extends ForgeModule {
  WebsiteEditorModule({
    this.configFileName = 'tom.website-editor.yaml',
    WebsiteProcessRunner runner = const DartIoWebsiteProcessRunner(),
  }) : _runner = runner;

  /// Name of the config file resolved against the workspace root.
  final String configFileName;

  /// Spawns the external generator/build/dev-server processes (§5). Injectable
  /// so tests can drive the control panel without starting real processes.
  final WebsiteProcessRunner _runner;

  ForgeShellApi? _shell;
  Uri? _configUri;
  WebsiteConfigEditor? _configEditor;
  ForgeDiagnosticCollection? _configDiagnostics;
  WebsiteEditorController? _controller;
  WebsitePreviewController? _previewController;
  WebsitePreviewView? _previewView;
  WebsiteControlController? _controlController;
  WebsiteControlView? _controlView;
  WebsiteContentController? _contentController;
  WebsiteContentBrowser? _contentView;
  WebsiteStructureController? _structureController;
  WebsiteStructureExplorer? _structureView;

  /// The active controller, available after [activate].
  WebsiteEditorController? get controller => _controller;

  /// The dev-server / generator control controller (§5), available after
  /// [activate]. Exposed so a host (or test) can drive command runs directly.
  WebsiteControlController? get controlController => _controlController;

  /// The content catalog controller (§6a), available after [activate].
  WebsiteContentController? get contentController => _contentController;

  /// The filesystem structure controller (§6b), available after [activate].
  WebsiteStructureController? get structureController => _structureController;

  /// The embedded site preview (§9.3), available after [activate].
  ///
  /// Exposed individually so a host shell can place each surface in the panel
  /// that fits its shape (e.g. the wide preview across the bottom, the
  /// management views in a side panel) rather than parsing [views] by title.
  WebsitePreviewView? get previewView => _previewView;

  /// The dev-server / generator control panel (§9.4), available after [activate].
  WebsiteControlView? get controlView => _controlView;

  /// The content catalog browser (§6a), available after [activate].
  WebsiteContentBrowser? get contentView => _contentView;

  /// The filesystem-driven structure explorer (§6b), available after [activate].
  WebsiteStructureExplorer? get structureView => _structureView;

  @override
  String get displayName => 'Website Editor';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
    final configUri = _resolveConfigUri(shell);
    _configUri = configUri;
    final controller = WebsiteEditorController(
      configReader: () => shell.fileSystem.read(configUri),
    );
    _controller = controller;
    // §6 config editor: built on ForgeYamlEditor, self-loads the on-disk config,
    // and on save reloads the registry (an invalid save is rejected, last-good
    // kept). Its schema/placeholder diagnostics are forwarded to the shell.
    final configEditor = WebsiteConfigEditor(
      controller: YamlEditorController(uri: configUri),
      module: this,
      configFileName: configFileName,
      onSaveReload: controller.reload,
      configReader: () => shell.fileSystem.read(configUri),
    );
    _configEditor = configEditor;
    final diagnostics = shell.diagnostics.createCollection('website-editor-config');
    _configDiagnostics = diagnostics;
    configEditor.configDiagnostics.addListener(_pushConfigDiagnostics);
    _pushConfigDiagnostics();
    final previewController = WebsitePreviewController(editor: controller);
    _previewController = previewController;
    _previewView = WebsitePreviewView(controller: previewController);
    final controlController = WebsiteControlController(
      editor: controller,
      runner: _runner,
      // Auto-refresh the embedded preview when the dev server signals a
      // completed rebuild (§5, §9.5).
      onRebuildComplete: previewController.refresh,
      // After a control-panel generate run, refresh the content tree and the
      // structure explorer from disk so they reflect what the generator wrote
      // (§5) — no manual reload needed.
      onContentRegenerated: _refreshContentTrees,
    );
    _controlController = controlController;
    _controlView = WebsiteControlView(controller: controlController);
    final contentController = WebsiteContentController(
      editor: controller,
      fileSystem: ForgeContentFs(shell.fileSystem),
    );
    _contentController = contentController;
    _contentView = WebsiteContentBrowser(
      controller: contentController,
      onOpenFile: _openFile,
    );
    final structureController = WebsiteStructureController(
      editor: controller,
      fileSystem: ForgeContentFs(shell.fileSystem),
    );
    _structureController = structureController;
    _structureView = WebsiteStructureExplorer(controller: structureController);
    unawaited(controller.load());
  }

  /// Opens `tom.website-editor.yaml` in the dedicated [WebsiteConfigEditor]
  /// (§6). Routing matches on the filename via [WebsiteConfigEditor.canHandle].
  void _openConfigEditor() {
    final shell = _shell;
    final uri = _configUri;
    if (shell != null && uri != null) shell.layout.openFile(uri);
  }

  /// Opens [uri] in the shell, routing to the matching editor via `canHandle`.
  ///
  /// The shared open seam (item 1) the content/structure browsers call so a tap
  /// on a content file routes through `ForgeLayoutController.openFile`.
  void _openFile(Uri uri) => _shell?.layout.openFile(uri);

  /// Refreshes the content tree and structure explorer from disk after a
  /// control-panel generate run (§5). Both controllers already debounce to the
  /// active website, so this is a cheap no-op when nothing on disk changed.
  void _refreshContentTrees() {
    unawaited(_contentController?.refresh());
    unawaited(_structureController?.refresh());
  }

  /// Forwards the config editor's schema/placeholder diagnostics to the shell.
  void _pushConfigDiagnostics() {
    final uri = _configUri;
    final editor = _configEditor;
    if (uri != null && editor != null) {
      _configDiagnostics?.set(uri, editor.configDiagnostics.value);
    }
  }

  @override
  void deactivate() {
    final uri = _configUri;
    _configEditor?.configDiagnostics.removeListener(_pushConfigDiagnostics);
    if (uri != null) _configDiagnostics?.set(uri, const []);
    _configEditor?.dispose();
    _configEditor = null;
    _configDiagnostics = null;
    _configUri = null;
    _shell = null;
    _structureView = null;
    _structureController?.dispose();
    _structureController = null;
    _contentView = null;
    _contentController?.dispose();
    _contentController = null;
    _controlView = null;
    _controlController?.dispose();
    _controlController = null;
    _previewView = null;
    _previewController?.dispose();
    _previewController = null;
    _controller?.dispose();
    _controller = null;
  }

  Uri _resolveConfigUri(ForgeShellApi shell) {
    final root = shell.systemState.workspaceRootPath;
    return Directory(root).uri.resolve(configFileName);
  }

  @override
  List<ForgeEditor> get editors => [?_configEditor];

  @override
  List<ForgeView> get views =>
      [?_previewView, ?_controlView, ?_contentView, ?_structureView];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeConfigPanel> get configPanels {
    final controller = _controller;
    if (controller == null) return const [];
    return [
      ForgeConfigPanel(
        id: 'website-editor',
        title: 'Website Editor',
        icon: Icons.public,
        priority: 120,
        builder: (_) => WebsiteConfigPanel(
          controller: controller,
          onEditConfiguration: _openConfigEditor,
        ),
      ),
    ];
  }
}
