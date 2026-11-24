import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_problems_view.dart';

/// The id of the Problems view ([ForgeViewPlacementHint.id]).
const String forgeProblemsViewId = 'forge.view.problems';

/// Where the Problems view goes unless the application says otherwise: with
/// the messages, first.
const ForgeViewPlacementHint forgeProblemsViewPlacement =
    ForgeViewPlacementHint(
      id: forgeProblemsViewId,
      role: ForgeViewRole.messages,
      group: 'Problems',
      groupIcon: Icons.error_outline,
    );

/// The module that contributes the Problems view ([ForgeProblemsView]) to
/// any application on the kit, with [placement] as its hint.
ForgeProblemsViewModule forgeProblemsViewModule({
  ForgeViewPlacementHint placement = forgeProblemsViewPlacement,
}) => ForgeProblemsViewModule(placement: placement);

/// Contributes the Problems view: made at activation over the application's
/// API ([ForgeProblemsView.forApi]), listed in [views], placed by its
/// [ForgeViewContributionsExtra].
class ForgeProblemsViewModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeProblemsViewModule({this.placement = forgeProblemsViewPlacement});

  /// The view's placement hint.
  final ForgeViewPlacementHint placement;

  ForgeProblemsView? _view;

  /// The view, once activated.
  ForgeProblemsView? get view => _view;

  @override
  String get displayName => 'Problems';

  @override
  void activate(ForgeKitApi api) {
    _view = ForgeProblemsView.forApi(api);
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
