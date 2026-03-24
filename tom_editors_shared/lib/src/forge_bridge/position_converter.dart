import 'package:tom_forge_core/tom_forge_core.dart';

/// Utility for converting between character offset positions and
/// line/column positions in text documents.
///
/// Text editors internally may use different position representations.
/// This converter bridges offset-based positions (used by Flutter's
/// TextEditingController) to line/column positions (used by Forge types).
class PositionConverter {
  /// The text content used for position calculations.
  final String _text;

  /// Cached line start offsets for efficient conversion.
  late final List<int> _lineStarts = _computeLineStarts();

  PositionConverter(this._text);

  /// Number of lines in the text.
  int get lineCount => _lineStarts.length;

  /// Convert a character offset to a [ForgeTextPosition].
  ForgeTextPosition offsetToPosition(int offset) {
    if (offset < 0) return const ForgeTextPosition.zero();
    if (offset >= _text.length) {
      final lastLine = _lineStarts.length - 1;
      return ForgeTextPosition(
        line: lastLine,
        column: _text.length - _lineStarts[lastLine],
      );
    }

    // Binary search for the line containing this offset.
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (_lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }

    return ForgeTextPosition(line: low, column: offset - _lineStarts[low]);
  }

  /// Convert a [ForgeTextPosition] to a character offset.
  int positionToOffset(ForgeTextPosition position) {
    if (position.line < 0 || position.line >= _lineStarts.length) {
      return _text.length;
    }
    return _lineStarts[position.line] + position.column;
  }

  /// Get the text of a specific line (0-based), without the newline.
  String lineAt(int line) {
    if (line < 0 || line >= _lineStarts.length) return '';
    final start = _lineStarts[line];
    final end = (line + 1 < _lineStarts.length)
        ? _lineStarts[line + 1] - 1  // exclude newline
        : _text.length;
    if (end < start) return '';
    return _text.substring(start, end);
  }

  /// Get text within a [ForgeTextRange].
  String textInRange(ForgeTextRange range) {
    final startOffset = positionToOffset(range.start);
    final endOffset = positionToOffset(range.end);
    if (startOffset >= endOffset) return '';
    return _text.substring(
      startOffset.clamp(0, _text.length),
      endOffset.clamp(0, _text.length),
    );
  }

  List<int> _computeLineStarts() {
    final starts = <int>[0];
    for (var i = 0; i < _text.length; i++) {
      if (_text[i] == '\n') {
        starts.add(i + 1);
      }
    }
    return starts;
  }
}
