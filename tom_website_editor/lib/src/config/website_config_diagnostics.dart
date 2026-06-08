import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

/// Diagnostic `source` tag for everything the config editor (§6) emits, so the
/// shell can group / filter website-config diagnostics distinctly.
const String websiteConfigDiagnosticSource = 'website-editor-config';

/// Computes the diagnostics shown by the `WebsiteConfigEditor` (§6) for a
/// `tom.website-editor.yaml` document.
///
/// This reuses the **runtime** loader/validator ([loadWebsiteEditorConfig]) and
/// the **runtime** resolver ([PlaceholderResolver]) so the editor and the
/// runtime agree on what a valid config is (single source of truth, §6):
///
/// 1. Every [ConfigIssue] from the loader becomes a [ForgeDiagnostic] — missing
///    required keys, malformed `commands`/`paths`, wrong types, duplicate ids.
/// 2. When the document is otherwise valid, each `{placeholder}` template is
///    resolved with the same priority order the runtime uses; a token that
///    cannot be resolved (unknown name, unset `{env:…}`, cycle) is surfaced as a
///    **warning** so command templates can be authored safely before anything
///    runs.
///
/// The loader does not (yet) carry source line/column, so diagnostics are placed
/// at the document head and the offending document path travels in [ForgeDiagnostic.code]
/// (e.g. `websites[0].commands.build`). Callers that want inline squiggles per
/// line can map [ForgeDiagnostic.code] to a line; precise line mapping is a
/// tracked refinement (see `completion_steps.tom_forge.md`).
List<ForgeDiagnostic> websiteConfigDiagnostics({
  required String yamlText,
  required Uri uri,
  Map<String, String> builtins = const {},
}) {
  final diagnostics = <ForgeDiagnostic>[];
  final result = loadWebsiteEditorConfig(yamlText, source: uri.toString());

  for (final issue in result.issues) {
    diagnostics.add(
      _diagnostic(
        uri: uri,
        message: issue.message,
        severity: issue.severity == ConfigSeverity.error
            ? ForgeSeverity.error
            : ForgeSeverity.warning,
        code: issue.path,
      ),
    );
  }

  // Placeholder awareness only makes sense once the structure is valid enough to
  // have produced a config model; otherwise the structural errors above already
  // tell the author what to fix.
  final config = result.config;
  if (config != null) {
    diagnostics.addAll(_placeholderWarnings(config, uri, builtins));
  }

  return diagnostics;
}

/// Resolves every `{placeholder}` template in the config and reports the ones
/// that fail as warnings carrying the offending token + document location.
List<ForgeDiagnostic> _placeholderWarnings(
  WebsiteEditorConfig config,
  Uri uri,
  Map<String, String> builtins,
) {
  final warnings = <ForgeDiagnostic>[];
  for (var i = 0; i < config.websites.length; i++) {
    final website = config.websites[i];
    final resolver = PlaceholderResolver.forWebsite(
      config,
      website,
      builtins: builtins,
    );

    void check(String? template, String location) {
      if (template == null) return;
      try {
        resolver.resolve(template, location: location);
      } on PlaceholderException catch (e) {
        warnings.add(
          _diagnostic(
            uri: uri,
            message: e.message,
            severity: ForgeSeverity.warning,
            code: location,
          ),
        );
      }
    }

    final prefix = 'websites[$i]';
    website.paths.forEach((k, v) => check(v, '$prefix.paths.$k'));
    website.preview.forEach((k, v) => check(v, '$prefix.preview.$k'));
    check(website.cwd, '$prefix.cwd');
    website.commands.forEach((k, v) => check(v, '$prefix.commands.$k'));
  }
  return warnings;
}

ForgeDiagnostic _diagnostic({
  required Uri uri,
  required String message,
  required ForgeSeverity severity,
  required String code,
}) {
  return ForgeDiagnostic(
    uri: uri,
    range: const ForgeTextRange(
      start: ForgeTextPosition(line: 0, column: 0),
      end: ForgeTextPosition(line: 0, column: 1),
    ),
    message: message,
    severity: severity,
    source: websiteConfigDiagnosticSource,
    code: code,
  );
}
