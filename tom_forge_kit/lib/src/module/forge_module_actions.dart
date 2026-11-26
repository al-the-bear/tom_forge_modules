import '../actions/forge_action.dart';
import 'forge_kit_module.dart';

/// [module]'s actions, each with a title read under the module's text scope
/// (`ForgeAction.withTextResolver(module.textScope)`): what a host shows in
/// its menus, command palette and tool bars, and what it registers. An
/// action that already names its resolver, or has a literal label, is
/// handed out as it is.
List<ForgeAction> forgeModuleActions(ForgeKitModule module) => [
  for (final action in module.actions)
    action.withTextResolver(module.textScope),
];
