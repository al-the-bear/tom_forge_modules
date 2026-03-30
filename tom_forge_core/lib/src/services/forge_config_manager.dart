import 'package:tom_forge_core/tom_forge_core.dart';

/// Configuration access and updates.
abstract class ForgeConfigManager {
  /// The current configuration.
  ForgeConfig get current;

  /// Update configuration via a mutator.
  void update(void Function(ForgeConfig config) updater);

  /// Gets typed module-specific configuration.
  ///
  /// Returns the configuration for (moduleId), or `null` if not set.
  /// The returned configuration is cast to type [T].
  ///
  /// Example:
  /// ```dart
  /// final settings = config.getModuleConfig<MyModuleSettings>('my-module');
  /// ```
  T? getModuleConfig<T>(String moduleId);

  /// Sets module-specific configuration.
  ///
  /// Stores [config] for [moduleId] and emits a [ConfigChangeEvent].
  void setModuleConfig<T>(String moduleId, T config);

  /// Reset all settings to defaults.
  void resetToDefaults();

  /// Stream of configuration changes.
  Stream<ConfigChangeEvent> get onDidChange;
}
