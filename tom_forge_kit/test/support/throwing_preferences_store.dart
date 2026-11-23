import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// A shared_preferences platform that counts every call and fails it: with
/// it installed, any shared_preferences call the code under test makes is
/// seen (and breaks the test).
class ThrowingPreferencesStore extends SharedPreferencesStorePlatform {
  /// The calls made.
  int calls = 0;

  Never _fail() {
    calls++;
    throw StateError('shared_preferences was called');
  }

  @override
  Future<bool> clear() async => _fail();

  @override
  Future<bool> clearWithPrefix(String prefix) async => _fail();

  @override
  Future<Map<String, Object>> getAll() async => _fail();

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) async => _fail();

  @override
  Future<bool> remove(String key) async => _fail();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      _fail();

  /// Installs a fresh one (and resets the shared_preferences singleton).
  static ThrowingPreferencesStore install() {
    SharedPreferences.resetStatic();
    final store = ThrowingPreferencesStore();
    SharedPreferencesStorePlatform.instance = store;
    return store;
  }

  /// Puts the in-memory platform back.
  static void uninstall() {
    SharedPreferencesStorePlatform.instance =
        InMemorySharedPreferencesStore.empty();
    SharedPreferences.resetStatic();
  }
}
