import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_search_view.dart';

/// The id of the Search view ([ForgeViewPlacementHint.id]).
const String forgeSearchViewId = 'forge.view.search';

/// Where the Search view goes unless the application says otherwise: with
/// the navigation, after the file explorer's group.
const ForgeViewPlacementHint forgeSearchViewPlacement = ForgeViewPlacementHint(
  id: forgeSearchViewId,
  role: ForgeViewRole.navigation,
  group: 'Search',
  groupIcon: Icons.search,
  order: 10,
);

/// The module that contributes the Search view ([ForgeSearchView]) to any
/// application on the kit, with [placement] as its hint; [workspaceRoot] is
/// the folder its paths are shown relative to (default: the application
/// state's [ForgeWorkspaceRoot]).
ForgeSearchViewModule forgeSearchViewModule({
  ForgeViewPlacementHint placement = forgeSearchViewPlacement,
  String? workspaceRoot,
}) => ForgeSearchViewModule(placement: placement, workspaceRoot: workspaceRoot);

/// Contributes the Search view: made at activation over the application's
/// API ([ForgeSearchView.forApi]), listed in [views], placed by its
/// [ForgeViewContributionsExtra].
class ForgeSearchViewModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeSearchViewModule({
    this.placement = forgeSearchViewPlacement,
    this.workspaceRoot,
  });

  /// The view's placement hint.
  final ForgeViewPlacementHint placement;

  /// The folder the view's paths are shown relative to; null takes the
  /// application state's [ForgeWorkspaceRoot].
  final String? workspaceRoot;

  ForgeSearchView? _view;

  /// The view, once activated.
  ForgeSearchView? get view => _view;

  @override
  String get displayName => 'Search';

  @override
  void activate(ForgeKitApi api) {
    _view = ForgeSearchView.forApi(api, workspaceRoot: workspaceRoot);
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
