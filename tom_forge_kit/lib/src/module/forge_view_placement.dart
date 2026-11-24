import 'package:flutter/widgets.dart' show IconData;

import '../components/forge_view.dart';
import 'forge_kit_module.dart';
import 'forge_kit_module_registry.dart';

/// What a contributed view is for, which an application maps to where it
/// shows it. It names no panel, tab or window: the panel shell puts
/// [navigation] views on one side, [details] on the other and [messages]
/// below the editors; another application decides as it likes.
enum ForgeViewRole {
  /// Finding and choosing what to work on: files, search results, revisions.
  navigation,

  /// About what the user works on now: the outline of the active editor.
  details,

  /// What the application reports: problems, output.
  messages,
}

/// A layout-free hint where a contributed view goes, read by the application
/// as it decides (the panel shell maps it to its panels, as it maps an
/// editor's placement hint to a middle panel).
///
/// Views of one [group] are shown together (the panel shell: as sections of
/// one tab, titled [group] with [groupIcon]); groups and the views in a group
/// are ordered by [order], lowest first.
class ForgeViewPlacementHint {
  const ForgeViewPlacementHint({
    required this.id,
    required this.role,
    this.group,
    this.groupIcon,
    this.order = 0,
  });

  /// The view's stable id, e.g. `forge.view.outline`: what an application
  /// finds the view by ([forgeContributedViewById]).
  final String id;

  /// What the view is for.
  final ForgeViewRole role;

  /// The views shown together with it; null: a group of its own, named by
  /// the view's title.
  final String? group;

  /// The group's icon; null: the view's own icon.
  final IconData? groupIcon;

  /// The order among the views of the same role (and within the group).
  final int order;

  @override
  String toString() => 'ForgeViewPlacementHint($id, ${role.name})';
}

/// One view a module contributes ([ForgeKitModule.views]) with its
/// placement hint.
class ForgeViewContribution {
  const ForgeViewContribution({required this.view, required this.hint});

  final ForgeView view;
  final ForgeViewPlacementHint hint;
}

/// The placement hints of a module's views, as a [ForgeModuleExtra]: the
/// module lists its views in [ForgeKitModule.views] and hands their hints
/// over here; an application without a use for them ignores the kind.
class ForgeViewContributionsExtra extends ForgeModuleExtra {
  const ForgeViewContributionsExtra(List<ForgeViewContribution> contributions)
    : super(kind: kindId, value: contributions);

  /// The kind of this extra.
  static const kindId = 'forge.kit.viewContributions';

  /// The views with their hints.
  List<ForgeViewContribution> get contributions =>
      value as List<ForgeViewContribution>;
}

/// A view a registered module contributes, with its hint (null when the
/// module gives none) and the module.
class ForgeContributedView {
  const ForgeContributedView({
    required this.view,
    required this.module,
    this.hint,
  });

  final ForgeView view;
  final ForgeKitModule module;
  final ForgeViewPlacementHint? hint;
}

/// Every view the modules of [registry] contribute, in registration order
/// and each module's [ForgeKitModule.views] order, with the hint the module
/// gives it ([ForgeViewContributionsExtra]). A hint for a view the module
/// does not list is ignored. Empty when no module has a view.
List<ForgeContributedView> forgeContributedViews(
  ForgeKitModuleRegistry registry,
) {
  final out = <ForgeContributedView>[];
  for (final module in registry.allKitModules) {
    final views = module.views;
    if (views.isEmpty) continue;
    final hints = <ForgeView, ForgeViewPlacementHint>{
      for (final extra
          in module.extras.whereType<ForgeViewContributionsExtra>())
        for (final contribution in extra.contributions)
          contribution.view: contribution.hint,
    };
    for (final view in views) {
      out.add(
        ForgeContributedView(view: view, module: module, hint: hints[view]),
      );
    }
  }
  return out;
}

/// The contributed view whose hint has [id], or null.
ForgeView? forgeContributedViewById(
  ForgeKitModuleRegistry registry,
  String id,
) {
  for (final contributed in forgeContributedViews(registry)) {
    if (contributed.hint?.id == id) return contributed.view;
  }
  return null;
}

/// Where an application shows its terminals — one section per open
/// terminal, made at run time — as a [ForgeModuleExtra] a terminal module
/// contributes: [hint]'s role says where (the panel shell: messages, the
/// bottom panel), its group titles the tab and its group icon is the tab's.
/// An application without terminals ignores the kind; with none contributed
/// it shows no terminal tab.
class ForgeTerminalSectionsExtra extends ForgeModuleExtra {
  const ForgeTerminalSectionsExtra(ForgeViewPlacementHint hint)
    : super(kind: kindId, value: hint);

  /// The kind of this extra.
  static const kindId = 'forge.kit.terminalSections';

  /// Where the terminals go.
  ForgeViewPlacementHint get hint => value as ForgeViewPlacementHint;
}

/// The placement of the terminals the first module of [registry] that
/// contributes one gives ([ForgeTerminalSectionsExtra]), or null.
ForgeViewPlacementHint? forgeTerminalSectionsHint(
  ForgeKitModuleRegistry registry,
) {
  for (final module in registry.allKitModules) {
    for (final extra in module.extras.whereType<ForgeTerminalSectionsExtra>()) {
      return extra.hint;
    }
  }
  return null;
}
