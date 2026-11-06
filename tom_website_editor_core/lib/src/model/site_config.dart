import 'package:tom_basics/utilities.dart' show tomYamlToPlain;
import 'package:yaml/yaml.dart';

import '../config/config_issue.dart';
import '../config/site_validator.dart';

/// A structured, validated view of a website's `content/site.yaml` (§4.3).
///
/// The file is hand-authored and holds the site's nav, categories, and
/// home-page fields. This model surfaces the scalars the editor edits today —
/// the [title], the [taglineMd], and the home page's [featured] component
/// (§9 todo 4) — and records the [featuredSourceLine] so a line-precise edit
/// can set or clear `home.featured` without disturbing the rest of the file.
///
/// `home.featured` is optional: a blank or absent value means "no featured
/// component" ([hasFeatured] is `false`) and the components page renders the
/// flat grid.
class SiteConfig {
  const SiteConfig({
    required this.title,
    required this.taglineMd,
    required this.featured,
    required this.featuredSourceLine,
    this.detailedComponents,
    this.detailedComponentsSourceLine,
  });

  /// Parses [raw] site YAML into a [SiteConfig]. A document that is not a YAML
  /// mapping yields an empty config (all fields `null`); malformed YAML throws
  /// [YamlException] (use [loadSiteConfig] to capture that as an issue).
  factory SiteConfig.parse(String raw) {
    final doc = loadYaml(raw);
    if (doc is! YamlMap) {
      return const SiteConfig(
        title: null,
        taglineMd: null,
        featured: null,
        featuredSourceLine: null,
      );
    }

    String? featured;
    int? featuredLine;
    final home = doc.nodes['home'];
    if (home is YamlMap) {
      for (final entry in home.nodes.entries) {
        final key = entry.key as YamlNode;
        if (key.value.toString() != 'featured') continue;
        featuredLine = key.span.start.line;
        final value = entry.value.value;
        final text = value?.toString().trim() ?? '';
        featured = text.isEmpty ? null : text;
        break;
      }
    }

    // `detailedComponents:` is a top-level list (§9 item 7). The key's source
    // line drives a line-precise edit; the value is captured only when the key
    // is present, so an absent key (`null`) is distinct from an explicit empty
    // list (the website falls back to its default only for the absent case).
    List<String>? detailed;
    int? detailedLine;
    for (final entry in doc.nodes.entries) {
      final key = entry.key as YamlNode;
      if (key.value.toString() != 'detailedComponents') continue;
      detailedLine = key.span.start.line;
      final value = entry.value.value;
      detailed = value is List
          ? [for (final e in value) e.toString()]
          : const [];
      break;
    }

    return SiteConfig(
      title: doc['title']?.toString(),
      taglineMd: doc['tagline-md']?.toString(),
      featured: featured,
      featuredSourceLine: featuredLine,
      detailedComponents: detailed,
      detailedComponentsSourceLine: detailedLine,
    );
  }

  /// The site title (`title:`), or `null` when absent.
  final String? title;

  /// The site tagline Markdown (`tagline-md:`), or `null` when absent.
  final String? taglineMd;

  /// The featured component id (`home.featured:`), or `null` when the value is
  /// blank or the key is absent.
  final String? featured;

  /// The 0-based source line of the `home.featured:` key, or `null` when the
  /// key is absent. Present even when the value is blank, so the editor can set
  /// a value on the existing line.
  final int? featuredSourceLine;

  /// The component ids whose detailed docs/API trees the site exposes
  /// (`detailedComponents:`, §9 item 7), or `null` when the key is absent.
  ///
  /// `null` means "key absent" — the website falls back to its built-in
  /// default. An explicit (possibly empty) list overrides that default, so an
  /// empty list means "no detailed components". This distinction is what lets
  /// the editor show the *effective* scope and round-trip an empty selection.
  final List<String>? detailedComponents;

  /// The 0-based source line of the top-level `detailedComponents:` key, or
  /// `null` when the key is absent. Drives a line-precise edit of the list.
  final int? detailedComponentsSourceLine;

  /// `true` when a non-empty featured component is configured.
  bool get hasFeatured => featured != null && featured!.isNotEmpty;

  /// `true` when the `detailedComponents:` key is present in the file (even if
  /// empty), so the editor can edit it in place rather than insert a new key.
  bool get hasDetailedComponents => detailedComponentsSourceLine != null;
}

/// Outcome of loading a `content/site.yaml` document: the parsed [config] (or
/// `null` on a YAML parse failure) and every [issue] found while validating it.
class SiteConfigResult {
  const SiteConfigResult({required this.config, required this.issues});

  /// The parsed model, or `null` when the document could not be parsed.
  final SiteConfig? config;

  /// Validation issues (errors and warnings).
  final List<ConfigIssue> issues;

  /// `true` when there are no error-severity issues.
  bool get isValid =>
      issues.every((issue) => issue.severity != ConfigSeverity.error);
}

/// Loads, validates, and parses a [SiteConfig] from YAML [raw].
///
/// YAML parse failures and validation violations are returned as
/// [ConfigIssue]s rather than thrown, so the site editor (§6a) can render them.
/// `home.featured` is validated against [knownComponentIds] when supplied: an
/// unknown id surfaces a warning (never an error), so an empty or absent
/// featured — and a featured pointing at a real component — both validate green.
SiteConfigResult loadSiteConfig(
  String raw, {
  Set<String> knownComponentIds = const {},
}) {
  final Object? decoded;
  try {
    final doc = loadYaml(raw);
    decoded = tomYamlToPlain(doc);
  } on YamlException catch (error) {
    return SiteConfigResult(
      config: null,
      issues: [
        ConfigIssue(path: 'site.yaml', message: 'invalid YAML: ${error.message}'),
      ],
    );
  }

  final issues =
      validateSiteConfig(decoded, knownComponentIds: knownComponentIds);
  return SiteConfigResult(config: SiteConfig.parse(raw), issues: issues);
}
