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

  /// Tracks dirty-state listeners attached to open editors.
  final Map<ForgeEditor, VoidCallback> _editorDirtyListeners = {};

  /// Cleanup callback for selection listener on active editor.
  VoidCallback? _selectionCleanup;

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
  final _onApplicationChanged =
      StreamController<ApplicationChangeEvent>.broadcast();

  /// Per-application state storage for open editors and layout.
  /// Maps application title to { 'openEditors': List<Uri>, 'activeEditor': Uri? }.
  final Map<String, Map<String, dynamic>> _applicationStates = {};

  /// Tracks last-active timestamp per application for resource management.
  final Map<String, DateTime> _applicationLastActive = {};

  /// Maximum number of application states kept in memory before
  /// least-recently-active states are evicted.
  final int maxApplicationStates;

  DefaultSystemState({
    String workspaceRootPath = '/',
    ForgeApplication? initialApplication,
    this.maxApplicationStates = 10,
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
    if (active == null) return false;
    return active.hasTextSelection;
  }

  @override
  List<Uri> get selectedExplorerItems => _selectedExplorerItems.value;

  ValueListenable<List<Uri>> get selectedExplorerItemsListenable =>
      _selectedExplorerItems;

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
  Stream<ApplicationChangeEvent> get onApplicationChanged =>
      _onApplicationChanged.stream;

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
    _cleanupSelectionListener();
    _activeEditor.value = editor;
    if (editor != null) {
      setFocusedComponent(editor);
      _setupSelectionListener(editor);
    }
  }

  /// Fire a text-selection-changed event for the given editor.
  ///
  /// Used by adapters (e.g. YAML text mode) that report selection changes
  /// through the integration context rather than a [ForgeTextEditor]
  /// selection [ValueListenable].
  void notifyTextSelectionChanged(ForgeEditor editor) {
    _onTextSelectionChanged.add(TextSelectionChangeEvent(
      editor: editor,
      selection: null,
    ));
  }

  void addOpenEditor(ForgeEditor editor) {
    _openEditors.value = [..._openEditors.value, editor];
    _onEditorsChanged.add(EditorListChangeEvent(opened: [editor]));

    // Track dirty state changes for this editor.
    void dirtyChanged() {
      updateDirtyEditors();
      _onDirtyStateChanged.add(DirtyStateEvent(
        editor: editor,
        isDirty: editor.isDirty.value,
      ));
    }
    _editorDirtyListeners[editor] = dirtyChanged;
    editor.isDirty.addListener(dirtyChanged);
  }

  void removeOpenEditor(ForgeEditor editor) {
    _openEditors.value =
        _openEditors.value.where((e) => e != editor).toList();
    _onEditorsChanged.add(EditorListChangeEvent(closed: [editor]));

    // Clean up dirty-state listener.
    final listener = _editorDirtyListeners.remove(editor);
    if (listener != null) {
      editor.isDirty.removeListener(listener);
    }

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

  /// Panel cycle order for focus navigation.
  static const _panelCycleOrder = [
    ForgePanelLocation.left,
    ForgePanelLocation.middle,
    ForgePanelLocation.right,
    ForgePanelLocation.bottom,
  ];

  @override
  void focusNextPanel() {
    final visible = _visiblePanels.value;
    if (visible.isEmpty) return;
    final ordered = _panelCycleOrder.where(visible.contains).toList();
    if (ordered.isEmpty) return;
    final current = focusedPanelLocation;
    final idx = current != null ? ordered.indexOf(current) : -1;
    final next = ordered[(idx + 1) % ordered.length];
    setFocusedPanelLocation(next);
  }

  @override
  void focusPreviousPanel() {
    final visible = _visiblePanels.value;
    if (visible.isEmpty) return;
    final ordered = _panelCycleOrder.where(visible.contains).toList();
    if (ordered.isEmpty) return;
    final current = focusedPanelLocation;
    final idx = current != null ? ordered.indexOf(current) : -1;
    final prev = idx <= 0 ? ordered.last : ordered[idx - 1];
    setFocusedPanelLocation(prev);
  }

  void setWorkspaceRootPath(String path) {
    _workspaceRootPath = path;
  }

  void setApplications(List<ForgeApplication> apps) {
    _applications = apps;
  }

  /// Switches to the specified application, preserving the previous app's state
  /// and restoring the new app's saved state.
  ///
  /// Emits [ApplicationChangeEvent] to notify listeners of the switch.
  /// When the number of stored application states exceeds
  /// [maxApplicationStates], the least-recently-active state is evicted.
  void setActiveApplication(ForgeApplication app) {
    if (_activeApplication == app) return;

    final previous = _activeApplication;

    // Save current application state before switching
    _saveApplicationState(previous);
    _applicationLastActive[previous.title] = DateTime.now();

    // Mark previous as inactive, new as active
    previous.isActive = false;
    app.isActive = true;

    _activeApplication = app;
    _applicationLastActive[app.title] = DateTime.now();

    // Restore new application state (if any saved)
    _restoreApplicationState(app);

    // Evict least-recently-active application states if over limit.
    _evictStaleApplicationStates();

    // Emit application change event
    _onApplicationChanged.add(ApplicationChangeEvent(
      previous: previous,
      current: app,
      isInitial: false,
    ));
  }

  /// Evicts the least-recently-active application state entries when
  /// the stored count exceeds [maxApplicationStates].
  void _evictStaleApplicationStates() {
    while (_applicationStates.length > maxApplicationStates) {
      // Find the oldest non-active application.
      String? oldest;
      DateTime? oldestTime;
      for (final title in _applicationStates.keys) {
        if (title == _activeApplication.title) continue;
        final lastActive =
            _applicationLastActive[title] ?? DateTime(2000);
        if (oldestTime == null || lastActive.isBefore(oldestTime)) {
          oldestTime = lastActive;
          oldest = title;
        }
      }
      if (oldest == null) break;
      _applicationStates.remove(oldest);
      _applicationLastActive.remove(oldest);
    }
  }

  /// Saves the current state of an application (open editors, active editor).
  void _saveApplicationState(ForgeApplication app) {
    _applicationStates[app.title] = {
      'openEditors': _openEditors.value.map((e) => e.uri).whereType<Uri>().toList(),
      'activeEditor': _activeEditor.value?.uri,
    };
  }

  /// Restores a previously saved application state.
  /// Does not re-open editors — that's handled by the layout controller.
  void _restoreApplicationState(ForgeApplication app) {
    final state = _applicationStates[app.title];
    if (state == null) {
      // First time activating this app — start fresh
      _openEditors.value = [];
      _activeEditor.value = null;
      _onEditorsChanged.add(const EditorListChangeEvent(opened: [], closed: []));
      return;
    }
    // Note: The actual editor instances are managed by the layout controller.
    // This just clears the current state; the scaffold will restore editors.
  }

  /// Returns saved state for an application (for persistence).
  Map<String, dynamic>? getApplicationState(String appTitle) {
    return _applicationStates[appTitle];
  }

  /// Restores application state from external source (e.g., disk).
  void restoreApplicationStateFromPersistence(
    String appTitle,
    Map<String, dynamic> state,
  ) {
    _applicationStates[appTitle] = state;
  }

  /// Sets up selection/cursor listeners on the active editor.
  void _setupSelectionListener(ForgeEditor editor) {
    if (editor is ForgeTextEditor) {
      void onSelChanged() {
        final sel = editor.selection.value;
        _onSelectionChanged.add(SelectionChangeEvent(
          component: editor,
          selection: sel,
        ));
        _onTextSelectionChanged.add(TextSelectionChangeEvent(
          editor: editor,
          selection: sel,
        ));
      }
      editor.selection.addListener(onSelChanged);
      _selectionCleanup = () {
        editor.selection.removeListener(onSelChanged);
      };
    }
  }

  /// Removes selection listener from the previously active editor.
  void _cleanupSelectionListener() {
    _selectionCleanup?.call();
    _selectionCleanup = null;
  }

  /// Dispose all controllers and notifiers.
  void dispose() {
    _cleanupSelectionListener();
    // Clean up all dirty-state listeners.
    for (final entry in _editorDirtyListeners.entries) {
      entry.key.isDirty.removeListener(entry.value);
    }
    _editorDirtyListeners.clear();
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
    _onApplicationChanged.close();
  }
}
