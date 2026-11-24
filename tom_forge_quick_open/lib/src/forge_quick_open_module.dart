import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_quick_open.dart';

/// The priority of quick open's [ForgeQuickOpenExtra]: above the command
/// palette's, so an application with both shows quick open.
const int forgeQuickOpenPriority = 10;

/// The module that contributes quick open ([ForgeQuickOpen]) to any
/// application on the kit: a [ForgeQuickOpenExtra] for every mode (all,
/// actions, chord) the application asks for when the user opens it.
ForgeQuickOpenModule forgeQuickOpenModule() => ForgeQuickOpenModule();

/// Contributes quick open as a [ForgeQuickOpenExtra]; no views, actions or
/// shortcuts of its own (the application binds the shortcuts that open it).
class ForgeQuickOpenModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeQuickOpenModule();

  late final ForgeQuickOpenExtra _extra = ForgeQuickOpenExtra(
    (key, request) => ForgeQuickOpen.fromRequest(request, key: key),
    priority: forgeQuickOpenPriority,
  );

  @override
  String get displayName => 'Quick Open';

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
