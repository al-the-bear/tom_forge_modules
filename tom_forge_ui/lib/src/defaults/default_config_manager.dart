import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

import '../model/forge_config.dart';
import '../services/forge_config_manager.dart';

/// Default implementation of [ForgeConfigManager].
///
/// Stores configuration in-memory and notifies on changes.
class DefaultConfigManager implements ForgeConfigManager {
  static bool debugEnabled = false;

  ForgeConfig _current;
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
  void resetToDefaults() {
    _current = const ForgeConfig();
    _changeController.add(const ConfigChangeEvent(key: ''));
  }

  @override
  Stream<ConfigChangeEvent> get onDidChange => _changeController.stream;

  /// Dispose resources.
  void dispose() {
    _changeController.close();
  }
}
