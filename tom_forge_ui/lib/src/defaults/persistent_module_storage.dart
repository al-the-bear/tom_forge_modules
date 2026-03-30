import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../module/forge_module.dart';
import '../services/forge_module_storage.dart';

/// Persistent implementation of [ForgeModuleStorage] backed by
/// `.forge/state/modules/` directory.
///
/// Each module gets a JSON file keyed by a hash of its display name.
/// Data is loaded lazily on first access and flushed on every write.
class PersistentModuleStorage implements ForgeModuleStorage {
  static bool debugEnabled = false;

  final String _forgeDir;
  final Map<String, _PersistentKeyValueStore> _stores = {};

  PersistentModuleStorage({required String forgeDir}) : _forgeDir = forgeDir;

  /// The directory where module storage files are kept.
  String get _modulesDir => '$_forgeDir/state/modules';

  @override
  ForgeKeyValueStore forModule(ForgeModule module) {
    return _stores.putIfAbsent(
      module.displayName,
      () => _PersistentKeyValueStore(
        filePath: '$_modulesDir/${_moduleHash(module.displayName)}.json',
      ),
    );
  }

  String _moduleHash(String name) {
    final h1 = name.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    final h2 = name
        .split('')
        .reversed
        .join()
        .hashCode
        .toUnsigned(32)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$h1$h2';
  }
}

/// A key-value store backed by a single JSON file.
class _PersistentKeyValueStore implements ForgeKeyValueStore {
  final String _filePath;
  Map<String, Object?>? _data;
  bool _loaded = false;

  _PersistentKeyValueStore({required String filePath}) : _filePath = filePath;

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = File(_filePath);
      if (file.existsSync()) {
        final json = jsonDecode(file.readAsStringSync());
        if (json is Map<String, dynamic>) {
          _data = Map<String, Object?>.from(json);
          return;
        }
      }
    } catch (e) {
      if (PersistentModuleStorage.debugEnabled) {
        debugPrint('[PersistentModuleStorage] load failed for $_filePath: $e');
      }
    }
    _data = {};
  }

  Future<void> _flush() async {
    try {
      final file = File(_filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(_data),
      );
    } catch (e) {
      if (PersistentModuleStorage.debugEnabled) {
        debugPrint('[PersistentModuleStorage] flush failed for $_filePath: $e');
      }
    }
  }

  @override
  T? get<T>(String key) {
    _ensureLoaded();
    final value = _data![key];
    return value is T ? value : null;
  }

  @override
  Future<void> set(String key, Object? value) async {
    _ensureLoaded();
    _data![key] = value;
    await _flush();
  }

  @override
  Future<void> remove(String key) async {
    _ensureLoaded();
    _data!.remove(key);
    await _flush();
  }

  @override
  List<String> get keys {
    _ensureLoaded();
    return List.unmodifiable(_data!.keys);
  }
}
