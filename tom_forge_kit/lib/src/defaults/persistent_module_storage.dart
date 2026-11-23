import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tom_file_system/tom_file_system.dart';

import '../module/forge_kit_module.dart';
import '../services/forge_module_storage.dart';

/// Persistent implementation of [ForgeModuleStorage]: one JSON file per
/// module under `.forge/state/modules/`, read and written through the
/// workspace's [TomFileSystem].
///
/// [open] reads every module's file once, so [ForgeKeyValueStore.get] stays
/// synchronous; every write is flushed to the module's file. A file that
/// cannot be read or is not a JSON object counts as empty.
class PersistentModuleStorage implements ForgeModuleStorage {
  static bool debugEnabled = false;

  PersistentModuleStorage._(this._fileSystem, this._loaded);

  final TomFileSystem _fileSystem;

  /// The stored data by file name, as read at [open].
  final Map<String, Map<String, Object?>> _loaded;
  final Map<String, _PersistentKeyValueStore> _stores = {};

  /// The module storage of the workspace [fileSystem] (whose root is the
  /// workspace folder), with what is stored read.
  static Future<PersistentModuleStorage> open(TomFileSystem fileSystem) async {
    final loaded = <String, Map<String, Object?>>{};
    final folder = fileSystem.uriOf('$_modulesPath/');
    try {
      if (await fileSystem.exists(folder)) {
        for (final entry in await fileSystem.list(folder)) {
          if (entry.isDirectory || !entry.name.endsWith('.json')) continue;
          try {
            final json = jsonDecode(await fileSystem.readText(entry.uri));
            if (json is Map<String, dynamic>) {
              loaded[entry.name] = Map<String, Object?>.from(json);
            }
          } on Exception catch (e) {
            _log('load failed for ${entry.path}: $e');
          }
        }
      }
    } on Exception catch (e) {
      _log('listing $_modulesPath failed: $e');
    }
    return PersistentModuleStorage._(fileSystem, loaded);
  }

  static const _modulesPath = '.forge/state/modules';

  static void _log(String message) {
    if (debugEnabled) debugPrint('[PersistentModuleStorage] $message');
  }

  @override
  ForgeKeyValueStore forModule(ForgeKitModule module) {
    final name = '${_moduleHash(module.displayName)}.json';
    return _stores.putIfAbsent(
      module.displayName,
      () => _PersistentKeyValueStore(
        fileSystem: _fileSystem,
        file: _fileSystem.uriOf('$_modulesPath/$name'),
        data: {...?_loaded[name]},
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
  _PersistentKeyValueStore({
    required TomFileSystem fileSystem,
    required Uri file,
    required Map<String, Object?> data,
  }) : _fileSystem = fileSystem,
       _file = file,
       _data = data;

  final TomFileSystem _fileSystem;
  final Uri _file;
  final Map<String, Object?> _data;

  Future<void> _flush() async {
    try {
      await _fileSystem.writeTextMakingFolder(
        _file,
        const JsonEncoder.withIndent('  ').convert(_data),
      );
    } on Exception catch (e) {
      PersistentModuleStorage._log('flush failed for $_file: $e');
    }
  }

  @override
  T? get<T>(String key) {
    final value = _data[key];
    return value is T ? value : null;
  }

  @override
  Future<void> set(String key, Object? value) async {
    _data[key] = value;
    await _flush();
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
    await _flush();
  }

  @override
  List<String> get keys => List.unmodifiable(_data.keys);
}
