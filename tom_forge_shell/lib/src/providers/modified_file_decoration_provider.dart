import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/forge_file_decoration_manager.dart';
import '../shell/forge_system_state.dart';

/// Decoration provider that marks dirty (unsaved) editors with an 'M' badge.
///
/// Listens to editor-change events on [ForgeSystemState] and fires
/// invalidation events so the file explorer can update decorations in
/// real time as editors become dirty or are saved.
class ModifiedFileDecorationProvider implements ForgeFileDecorationProvider {
  ModifiedFileDecorationProvider({required ForgeSystemState systemState})
      : _systemState = systemState {
    _subscription = _systemState.onEditorsChanged.listen((_) {
      _changeController.add(null);
    });
  }

  final ForgeSystemState _systemState;
  final StreamController<Uri?> _changeController =
      StreamController<Uri?>.broadcast();
  StreamSubscription<void>? _subscription;

  static const _modifiedColor = Color(0xFFE2C08D);

  @override
  ForgeFileDecoration? provideDecoration(Uri uri) {
    final isDirty = _systemState.openEditors
        .where((e) => e.uri == uri)
        .any((e) => e.isDirty.value);
    if (!isDirty) return null;
    return const ForgeFileDecoration(
      badge: 'M',
      tooltip: 'Modified — unsaved changes',
      color: _modifiedColor,
      propagate: true,
    );
  }

  @override
  Stream<Uri?> get onDidChange => _changeController.stream;

  /// Release resources.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _changeController.close();
  }
}
