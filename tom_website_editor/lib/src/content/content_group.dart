import 'package:flutter/foundation.dart';

/// One hand-authored module group on a component (§9 item 1).
///
/// A component's `content/components/*.yaml` may carry a `groups:` block —
/// `groups: [{label, members: [moduleId, …]}]` — an arbitrary grouping of the
/// component's modules, authored by hand. Unlike the rest of the record (`id`,
/// `name`, `category`, `modules`), the generator never owns or rewrites this
/// block: it is **editable** and preserved across regeneration. Modules not
/// listed in any group fall under an "Other modules" section on the component
/// page.
@immutable
class ContentGroup {
  const ContentGroup({required this.label, required this.members});

  /// The group's display heading on the component page.
  final String label;

  /// The ids of the modules assigned to this group, in author order. Each id
  /// is expected to resolve to one of the component's real modules
  /// (validated by [unknownGroupMembers]).
  final List<String> members;

  /// A copy of this group with [label] and/or [members] replaced. Used by the
  /// browser's add/rename/reorder/assign edits before they are written back.
  ContentGroup copyWith({String? label, List<String>? members}) => ContentGroup(
        label: label ?? this.label,
        members: members ?? this.members,
      );

  @override
  bool operator ==(Object other) =>
      other is ContentGroup &&
      other.label == label &&
      listEquals(other.members, members);

  @override
  int get hashCode => Object.hash(label, Object.hashAll(members));

  @override
  String toString() => 'ContentGroup(label: $label, members: $members)';
}
