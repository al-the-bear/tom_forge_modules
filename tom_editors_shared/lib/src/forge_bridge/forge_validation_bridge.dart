import 'package:tom_forge_core/tom_forge_core.dart';

import 'package:tom_ui_controls/tom_ui_controls.dart'
    show ValidationError, ValidationSeverity;

/// Converts [ValidationError] instances to [ForgeDiagnostic] instances.
///
/// Used by editor adapters (markdown, YAML) to bridge the
/// tom_editors_shared validation framework to the forge diagnostic system.
class ForgeValidationBridge {
  /// Converts a list of validation errors to forge diagnostics.
  ///
  /// The [uri] identifies the document.
  /// The [pathToRange] function converts a validation error path
  /// (list of keys/indices) to a text range in the document.
  static List<ForgeDiagnostic> convert(
    List<ValidationError> errors,
    Uri uri,
    ForgeTextRange Function(List<Object> path) pathToRange,
  ) {
    return errors.map((e) => ForgeDiagnostic(
      uri: uri,
      range: pathToRange(e.path),
      message: e.message,
      severity: _mapSeverity(e.severity),
      source: 'Schema',
      code: e.code,
    )).toList();
  }

  /// Maps a [ValidationSeverity] to a [ForgeSeverity].
  static ForgeSeverity _mapSeverity(ValidationSeverity severity) {
    return switch (severity) {
      ValidationSeverity.error => ForgeSeverity.error,
      ValidationSeverity.warning => ForgeSeverity.warning,
      ValidationSeverity.info => ForgeSeverity.info,
    };
  }
}
