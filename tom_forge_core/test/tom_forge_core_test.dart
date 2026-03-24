import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:test/test.dart';

void main() {
  group('ForgeTextPosition', () {
    test('equality', () {
      const a = ForgeTextPosition(line: 1, column: 5);
      const b = ForgeTextPosition(line: 1, column: 5);
      expect(a, equals(b));
    });

    test('zero constructor', () {
      const pos = ForgeTextPosition.zero();
      expect(pos.line, 0);
      expect(pos.column, 0);
    });
  });

  group('ForgeTextRange', () {
    test('isEmpty', () {
      const range = ForgeTextRange.empty();
      expect(range.isEmpty, isTrue);
    });

    test('non-empty range', () {
      const range = ForgeTextRange(
        start: ForgeTextPosition(line: 0, column: 0),
        end: ForgeTextPosition(line: 1, column: 10),
      );
      expect(range.isEmpty, isFalse);
    });
  });

  group('ForgeDiagnostic', () {
    test('construction', () {
      final diag = ForgeDiagnostic(
        uri: Uri.parse('file:///test.dart'),
        range: const ForgeTextRange.empty(),
        message: 'test error',
        severity: ForgeSeverity.error,
        source: 'test',
      );
      expect(diag.message, 'test error');
      expect(diag.severity, ForgeSeverity.error);
    });
  });

  group('DiagnosticSummary', () {
    test('total', () {
      const summary = DiagnosticSummary(errors: 2, warnings: 3, infos: 1);
      expect(summary.total, 6);
    });
  });

  group('FileHandlingResult', () {
    test('values', () {
      expect(FileHandlingResult.values.length, 3);
    });
  });
}
