import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_file_explorer_view.dart';

/// The id of the file explorer ([ForgeViewPlacementHint.id]).
const String forgeExplorerViewId = 'forge.view.explorer';

/// Where the file explorer goes unless the application says otherwise: with
/// the navigation, first in the Explorer group.
const ForgeViewPlacementHint forgeExplorerViewPlacement =
    ForgeViewPlacementHint(
      id: forgeExplorerViewId,
      role: ForgeViewRole.navigation,
      group: 'Explorer',
      groupIcon: Icons.folder_outlined,
    );

/// The module that contributes the file explorer ([ForgeFileExplorerView])
/// to any application on the kit, with [placement] as its hint, showing
/// [rootUri] (default: the folder of the application state's
/// [ForgeWorkspaceRoot], else the file system's root).
ForgeFileExplorerModule forgeFileExplorerModule({
  ForgeViewPlacementHint placement = forgeExplorerViewPlacement,
  Uri? rootUri,
}) => ForgeFileExplorerModule(placement: placement, rootUri: rootUri);

/// Contributes the file explorer: made at activation over the application's
/// API ([ForgeFileExplorerView.forApi]), listed in [views], placed by its
/// [ForgeViewContributionsExtra].
class ForgeFileExplorerModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeFileExplorerModule({
    this.placement = forgeExplorerViewPlacement,
    this.rootUri,
  });

  /// The view's placement hint.
  final ForgeViewPlacementHint placement;

  /// The folder the explorer shows; null takes the application state's
  /// [ForgeWorkspaceRoot] at activation.
  final Uri? rootUri;

  ForgeFileExplorerView? _view;

  /// The view, once activated.
  ForgeFileExplorerView? get view => _view;

  @override
  String get displayName => 'Explorer';

  @override
  void activate(ForgeKitApi api) {
    _view = ForgeFileExplorerView.forApi(
      api,
      rootUri:
          rootUri ??
          switch (api.state) {
            final ForgeWorkspaceRoot root => Uri.directory(
              root.workspaceRootPath,
            ),
            _ => Uri.directory('/'),
          },
    );
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
