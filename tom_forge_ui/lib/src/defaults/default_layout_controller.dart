import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

import '../adapters/forge_dart_editor.dart';
import '../adapters/forge_md_editor.dart';
import '../adapters/forge_plain_text_editor.dart';
import '../adapters/forge_yaml_editor.dart';
import '../components/forge_component.dart';
import '../components/forge_editor.dart';
import '../components/forge_text_editor.dart';
import '../module/forge_module.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_module_registry.dart';
import 'default_system_state.dart';
import 'stub_services.dart';

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
  final DefaultVirtualDocumentManager? _virtualDocuments;

  /// Late-bound diagnostic manager for emitting editor fallback diagnostics.
  ForgeDiagnosticManager? diagnosticManager;

  final ValueNotifier<LayoutPanelConfig> _leftPanel;
  final ValueNotifier<LayoutPanelConfig> _rightPanel;
  final ValueNotifier<LayoutPanelConfig> _bottomPanel;
  final ValueNotifier<List<List<ForgeEditor>>> _middlePanels;
  final ValueNotifier<int> _activeMiddlePanelIndex;

  /// Pending "Open With" editor candidates. The shell can observe this to show
  /// a chooser dialog. The first element is the URI, followed by the candidate
  /// editors.
  final ValueNotifier<(Uri, List<ForgeEditor>)?> pendingEditorChoice =
      ValueNotifier(null);

  DefaultLayoutController({
    required DefaultSystemState systemState,
    required ForgeFileSystem fileSystem,
    required ForgeModuleRegistry moduleRegistry,
    DefaultVirtualDocumentManager? virtualDocuments,
    double leftSize = 250,
    double rightSize = 220,
    double bottomSize = 180,
  })  : _systemState = systemState,
        _fileSystem = fileSystem,
        _moduleRegistry = moduleRegistry,
        _virtualDocuments = virtualDocuments,
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
  void openFile(Uri uri, {int? middlePanelIndex, int? line, int? column}) {
    // Check if already open.
    final existing = _systemState.openEditors.where((e) => e.uri == uri);
    if (existing.isNotEmpty) {
      final editor = existing.first;
      _systemState.setActiveEditor(editor);
      _navigateEditorTo(editor, line: line, column: column);
      return;
    }

    // Resolve content from virtual document provider or file system.
    _resolveContent(uri).then((content) async {
      if (content == null) {
        if (debugEnabled) {
          // ignore: avoid_print
          print('[DefaultLayoutController] Cannot read content for: $uri');
        }
        return;
      }
      final editor = await _createEditor(uri, content);
      if (editor == null) {
        if (debugEnabled) {
          // ignore: avoid_print
          print('[DefaultLayoutController] No editor for: $uri');
        }
        return;
      }
      _addEditorToPanel(editor, panelIdx: middlePanelIndex);
      _navigateEditorTo(editor, line: line, column: column);
    }).catchError((Object e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultLayoutController] openFile error: $e');
      }
    });
  }

  /// Resolve content for a URI, trying virtual document providers first
  /// for non-file schemes, then falling back to file system.
  Future<String?> _resolveContent(Uri uri) async {
    // Check if a virtual document provider handles this scheme.
    if (_virtualDocuments != null &&
        uri.scheme != 'file' &&
        _virtualDocuments.hasProvider(uri.scheme)) {
      return await _virtualDocuments.resolveContent(uri);
    }
    // Fall back to file system.
    return await _fileSystem.read(uri);
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
    // Collect all editors that can handle this URI.
    final candidates = <ForgeEditor>[];
    for (final module in _moduleRegistry.allModules) {
      for (final editor in module.editors) {
        final result = editor.canHandle(uri);
        if (result == FileHandlingResult.accept) {
          candidates.add(editor);
        } else if (result == FileHandlingResult.inspect) {
          // Phase 2: check content.
          try {
            final bytes = await _fileSystem.readBytes(uri);
            if (editor.canHandleContent(uri, bytes) ==
                FileHandlingResult.accept) {
              candidates.add(editor);
            }
          } catch (_) {
            // Skip editors that fail content inspection.
          }
        }
      }
    }

    if (candidates.length <= 1) {
      // Zero or one: just open normally.
      openFile(uri, middlePanelIndex: middlePanelIndex);
      return;
    }

    // Multiple candidates — surface the choice for the shell UI.
    pendingEditorChoice.value = (uri, candidates);
  }

  /// Resolve a pending "Open With" choice by opening the selected editor.
  void resolveEditorChoice(ForgeEditor editor, Uri uri,
      {int? middlePanelIndex}) {
    pendingEditorChoice.value = null;
    openEditor(editor, uri, middlePanelIndex: middlePanelIndex);
  }

  @override
  void splitMiddlePanel() {
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    // Limit to 4 middle panels maximum.
    if (panels.length >= 4) return;
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

  @override
  void moveComponent(ForgeComponent component, int targetPanelIndex) {
    if (component is! ForgeEditor) return;
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    // Remove from current panel.
    for (var i = 0; i < panels.length; i++) {
      panels[i] = panels[i].where((e) => e != component).toList();
    }
    // Add to target panel.
    while (panels.length <= targetPanelIndex) {
      panels.add([]);
    }
    panels[targetPanelIndex].add(component);
    // Clean up empty trailing panels.
    while (panels.length > 1 && panels.last.isEmpty) {
      panels.removeLast();
    }
    _middlePanels.value = panels;
    _systemState.setMiddlePanelCount(panels.length);
    _activeMiddlePanelIndex.value =
        targetPanelIndex.clamp(0, panels.length - 1);
  }

  @override
  void copyComponent(ForgeComponent component, int targetPanelIndex) {
    if (component is! ForgeEditor) return;
    if (!component.supportsMultiRender) return;
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    while (panels.length <= targetPanelIndex) {
      panels.add([]);
    }
    // The same editor instance is added to the target panel.
    // `buildCopy(context)` provides an independent UI rendering.
    panels[targetPanelIndex].add(component);
    _middlePanels.value = panels;
    _systemState.setMiddlePanelCount(panels.length);
    _activeMiddlePanelIndex.value =
        targetPanelIndex.clamp(0, panels.length - 1);
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

  /// Add an editor to the active (or specified) middle panel.
  void _addEditorToPanel(ForgeEditor editor, {int? panelIdx}) {
    _systemState.addOpenEditor(editor);
    _systemState.setActiveEditor(editor);

    final idx = panelIdx ?? _activeMiddlePanelIndex.value;
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    if (idx < panels.length) {
      panels[idx] = [...panels[idx], editor];
    }
    _middlePanels.value = panels;
  }

  Future<ForgeEditor?> _createEditor(Uri uri, String content) async {
    final ext = uri.path.split('.').last.toLowerCase();

    ForgeModule? ownerModule;
    for (final module in _moduleRegistry.allModules) {
      ownerModule = module;
      break;
    }
    if (ownerModule == null) return null;

    // Phase 1: Check if any module editor explicitly accepts this URI.
    final inspectEditors = <ForgeEditor>[];
    for (final module in _moduleRegistry.allModules) {
      for (final editor in module.editors) {
        final result = editor.canHandle(uri);
        if (result == FileHandlingResult.accept) {
          return editor;
        } else if (result == FileHandlingResult.inspect) {
          inspectEditors.add(editor);
        }
      }
    }

    // Phase 2: Let inspecting editors examine file content.
    if (inspectEditors.isNotEmpty) {
      final bytes = utf8.encode(content);
      for (final editor in inspectEditors) {
        if (editor.canHandleContent(uri, bytes) ==
            FileHandlingResult.accept) {
          return editor;
        }
      }
    }

    // Phase 3: Default creation for known extensions.
    switch (ext) {
      case _extMarkdown:
      case _extMarkdownAlt:
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
        // Fallback to plain text editor when no specialized editor
        // is registered for the current file type.
        _emitFallbackDiagnostic(uri, ext);
        return ForgePlainTextEditor.fromContent(
          content: content,
          uri: uri,
          module: ownerModule,
        );
    }
  }

  /// Navigate an editor to a specific line/column if supported.
  void _navigateEditorTo(ForgeEditor editor, {int? line, int? column}) {
    if (line == null) return;
    if (editor is ForgeTextEditor) {
      editor.setCursorPosition(
        ForgeTextPosition(line: line, column: column ?? 0),
      );
    }
  }

  /// Emit an ED002 diagnostic when falling back to the plain-text editor
  /// because no specialised editor matched the file extension.
  void _emitFallbackDiagnostic(Uri uri, String ext) {
    final dm = diagnosticManager;
    if (dm == null) return;
    final collection = dm.createCollection('editor-fallback');
    collection.set(uri, [
      ForgeDiagnostic(
        uri: uri,
        range: const ForgeTextRange.empty(),
        message: 'No editor registered for ".$ext" — opened as plain text',
        severity: ForgeSeverity.info,
        source: 'forge-shell',
        code: ForgeErrorCodes.edNoEditor,
      ),
    ]);
  }

  /// Serializes current layout state to a JSON-compatible map.
  ///
  /// Captures panel sizes, visibility, active middle panel index,
  /// and open editor URIs per panel.
  Map<String, dynamic> toLayoutSnapshot() {
    return {
      'panels': {
        'left': {
          'size': _leftPanel.value.size,
          'isVisible': _leftPanel.value.isVisible,
        },
        'right': {
          'size': _rightPanel.value.size,
          'isVisible': _rightPanel.value.isVisible,
        },
        'bottom': {
          'size': _bottomPanel.value.size,
          'isVisible': _bottomPanel.value.isVisible,
        },
      },
      'activeMiddlePanelIndex': _activeMiddlePanelIndex.value,
      'middlePanels': _middlePanels.value
          .map((panel) => panel.map((e) => e.uri.toString()).toList())
          .toList(),
    };
  }

  /// Restores layout state from a snapshot created by [toLayoutSnapshot].
  ///
  /// Panel sizes and visibility are restored immediately; editors are
  /// re-opened via [openFile].
  void loadLayoutSnapshot(Map<String, dynamic> snapshot) {
    final panels = snapshot['panels'];
    if (panels is Map<String, dynamic>) {
      for (final entry in panels.entries) {
        final location = ForgePanelLocation.values
            .where((l) => l.name == entry.key)
            .firstOrNull;
        if (location == null || location == ForgePanelLocation.middle) continue;
        final data = entry.value;
        if (data is Map<String, dynamic>) {
          final size = data['size'];
          final isVisible = data['isVisible'];
          if (size is num) setPanelSize(location, size.toDouble());
          if (isVisible is bool) {
            if (isVisible) {
              openPanel(location);
            } else {
              closePanel(location);
            }
          }
        }
      }
    }

    final activeIdx = snapshot['activeMiddlePanelIndex'];
    if (activeIdx is int) {
      _activeMiddlePanelIndex.value = activeIdx;
    }

    final middlePanelUris = snapshot['middlePanels'];
    if (middlePanelUris is List) {
      for (var i = 0; i < middlePanelUris.length; i++) {
        final panelUris = middlePanelUris[i];
        if (panelUris is List) {
          for (final uriStr in panelUris) {
            if (uriStr is String) {
              try {
                openFile(Uri.parse(uriStr), middlePanelIndex: i);
              } catch (_) {}
            }
          }
        }
      }
    }
  }

  /// Dispose notifiers.
  void dispose() {
    _leftPanel.dispose();
    _rightPanel.dispose();
    _bottomPanel.dispose();
    _middlePanels.dispose();
    _activeMiddlePanelIndex.dispose();
    pendingEditorChoice.dispose();
  }
}
