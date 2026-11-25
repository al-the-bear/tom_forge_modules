import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeConfigurationDescription, ForgeSettingHooks;

import '../kit/forge_kit_api.dart';
import '../kit/forge_kit_modules_host.dart';
import 'forge_kit_module.dart';
import 'forge_kit_module_registry.dart';

/// What a module's components can be configured in, as a
/// [ForgeModuleExtra]: their [ForgeConfigurationDescription]s.
///
/// Every component with options describes them (`tom_forge_core`'s
/// configuration description); its module hands the descriptions over with
/// this extra, the kit collects them from every registered module
/// ([forgeConfigurationDescriptions]) and keeps the values through its
/// state-store port (`ForgeConfigurationValues`). How they are shown — a
/// side panel, a page of tiles, a layout of its own — is the application's
/// decision (`tom_configuration_ui` draws the tiles).
class ForgeConfigurationDescriptionsExtra extends ForgeModuleExtra {
  const ForgeConfigurationDescriptionsExtra(
    List<ForgeConfigurationDescription> descriptions,
  ) : super(kind: kindId, value: descriptions);

  /// The kind of this extra.
  static const kindId = 'forge.kit.configurationDescriptions';

  /// The descriptions, in the order the module gives them.
  List<ForgeConfigurationDescription> get descriptions =>
      value as List<ForgeConfigurationDescription>;
}

/// A description a registered module contributes, with the module.
class ForgeContributedConfiguration {
  const ForgeContributedConfiguration({
    required this.description,
    required this.module,
  });

  final ForgeConfigurationDescription description;
  final ForgeKitModule module;
}

/// Every configuration description the modules of [registry] contribute
/// ([ForgeConfigurationDescriptionsExtra]), in registration order and each
/// module's order. A description whose id an earlier one has is left out
/// (the first registered wins). Empty when no module describes anything.
List<ForgeContributedConfiguration> forgeConfigurationDescriptions(
  ForgeKitModuleRegistry registry,
) {
  final out = <ForgeContributedConfiguration>[];
  final ids = <String>{};
  for (final module in registry.allKitModules) {
    for (final extra
        in module.extras.whereType<ForgeConfigurationDescriptionsExtra>()) {
      for (final description in extra.descriptions) {
        if (!ids.add(description.id)) continue;
        out.add(
          ForgeContributedConfiguration(
            description: description,
            module: module,
          ),
        );
      }
    }
  }
  return out;
}

/// The configuration descriptions of the modules registered with [api]
/// ([forgeConfigurationDescriptions]); empty when the API does not tell its
/// modules ([ForgeKitModulesHost]).
List<ForgeConfigurationDescription> forgeConfigurationDescriptionsOf(
  ForgeKitApi api,
) {
  final registry = forgeKitModulesOf(api);
  if (registry == null) return const [];
  return [
    for (final contributed in forgeConfigurationDescriptions(registry))
      contributed.description,
  ];
}

/// The behaviour a module's settings name, as a [ForgeModuleExtra]: its
/// [ForgeSettingHooks] (actions, flows, detectors, choices providers, status
/// providers, action catalogues).
///
/// A description names hooks by id; the module (or the application) that
/// can do the work hands them over with this extra, the kit merges them
/// from every registered module ([forgeConfigurationHooks]) and the
/// application gives the registry to its `ForgeConfigurationValues`.
class ForgeConfigurationHooksExtra extends ForgeModuleExtra {
  const ForgeConfigurationHooksExtra(ForgeSettingHooks hooks)
    : super(kind: kindId, value: hooks);

  /// The kind of this extra.
  static const kindId = 'forge.kit.configurationHooks';

  /// The hooks.
  ForgeSettingHooks get hooks => value as ForgeSettingHooks;
}

/// Every hook the modules of [registry] contribute
/// ([ForgeConfigurationHooksExtra]) in one registry, in registration order:
/// a later module's hook of an id replaces an earlier one's.
ForgeSettingHooks forgeConfigurationHooks(ForgeKitModuleRegistry registry) =>
    ForgeSettingHooks.merged([
      for (final module in registry.allKitModules)
        for (final extra
            in module.extras.whereType<ForgeConfigurationHooksExtra>())
          extra.hooks,
    ]);

/// The hooks of the modules registered with [api]
/// ([forgeConfigurationHooks]); empty when the API does not tell its
/// modules ([ForgeKitModulesHost]).
ForgeSettingHooks forgeConfigurationHooksOf(ForgeKitApi api) {
  final registry = forgeKitModulesOf(api);
  return registry == null
      ? ForgeSettingHooks()
      : forgeConfigurationHooks(registry);
}
