import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'forge_state_store.dart';

/// A [ForgeStateStore] over `shared_preferences`, the default store of the
/// preferences: a key is the shared_preferences key, and a value is stored
/// as the Forge preferences always stored it, so an existing user's
/// preferences load unchanged.
///
/// | document                     | stored with                    |
/// | ---------------------------- | ------------------------------ |
/// | bool                         | `setBool`                      |
/// | int                          | `setInt`                       |
/// | double                       | `setDouble`                    |
/// | String                       | `setString`                    |
/// | `List<String>`               | `setStringList`                |
/// | a Map, any other List        | `setString(jsonEncode(...))`   |
/// | null                         | `remove`                       |
///
/// [read] answers the stored value: a Map or other List written here comes
/// back as its JSON text (a String), as shared_preferences keeps it — the
/// preferences write their maps as JSON text themselves and decode what
/// they read, whichever store they are given.
///
/// Every call asks `SharedPreferences.getInstance()` again (it answers the
/// same instance, but a test resetting it with `setMockInitialValues` is
/// followed); nothing is read from shared_preferences before the first call.
class ForgeSharedPreferencesStateStore implements ForgeStateStore {
  ForgeSharedPreferencesStateStore();

  final Set<Future<void>> _inFlight = {};

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  @override
  Future<Object?> read(String key) async {
    final value = (await _preferences).get(key);
    if (value is List) return List<String>.from(value);
    return value;
  }

  @override
  Future<void> write(String key, Object? document) {
    final future = _write(key, document);
    _inFlight.add(future);
    void ended() => _inFlight.remove(future);
    future.then((_) => ended(), onError: (Object _) => ended());
    return future;
  }

  Future<void> _write(String key, Object? document) async {
    final preferences = await _preferences;
    final Future<bool> done;
    if (document == null) {
      done = preferences.remove(key);
    } else if (document is bool) {
      done = preferences.setBool(key, document);
    } else if (document is int) {
      done = preferences.setInt(key, document);
    } else if (document is double) {
      done = preferences.setDouble(key, document);
    } else if (document is String) {
      done = preferences.setString(key, document);
    } else if (document is List<String>) {
      done = preferences.setStringList(key, document);
    } else if (document is Map || document is List) {
      done = preferences.setString(key, jsonEncode(document));
    } else {
      throw ArgumentError.value(
        document,
        'document',
        'not a JSON-compatible value',
      );
    }
    await done;
  }

  @override
  Future<List<String>> keys({String prefix = ''}) async => [
    for (final key in (await _preferences).getKeys())
      if (key.startsWith(prefix)) key,
  ]..sort();

  @override
  Future<void> flushed() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait([
        for (final write in _inFlight.toList()) write.catchError((Object _) {}),
      ]);
    }
  }
}
