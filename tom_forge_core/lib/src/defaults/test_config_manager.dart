import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Test implementation of [ForgeConfigManager] with tracking capabilities.
///
/// Provides additional methods for testing:
/// - [updateCount] tracks how many times [update] was called
/// - [lastChangeKey] stores the last emitted change event key
/// - [simulateChange] emits a synthetic change event
/// - All module configs are accessible via [allModuleConfigs]
class TestConfigManager implements ForgeConfigManager {
  ForgeConfig _current;
  final Map<String, Object> _moduleConfigs = {};
  final StreamController<ConfigChangeEvent> _changeController =
      StreamController<ConfigChangeEvent>.broadcast();

  /// Number of times [update] was called.
  int updateCount = 0;

  /// The key from the last emitted [ConfigChangeEvent].
  String? lastChangeKey;

  TestConfigManager({ForgeConfig? initial})
      : _current = initial ?? const ForgeConfig();

  @override
  ForgeConfig get current => _current;

  /// Replaces the current top-level configuration and emits a change event.
  void setCurrent(ForgeConfig config, {String key = ''}) {
    _current = config;
    lastChangeKey = key;
    _changeController.add(ConfigChangeEvent(key: key));
  }

  @override
  void update(void Function(ForgeConfig config) updater) {
    updateCount++;
    updater(_current);
    lastChangeKey = '';
    _changeController.add(const ConfigChangeEvent(key: ''));
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
    lastChangeKey = 'module.$moduleId';
    _changeController.add(ConfigChangeEvent(key: 'module.$moduleId'));
  }

  /// Returns a copy of all module configurations for inspection.
  Map<String, Object> get allModuleConfigs => Map.unmodifiable(_moduleConfigs);

  @override
  void resetToDefaults() {
    _current = const ForgeConfig();
    _moduleConfigs.clear();
    updateCount = 0;
    lastChangeKey = '';
    _changeController.add(const ConfigChangeEvent(key: ''));
  }

  @override
  Stream<ConfigChangeEvent> get onDidChange => _changeController.stream;

  /// Simulate a configuration change event for testing.
  void simulateChange(String key) {
    lastChangeKey = key;
    _changeController.add(ConfigChangeEvent(key: key));
  }

  /// Dispose resources.
  void dispose() {
    _changeController.close();
  }
}
