import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_command_palette.dart';

/// The module that contributes the command palette ([ForgeCommandPalette])
/// to any application on the kit: a [ForgeQuickOpenExtra] for the all and
/// actions modes, at priority 0 — an application that also has quick open
/// (`tom_forge_quick_open`, a higher priority) shows quick open, one without
/// it shows the palette.
ForgeCommandPaletteModule forgeCommandPaletteModule() =>
    ForgeCommandPaletteModule();

/// Contributes the command palette as a [ForgeQuickOpenExtra]; no views,
/// actions or shortcuts of its own (the application binds the shortcuts
/// that open it).
class ForgeCommandPaletteModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeCommandPaletteModule();

  late final ForgeQuickOpenExtra _extra = ForgeQuickOpenExtra(
    (key, request) => ForgeCommandPalette.fromRequest(request, key: key),
    modes: const {ForgeQuickOpenMode.all, ForgeQuickOpenMode.actions},
  );

  @override
  String get displayName => 'Command Palette';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeModuleExtra> get ownExtras => [_extra];
}
