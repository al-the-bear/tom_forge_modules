import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../module/forge_kit_module_registry.dart';
import '../services/forge_action_registry.dart';

/// Resolves module context-menu contributions at a target and asks the
/// application to draw them.
///
/// Reached as `api.contextMenus`. A view or an editor that knows what is
/// under the pointer builds a [ForgeContextTarget] and calls [show]; the
/// application, which owns the overlay, is the [presenter] and draws the
/// menu. [entriesFor] is the resolution alone, for a surface that draws its
/// own menu and appends the contributions to it.
class ForgeContextMenuController {
  /// Resolves the contributions of the [modules] against the [actions];
  /// [moreContributions], when given, adds the contributions of whatever else
  /// the application has active (the panel shell passes its active
  /// application's), read on every resolution.
  ForgeContextMenuController({
    required ForgeKitModuleRegistry modules,
    required ForgeActionRegistry actions,
    Iterable<ForgeContextMenuContribution> Function()? moreContributions,
  }) : _modules = modules,
       _actions = actions,
       _moreContributions = moreContributions;

  final ForgeKitModuleRegistry _modules;
  final ForgeActionRegistry _actions;
  final Iterable<ForgeContextMenuContribution> Function()? _moreContributions;

  /// Draws the entries of a target at a global position. Bound by the
  /// application while it can draw; null means nothing can draw a menu, and
  /// [show] returns false.
  Future<void> Function(ForgeContextTarget target, Offset globalPosition)?
  presenter;

  /// The entries drawn at [target]: every registered module's contributions
  /// keyed by the target's kind that apply there, in module and declaration
  /// order, then the [moreContributions], then the target's own items that
  /// no contribution already stands for. Empty when nothing applies.
  List<ForgeContextMenuEntry> entriesFor(ForgeContextTarget target) {
    final entries = <ForgeContextMenuEntry>[];
    final drawn = <String>{};
    final contributions = [
      for (final module in _modules.allKitModules) ...module.contextMenus,
      ...?_moreContributions?.call(),
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
      entries.add(
        ForgeContextMenuEntry(
          id: action.id,
          label: contribution.label?.call(target) ?? action.label,
          enabled: enabled,
          unavailableReason: enabled ? null : reason,
          group: contribution.group,
          run: () async {
            await action.execute({ForgeContextTarget.parameterKey: target});
          },
        ),
      );
    }
    for (final item in target.items) {
      if (drawn.contains(item.id)) continue;
      entries.add(
        ForgeContextMenuEntry(
          id: item.id,
          label: item.label,
          enabled: item.enabled,
          unavailableReason: item.enabled ? null : item.unavailableReason,
          group: item.group,
          run: item.run,
        ),
      );
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
/// The application asks it on a secondary tap inside the editor, before it
/// draws its generic editor menu: a non-null target is drawn through
/// [ForgeContextMenuController] with the contributions keyed by its kind,
/// null falls back to the generic menu. An editor whose bodies know their
/// units better than a hit-test does — a grid cell, a board card — may
/// instead report them itself through `api.contextMenus.show` and answer
/// null here.
abstract interface class ForgeContextTargetProvider {
  ForgeContextTarget? contextTargetAt(Offset globalPosition);
}
