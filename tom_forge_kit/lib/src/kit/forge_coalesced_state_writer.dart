import 'dart:async';

import 'forge_state_store.dart';

/// Writes to a [ForgeStateStore] **once per gesture, never before the
/// start's restore** — the rule every kit user of a store follows.
///
/// - **Coalesced:** the writes of one key within a microtask (one gesture:
///   a key press, a drag frame, a settings change and the save it triggers)
///   become one [ForgeStateStore.write] of the last value. Each [write]'s
///   future completes when that write is stored (or fails with it).
/// - **Not before the restore:** until [open] is called — the owner calls it
///   when its restore (`load()` / `initialize()`) has finished — a [write]
///   stores nothing and completes at once: the value set before the restore
///   stays in the owner's memory only and is **dropped**, since the restore
///   then reads the stored value over it. Writing it after the restore
///   would put back a value the user never saw take effect.
class ForgeCoalescedStateWriter {
  /// A writer to [store], closed until [open] unless [open] is true.
  ForgeCoalescedStateWriter(this.store, {bool open = false}) : _open = open;

  /// The store written to.
  final ForgeStateStore store;

  bool _open;
  bool _scheduled = false;
  final Map<String, Object?> _pending = {};
  final Map<String, Completer<void>> _waiters = {};
  final Map<String, Future<void>> _inFlight = {};

  /// Whether the restore has finished and writes are stored.
  bool get isOpen => _open;

  /// Lets writes through from now on: the restore has finished.
  void open() => _open = true;

  /// Stores [document] under [key] — coalesced with the other writes of
  /// [key] in this microtask, the last one stored. Before [open], stores
  /// nothing (see the class).
  Future<void> write(String key, Object? document) {
    if (!_open) return Future<void>.value();
    _pending[key] = document;
    final waiter = _waiters[key] ??= Completer<void>();
    if (!_scheduled) {
      _scheduled = true;
      scheduleMicrotask(_flush);
    }
    return waiter.future;
  }

  /// The document of [key] in the store, after the writes of [key] started
  /// before it (coalesced ones included) have ended.
  Future<Object?> read(String key) async {
    final waiting = _waiters[key]?.future ?? _inFlight[key];
    if (waiting != null) {
      try {
        await waiting;
      } on Object {
        // A failed write leaves the document as it was: read that.
      }
    }
    return store.read(key);
  }

  void _flush() {
    _scheduled = false;
    final batch = Map<String, Object?>.of(_pending);
    final waiters = Map<String, Completer<void>>.of(_waiters);
    _pending.clear();
    _waiters.clear();
    for (final entry in batch.entries) {
      final key = entry.key;
      final waiter = waiters[key]!;
      final Future<void> stored;
      try {
        stored = store.write(key, entry.value);
      } on Object catch (error, stackTrace) {
        waiter.completeError(error, stackTrace);
        continue;
      }
      _inFlight[key] = stored;
      stored.then(
        (_) {
          if (identical(_inFlight[key], stored)) _inFlight.remove(key);
          waiter.complete();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (identical(_inFlight[key], stored)) _inFlight.remove(key);
          waiter.completeError(error, stackTrace);
        },
      );
    }
  }

  /// Completes when every write made before is stored (or has failed), and
  /// the store has flushed.
  Future<void> flushed() async {
    while (_scheduled || _waiters.isNotEmpty || _inFlight.isNotEmpty) {
      await Future.wait([
        for (final waiter in _waiters.values.toList())
          waiter.future.catchError((Object _) {}),
        for (final write in _inFlight.values.toList())
          write.catchError((Object _) {}),
        if (_scheduled) Future<void>.microtask(() {}),
      ]);
    }
    await store.flushed();
  }
}
