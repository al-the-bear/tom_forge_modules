import 'package:flutter/foundation.dart';

import '../components/component_history_manager.dart';
import '../components/forge_editor.dart';
import '../components/forge_text_editor.dart';
import '../services/forge_navigation_history.dart';
import 'default_layout_controller.dart';
import 'default_system_state.dart';

/// Default [ForgeNavigationHistory]: follows the active editor of
/// [DefaultSystemState] — every change records the place the old editor was
/// at — and goes back and forward through [DefaultLayoutController.openFile],
/// switching to the application a place was in first.
class DefaultNavigationHistory implements ForgeNavigationHistory {
  DefaultNavigationHistory({
    required DefaultSystemState systemState,
    required DefaultLayoutController layout,
    this.maxEntries = 50,
  }) : _systemState = systemState,
       _layout = layout {
    _current = systemState.activeEditor;
    _currentApplicationId = systemState.activeApplication?.id;
    _bindEditorHistory(_current);
    systemState.activeEditorListenable.addListener(_activeEditorChanged);
  }

  final DefaultSystemState _systemState;
  final DefaultLayoutController _layout;

  /// The most places kept in each direction; the oldest go first.
  final int maxEntries;

  final List<ForgeNavigationLocation> _back = [];
  final List<ForgeNavigationLocation> _forward = [];
  final ValueNotifier<bool> _canGoBack = ValueNotifier(false);
  final ValueNotifier<bool> _canGoForward = ValueNotifier(false);

  /// The active editor, and the application it is shown in: kept here, since
  /// when the active editor changes the system state already names the new
  /// one (and on a switch, the new application).
  ForgeEditor? _current;
  String? _currentApplicationId;

  /// The active editor's own history, while it supplies one.
  ComponentHistoryManager? _editorHistory;

  /// Above zero while the history itself moves, or a caller asked
  /// [withoutRecording]: nothing is recorded then.
  int _suppressed = 0;

  /// The document a Back or Forward is still opening (a closed file read
  /// from disk): its editor becoming active is that move's arrival, not a
  /// move of the user's.
  Uri? _arriving;

  @override
  ValueListenable<bool> get canGoBack => _canGoBack;

  @override
  ValueListenable<bool> get canGoForward => _canGoForward;

  @override
  List<ForgeNavigationLocation> get backLocations => List.unmodifiable(_back);

  @override
  List<ForgeNavigationLocation> get forwardLocations =>
      List.unmodifiable(_forward);

  @override
  bool goBack() {
    final editorHistory = _editorHistory;
    if (editorHistory != null && editorHistory.canGoBack.value) {
      editorHistory.goBack();
      return true;
    }
    return _move(from: _back, to: _forward);
  }

  @override
  bool goForward() {
    final editorHistory = _editorHistory;
    if (editorHistory != null && editorHistory.canGoForward.value) {
      editorHistory.goForward();
      return true;
    }
    return _move(from: _forward, to: _back);
  }

  @override
  void recordCurrentLocation() {
    if (_suppressed > 0) return;
    final here = _currentLocation();
    if (here == null) return;
    _record(here);
    _update();
  }

  @override
  void withoutRecording(void Function() action) {
    _suppressed++;
    try {
      action();
    } finally {
      _suppressed--;
    }
  }

  void dispose() {
    _systemState.activeEditorListenable.removeListener(_activeEditorChanged);
    _bindEditorHistory(null);
    _canGoBack.dispose();
    _canGoForward.dispose();
  }

  // ── Recording ──

  void _activeEditorChanged() {
    final next = _systemState.activeEditor;
    final left = _current;
    if (identical(next, left)) return;
    final leftLocation = left == null
        ? null
        : _locationOf(left, _currentApplicationId);
    _current = next;
    _currentApplicationId = _systemState.activeApplication?.id;
    _bindEditorHistory(next);
    final arriving = _arriving;
    _arriving = null;
    final isArrival = arriving != null && next?.uri == arriving;
    if (_suppressed == 0 && !isArrival && leftLocation != null) {
      _record(leftLocation);
    }
    _update();
  }

  /// Records [place] as the place left: a new move drops what Forward had.
  void _record(ForgeNavigationLocation place) {
    _push(_back, place);
    _forward.clear();
  }

  /// Adds [place] to [stack]; the same place as its last one replaces it.
  void _push(
    List<ForgeNavigationLocation> stack,
    ForgeNavigationLocation place,
  ) {
    if (stack.isNotEmpty && stack.last.samePlaceAs(place)) stack.removeLast();
    stack.add(place);
    if (stack.length > maxEntries) stack.removeAt(0);
  }

  ForgeNavigationLocation? _currentLocation() {
    final current = _current;
    return current == null ? null : _locationOf(current, _currentApplicationId);
  }

  ForgeNavigationLocation _locationOf(ForgeEditor editor, String? appId) {
    final caret = editor is ForgeTextEditor
        ? editor.cursorPosition.value
        : null;
    final panel = _layout.middlePanels.value.indexWhere(
      (group) => group.contains(editor),
    );
    return ForgeNavigationLocation(
      uri: editor.uri,
      line: caret?.line,
      column: caret?.column,
      applicationId: appId,
      middlePanelIndex: panel < 0 ? null : panel,
    );
  }

  // ── Moving ──

  /// Goes to the last place of [from], keeping where the user is now on
  /// [to]; false when [from] is empty.
  bool _move({
    required List<ForgeNavigationLocation> from,
    required List<ForgeNavigationLocation> to,
  }) {
    if (from.isEmpty) return false;
    final target = from.removeLast();
    final here = _currentLocation();
    if (here != null) _push(to, here);
    _navigateTo(target);
    _update();
    return true;
  }

  void _navigateTo(ForgeNavigationLocation target) {
    withoutRecording(() {
      final appId = target.applicationId;
      if (appId != null &&
          appId != _systemState.activeApplication?.id &&
          _systemState.byId(appId) != null) {
        _systemState.activate(appId);
      }
      final panel = target.middlePanelIndex;
      _layout.openFile(
        target.uri,
        middlePanelIndex:
            panel != null && panel < _layout.middlePanels.value.length
            ? panel
            : null,
        line: target.line,
        column: target.column,
      );
    });
    // A closed file is read before its editor opens: its activation, when
    // it comes, is this move's.
    if (_systemState.activeEditor?.uri != target.uri) _arriving = target.uri;
  }

  // ── Enablement ──

  void _bindEditorHistory(ForgeEditor? editor) {
    final old = _editorHistory;
    old?.canGoBack.removeListener(_update);
    old?.canGoForward.removeListener(_update);
    final history = editor?.historyManager;
    history?.canGoBack.addListener(_update);
    history?.canGoForward.addListener(_update);
    _editorHistory = history;
  }

  void _update() {
    final editorHistory = _editorHistory;
    _canGoBack.value =
        _back.isNotEmpty || (editorHistory?.canGoBack.value ?? false);
    _canGoForward.value =
        _forward.isNotEmpty || (editorHistory?.canGoForward.value ?? false);
  }
}
