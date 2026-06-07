import 'config_issue.dart';
import 'config_schema.dart';

/// Validates a decoded `tom.website-editor.yaml` document (plain Dart
/// maps/lists, e.g. from `yamlToMap`) against the config format.
///
/// Returns every problem found. Structural rules come from the shared
/// [websiteEditorConfigSpec] (the same source the JSON Schema is generated
/// from); semantic rules JSON Schema cannot express — currently website-id
/// uniqueness — are checked here.
List<ConfigIssue> validateWebsiteEditorConfig(Object? decoded) {
  final issues = <ConfigIssue>[];
  websiteEditorConfigSpec.validateNode(decoded, '', issues);
  _checkDuplicateIds(decoded, issues);
  return issues;
}

void _checkDuplicateIds(Object? decoded, List<ConfigIssue> issues) {
  if (decoded is! Map) return;
  final websites = decoded['websites'];
  if (websites is! List) return;
  final seen = <String>{};
  for (var i = 0; i < websites.length; i++) {
    final website = websites[i];
    if (website is! Map) continue;
    final id = website['id'];
    if (id is String && !seen.add(id)) {
      issues.add(ConfigIssue(
          path: 'websites[$i].id', message: 'duplicate website id "$id"'));
    }
  }
}
