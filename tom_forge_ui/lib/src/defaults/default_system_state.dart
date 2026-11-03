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
class DefaultSystemState
    implements ForgeSystemState, ForgeApplicationRegistry {
  static bool debugEnabled = false;

  final _focusedComponent = ValueNotifier<ForgeComponent?>(null);
  final _focusedPanelLocation = ValueNotifier<ForgePanelLocation?>(null);
  final _openEditors = ValueNotifier<List<ForgeEditor>>([]);
  final _activeEditor = ValueNotifier<ForgeEditor?>(null);
  final _dirtyEditors = ValueNotifier<List<ForgeEditor>>([]);
  final _selectedExplorerItems = ValueNotifier<List<Uri>>([]);
  final _hoveredExplorerItem = ValueNotifier<Uri?>(null);
  final _diagnosticSummary = ValueNotifier<DiagnosticSummary>(
    const DiagnosticSummary(),
  );
  final _diagnostics = ValueNotifier<List<ForgeDiagnostic>>([]);
  final _searchQuery = ValueNotifier<String>('');
  final _isSearchActive = ValueNotifier<bool>(false);
  final _isWindowFocused = ValueNotifier<bool>(true);
  final _visiblePanels = ValueNotifier<Set<ForgePanelLocation>>(
    Set.of(ForgePanelLocation.values),
  );
  final _middlePanelCount = ValueNotifier<int>(1);
  final _activeMiddlePanelIndex = ValueNotifier<int>(0);
  final Map<String, ForgeTextContext> _editorContexts = {};

  /// Tracks dirty-state listeners attached to open editors.
  final Map<ForgeEditor, VoidCallback> _editorDirtyListeners = {};

  final _applications = ValueNotifier<List<ForgeApplication>>(const []);
  ForgeApplication? _activeApplication;
  final Map<String, ForgeApplicationFactory> _factories = {};

  /// Snapshot entries [restore] could not recreate (no factory for their
  /// kind); [snapshot] writes them back so they are not lost.
  final List<Map<String, Object?>> _unrestored = [];

  /// Activation order, most recent last: removing the active application
  /// activates the one before it.
  final List<String> _activationOrder = [];

  /// Makes the per-start part of a fresh application id.
  int _idSequence = 0;
  String _workspaceRootPath;

  // ── Event streams ──
  final _onFocusChanged = StreamController<FocusChangeEvent>.broadcast();
  final _onDirtyStateChanged = StreamController<DirtyStateEvent>.broadcast();
  final _onDiagnosticsChanged =
      StreamController<DiagnosticChangeEvent>.broadcast();
  final _onEditorsChanged = StreamController<EditorListChangeEvent>.broadcast();
  final _onWindowFocusChanged = StreamController<WindowFocusEvent>.broadcast();
  final _onLayoutChanged = StreamController<LayoutChangeEvent>.broadcast();
  final _onApplicationChanged =
      StreamController<ApplicationChangeEvent>.broadcast();

  /// Per-application state storage for open editors and layout, keyed by
  /// application id.
  final Map<String, Map<String, dynamic>> _applicationStates = {};

  /// The open editor instances of each application not currently active, so
  /// switching back to it puts the same editors back in the list. Keyed like
  /// [_applicationStates]; the URIs there are what persistence writes.
  final Map<String, ({List<ForgeEditor> editors, ForgeEditor? active})>
  _liveEditorStates = {};

  /// Tracks last-active timestamp per application for resource management.
  final Map<String, DateTime> _applicationLastActive = {};

  /// Maximum number of application states kept in memory before
  /// least-recently-active states are evicted.
  final int maxApplicationStates;

  DefaultSystemState({
    String workspaceRootPath = '/',
    this.maxApplicationStates = 10,
  }) : _workspaceRootPath = workspaceRootPath;

  // ── ForgeSystemState getters ──

  @override
  ForgeComponent? get focusedComponent => _focusedComponent.value;

  @override
  bool get isFocusedComponentMain =>
      _focusedComponent.value == _activeEditor.value;

  @override
  ForgePanelLocation? get focusedPanelLocation => _focusedPanelLocation.value;

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
  ForgeApplication? get activeApplication => _activeApplication;

  @override
  List<ForgeApplication> get applications => _applications.value;

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
    if (component is ForgeEditor) {
      _focusedPanelLocation.value = ForgePanelLocation.middle;
    }
    _onFocusChanged.add(
      FocusChangeEvent(previous: previous, current: component),
    );
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

    // Track dirty state changes for this editor.
    void dirtyChanged() {
      updateDirtyEditors();
      _onDirtyStateChanged.add(
        DirtyStateEvent(editor: editor, isDirty: editor.isDirty.value),
      );
    }

    _editorDirtyListeners[editor] = dirtyChanged;
    editor.isDirty.addListener(dirtyChanged);
  }

  void removeOpenEditor(ForgeEditor editor) {
    _openEditors.value = _openEditors.value.where((e) => e != editor).toList();
    _onEditorsChanged.add(EditorListChangeEvent(closed: [editor]));

    // Clean up dirty-state listener.
    final listener = _editorDirtyListeners.remove(editor);
    if (listener != null) {
      editor.isDirty.removeListener(listener);
    }

    if (_activeEditor.value == editor) {
      _activeEditor.value = _openEditors.value.isNotEmpty
          ? _openEditors.value.last
          : null;
    }
  }

  void updateDirtyEditors() {
    _dirtyEditors.value = _openEditors.value
        .where((e) => e.isDirty.value)
        .toList();
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
      DiagnosticChangeEvent(uris: diags.map((d) => d.uri).toSet().toList()),
    );
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
      _onLayoutChanged.add(
        LayoutChangeEvent(type: LayoutChangeType.panelOpened, panel: location),
      );
    }
    _focusedPanelLocation.value = location;
    // Clear component focus when moving to a panel
    setFocusedComponent(null);
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

  // ── ForgeApplicationRegistry ──

  @override
  ValueListenable<List<ForgeApplication>> get listenable => _applications;

  @override
  List<ForgeApplication> get all => _applications.value;

  @override
  ForgeApplication? get active => _activeApplication;

  @override
  ForgeApplication? byId(String id) {
    for (final app in _applications.value) {
      if (app.id == id) return app;
    }
    return null;
  }

  ForgeApplication _require(String id) =>
      byId(id) ?? (throw StateError('no open application "$id"'));

  @override
  void registerFactory(ForgeApplicationFactory factory) {
    if (_factories.containsKey(factory.kind)) {
      throw StateError(
        'an application factory for "${factory.kind}" is already registered',
      );
    }
    _factories[factory.kind] = factory;
  }

  @override
  void add(ForgeApplication application, {bool activate = false}) {
    if (byId(application.id) != null) {
      throw StateError('an application "${application.id}" is already open');
    }
    application.isActive = false;
    _applications.value = [..._applications.value, application];
    if (activate || _activeApplication == null) {
      _activate(application);
    }
  }

  @override
  ForgeApplication open(
    String kind, {
    required String title,
    Map<String, Object?> payload = const {},
    bool activate = true,
  }) {
    final factory = _factories[kind];
    if (factory == null) {
      throw StateError('no application factory for "$kind"');
    }
    String id;
    do {
      id =
          '$kind-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
          '-${(_idSequence++).toRadixString(36)}';
    } while (byId(id) != null);
    final application = _create(factory, id, title, payload);
    add(application, activate: activate);
    return application;
  }

  ForgeApplication _create(
    ForgeApplicationFactory factory,
    String id,
    String title,
    Map<String, Object?> payload,
  ) {
    final application = factory.create(id: id, title: title, payload: payload);
    if (application.id != id || application.kind != factory.kind) {
      throw StateError(
        'the "${factory.kind}" factory made "${application.id}" of kind '
        '"${application.kind}" when asked for "$id"',
      );
    }
    return application;
  }

  @override
  void rename(String id, String title) {
    final application = _require(id);
    if (application.title == title) return;
    application.renameTo(title);
    _applications.value = [..._applications.value];
  }

  @override
  void remove(String id) {
    final application = _require(id);
    if (_applications.value.length == 1) {
      throw StateError('the last application "$id" cannot be removed');
    }
    if (identical(application, _activeApplication)) {
      final next = _activationOrder.reversed
          .where((other) => other != id)
          .map(byId)
          .whereType<ForgeApplication>()
          .firstOrNull ??
          _applications.value.firstWhere((other) => other.id != id);
      _activate(next);
    }
    _activationOrder.remove(id);
    _applicationStates.remove(id);
    _liveEditorStates.remove(id);
    _applicationLastActive.remove(id);
    _applications.value = [
      for (final other in _applications.value)
        if (other.id != id) other,
    ];
  }

  @override
  void activate(String id) => _activate(_require(id));

  @override
  Map<String, Object?> snapshot() => {
    'applications': [
      for (final app in _applications.value)
        if (app.isRestorable)
          {
            'id': app.id,
            'kind': app.kind,
            'title': app.title,
            'payload': app.payload,
          },
      ..._unrestored,
    ],
    'active': _activeApplication?.id,
  };

  @override
  void restore(Map<String, Object?> snapshot) {
    final entries = snapshot['applications'];
    if (entries is List) {
      for (final entry in entries.whereType<Map>()) {
        final id = entry['id'];
        final kind = entry['kind'];
        final title = entry['title'];
        final payload = entry['payload'];
        if (id is! String || kind is! String || title is! String) continue;
        if (byId(id) != null) continue;
        final factory = _factories[kind];
        if (factory == null) {
          _unrestored.add(Map<String, Object?>.from(entry));
          continue;
        }
        add(
          _create(
            factory,
            id,
            title,
            payload is Map ? Map<String, Object?>.from(payload) : const {},
          ),
        );
      }
    }
    final active = snapshot['active'];
    if (active is String && byId(active) != null) activate(active);
  }

  /// Makes [app] active, keeping the previous application's editors and
  /// putting [app]'s back.
  ///
  /// Emits [ApplicationChangeEvent] to notify listeners of the switch.
  /// When the number of stored application states exceeds
  /// [maxApplicationStates], the least-recently-active state is evicted.
  void _activate(ForgeApplication app) {
    final previous = _activeApplication;
    if (identical(previous, app)) return;

    if (previous != null) {
      _saveApplicationState(previous);
      _applicationLastActive[previous.id] = DateTime.now();
      previous.isActive = false;
    }
    app.isActive = true;
    _activeApplication = app;
    _applicationLastActive[app.id] = DateTime.now();
    _activationOrder
      ..remove(app.id)
      ..add(app.id);

    _restoreApplicationState(app);
    _evictStaleApplicationStates();

    _onApplicationChanged.add(
      ApplicationChangeEvent(
        previous: previous,
        current: app,
        isInitial: previous == null,
      ),
    );
    _applications.value = [..._applications.value];
  }

  /// Evicts the least-recently-active application state entries when
  /// the stored count exceeds [maxApplicationStates].
  void _evictStaleApplicationStates() {
    while (_applicationStates.length > maxApplicationStates) {
      // Find the oldest non-active application.
      String? oldest;
      DateTime? oldestTime;
      for (final id in _applicationStates.keys) {
        if (id == _activeApplication?.id) continue;
        final lastActive = _applicationLastActive[id] ?? DateTime(2000);
        if (oldestTime == null || lastActive.isBefore(oldestTime)) {
          oldestTime = lastActive;
          oldest = id;
        }
      }
      if (oldest == null) break;
      _applicationStates.remove(oldest);
      _liveEditorStates.remove(oldest);
      _applicationLastActive.remove(oldest);
    }
  }

  /// Saves the current state of an application (open editors, active editor).
  void _saveApplicationState(ForgeApplication app) {
    _applicationStates[app.id] = {
      'openEditors': _openEditors.value
          .map((e) => e.uri)
          .whereType<Uri>()
          .toList(),
      'activeEditor': _activeEditor.value?.uri,
    };
    _liveEditorStates[app.id] = (
      editors: _openEditors.value,
      active: _activeEditor.value,
    );
  }

  /// Puts [app]'s open editors back: the instances it had when it was last
  /// switched away from, or none when it has not been active in this session.
  void _restoreApplicationState(ForgeApplication app) {
    final live = _liveEditorStates.remove(app.id);
    _openEditors.value = live?.editors ?? const <ForgeEditor>[];
    _activeEditor.value = live?.active;
    // A switch neither opens nor closes an editor — the instances stay alive
    // with the application that holds them — so the event names none, and
    // nothing saves or restores per-editor state on its account.
    _onEditorsChanged.add(const EditorListChangeEvent(opened: [], closed: []));
  }

  /// Dispose all controllers and notifiers.
  void dispose() {
    // Clean up all dirty-state listeners.
    for (final entry in _editorDirtyListeners.entries) {
      entry.key.isDirty.removeListener(entry.value);
    }
    _editorDirtyListeners.clear();
    _focusedComponent.dispose();
    _openEditors.dispose();
    _applications.dispose();
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
    _onDiagnosticsChanged.close();
    _onEditorsChanged.close();
    _onWindowFocusChanged.close();
    _onLayoutChanged.close();
    _onApplicationChanged.close();
  }
}
