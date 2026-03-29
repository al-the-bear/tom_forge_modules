import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import '../adapters/forge_dart_editor.dart';
import '../adapters/forge_md_editor.dart';
import '../adapters/forge_yaml_editor.dart';
import '../components/forge_component.dart';
import '../components/forge_editor.dart';
import '../module/forge_module.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_module_registry.dart';
import 'default_system_state.dart';

/// Default implementation of [ForgeLayoutController].
///
/// Manages panel visibility/sizes and editor tab lifecycle.
class DefaultLayoutController implements ForgeLayoutController {
  static bool debugEnabled = false;
  static const String _extMarkdown = 'md';
  static const String _extMarkdownAlt = 'markdown';
  static const String _extDart = 'dart';
  static const String _extYaml = 'yaml';
  static const String _extYml = 'yml';
  static const String _extText = 'txt';

  final DefaultSystemState _systemState;
  final ForgeFileSystem _fileSystem;
  final ForgeModuleRegistry _moduleRegistry;

  final ValueNotifier<LayoutPanelConfig> _leftPanel;
  final ValueNotifier<LayoutPanelConfig> _rightPanel;
  final ValueNotifier<LayoutPanelConfig> _bottomPanel;
  final ValueNotifier<List<List<ForgeEditor>>> _middlePanels;
  final ValueNotifier<int> _activeMiddlePanelIndex;

  DefaultLayoutController({
    required DefaultSystemState systemState,
    required ForgeFileSystem fileSystem,
    required ForgeModuleRegistry moduleRegistry,
    double leftSize = 250,
    double rightSize = 220,
    double bottomSize = 180,
  })  : _systemState = systemState,
        _fileSystem = fileSystem,
        _moduleRegistry = moduleRegistry,
        _leftPanel = ValueNotifier(
            LayoutPanelConfig(size: leftSize, isVisible: true)),
        _rightPanel = ValueNotifier(
            LayoutPanelConfig(size: rightSize, isVisible: true)),
        _bottomPanel = ValueNotifier(
            LayoutPanelConfig(size: bottomSize, isVisible: true)),
        _middlePanels = ValueNotifier([[]]),
        _activeMiddlePanelIndex = ValueNotifier(0);

  @override
  void openPanel(ForgePanelLocation location) {
    _setPanelVisible(location, true);
  }

  @override
  void closePanel(ForgePanelLocation location) {
    _setPanelVisible(location, false);
  }

  @override
  void togglePanel(ForgePanelLocation location) {
    final config = _panelNotifier(location);
    if (config != null) {
      _setPanelVisible(location, !config.value.isVisible);
    }
  }

  @override
  void focusComponent(ForgeComponent component) {
    _systemState.setFocusedComponent(component);
  }

  @override
  void openFile(Uri uri, {int? middlePanelIndex}) {
    // Check if already open.
    final existing = _systemState.openEditors.where((e) => e.uri == uri);
    if (existing.isNotEmpty) {
      _systemState.setActiveEditor(existing.first);
      return;
    }

    _fileSystem.read(uri).then((content) {
      final editor = _createEditor(uri, content);
      if (editor == null) {
        if (debugEnabled) {
          // ignore: avoid_print
          print('[DefaultLayoutController] No editor for: $uri');
        }
        return;
      }

      _systemState.addOpenEditor(editor);
      _systemState.setActiveEditor(editor);

      final panelIdx = middlePanelIndex ?? _activeMiddlePanelIndex.value;
      final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
      if (panelIdx < panels.length) {
        panels[panelIdx] = [...panels[panelIdx], editor];
      }
      _middlePanels.value = panels;
    }).catchError((Object e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultLayoutController] openFile error: $e');
      }
    });
  }

  @override
  void openEditor(ForgeEditor editor, Uri uri, {int? middlePanelIndex}) {
    if (_systemState.openEditors.contains(editor)) {
      _systemState.setActiveEditor(editor);
      return;
    }
    _systemState.addOpenEditor(editor);
    _systemState.setActiveEditor(editor);

    final panelIdx = middlePanelIndex ?? _activeMiddlePanelIndex.value;
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    if (panelIdx < panels.length) {
      panels[panelIdx] = [...panels[panelIdx], editor];
    }
    _middlePanels.value = panels;
  }

  @override
  Future<void> openFileWith(Uri uri, {int? middlePanelIndex}) async {
    // Resolve editor from modules and open.
    openFile(uri, middlePanelIndex: middlePanelIndex);
  }

  @override
  void splitMiddlePanel() {
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    panels.add([]);
    _middlePanels.value = panels;
    _activeMiddlePanelIndex.value = panels.length - 1;
    _systemState.setMiddlePanelCount(panels.length);
  }

  @override
  LayoutPanelConfig? getPanelConfig(ForgePanelLocation location) {
    return _panelNotifier(location)?.value;
  }

  @override
  int get activeMiddlePanelIndex => _activeMiddlePanelIndex.value;

  @override
  void revealInExplorer(Uri uri) {
    _systemState.setSelectedExplorerItems([uri]);
  }

  /// Close a specific editor.
  void closeEditor(ForgeEditor editor) {
    _systemState.removeOpenEditor(editor);
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    for (var i = 0; i < panels.length; i++) {
      panels[i] = panels[i].where((e) => e != editor).toList();
    }
    while (panels.length > 1 && panels.last.isEmpty) {
      panels.removeLast();
    }
    _middlePanels.value = panels;
    _systemState.setMiddlePanelCount(panels.length);
    _systemState.updateDirtyEditors();
  }

  /// Close all open editors.
  void closeAllEditors() {
    for (final editor in List.of(_systemState.openEditors)) {
      _systemState.removeOpenEditor(editor);
    }
    _middlePanels.value = [[]];
    _systemState.setMiddlePanelCount(1);
    _systemState.updateDirtyEditors();
  }

  // ── Accessors for widgets ──

  ValueListenable<LayoutPanelConfig> get leftPanel => _leftPanel;
  ValueListenable<LayoutPanelConfig> get rightPanel => _rightPanel;
  ValueListenable<LayoutPanelConfig> get bottomPanel => _bottomPanel;
  ValueListenable<List<List<ForgeEditor>>> get middlePanels => _middlePanels;
  ValueListenable<int> get activeMiddlePanelIndexNotifier =>
      _activeMiddlePanelIndex;

  void setActiveMiddlePanelIndex(int index) {
    _activeMiddlePanelIndex.value = index;
    _systemState.setActiveMiddlePanelIndex(index);
  }

  // ── Private helpers ──

  void _setPanelVisible(ForgePanelLocation location, bool visible) {
    final notifier = _panelNotifier(location);
    if (notifier == null) return;
    final current = notifier.value;
    notifier.value = LayoutPanelConfig(
      size: current.size,
      isVisible: visible,
    );
    final panels = Set<ForgePanelLocation>.from(_systemState.visiblePanels);
    if (visible) {
      panels.add(location);
    } else {
      panels.remove(location);
    }
    _systemState.setVisiblePanels(panels);
  }

  void setPanelSize(ForgePanelLocation location, double size) {
    final notifier = _panelNotifier(location);
    if (notifier == null) return;
    final current = notifier.value;
    notifier.value = LayoutPanelConfig(
      size: size,
      isVisible: current.isVisible,
    );
  }

  ValueNotifier<LayoutPanelConfig>? _panelNotifier(
      ForgePanelLocation location) {
    switch (location) {
      case ForgePanelLocation.left:
        return _leftPanel;
      case ForgePanelLocation.right:
        return _rightPanel;
      case ForgePanelLocation.bottom:
        return _bottomPanel;
      case ForgePanelLocation.middle:
        return null;
    }
  }

  ForgeEditor? _createEditor(Uri uri, String content) {
    final ext = uri.path.split('.').last.toLowerCase();

    ForgeModule? ownerModule;
    for (final module in _moduleRegistry.allModules) {
      ownerModule = module;
      break;
    }
    if (ownerModule == null) return null;

    switch (ext) {
      case _extMarkdown:
      case _extMarkdownAlt:
        final controller = MdEditorController(
          initialMarkdown: content,
          uri: uri,
        );
        return ForgeMdEditor(controller: controller, module: ownerModule);
      case _extText:
        final controller = MdEditorController(
          initialMarkdown: content,
          uri: uri,
        );
        return ForgeMdEditor(controller: controller, module: ownerModule);
      case _extDart:
        final controller = DartCodeController(
          initialCode: content,
          uri: uri,
        );
        return ForgeDartEditor(controller: controller, module: ownerModule);
      case _extYaml:
      case _extYml:
        final controller = YamlEditorController(
          initialYaml: content,
          uri: uri,
        );
        return ForgeYamlEditor(controller: controller, module: ownerModule);
      default:
        for (final module in _moduleRegistry.allModules) {
          for (final editor in module.editors) {
            if (editor.canHandle(uri) == FileHandlingResult.accept) {
              return editor;
            }
          }
        }
        // Fallback to a plain text-capable editor when no specialized editor
        // is registered for the current file type.
        final controller = MdEditorController(
          initialMarkdown: content,
          uri: uri,
        );
        return ForgeMdEditor(controller: controller, module: ownerModule);
    }
  }

  /// Dispose notifiers.
  void dispose() {
    _leftPanel.dispose();
    _rightPanel.dispose();
    _bottomPanel.dispose();
    _middlePanels.dispose();
    _activeMiddlePanelIndex.dispose();
  }
}
