import 'package:flutter/foundation.dart';

/// Dirty measured against the saved state, never against the history.
///
/// An editor keeps one of these per document. [compare] is called with the
/// document's current value after every change, undo and redo included, so
/// undoing back to what was saved shows clean again; [markSaved] moves the
/// marker after a save, a load, a reload or a restore. Whether the history
/// can undo says nothing about dirtiness: after a save there is still
/// history, and after an undo to the saved state the document is clean.
///
/// [T] is whatever identifies a saved state cheaply and exactly — the text,
/// a fingerprint, a revision id.
class ForgeSavedMarker<T> {
  ForgeSavedMarker(T saved, {bool Function(T a, T b)? equals})
    : _saved = saved,
      _equals = equals ?? _defaultEquals;

  static bool _defaultEquals(Object? a, Object? b) => a == b;

  T _saved;
  final bool Function(T a, T b) _equals;
  final ValueNotifier<bool> _isDirty = ValueNotifier(false);

  /// The saved state.
  T get saved => _saved;

  /// Whether the document differs from [saved], as of the last [compare].
  ValueListenable<bool> get isDirty => _isDirty;

  /// Records the document's current value.
  void compare(T current) => _isDirty.value = !_equals(current, _saved);

  /// [current] is now the saved state: the document is clean.
  void markSaved(T current) {
    _saved = current;
    _isDirty.value = false;
  }

  void dispose() => _isDirty.dispose();
}
