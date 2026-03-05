import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/src/dart_code_editor.dart';
import 'package:tom_dart_editor/src/editor_diagnostics_utils.dart';

void main() {
  group('EditorDiagnosticsUtils', () {
    final diagnostics = <CodeError>[
      const CodeError(
        line: 3,
        column: 1,
        offset: 0,
        length: 1,
        message: 'Missing semicolon',
        severity: 'warning',
        code: 'missing_semicolon',
      ),
      const CodeError(
        line: 3,
        column: 5,
        offset: 4,
        length: 1,
        message: 'Unused variable',
        severity: 'info',
        code: 'unused_local_variable',
      ),
      const CodeError(
        line: 5,
        column: 2,
        offset: 12,
        length: 3,
        message: 'Undefined name',
        severity: 'error',
        code: 'undefined_identifier',
      ),
    ];

    test('diagnosticsForLine returns all diagnostics for line', () {
      final lineDiagnostics = EditorDiagnosticsUtils.diagnosticsForLine(
        diagnostics,
        3,
      );

      expect(lineDiagnostics.length, 2);
      expect(lineDiagnostics.first.code, 'missing_semicolon');
      expect(lineDiagnostics.last.code, 'unused_local_variable');
    });

    test('diagnosticsSummaryForLine joins all diagnostics in line order', () {
      final summary = EditorDiagnosticsUtils.diagnosticsSummaryForLine(
        diagnostics,
        3,
      );

      expect(
          summary, contains('[WARNING] missing_semicolon: Missing semicolon'));
      expect(
          summary, contains('[INFO] unused_local_variable: Unused variable'));
      expect('\n'.allMatches(summary).length, 1);
    });

    test('diagnosticsSummaryForLine returns empty when no diagnostics', () {
      final summary = EditorDiagnosticsUtils.diagnosticsSummaryForLine(
        diagnostics,
        99,
      );

      expect(summary, isEmpty);
    });
  });
}
