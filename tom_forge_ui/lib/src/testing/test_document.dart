import 'dart:async';
import 'dart:convert';

import 'package:tom_forge_core/tom_forge_core.dart';

/// In-memory [ForgeDocument] implementation for testing.
class ForgeTestDocument implements ForgeDocument {
  final Uri _uri;
  final List<String> _lines;
  final _changeController = StreamController<DocumentChangeEvent>.broadcast();
  int _version = 0;

  ForgeTestDocument({Uri? uri, String content = ''})
      : _uri = uri ?? Uri.parse('test://untitled'),
        _lines = content.isEmpty ? [''] : content.split('\n');

  @override
  Uri get uri => _uri;

  @override
  String get text => _lines.join('\n');

  @override
  int get lineCount => _lines.length;

  @override
  String lineAt(int line) => _lines[line];

  @override
  String textInRange(ForgeTextRange range) {
    if (range.start.line == range.end.line) {
      return _lines[range.start.line]
          .substring(range.start.column, range.end.column);
    }
    final buffer = StringBuffer();
    buffer.write(_lines[range.start.line].substring(range.start.column));
    for (var i = range.start.line + 1; i < range.end.line; i++) {
      buffer.write('\n');
      buffer.write(_lines[i]);
    }
    buffer.write('\n');
    buffer.write(_lines[range.end.line].substring(0, range.end.column));
    return buffer.toString();
  }

  @override
  String get languageId => 'plaintext';

  @override
  Encoding get encoding => utf8;

  @override
  int get version => _version;

  @override
  bool get isUntitled => _uri.scheme == 'test';

  @override
  Stream<DocumentChangeEvent> get onDidChange => _changeController.stream;

  /// Insert text at a position.
  void insert(ForgeTextPosition pos, String text) {
    final line = _lines[pos.line];
    _lines[pos.line] =
        line.substring(0, pos.column) + text + line.substring(pos.column);
    // Handle inserted newlines.
    final parts = _lines[pos.line].split('\n');
    if (parts.length > 1) {
      _lines[pos.line] = parts.first;
      _lines.insertAll(pos.line + 1, parts.skip(1));
    }
    _version++;
    _fireChange([ForgeTextRange(start: pos, end: pos)]);
  }

  /// Replace text in a range.
  void replace(ForgeTextRange range, String text) {
    if (range.start.line == range.end.line) {
      final line = _lines[range.start.line];
      _lines[range.start.line] = line.substring(0, range.start.column) +
          text +
          line.substring(range.end.column);
    } else {
      // Multi-line replace: combine start/end lines, remove middle.
      final before = _lines[range.start.line].substring(0, range.start.column);
      final after = _lines[range.end.line].substring(range.end.column);
      _lines.removeRange(range.start.line, range.end.line + 1);
      _lines.insert(range.start.line, before + text + after);
    }
    // Handle inserted newlines.
    final parts = _lines[range.start.line].split('\n');
    if (parts.length > 1) {
      _lines[range.start.line] = parts.first;
      _lines.insertAll(range.start.line + 1, parts.skip(1));
    }
    _version++;
    _fireChange([range]);
  }

  /// Find all occurrences of a pattern.
  List<ForgeTextRange> findAll(Pattern pattern) {
    final results = <ForgeTextRange>[];
    for (var lineNum = 0; lineNum < _lines.length; lineNum++) {
      for (final match in pattern.allMatches(_lines[lineNum])) {
        results.add(ForgeTextRange(
          start: ForgeTextPosition(line: lineNum, column: match.start),
          end: ForgeTextPosition(line: lineNum, column: match.end),
        ));
      }
    }
    return results;
  }

  /// Replace all occurrences of a pattern and return the count.
  int replaceAll(Pattern pattern, String replacement) {
    var count = 0;
    for (var i = 0; i < _lines.length; i++) {
      final matches = pattern.allMatches(_lines[i]).length;
      if (matches > 0) {
        count += matches;
        _lines[i] = _lines[i].replaceAll(pattern, replacement);
      }
    }
    if (count > 0) {
      _version++;
    }
    return count;
  }

  /// Set the full content, replacing all lines.
  void setContent(String content) {
    _lines.clear();
    _lines.addAll(content.isEmpty ? [''] : content.split('\n'));
    _version++;
    _fireChange([]);
  }

  void _fireChange(List<ForgeTextRange> changes) {
    _changeController
        .add(DocumentChangeEvent(changes: changes, document: this));
  }

  /// Dispose the change stream.
  void dispose() {
    _changeController.close();
  }
}
