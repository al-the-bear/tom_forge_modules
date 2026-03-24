import 'package:tom_forge_core/src/types/text_position.dart';

/// A range in a text document, defined by a start and end position.
class ForgeTextRange {
  final ForgeTextPosition start;
  final ForgeTextPosition end;

  const ForgeTextRange({required this.start, required this.end});

  /// Creates an empty range at the origin.
  const ForgeTextRange.empty()
      : start = const ForgeTextPosition.zero(),
        end = const ForgeTextPosition.zero();

  /// Whether this range is empty (start equals end).
  bool get isEmpty => start == end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForgeTextRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ForgeTextRange($start → $end)';
}
