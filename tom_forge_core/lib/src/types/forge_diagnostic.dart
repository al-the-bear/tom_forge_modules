import 'package:tom_forge_core/src/types/forge_severity.dart';
import 'package:tom_forge_core/src/types/text_range.dart';

/// Category of a diagnostic, distinguishing tool analysis results from
/// system-level operational messages.
enum DiagnosticCategory {
  /// Code analysis diagnostic from a tool (e.g. linter, schema validator).
  analysis,

  /// System/operational diagnostic (e.g. module load failure, file open error).
  system,
}

/// A single diagnostic issue (error, warning, info, hint) associated
/// with a file and a text range.
class ForgeDiagnostic {
  /// The file this diagnostic applies to.
  final Uri uri;

  /// The range in the document.
  final ForgeTextRange range;

  /// The diagnostic message.
  final String message;

  /// Severity level.
  final ForgeSeverity severity;

  /// Source identifier (e.g., 'dart', 'yaml-lint', 'form-validator').
  final String source;

  /// Optional error code.
  final String? code;

  /// Category distinguishing tool analysis from system messages.
  final DiagnosticCategory category;

  const ForgeDiagnostic({
    required this.uri,
    required this.range,
    required this.message,
    required this.severity,
    required this.source,
    this.code,
    this.category = DiagnosticCategory.analysis,
  });

  @override
  String toString() =>
      'ForgeDiagnostic(${severity.name}: $message [$source]${code != null ? ' $code' : ''})';
}

/// Aggregated diagnostic counts by severity.
class DiagnosticSummary {
  final int errors;
  final int warnings;
  final int infos;
  final int hints;

  const DiagnosticSummary({
    this.errors = 0,
    this.warnings = 0,
    this.infos = 0,
    this.hints = 0,
  });

  /// Total number of diagnostics across all severities.
  int get total => errors + warnings + infos + hints;

  @override
  String toString() =>
      'DiagnosticSummary(E:$errors W:$warnings I:$infos H:$hints)';
}
