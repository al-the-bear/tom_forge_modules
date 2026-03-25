import '../module/forge_module.dart';

/// Per-module persistent key/value storage.
abstract class ForgeModuleStorage {
  ForgeKeyValueStore forModule(ForgeModule module);
}

/// A simple key/value store.
abstract class ForgeKeyValueStore {
  T? get<T>(String key);
  Future<void> set(String key, Object? value);
  Future<void> remove(String key);
  List<String> get keys;
}
