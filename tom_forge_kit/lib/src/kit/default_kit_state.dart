import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_editors_shared/text_types.dart' show ForgeTextContext;
import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_component.dart';
import '../components/forge_editor.dart';
import '../components/forge_text_editor.dart';
import 'forge_kit_state.dart';

/// A [ForgeKitState] its host feeds: the host reports the editors it shows
/// ([addOpenEditor]), closes ([removeOpenEditor]) and focuses
/// ([setActiveEditor], [setFocusedComponent]), and the diagnostics
/// ([setDiagnostics]); the state derives the rest (the unsaved editors, the
/// summary) and reports every change on its streams.
class DefaultKitState implements ForgeKitState {
  ForgeComponent? _focusedComponent;
  ForgeEditor? _activeEditor;
  List<ForgeEditor> _openEditors = const [];
  List<ForgeEditor> _dirtyEditors = const [];
  List<ForgeDiagnostic> _diagnostics = const [];
  DiagnosticSummary _diagnosticSummary = const DiagnosticSummary();
  final Map<String, ForgeTextContext> _editorContexts = {};
  final Map<ForgeEditor, VoidCallback> _dirtyListeners = {};

  final _onFocusChanged = StreamController<FocusChangeEvent>.broadcast();
  final _onDirtyStateChanged = StreamController<DirtyStateEvent>.broadcast();
  final _onDiagnosticsChanged =
      StreamController<DiagnosticChangeEvent>.broadcast();
  final _onEditorsChanged = StreamController<EditorListChangeEvent>.broadcast();

  @override
  ForgeComponent? get focusedComponent => _focusedComponent;

  @override
  List<ForgeEditor> get openEditors => _openEditors;

  @override
  ForgeEditor? get activeEditor => _activeEditor;

  @override
  List<ForgeEditor> get dirtyEditors => _dirtyEditors;

  @override
  bool get hasUnsavedChanges => _dirtyEditors.isNotEmpty;

  @override
  String? get focusedSelectedText {
    final active = _activeEditor;
    return active is ForgeTextEditor ? active.selectedText : null;
  }

  @override
  DiagnosticSummary get diagnosticSummary => _diagnosticSummary;

  @override
  List<ForgeDiagnostic> get diagnostics => _diagnostics;

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
  void updateEditorContext(String editorId, ForgeTextContext context) {
    _editorContexts[editorId] = context;
  }

  @override
  ForgeTextContext? getEditorContext(String editorId) =>
      _editorContexts[editorId];

  // ── What the host reports ──

  /// The focus moved to [component] (null: to nothing the kit knows).
  void setFocusedComponent(ForgeComponent? component) {
    final previous = _focusedComponent;
    _focusedComponent = component;
    _onFocusChanged.add(
      FocusChangeEvent(previous: previous, current: component),
    );
  }

  /// [editor] is the one the user works in now; it takes the focus.
  void setActiveEditor(ForgeEditor? editor) {
    _activeEditor = editor;
    if (editor != null) setFocusedComponent(editor);
  }

  /// [editor] is shown; its unsaved state is followed from now on. An editor
  /// already reported is left as it is.
  void addOpenEditor(ForgeEditor editor) {
    if (_openEditors.contains(editor)) return;
    _openEditors = [..._openEditors, editor];
    _onEditorsChanged.add(EditorListChangeEvent(opened: [editor]));
    void dirtyChanged() {
      _updateDirtyEditors();
      _onDirtyStateChanged.add(
        DirtyStateEvent(editor: editor, isDirty: editor.isDirty.value),
      );
    }

    _dirtyListeners[editor] = dirtyChanged;
    editor.isDirty.addListener(dirtyChanged);
    _updateDirtyEditors();
  }

  /// [editor] is closed. When it was the active one, the last opened editor
  /// becomes active.
  void removeOpenEditor(ForgeEditor editor) {
    if (!_openEditors.contains(editor)) return;
    _openEditors = [
      for (final open in _openEditors)
        if (!identical(open, editor)) open,
    ];
    _onEditorsChanged.add(EditorListChangeEvent(closed: [editor]));
    final listener = _dirtyListeners.remove(editor);
    if (listener != null) editor.isDirty.removeListener(listener);
    _updateDirtyEditors();
    if (identical(_activeEditor, editor)) {
      _activeEditor = _openEditors.isEmpty ? null : _openEditors.last;
    }
    if (identical(_focusedComponent, editor)) {
      setFocusedComponent(_activeEditor);
    }
  }

  /// The diagnostics now; the summary is counted from them.
  void setDiagnostics(List<ForgeDiagnostic> diagnostics) {
    _diagnostics = diagnostics;
    var errors = 0;
    var warnings = 0;
    var infos = 0;
    for (final d in diagnostics) {
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
    _diagnosticSummary = DiagnosticSummary(
      errors: errors,
      warnings: warnings,
      infos: infos,
    );
    _onDiagnosticsChanged.add(
      DiagnosticChangeEvent(
        uris: diagnostics.map((d) => d.uri).toSet().toList(),
      ),
    );
  }

  void _updateDirtyEditors() {
    _dirtyEditors = [
      for (final editor in _openEditors)
        if (editor.isDirty.value) editor,
    ];
  }

  /// Stops following the editors and closes the streams.
  void dispose() {
    for (final MapEntry(key: editor, value: listener)
        in _dirtyListeners.entries) {
      editor.isDirty.removeListener(listener);
    }
    _dirtyListeners.clear();
    _onFocusChanged.close();
    _onDirtyStateChanged.close();
    _onDiagnosticsChanged.close();
    _onEditorsChanged.close();
  }
}
