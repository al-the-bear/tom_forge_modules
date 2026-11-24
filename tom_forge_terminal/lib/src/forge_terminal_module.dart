import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The id of the terminals' placement ([ForgeViewPlacementHint.id]).
const String forgeTerminalViewId = 'forge.view.terminal';

/// Where the terminals go unless the application says otherwise: with what
/// the application reports (the panel shell: the bottom panel), in a group
/// `Terminal` of their own, after the other groups there.
const ForgeViewPlacementHint forgeTerminalViewPlacement =
    ForgeViewPlacementHint(
      id: forgeTerminalViewId,
      role: ForgeViewRole.messages,
      group: 'Terminal',
      groupIcon: Icons.code,
      order: 100,
    );

/// The module that tells an application where its terminals go, with
/// [placement] as their hint ([ForgeTerminalSectionsExtra]): the panel shell
/// makes its terminal tab from it (`forgeContributedTerminalTab`) and shows
/// one section per open terminal there. The terminals themselves come from
/// the shell's terminal manager ([forgeTerminalComponents]).
ForgeTerminalModule forgeTerminalModule({
  ForgeViewPlacementHint placement = forgeTerminalViewPlacement,
}) => ForgeTerminalModule(placement: placement);

/// Contributes the terminals' placement; no views, actions or shortcuts of
/// its own (a terminal's view is made per terminal by the shell).
class ForgeTerminalModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeTerminalModule({this.placement = forgeTerminalViewPlacement});

  /// The terminals' placement hint.
  final ForgeViewPlacementHint placement;

  @override
  String get displayName => 'Terminal';

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
  List<ForgeModuleExtra> get ownExtras => [
    ForgeTerminalSectionsExtra(placement),
  ];
}
