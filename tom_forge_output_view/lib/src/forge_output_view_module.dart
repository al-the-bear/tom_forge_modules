import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_output_view.dart';

/// The id of the Output view ([ForgeViewPlacementHint.id]).
const String forgeOutputViewId = 'forge.view.output';

/// Where the Output view goes unless the application says otherwise: among
/// what the application reports, after the problems.
const ForgeViewPlacementHint forgeOutputViewPlacement = ForgeViewPlacementHint(
  id: forgeOutputViewId,
  role: ForgeViewRole.messages,
  group: 'Output',
  groupIcon: Icons.terminal,
  order: 10,
);

/// The module that contributes the Output view ([ForgeOutputView]) to any
/// application on the kit, with [placement] as its hint.
ForgeOutputViewModule forgeOutputViewModule({
  ForgeViewPlacementHint placement = forgeOutputViewPlacement,
}) => ForgeOutputViewModule(placement: placement);

/// Contributes the Output view: made at activation over the application's
/// output channels, listed in [views], placed by its
/// [ForgeViewContributionsExtra].
class ForgeOutputViewModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeOutputViewModule({this.placement = forgeOutputViewPlacement});

  /// The view's placement hint.
  final ForgeViewPlacementHint placement;

  ForgeOutputView? _view;

  /// The view, once activated.
  ForgeOutputView? get view => _view;

  @override
  String get displayName => 'Output';

  @override
  void activate(ForgeKitApi api) {
    _view = ForgeOutputView(channelManager: api.output);
  }

  @override
  void deactivate() => _view = null;

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => [?_view];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeModuleExtra> get ownExtras => [
    if (_view case final view?)
      ForgeViewContributionsExtra([
        ForgeViewContribution(view: view, hint: placement),
      ]),
  ];
}
