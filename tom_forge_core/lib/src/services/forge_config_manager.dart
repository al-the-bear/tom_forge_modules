import 'package:tom_forge_core/tom_forge_core.dart';

/// Configuration access and updates.
abstract class ForgeConfigManager {
  /// The current configuration.
  ForgeConfig get current;

  /// Update configuration via a mutator.
  void update(void Function(ForgeConfig config) updater);

  /// Reset all settings to defaults.
  void resetToDefaults();

  /// Stream of configuration changes.
  Stream<ConfigChangeEvent> get onDidChange;
}
