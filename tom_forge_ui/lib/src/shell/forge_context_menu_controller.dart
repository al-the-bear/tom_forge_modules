import '../model/forge_application.dart';
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../services/forge_action_registry.dart';
import 'forge_module_registry.dart';

/// One entry of a context menu the shell draws at a [ForgeContextTarget]:
/// a module contribution resolved against its action, or an item the target
/// brought of its own.
class ForgeContextMenuEntry {
  const ForgeContextMenuEntry({
    required this.id,
    required this.label,
    required this.enabled,
    required this.run,
    this.unavailableReason,
    this.group,
  });

  /// The action id of a contribution, or the item's own id.
  final String id;

  final String label;

  final bool enabled;

  /// Shown as the disabled entry's tooltip.
  final String? unavailableReason;

  /// A divider is drawn where it changes.
  final String? group;

  final Future<void> Function() run;
}

/// Resolves module context-menu contributions at a target and asks the shell
/// to draw them.
///
/// Reached as `shell.contextMenus`. A view or an editor that knows what is
/// under the pointer builds a [ForgeContextTarget] and calls [show]; the
/// shell's scaffold, which owns the overlay, is the [presenter] and draws the
/// menu. [entriesFor] is the resolution alone, for a surface that draws its
/// own menu and appends the contributions to it — the shell's file explorer.
class ForgeContextMenuController {
  ForgeContextMenuController({
    required ForgeModuleRegistry modules,
    required ForgeActionRegistry actions,
    required ForgeApplicationRegistry applications,
  })  : _modules = modules,
        _actions = actions,
        _applications = applications;

  final ForgeModuleRegistry _modules;
  final ForgeActionRegistry _actions;
  final ForgeApplicationRegistry _applications;

  /// Draws the entries of a target at a global position. Bound by the shell
  /// scaffold while it is mounted; null means nothing can draw a menu, and
  /// [show] returns false.
  Future<void> Function(ForgeContextTarget target, Offset globalPosition)?
      presenter;

  /// The entries drawn at [target]: every registered module's contributions
  /// keyed by the target's kind that apply there, in module and declaration
  /// order, then the active application's, then the target's own items that
  /// no contribution already stands for. Empty when nothing applies.
  List<ForgeContextMenuEntry> entriesFor(ForgeContextTarget target) {
    final entries = <ForgeContextMenuEntry>[];
    final drawn = <String>{};
    final contributions = [
      for (final module in _modules.allModules) ...module.contextMenus,
      ...?_applications.active?.contributions.contextMenus,
    ];
    for (final contribution in contributions) {
      if (contribution.targetKind != target.kind) continue;
      if (!(contribution.isApplicable?.call(target) ?? true)) continue;
      final action = _actions.getAction(contribution.actionId);
      if (action == null || !action.isVisible()) continue;
      if (!drawn.add(action.id)) continue;
      final reason = contribution.unavailableReason?.call(target);
      final enabled = contribution.unavailableReason != null
          ? reason == null
          : action.isEnabled();
      entries.add(ForgeContextMenuEntry(
        id: action.id,
        label: contribution.label?.call(target) ?? action.label,
        enabled: enabled,
        unavailableReason: enabled ? null : reason,
        group: contribution.group,
        run: () async {
          await action.execute({ForgeContextTarget.parameterKey: target});
        },
      ));
    }
    for (final item in target.items) {
      if (drawn.contains(item.id)) continue;
      entries.add(ForgeContextMenuEntry(
        id: item.id,
        label: item.label,
        enabled: item.enabled,
        unavailableReason: item.enabled ? null : item.unavailableReason,
        group: item.group,
        run: item.run,
      ));
    }
    return entries;
  }

  /// Draws the menu for [target] at [globalPosition] through the presenter.
  /// False when no presenter is bound or nothing applies at the target, so
  /// the caller can draw its own menu instead.
  Future<bool> show(ForgeContextTarget target, Offset globalPosition) async {
    final present = presenter;
    if (present == null) return false;
    if (entriesFor(target).isEmpty) return false;
    await present(target, globalPosition);
    return true;
  }
}

/// An editor (or view) that can say what is under the pointer.
///
/// The shell asks it on a secondary tap inside the editor area, before it
/// draws its generic editor menu: a non-null target is drawn through
/// [ForgeContextMenuController] with the contributions keyed by its kind,
/// null falls back to the generic menu. An editor whose bodies know their
/// units better than a hit-test does — a grid cell, a board card — may
/// instead report them itself through `shell.contextMenus.show` and answer
/// null here.
abstract interface class ForgeContextTargetProvider {
  ForgeContextTarget? contextTargetAt(Offset globalPosition);
}
