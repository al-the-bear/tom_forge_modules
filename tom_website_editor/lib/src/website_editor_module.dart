import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'website_config_panel.dart';
import 'website_control_controller.dart';
import 'website_control_view.dart';
import 'website_editor_controller.dart';
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
/// The preview view (§9.3) is contributed here on the shared [controller]. The
/// control view (§9.4) and the dedicated `WebsiteConfigEditor` (§6) are added in
/// later steps.
class WebsiteEditorModule extends ForgeModule {
  WebsiteEditorModule({this.configFileName = 'tom.website-editor.yaml'});

  /// Name of the config file resolved against the workspace root.
  final String configFileName;

  WebsiteEditorController? _controller;
  WebsitePreviewController? _previewController;
  WebsitePreviewView? _previewView;
  WebsiteControlController? _controlController;
  WebsiteControlView? _controlView;

  /// The active controller, available after [activate].
  WebsiteEditorController? get controller => _controller;

  @override
  String get displayName => 'Website Editor';

  @override
  void activate(ForgeShellApi shell) {
    final configUri = _resolveConfigUri(shell);
    final controller = WebsiteEditorController(
      configReader: () => shell.fileSystem.read(configUri),
    );
    _controller = controller;
    final previewController = WebsitePreviewController(editor: controller);
    _previewController = previewController;
    _previewView = WebsitePreviewView(controller: previewController);
    final controlController = WebsiteControlController(
      editor: controller,
      // Auto-refresh the embedded preview when the dev server signals a
      // completed rebuild (§5, §9.5).
      onRebuildComplete: previewController.refresh,
    );
    _controlController = controlController;
    _controlView = WebsiteControlView(controller: controlController);
    unawaited(controller.load());
  }

  @override
  void deactivate() {
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
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => [?_previewView, ?_controlView];

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
        builder: (_) => WebsiteConfigPanel(controller: controller),
      ),
    ];
  }
}
