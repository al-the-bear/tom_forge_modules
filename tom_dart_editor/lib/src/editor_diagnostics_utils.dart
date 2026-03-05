import 'dart_code_editor.dart';

class EditorDiagnosticsUtils {
  static List<CodeError> diagnosticsForLine(
    List<CodeError> diagnostics,
    int line,
  ) {
    return diagnostics.where((d) => d.line == line).toList(growable: false);
  }

  static String diagnosticsSummaryForLine(
    List<CodeError> diagnostics,
    int line,
  ) {
    final lineDiagnostics = diagnosticsForLine(diagnostics, line);
    if (lineDiagnostics.isEmpty) return '';

    return lineDiagnostics
        .map((d) => '[${d.severity.toUpperCase()}] ${d.code}: ${d.message}')
        .join('\n');
  }
}
