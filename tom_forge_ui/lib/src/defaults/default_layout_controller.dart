import 'dart:async';
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
import '../adapters/tom_forge_shell_module.dart';
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
/// Includes LRU-based editor eviction: when the number of open editors
/// exceeds [maxOpenEditors], the least-recently-focused non-dirty editor
/// is automatically closed.
class DefaultLayoutController implements ForgeLayoutController {
  static bool debugEnabled = false;
  static const String _extMarkdown = 'md';
  static const String _extMarkdownAlt = 'markdown';
  static const String _extDart = 'dart';
  static const String _extYaml = 'yaml';
  static const String _extYml = 'yml';

  final DefaultSystemState _systemState;
  final ForgeFileSystem _fileSystem;
  final ForgeModuleRegistry _moduleRegistry;
  final DefaultVirtualDocumentManager? _virtualDocuments;

  /// Maximum open editors before LRU eviction kicks in.
  final int maxOpenEditors;

  /// Tracks the last-focused timestamp per editor for LRU ordering.
  final Map<ForgeEditor, DateTime> _editorLastFocused = {};

  /// Preferred default editor ids keyed by file extension (including dot).
  final Map<String, String> _fileTypeDefaultEditors = {};

  /// Late-bound diagnostic manager for emitting editor fallback diagnostics.
  ForgeDiagnosticManager? diagnosticManager;

  /// Late-bound notification manager for open-file recovery warnings.
  ForgeNotificationManager? notificationManager;

  ForgeDiagnosticCollection? _openRecoveryDiagnostics;

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
    this.maxOpenEditors = 20,
  }) : _systemState = systemState,
       _fileSystem = fileSystem,
       _moduleRegistry = moduleRegistry,
       _virtualDocuments = virtualDocuments,
       _leftPanel = ValueNotifier(
         LayoutPanelConfig(size: leftSize, isVisible: true),
       ),
       _rightPanel = ValueNotifier(
         LayoutPanelConfig(size: rightSize, isVisible: true),
       ),
       _bottomPanel = ValueNotifier(
         LayoutPanelConfig(size: bottomSize, isVisible: true),
       ),
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
    if (component is ForgeEditor) {
      _editorLastFocused[component] = DateTime.now();
    }
  }

  /// Creates an editor for the given URI without adding it to any panel.
  ///
  /// Returns `null` if the content cannot be read or no editor can handle it.
  Future<ForgeEditor?> createEditorForUri(Uri uri) async {
    // Check if already open — return the existing instance.
    final existing = _systemState.openEditors.where((e) => e.uri == uri);
    if (existing.isNotEmpty) return existing.first;

    try {
      final content = await _resolveContent(uri);
      if (content == null) return null;
      return _createEditor(uri, content);
    } catch (_) {
      return null;
    }
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

    unawaited(
      _openFileWithRecovery(
        uri,
        middlePanelIndex: middlePanelIndex,
        line: line,
        column: column,
      ),
    );
  }

  Future<void> _openFileWithRecovery(
    Uri uri, {
    int? middlePanelIndex,
    int? line,
    int? column,
  }) async {
    var timeoutAttempts = 0;
    String? content;

    // Resolve content from virtual document provider or file system.
    try {
      content = await ForgeRetryPolicy.withImmediateRetry<String?>(
        operation: () async {
          try {
            return await _resolveContent(uri);
          } on TimeoutException catch (error) {
            timeoutAttempts++;
            _reportOpenTimeoutAttempt(uri, timeoutAttempts, error);
            rethrow;
          }
        },
        maxAttempts: 3,
        retryableErrors: const {TimeoutException},
      );
    } on TimeoutException catch (error) {
      _reportOpenTimeoutExhausted(uri, timeoutAttempts, error);
      return;
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultLayoutController] openFile error: $e');
      }
      _reportOpenFailure(uri, e);
      return;
    }

    _clearOpenRecoveryDiagnostic(uri);
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
  }

  void _reportOpenTimeoutAttempt(Uri uri, int attempt, TimeoutException error) {
    final message =
        'Open timed out for "$uri" (attempt $attempt/3). Retrying...';
    _setOpenRecoveryDiagnostic(
      uri,
      message: message,
      severity: ForgeSeverity.warning,
    );
    notificationManager?.showWarning(message);
  }

  void _reportOpenTimeoutExhausted(
    Uri uri,
    int attempt,
    TimeoutException error,
  ) {
    final effectiveAttempts = attempt == 0 ? 3 : attempt;
    final message =
        'Open failed for "$uri" after $effectiveAttempts retries: $error';
    _setOpenRecoveryDiagnostic(
      uri,
      message: message,
      severity: ForgeSeverity.warning,
    );
    notificationManager?.showWarning(message);
  }

  void _reportOpenFailure(Uri uri, Object error) {
    final message = 'Failed to open "$uri": $error';
    _setOpenRecoveryDiagnostic(
      uri,
      message: message,
      severity: ForgeSeverity.error,
    );
    notificationManager?.showError(message);
  }

  void _setOpenRecoveryDiagnostic(
    Uri uri, {
    required String message,
    required ForgeSeverity severity,
  }) {
    final dm = diagnosticManager;
    if (dm == null) return;
    _openRecoveryDiagnostics ??= dm.createCollection('editor-open-recovery');
    _openRecoveryDiagnostics!.set(uri, [
      ForgeDiagnostic(
        uri: uri,
        range: const ForgeTextRange.empty(),
        message: message,
        severity: severity,
        source: 'forge-shell',
        code: ForgeErrorCodes.edLoadFailed,
        category: DiagnosticCategory.system,
      ),
    ]);
  }

  void _clearOpenRecoveryDiagnostic(Uri uri) {
    _openRecoveryDiagnostics?.set(uri, const []);
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
      _editorLastFocused[editor] = DateTime.now();
      return;
    }
    _systemState.addOpenEditor(editor);
    _systemState.setActiveEditor(editor);
    _editorLastFocused[editor] = DateTime.now();

    final panelIdx = middlePanelIndex ?? _activeMiddlePanelIndex.value;
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    if (panelIdx < panels.length) {
      panels[panelIdx] = [...panels[panelIdx], editor];
    }
    _middlePanels.value = panels;

    _evictLruEditors();
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

    final preferredTypeId =
        _fileTypeDefaultEditors[_normalizeExtension(_extensionForUri(uri))];
    if (preferredTypeId != null) {
      final preferred = candidates
          .where(
            (editor) => _editorTypeIdForCandidate(editor) == preferredTypeId,
          )
          .firstOrNull;
      if (preferred != null) {
        resolveEditorChoice(preferred, uri, middlePanelIndex: middlePanelIndex);
        return;
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
  void resolveEditorChoice(
    ForgeEditor editor,
    Uri uri, {
    int? middlePanelIndex,
  }) {
    pendingEditorChoice.value = null;
    openEditor(editor, uri, middlePanelIndex: middlePanelIndex);
  }

  /// Sets the preferred default editor id for a file extension.
  void setFileTypeDefaultEditor(String extension, String editorTypeId) {
    _fileTypeDefaultEditors[_normalizeExtension(extension)] = editorTypeId;
  }

  /// Clears the preferred default editor id for a file extension.
  void clearFileTypeDefaultEditor(String extension) {
    _fileTypeDefaultEditors.remove(_normalizeExtension(extension));
  }

  /// Returns preferred default editor id for a file extension.
  String? getFileTypeDefaultEditor(String extension) {
    return _fileTypeDefaultEditors[_normalizeExtension(extension)];
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
  void splitAndInsertPanel(int position, ForgeEditor editor) {
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    if (panels.length >= 4) return;
    // Remove editor from its current panel.
    for (var i = 0; i < panels.length; i++) {
      panels[i] = panels[i].where((e) => e != editor).toList();
    }
    // Insert a new panel at the requested position.
    final insertAt = position.clamp(0, panels.length);
    panels.insert(insertAt, [editor]);
    // Remove any empty panels (keep at least one).
    panels.removeWhere((p) => p.isEmpty);
    if (panels.isEmpty) panels.add([]);
    // Find the panel that now contains the editor.
    final newIdx = panels.indexWhere((p) => p.contains(editor));
    _middlePanels.value = panels;
    _activeMiddlePanelIndex.value = (newIdx >= 0 ? newIdx : 0).clamp(
      0,
      panels.length - 1,
    );
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
    // Remove any empty panels (keep at least one).
    panels.removeWhere((p) => p.isEmpty);
    if (panels.isEmpty) panels.add([]);
    // Find the panel that now contains the component.
    final newTarget = panels.indexWhere((p) => p.contains(component));
    _middlePanels.value = panels;
    _systemState.setMiddlePanelCount(panels.length);
    _activeMiddlePanelIndex.value = (newTarget >= 0 ? newTarget : 0).clamp(
      0,
      panels.length - 1,
    );
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
    _activeMiddlePanelIndex.value = targetPanelIndex.clamp(
      0,
      panels.length - 1,
    );
  }

  /// Close a specific editor.
  void closeEditor(ForgeEditor editor) {
    _systemState.removeOpenEditor(editor);
    _editorLastFocused.remove(editor);
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    for (var i = 0; i < panels.length; i++) {
      panels[i] = panels[i].where((e) => e != editor).toList();
    }
    // Remove any empty panels (keep at least one).
    panels.removeWhere((p) => p.isEmpty);
    if (panels.isEmpty) panels.add([]);
    _middlePanels.value = panels;
    _activeMiddlePanelIndex.value = _activeMiddlePanelIndex.value.clamp(
      0,
      panels.length - 1,
    );
    _systemState.setMiddlePanelCount(panels.length);
    _systemState.updateDirtyEditors();
  }

  /// Close one rendered copy of an editor in a specific panel.
  ///
  /// If no copies remain after removal, the editor is fully closed.
  void closeEditorInPanel(ForgeEditor editor, int panelIndex) {
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    if (panelIndex < 0 || panelIndex >= panels.length) {
      closeEditor(editor);
      return;
    }

    final idx = panels[panelIndex].lastIndexOf(editor);
    if (idx == -1) {
      closeEditor(editor);
      return;
    }

    panels[panelIndex] = List<ForgeEditor>.from(panels[panelIndex])
      ..removeAt(idx);

    final stillOpen = panels.any((panel) => panel.contains(editor));
    if (!stillOpen) {
      _systemState.removeOpenEditor(editor);
      _editorLastFocused.remove(editor);
    }

    panels.removeWhere((p) => p.isEmpty);
    if (panels.isEmpty) panels.add([]);

    _middlePanels.value = panels;
    _activeMiddlePanelIndex.value = _activeMiddlePanelIndex.value.clamp(
      0,
      panels.length - 1,
    );
    _systemState.setMiddlePanelCount(panels.length);
    _systemState.updateDirtyEditors();
  }

  /// Close all open editors.
  void closeAllEditors() {
    for (final editor in List.of(_systemState.openEditors)) {
      _systemState.removeOpenEditor(editor);
    }
    _editorLastFocused.clear();
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

  @override
  void setActiveMiddlePanelIndex(int index) {
    _activeMiddlePanelIndex.value = index;
    _systemState.setActiveMiddlePanelIndex(index);
  }

  // ── Private helpers ──

  void _setPanelVisible(ForgePanelLocation location, bool visible) {
    final notifier = _panelNotifier(location);
    if (notifier == null) return;
    final current = notifier.value;
    notifier.value = LayoutPanelConfig(size: current.size, isVisible: visible);
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

  /// Resets all panel sizes to their constructor defaults.
  void resetPanelSizes({
    double leftSize = 250,
    double rightSize = 220,
    double bottomSize = 180,
  }) {
    setPanelSize(ForgePanelLocation.left, leftSize);
    setPanelSize(ForgePanelLocation.right, rightSize);
    setPanelSize(ForgePanelLocation.bottom, bottomSize);
  }

  ValueNotifier<LayoutPanelConfig>? _panelNotifier(
    ForgePanelLocation location,
  ) {
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
  ///
  /// If the number of open editors exceeds [maxOpenEditors], the
  /// least-recently-focused non-dirty editor is automatically closed.
  void _addEditorToPanel(ForgeEditor editor, {int? panelIdx}) {
    _systemState.addOpenEditor(editor);
    _systemState.setActiveEditor(editor);
    _editorLastFocused[editor] = DateTime.now();

    final idx = panelIdx ?? _activeMiddlePanelIndex.value;
    final panels = List<List<ForgeEditor>>.from(_middlePanels.value);
    if (idx < panels.length) {
      panels[idx] = [...panels[idx], editor];
    }
    _middlePanels.value = panels;

    _evictLruEditors();
  }

  /// Evict least-recently-focused non-dirty editors until the count
  /// is within [maxOpenEditors].
  void _evictLruEditors() {
    while (_systemState.openEditors.length > maxOpenEditors) {
      final candidate = _findLruCandidate();
      if (candidate == null) break; // All remaining editors are dirty.
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultLayoutController] LRU evicting: ${candidate.uri}');
      }
      closeEditor(candidate);
    }
  }

  /// Find the least-recently-focused non-dirty editor that is not the
  /// currently active editor.
  ForgeEditor? _findLruCandidate() {
    final active = _systemState.activeEditor;
    ForgeEditor? oldest;
    DateTime? oldestTime;

    for (final editor in _systemState.openEditors) {
      if (editor == active) continue;
      if (editor.isDirty.value) continue;

      final focusTime = _editorLastFocused[editor] ?? DateTime(2000);
      if (oldestTime == null || focusTime.isBefore(oldestTime)) {
        oldestTime = focusTime;
        oldest = editor;
      }
    }
    return oldest;
  }

  Future<ForgeEditor?> _createEditor(Uri uri, String content) async {
    final ext = _extensionForUri(uri);
    final normalizedExt = _normalizeExtension(ext);

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
        if (editor.canHandleContent(uri, bytes) == FileHandlingResult.accept) {
          return editor;
        }
      }
    }

    // Resolve owner module: prefer TomForgeShellModule for built-in editor
    // types, fall back to the first registered module.
    final ownerModule =
        _moduleRegistry.allModules
            .whereType<TomForgeShellModule>()
            .firstOrNull ??
        _moduleRegistry.allModules.firstOrNull;
    if (ownerModule == null) return null;

    final preferredTypeId = _fileTypeDefaultEditors[normalizedExt];
    if (preferredTypeId != null) {
      final preferred = _createBuiltInEditor(
        editorTypeId: preferredTypeId,
        uri: uri,
        content: content,
        ownerModule: ownerModule,
      );
      if (preferred != null) {
        return preferred;
      }
    }

    // Phase 3: Default creation for known extensions.
    final wildcardDefault = _fileTypeDefaultEditors['*'];
    final defaultTypeId = switch (ext) {
      _extMarkdown || _extMarkdownAlt => 'md',
      _extDart => 'dart',
      _extYaml || _extYml => 'yaml',
      _ => wildcardDefault ?? 'plaintext',
    };

    if (defaultTypeId == 'plaintext') {
      // Fallback to plain text editor when no specialized editor
      // is registered for the current file type.
      _emitFallbackDiagnostic(uri, ext);
    }

    return _createBuiltInEditor(
      editorTypeId: defaultTypeId,
      uri: uri,
      content: content,
      ownerModule: ownerModule,
    );
  }

  ForgeEditor? _createBuiltInEditor({
    required String editorTypeId,
    required Uri uri,
    required String content,
    required ForgeModule ownerModule,
  }) {
    switch (editorTypeId) {
      case 'md':
        final controller = MdEditorController(
          initialMarkdown: content,
          uri: uri,
        );
        return ForgeMdEditor(controller: controller, module: ownerModule);
      case 'dart':
        final controller = DartCodeController(initialCode: content, uri: uri);
        return ForgeDartEditor(controller: controller, module: ownerModule);
      case 'yaml':
        final controller = YamlEditorController(initialYaml: content, uri: uri);
        return ForgeYamlEditor(controller: controller, module: ownerModule);
      case 'plaintext':
        return ForgePlainTextEditor.fromContent(
          content: content,
          uri: uri,
          module: ownerModule,
        );
    }
    return null;
  }

  String _extensionForUri(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      return '';
    }
    final fileName = segments.last;
    if (!fileName.contains('.')) {
      return '';
    }
    return fileName.split('.').last.toLowerCase();
  }

  String _normalizeExtension(String extension) {
    if (extension.isEmpty) {
      return extension;
    }
    final lowered = extension.toLowerCase();
    if (lowered == '*') {
      return lowered;
    }
    return lowered.startsWith('.') ? lowered : '.$lowered';
  }

  String? _editorTypeIdForCandidate(ForgeEditor editor) {
    if (editor is ForgeMdEditor) return 'md';
    if (editor is ForgeDartEditor) return 'dart';
    if (editor is ForgeYamlEditor) return 'yaml';
    if (editor is ForgePlainTextEditor) return 'plaintext';
    return null;
  }

  /// Navigate an editor to a specific line/column if supported.
  void _navigateEditorTo(ForgeEditor editor, {int? line, int? column}) {
    if (line == null) return;
    if (editor is ForgeTextEditor) {
      final pos = ForgeTextPosition(line: line, column: column ?? 0);
      editor.revealPosition(pos);
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
        category: DiagnosticCategory.system,
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
      final panelCount = middlePanelUris.isEmpty ? 1 : middlePanelUris.length;
      _middlePanels.value = List<List<ForgeEditor>>.generate(
        panelCount,
        (_) => <ForgeEditor>[],
      );
      _systemState.setMiddlePanelCount(panelCount);

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
