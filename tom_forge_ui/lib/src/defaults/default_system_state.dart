import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
  show ForgeTextContext;

import '../components/forge_component.dart';
import '../components/forge_editor.dart';
import '../components/forge_text_editor.dart';
import '../model/forge_application.dart';
import '../shell/forge_system_state.dart';

/// Default implementation of [ForgeSystemState].
///
/// Uses [ValueNotifier] for mutable state and
/// [StreamController.broadcast] for all event streams.
/// Exposes setter methods for internal shell use.
class DefaultSystemState implements ForgeSystemState {
  static bool debugEnabled = false;

  final _focusedComponent = ValueNotifier<ForgeComponent?>(null);
  final _openEditors = ValueNotifier<List<ForgeEditor>>([]);
  final _activeEditor = ValueNotifier<ForgeEditor?>(null);
  final _dirtyEditors = ValueNotifier<List<ForgeEditor>>([]);
  final _selectedExplorerItems = ValueNotifier<List<Uri>>([]);
  final _hoveredExplorerItem = ValueNotifier<Uri?>(null);
  final _diagnosticSummary =
      ValueNotifier<DiagnosticSummary>(const DiagnosticSummary());
  final _diagnostics = ValueNotifier<List<ForgeDiagnostic>>([]);
  final _searchQuery = ValueNotifier<String>('');
  final _isSearchActive = ValueNotifier<bool>(false);
  final _isWindowFocused = ValueNotifier<bool>(true);
  final _visiblePanels =
      ValueNotifier<Set<ForgePanelLocation>>(Set.of(ForgePanelLocation.values));
  final _middlePanelCount = ValueNotifier<int>(1);
  final _activeMiddlePanelIndex = ValueNotifier<int>(0);
  final Map<String, ForgeTextContext> _editorContexts = {};

  late ForgeApplication _activeApplication;
  List<ForgeApplication> _applications = [];
  String _workspaceRootPath;

  // ── Event streams ──
  final _onFocusChanged = StreamController<FocusChangeEvent>.broadcast();
  final _onDirtyStateChanged = StreamController<DirtyStateEvent>.broadcast();
  final _onSelectionChanged =
      StreamController<SelectionChangeEvent>.broadcast();
  final _onTextSelectionChanged =
      StreamController<TextSelectionChangeEvent>.broadcast();
  final _onDiagnosticsChanged =
      StreamController<DiagnosticChangeEvent>.broadcast();
  final _onEditorsChanged =
      StreamController<EditorListChangeEvent>.broadcast();
  final _onWindowFocusChanged =
      StreamController<WindowFocusEvent>.broadcast();
  final _onLayoutChanged = StreamController<LayoutChangeEvent>.broadcast();

  DefaultSystemState({
    String workspaceRootPath = '/',
    ForgeApplication? initialApplication,
  }) : _workspaceRootPath = workspaceRootPath {
    _activeApplication = initialApplication ??
        ForgeApplication(title: 'Default', isActive: true);
    _applications = [_activeApplication];
  }

  // ── ForgeSystemState getters ──

  @override
  ForgeComponent? get focusedComponent => _focusedComponent.value;

  @override
  bool get isFocusedComponentMain =>
      _focusedComponent.value == _activeEditor.value;

  @override
  ForgePanelLocation? get focusedPanelLocation {
    if (_focusedComponent.value is ForgeEditor) {
      return ForgePanelLocation.middle;
    }
    return null;
  }

  @override
  List<ForgeEditor> get openEditors => _openEditors.value;

  @override
  ForgeEditor? get activeEditor => _activeEditor.value;

  ValueListenable<ForgeEditor?> get activeEditorListenable => _activeEditor;

  @override
  List<ForgeEditor> get dirtyEditors => _dirtyEditors.value;

  @override
  bool get hasUnsavedChanges => _dirtyEditors.value.isNotEmpty;

  @override
  String? get focusedSelectedText {
    final active = _activeEditor.value;
    if (active is ForgeTextEditor) {
      return active.selectedText;
    }
    return null;
  }

  @override
  bool get hasTextSelection {
    final active = _activeEditor.value;
    if (active is ForgeTextEditor) {
      return active.hasSelection;
    }
    return false;
  }

  @override
  List<Uri> get selectedExplorerItems => _selectedExplorerItems.value;

  @override
  Uri? get hoveredExplorerItem => _hoveredExplorerItem.value;

  @override
  DiagnosticSummary get diagnosticSummary => _diagnosticSummary.value;

  @override
  List<ForgeDiagnostic> get diagnostics => _diagnostics.value;

  @override
  String get workspaceRootPath => _workspaceRootPath;

  @override
  ForgeApplication get activeApplication => _activeApplication;

  @override
  List<ForgeApplication> get applications => _applications;

  @override
  Set<ForgePanelLocation> get visiblePanels => _visiblePanels.value;

  @override
  int get middlePanelCount => _middlePanelCount.value;

  @override
  int get activeMiddlePanelIndex => _activeMiddlePanelIndex.value;

  @override
  bool get isWindowFocused => _isWindowFocused.value;

  @override
  String get searchQuery => _searchQuery.value;

  @override
  bool get isSearchActive => _isSearchActive.value;

  // ── Streams ──

  @override
  Stream<FocusChangeEvent> get onFocusChanged => _onFocusChanged.stream;

  @override
  Stream<DirtyStateEvent> get onDirtyStateChanged =>
      _onDirtyStateChanged.stream;

  @override
  Stream<SelectionChangeEvent> get onSelectionChanged =>
      _onSelectionChanged.stream;

  @override
  Stream<TextSelectionChangeEvent> get onTextSelectionChanged =>
      _onTextSelectionChanged.stream;

  @override
  Stream<DiagnosticChangeEvent> get onDiagnosticsChanged =>
      _onDiagnosticsChanged.stream;

  @override
  Stream<EditorListChangeEvent> get onEditorsChanged =>
      _onEditorsChanged.stream;

  @override
  Stream<WindowFocusEvent> get onWindowFocusChanged =>
      _onWindowFocusChanged.stream;

  @override
  Stream<LayoutChangeEvent> get onLayoutChanged => _onLayoutChanged.stream;

  @override
  void updateEditorContext(String editorId, ForgeTextContext context) {
    _editorContexts[editorId] = context;
  }

  @override
  ForgeTextContext? getEditorContext(String editorId) {
    return _editorContexts[editorId];
  }

  // ── Setter methods for internal shell use ──

  void setFocusedComponent(ForgeComponent? component) {
    final previous = _focusedComponent.value;
    _focusedComponent.value = component;
    _onFocusChanged.add(FocusChangeEvent(
      previous: previous,
      current: component,
    ));
  }

  void setActiveEditor(ForgeEditor? editor) {
    _activeEditor.value = editor;
    if (editor != null) {
      setFocusedComponent(editor);
    }
  }

  void addOpenEditor(ForgeEditor editor) {
    _openEditors.value = [..._openEditors.value, editor];
    _onEditorsChanged.add(EditorListChangeEvent(opened: [editor]));
  }

  void removeOpenEditor(ForgeEditor editor) {
    _openEditors.value =
        _openEditors.value.where((e) => e != editor).toList();
    _onEditorsChanged.add(EditorListChangeEvent(closed: [editor]));
    if (_activeEditor.value == editor) {
      _activeEditor.value =
          _openEditors.value.isNotEmpty ? _openEditors.value.last : null;
    }
  }

  void updateDirtyEditors() {
    _dirtyEditors.value =
        _openEditors.value.where((e) => e.isDirty.value).toList();
  }

  void setDiagnostics(List<ForgeDiagnostic> diags) {
    _diagnostics.value = diags;
    var errors = 0;
    var warnings = 0;
    var infos = 0;
    for (final d in diags) {
      switch (d.severity) {
        case ForgeSeverity.error:
          errors++;
        case ForgeSeverity.warning:
          warnings++;
        case ForgeSeverity.info:
        case ForgeSeverity.hint:
          infos++;
      }
    }
    _diagnosticSummary.value = DiagnosticSummary(
      errors: errors,
      warnings: warnings,
      infos: infos,
    );
    _onDiagnosticsChanged.add(
        DiagnosticChangeEvent(uris: diags.map((d) => d.uri).toSet().toList()));
  }

  void setSelectedExplorerItems(List<Uri> items) {
    _selectedExplorerItems.value = items;
  }

  void setHoveredExplorerItem(Uri? item) {
    _hoveredExplorerItem.value = item;
  }

  void setSearchQuery(String query) {
    _searchQuery.value = query;
  }

  void setSearchActive(bool active) {
    _isSearchActive.value = active;
  }

  void setWindowFocused(bool focused) {
    _isWindowFocused.value = focused;
    _onWindowFocusChanged.add(WindowFocusEvent(focused: focused));
  }

  void setVisiblePanels(Set<ForgePanelLocation> panels) {
    _visiblePanels.value = panels;
  }

  void setMiddlePanelCount(int count) {
    _middlePanelCount.value = count;
  }

  void setActiveMiddlePanelIndex(int index) {
    _activeMiddlePanelIndex.value = index;
  }

  /// Sets the focused panel location, ensuring it is visible.
  void setFocusedPanelLocation(ForgePanelLocation location) {
    // Update visible panels to include this location if not visible
    if (!_visiblePanels.value.contains(location)) {
      _visiblePanels.value = {..._visiblePanels.value, location};
      _onLayoutChanged.add(LayoutChangeEvent(
        type: LayoutChangeType.panelOpened,
        panel: location,
      ));
    }
    // Clear component focus when moving to a panel
    _focusedComponent.value = null;
  }

  void setWorkspaceRootPath(String path) {
    _workspaceRootPath = path;
  }

  void setApplications(List<ForgeApplication> apps) {
    _applications = apps;
  }

  void setActiveApplication(ForgeApplication app) {
    _activeApplication = app;
  }

  /// Dispose all controllers and notifiers.
  void dispose() {
    _focusedComponent.dispose();
    _openEditors.dispose();
    _activeEditor.dispose();
    _dirtyEditors.dispose();
    _selectedExplorerItems.dispose();
    _hoveredExplorerItem.dispose();
    _diagnosticSummary.dispose();
    _diagnostics.dispose();
    _searchQuery.dispose();
    _isSearchActive.dispose();
    _isWindowFocused.dispose();
    _visiblePanels.dispose();
    _middlePanelCount.dispose();
    _activeMiddlePanelIndex.dispose();
    _onFocusChanged.close();
    _onDirtyStateChanged.close();
    _onSelectionChanged.close();
    _onTextSelectionChanged.close();
    _onDiagnosticsChanged.close();
    _onEditorsChanged.close();
    _onWindowFocusChanged.close();
    _onLayoutChanged.close();
  }
}
