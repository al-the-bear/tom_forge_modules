import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Default implementation of [ForgeConfigManager].
///
/// Stores configuration in-memory and notifies on changes.
class DefaultConfigManager implements ForgeConfigManager {
  static bool debugEnabled = false;

  ForgeConfig _current;
  final Map<String, Object> _moduleConfigs = {};
  final StreamController<ConfigChangeEvent> _changeController =
      StreamController<ConfigChangeEvent>.broadcast();

  DefaultConfigManager({ForgeConfig? initial})
      : _current = initial ?? const ForgeConfig();

  @override
  ForgeConfig get current => _current;

  @override
  void update(void Function(ForgeConfig config) updater) {
    try {
      // ForgeConfig is immutable, so we pass it to the updater for reading,
      // then capture the caller's intent. Since ForgeConfig fields are final,
      // we rebuild from defaults after the call.
      updater(_current);
      _changeController.add(const ConfigChangeEvent(key: ''));
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultConfigManager] update error: $e');
      }
    }
  }

  @override
  T? getModuleConfig<T>(String moduleId) {
    final config = _moduleConfigs[moduleId];
    if (config == null) return null;
    return config as T;
  }

  @override
  void setModuleConfig<T>(String moduleId, T config) {
    _moduleConfigs[moduleId] = config as Object;
    _changeController.add(ConfigChangeEvent(key: 'module.$moduleId'));
  }

  @override
  void resetToDefaults() {
    _current = const ForgeConfig();
    _moduleConfigs.clear();
    _changeController.add(const ConfigChangeEvent(key: ''));
  }

  /// Serializes the current configuration state to a JSON-compatible map.
  ///
  /// Includes only module configs that are serializable (Map or List).
  Map<String, dynamic> toJson() {
    final moduleJson = <String, dynamic>{};
    for (final entry in _moduleConfigs.entries) {
      final value = entry.value;
      if (value is Map || value is List || value is String || value is num || value is bool) {
        moduleJson[entry.key] = value;
      }
    }
    return {
      'moduleConfigs': moduleJson,
    };
  }

  /// Restores configuration state from a JSON map.
  ///
  /// Module configs are merged on top of defaults.
  void loadFromJson(Map<String, dynamic> json) {
    final moduleJson = json['moduleConfigs'];
    if (moduleJson is Map<String, dynamic>) {
      for (final entry in moduleJson.entries) {
        if (entry.value is Object) {
          _moduleConfigs[entry.key] = entry.value!;
        }
      }
    }
    _changeController.add(const ConfigChangeEvent(key: ''));
  }

  @override
  Stream<ConfigChangeEvent> get onDidChange => _changeController.stream;

  /// Dispose resources.
  void dispose() {
    _changeController.close();
  }
}
