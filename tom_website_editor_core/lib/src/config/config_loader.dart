import 'package:tom_build_base/tom_build_base.dart' show yamlToMap, toStringList;
import 'package:yaml/yaml.dart';

import '../model/website_editor_config.dart';
import 'config_issue.dart';
import 'config_validator.dart';

/// Outcome of loading a `tom.website-editor.yaml` document.
class ConfigLoadResult {
  const ConfigLoadResult({required this.config, required this.issues});

  /// The parsed config, or `null` when the document is invalid.
  final WebsiteEditorConfig? config;

  /// Every issue found while parsing/validating (errors and warnings).
  final List<ConfigIssue> issues;

  /// `true` when there are no error-severity issues (`config` is non-null).
  bool get isValid =>
      issues.every((issue) => issue.severity != ConfigSeverity.error);
}

/// Loads, validates, and builds a [WebsiteEditorConfig] from YAML [yamlSource].
///
/// YAML parse failures and validation violations are returned as
/// [ConfigIssue]s rather than thrown, so callers (and the §6 editor) can render
/// them. When any error-severity issue is present, [ConfigLoadResult.config]
/// is `null`.
ConfigLoadResult loadWebsiteEditorConfig(
  String yamlSource, {
  String source = 'tom.website-editor.yaml',
}) {
  final Object? decoded;
  try {
    final doc = loadYaml(yamlSource, sourceUrl: Uri.tryParse(source));
    decoded = doc is YamlMap ? yamlToMap(doc) : doc;
  } on YamlException catch (error) {
    return ConfigLoadResult(
      config: null,
      issues: [ConfigIssue(path: source, message: 'invalid YAML: ${error.message}')],
    );
  }

  final issues = validateWebsiteEditorConfig(decoded);
  if (!issues.every((i) => i.severity != ConfigSeverity.error) ||
      decoded is! Map) {
    return ConfigLoadResult(config: null, issues: issues);
  }
  return ConfigLoadResult(config: _buildConfig(decoded), issues: issues);
}

WebsiteEditorConfig _buildConfig(Map<dynamic, dynamic> root) {
  return WebsiteEditorConfig(
    version: root['version'] as int,
    defaults: _buildDefaults(root['defaults']),
    websites: [
      for (final entry in (root['websites'] as List))
        _buildWebsite(entry as Map),
    ],
  );
}

ConfigDefaults _buildDefaults(Object? raw) {
  if (raw is! Map) return const ConfigDefaults();
  final shell = raw.containsKey('shell')
      ? toStringList(raw['shell'])
      : kDefaultShell;
  return ConfigDefaults(
    shell: shell,
    placeholders: _stringMap(raw['placeholders']),
  );
}

WebsiteEntry _buildWebsite(Map<dynamic, dynamic> raw) {
  return WebsiteEntry(
    id: raw['id'] as String,
    label: raw['label'] as String?,
    paths: _stringMap(raw['paths']),
    preview: _stringMap(raw['preview']),
    cwd: raw['cwd'] as String?,
    commands: _stringMap(raw['commands']),
    content: _buildContent(raw['content']),
  );
}

WebsiteContentConfig? _buildContent(Object? raw) {
  if (raw is! Map) return null;
  return WebsiteContentConfig(
    dir: raw['dir'] as String,
    components:
        raw['components'] as String? ?? kDefaultContentComponents,
    copy: raw['copy'] as String? ?? kDefaultContentCopy,
    areas: raw['areas'] as String? ?? kDefaultContentAreas,
    site: raw['site'] as String? ?? kDefaultContentSite,
    pages: raw['pages'] as String? ?? kDefaultContentPages,
    editableFields: raw.containsKey('editableFields')
        ? toStringList(raw['editableFields'])
        : kDefaultEditableFields,
    manualPin: raw['manualPin'] as String? ?? kDefaultManualPin,
  );
}

Map<String, String> _stringMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      entry.key.toString(): entry.value.toString(),
  };
}
