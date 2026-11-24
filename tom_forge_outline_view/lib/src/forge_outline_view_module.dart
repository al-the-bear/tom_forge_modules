import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_outline_view.dart';

/// The id of the Outline view ([ForgeViewPlacementHint.id]).
const String forgeOutlineViewId = 'forge.view.outline';

/// Where the Outline view goes unless the application says otherwise: about
/// what the user works on now, a group of its own.
const ForgeViewPlacementHint forgeOutlineViewPlacement = ForgeViewPlacementHint(
  id: forgeOutlineViewId,
  role: ForgeViewRole.details,
  group: 'Outline',
  groupIcon: Icons.account_tree,
);

/// The module that contributes the Outline view ([ForgeOutlineView]) to any
/// application on the kit, with [placement] as its hint.
ForgeOutlineViewModule forgeOutlineViewModule({
  ForgeViewPlacementHint placement = forgeOutlineViewPlacement,
}) => ForgeOutlineViewModule(placement: placement);

/// Contributes the Outline view: made at activation from the application's
/// outline manager and state, listed in [views], placed by its
/// [ForgeViewContributionsExtra].
///
/// An application whose outline manager is not the kit's
/// [DefaultOutlineManager] gets no view.
class ForgeOutlineViewModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeOutlineViewModule({this.placement = forgeOutlineViewPlacement});

  /// The view's placement hint.
  final ForgeViewPlacementHint placement;

  ForgeOutlineView? _view;

  /// The view, once activated.
  ForgeOutlineView? get view => _view;

  @override
  String get displayName => 'Outline';

  @override
  void activate(ForgeKitApi api) {
    final outline = api.outline;
    if (outline is! DefaultOutlineManager) return;
    _view = ForgeOutlineView(outlineManager: outline, systemState: api.state);
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
