/// Module context-menu contributions and the targets they are drawn at.
///
/// A module declares *where* its actions appear as context-menu entries by
/// naming a **target kind** — a string the shell and the module agree on,
/// such as [ForgeContextTarget.explorerFileKind] for a row of the shell's own
/// file explorer, or an editor's own kinds for the units it reports. The
/// shell draws the menu: when a target of that kind is right-clicked (or
/// long-pressed), every contribution keyed by the kind that applies at the
/// target becomes one entry, enabled by the contribution's predicate and
/// showing its unavailable reason while disabled, followed by whatever items
/// the target itself brought. Nothing here is Flutter: the model is pure Dart
/// so a module's descriptor can be read and tested without a widget tree.
library;

/// What a context menu is opened on.
///
/// Produced by whoever knows what is under the pointer — the shell's file
/// explorer for its rows, an editor for the units it draws — and handed to
/// the shell, which resolves the contributions keyed by [kind] and draws them.
class ForgeContextTarget {
  const ForgeContextTarget({
    required this.kind,
    this.data,
    this.items = const [],
  });

  /// The kind the contributions are keyed by. Namespaced by its owner
  /// (`forge.explorer.file`, `<module>.<unit>`), so two modules' kinds cannot
  /// collide.
  final String kind;

  /// What the target is — a file [Uri], an editor's own focus object, anything
  /// a contribution's predicate knows how to read. Opaque to the shell.
  final Object? data;

  /// Items the target brings of its own: commands only the producer can
  /// perform (a grid's *Clear cell*, a row's *Rename…*), drawn after the
  /// contributed entries. An item whose [ForgeContextMenuItem.id] is the id
  /// of a contributed action that was drawn is skipped — the contribution
  /// already stands for it.
  final List<ForgeContextMenuItem> items;

  /// The key under which the shell passes the target to the action it runs:
  /// `action.execute({ForgeContextTarget.parameterKey: target})`. An action
  /// that acts "at the focus" can act at the target instead.
  static const parameterKey = 'contextTarget';

  /// A file row of the shell's file explorer; [data] is the file's [Uri].
  static const explorerFileKind = 'forge.explorer.file';

  /// A directory row of the shell's file explorer; [data] is the directory's
  /// [Uri].
  static const explorerDirectoryKind = 'forge.explorer.directory';

  @override
  String toString() =>
      'ForgeContextTarget($kind, ${data ?? '-'}, ${items.length} items)';
}

/// One item a [ForgeContextTarget] brings of its own.
class ForgeContextMenuItem {
  const ForgeContextMenuItem({
    required this.id,
    required this.label,
    required this.run,
    this.enabled = true,
    this.unavailableReason,
    this.group,
  });

  /// Stable id — also the menu entry's widget key suffix. When it is the id
  /// of a contributed action drawn at the same target, the item is skipped.
  final String id;

  final String label;

  /// Whether it can run at the target now. A disabled item is still listed,
  /// so a menu keeps its shape wherever it is opened.
  final bool enabled;

  /// Why it cannot run, shown as the disabled entry's tooltip.
  final String? unavailableReason;

  /// Items with the same group are drawn together; a divider is drawn where
  /// the group changes. Null groups with the item before it.
  final String? group;

  final Future<void> Function() run;
}

/// A module's declaration that one of its actions is a context-menu entry at
/// targets of [targetKind].
///
/// The action is named by [actionId] and resolved by the shell from its
/// action registry — the module registers the action itself, and the
/// contribution only places it. [label] and [unavailableReason] read the
/// target, so an entry can say *Delete row 3* and *Nothing to inline here*
/// rather than the action's static label and a bare disabled state.
class ForgeContextMenuContribution {
  const ForgeContextMenuContribution({
    required this.targetKind,
    required this.actionId,
    this.group,
    this.isApplicable,
    this.label,
    this.unavailableReason,
  });

  /// The [ForgeContextTarget.kind] this entry is drawn at.
  final String targetKind;

  /// The id of the module action the entry runs.
  final String actionId;

  /// Entries with the same group are drawn together, in declaration order; a
  /// divider is drawn where the group changes.
  final String? group;

  /// Whether the entry is drawn at [target] at all. Null draws it at every
  /// target of [targetKind]. An inapplicable entry is **absent**, not
  /// disabled: a menu lists what could apply here, disabled for a reason.
  final bool Function(ForgeContextTarget target)? isApplicable;

  /// The entry's label at [target]; null uses the action's label.
  final String Function(ForgeContextTarget target)? label;

  /// Why the entry cannot run at [target], or null when it can. When given,
  /// it decides the entry's enablement; when null, the action's own
  /// `isEnabled()` does.
  final String? Function(ForgeContextTarget target)? unavailableReason;

  @override
  String toString() => 'ForgeContextMenuContribution($targetKind → $actionId)';
}
