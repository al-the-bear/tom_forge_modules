import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_revision_view.dart';

/// The id of the Revisions view ([ForgeViewPlacementHint.id]).
const String forgeRevisionViewId = 'forge.view.revisions';

/// Where the Revisions view goes unless the application says otherwise:
/// beside the file explorer, below it in the explorer's group.
const ForgeViewPlacementHint forgeRevisionViewPlacement =
    ForgeViewPlacementHint(
      id: forgeRevisionViewId,
      role: ForgeViewRole.navigation,
      group: 'Explorer',
      groupIcon: Icons.folder_outlined,
      order: 1,
    );

/// The module that contributes the Revisions view ([ForgeRevisionView]) to
/// any application on the kit, with [placement] as its hint.
ForgeRevisionViewModule forgeRevisionViewModule({
  ForgeViewPlacementHint placement = forgeRevisionViewPlacement,
}) => ForgeRevisionViewModule(placement: placement);

/// Contributes the Revisions view: made at activation over the
/// application's API ([ForgeRevisionView.forApi]), listed in [views], placed
/// by its [ForgeViewContributionsExtra].
class ForgeRevisionViewModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeRevisionViewModule({this.placement = forgeRevisionViewPlacement});

  /// The view's placement hint.
  final ForgeViewPlacementHint placement;

  ForgeRevisionView? _view;

  /// The view, once activated.
  ForgeRevisionView? get view => _view;

  @override
  String get displayName => 'Revisions';

  @override
  void activate(ForgeKitApi api) {
    _view = ForgeRevisionView.forApi(api);
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
