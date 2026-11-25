import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'package:tom_file_session/tom_file_session.dart'
    show ForgeFilter, ForgeFilterPreset;

import 'forge_explorer_settings.dart';
import 'forge_explorer_tree_walk.dart';
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
/// [ForgeWorkspaceRoot], else the file system's root). [filter],
/// [filterPresets], [rootSwitcher], [pickFolder], [stateKey] and
/// [walkLimit] are the view's ([ForgeFileExplorerView]); left out, the
/// explorer is Tom Forge's.
ForgeFileExplorerModule forgeFileExplorerModule({
  ForgeViewPlacementHint placement = forgeExplorerViewPlacement,
  Uri? rootUri,
  ForgeFilter? filter,
  List<ForgeFilterPreset>? filterPresets,
  bool rootSwitcher = false,
  Future<Uri?> Function()? pickFolder,
  String stateKey = forgeExplorerDefaultStateKey,
  int walkLimit = forgeExplorerWalkLimit,
}) => ForgeFileExplorerModule(
  placement: placement,
  rootUri: rootUri,
  filter: filter,
  filterPresets: filterPresets,
  rootSwitcher: rootSwitcher,
  pickFolder: pickFolder,
  stateKey: stateKey,
  walkLimit: walkLimit,
);

/// Contributes the file explorer: made at activation over the application's
/// API ([ForgeFileExplorerView.forApi]), listed in [views], placed by its
/// [ForgeViewContributionsExtra].
class ForgeFileExplorerModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  ForgeFileExplorerModule({
    this.placement = forgeExplorerViewPlacement,
    this.rootUri,
    this.filter,
    this.filterPresets,
    this.rootSwitcher = false,
    this.pickFolder,
    this.stateKey = forgeExplorerDefaultStateKey,
    this.walkLimit = forgeExplorerWalkLimit,
  });

  /// The view's placement hint.
  final ForgeViewPlacementHint placement;

  /// The folder the explorer shows; null takes the application state's
  /// [ForgeWorkspaceRoot] at activation.
  final Uri? rootUri;

  /// The view's filter rules ([ForgeFileExplorerView.filter]).
  final ForgeFilter? filter;

  /// The view's presets ([ForgeFileExplorerView.filterPresets]).
  final List<ForgeFilterPreset>? filterPresets;

  /// Whether the view offers the root switcher.
  final bool rootSwitcher;

  /// The folder picker of the switcher's *Add folder…*.
  final Future<Uri?> Function()? pickFolder;

  /// The prefix of the view's state-store keys.
  final String stateKey;

  /// The filtering view's walk limit.
  final int walkLimit;

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
      filter: filter,
      filterPresets: filterPresets,
      rootSwitcher: rootSwitcher,
      pickFolder: pickFolder,
      stateKey: stateKey,
      walkLimit: walkLimit,
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
