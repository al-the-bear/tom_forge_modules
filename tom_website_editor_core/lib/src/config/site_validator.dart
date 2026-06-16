import 'config_issue.dart';

/// Validates a decoded `content/site.yaml` document (plain Dart maps/lists,
/// e.g. from `yamlToMap`).
///
/// The site file is hand-authored (the generator never rewrites it), so the
/// rules are deliberately lenient — the editor only flags what would break a
/// build. In particular `home.featured` is **optional**: a blank or absent
/// value means "no featured component" (the components page renders the flat
/// grid) and validates green (§9 todo 4). A non-empty `featured` that does not
/// resolve to one of [knownComponentIds] is a non-fatal [ConfigSeverity.warning]
/// (the value still loads), so the site editor can offer setting it back to a
/// real component id without blocking the registry. The same lenient rule
/// applies to the optional `detailedComponents:` list (§9 item 7): an unknown
/// id is a warning, an absent key is silent.
List<ConfigIssue> validateSiteConfig(
  Object? decoded, {
  Set<String> knownComponentIds = const {},
}) {
  final issues = <ConfigIssue>[];
  if (decoded is! Map) {
    issues.add(const ConfigIssue(
        path: '', message: 'site.yaml must be a YAML mapping'));
    return issues;
  }

  final home = decoded['home'];
  if (home != null && home is! Map) {
    issues.add(const ConfigIssue(
        path: 'home', message: 'home must be a mapping of home-page fields'));
    return issues;
  }
  if (home is Map) {
    _validateFeatured(home['featured'], knownComponentIds, issues);
  }
  _validateDetailedComponents(
      decoded['detailedComponents'], knownComponentIds, issues);
  return issues;
}

/// `detailedComponents` rules (§9 item 7): absent → no issue (optional, the
/// website falls back to its default); present must be a list of scalar ids; an
/// id that does not resolve to a [knownComponentIds] entry is a non-fatal
/// warning (the list still loads), mirroring the lenient `home.featured` rule.
void _validateDetailedComponents(
  Object? detailed,
  Set<String> knownComponentIds,
  List<ConfigIssue> issues,
) {
  if (detailed == null) return; // absent → fall back to the default scope.
  if (detailed is! List) {
    issues.add(const ConfigIssue(
        path: 'detailedComponents',
        message: 'detailedComponents must be a list of component ids'));
    return;
  }
  if (knownComponentIds.isEmpty) return;
  for (final entry in detailed) {
    final id = entry?.toString().trim() ?? '';
    if (id.isEmpty || knownComponentIds.contains(id)) continue;
    issues.add(ConfigIssue(
      path: 'detailedComponents',
      severity: ConfigSeverity.warning,
      message: 'detailedComponents references unknown component "$id"',
    ));
  }
}

/// `home.featured` rules: absent/blank → no issue (optional); a scalar id that
/// is unknown → warning; a non-scalar → error.
void _validateFeatured(
  Object? featured,
  Set<String> knownComponentIds,
  List<ConfigIssue> issues,
) {
  if (featured == null) return; // blank `featured:` → no featured component.
  if (featured is! String && featured is! num) {
    issues.add(const ConfigIssue(
        path: 'home.featured',
        message: 'featured must be a component id'));
    return;
  }
  final id = featured.toString().trim();
  if (id.isEmpty) return; // empty value → no featured component.
  if (knownComponentIds.isNotEmpty && !knownComponentIds.contains(id)) {
    issues.add(ConfigIssue(
      path: 'home.featured',
      severity: ConfigSeverity.warning,
      message: 'featured references unknown component "$id"',
    ));
  }
}
