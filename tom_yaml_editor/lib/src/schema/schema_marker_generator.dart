import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ValidationError, ValidationSeverity;
import 'package:tom_file_editors/tom_file_editors.dart'
    show TomTextMarker, TomTextMarkerSeverity;

/// Maps validation errors onto the source view's markers ([TomTextMarker]),
/// with their line and column.
///
/// Walks the YAML text to find the character offsets for each error's path,
/// so that squiggly underlines can be rendered in the text editor view.
///
/// ```dart
/// var markers = SchemaMarkerGenerator.generate(
///   yamlText: controller.yamlText,
///   errors: controller.errors,
/// );
/// ```
class SchemaMarkerGenerator {
  const SchemaMarkerGenerator._();

  /// Generate [TomTextMarker]s from validation errors.
  ///
  /// For each [ValidationError], finds the approximate line/column in the
  /// YAML source and creates a marker spanning the relevant token.
  static List<TomTextMarker> generate({
    required String yamlText,
    required List<ValidationError> errors,
  }) {
    if (errors.isEmpty || yamlText.isEmpty) return [];

    var lines = yamlText.split('\n');
    var markers = <TomTextMarker>[];

    for (var error in errors) {
      var location = _findPathLocation(lines, error.path);
      if (location == null) continue;

      markers.add(TomTextMarker(
        start: location.startOffset,
        end: location.endOffset,
        message: error.message,
        severity: _markerSeverity(error.severity),
        line: location.line,
        column: location.column,
      ));
    }

    return markers;
  }

  /// Find the character offset range of a path in the YAML text.
  ///
  /// Uses a simple heuristic: search for the key name at the expected
  /// indentation level. Not perfect for all edge cases but handles
  /// typical structured YAML well.
  static _PathLocation? _findPathLocation(
    List<String> lines,
    List<Object> path,
  ) {
    if (path.isEmpty) return null;

    // We search for the last segment of the path as a key
    var targetKey = path.last.toString();
    var expectedDepth = path.length - 1;

    // Approximate indent per level (common YAML convention)
    var indentPerLevel = 2;

    var charOffset = 0;
    for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
      var line = lines[lineIdx];

      // Check if this line contains the target key at approximately
      // the right indentation level
      var stripped = line.trimLeft();
      var actualIndent = line.length - stripped.length;
      var expectedIndent = expectedDepth * indentPerLevel;

      // Allow some tolerance in indent matching
      if ((actualIndent - expectedIndent).abs() <= indentPerLevel) {
        // Check for key pattern: "key:" or "key :"
        if (stripped.startsWith('$targetKey:') ||
            stripped.startsWith('$targetKey :')) {
          var keyStart = charOffset + actualIndent;
          var keyEnd = keyStart + targetKey.length;

          return _PathLocation(
            startOffset: keyStart,
            endOffset: keyEnd,
            line: lineIdx + 1,
            column: actualIndent + 1,
          );
        }

        // Check for list item with the key: "- key:" pattern
        if (stripped.startsWith('- $targetKey:') ||
            stripped.startsWith('- $targetKey :')) {
          var keyStart = charOffset + actualIndent + 2; // skip "- "
          var keyEnd = keyStart + targetKey.length;

          return _PathLocation(
            startOffset: keyStart,
            endOffset: keyEnd,
            line: lineIdx + 1,
            column: actualIndent + 3,
          );
        }
      }

      charOffset += line.length + 1; // +1 for newline
    }

    return null;
  }

  static TomTextMarkerSeverity _markerSeverity(ValidationSeverity severity) {
    switch (severity) {
      case ValidationSeverity.error:
        return TomTextMarkerSeverity.error;
      case ValidationSeverity.warning:
        return TomTextMarkerSeverity.warning;
      case ValidationSeverity.info:
        return TomTextMarkerSeverity.info;
    }
  }
}

class _PathLocation {
  final int startOffset;
  final int endOffset;
  final int line;
  final int column;

  const _PathLocation({
    required this.startOffset,
    required this.endOffset,
    required this.line,
    required this.column,
  });
}
