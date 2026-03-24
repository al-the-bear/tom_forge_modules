/// A position in a text document, identified by line and column.
///
/// Both [line] and [column] are 0-based.
class ForgeTextPosition {
  /// 0-based line number.
  final int line;

  /// 0-based column offset.
  final int column;

  const ForgeTextPosition({required this.line, required this.column});

  /// Creates a position at the origin (0, 0).
  const ForgeTextPosition.zero() : line = 0, column = 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ForgeTextPosition && line == other.line && column == other.column;

  @override
  int get hashCode => Object.hash(line, column);

  @override
  String toString() => 'ForgeTextPosition($line:$column)';
}
