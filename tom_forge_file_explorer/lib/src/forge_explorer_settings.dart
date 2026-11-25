/// What the explorer keeps through the kit's state store: the registered
/// roots, the root shown and each root's filter choice; and the filter
/// rules as text, one per line, for the rules dialog.
library;

import 'package:tom_file_session/tom_file_session.dart';

/// The prefix of the explorer's state-store keys unless the host names
/// another (`ForgeFileExplorerView.stateKey`).
const String forgeExplorerDefaultStateKey = 'forge.view.explorer';

/// A folder the explorer can show: the host's root, or one the user
/// registered (D36 §2.1).
class ForgeExplorerRoot {
  /// The name the root switcher lists it by.
  final String name;

  /// The folder.
  final Uri uri;

  const ForgeExplorerRoot({required this.name, required this.uri});

  /// The root of [uri], named by its folder's base name.
  factory ForgeExplorerRoot.of(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    return ForgeExplorerRoot(
      name: segments.isEmpty ? '/' : segments.last,
      uri: uri,
    );
  }

  Map<String, Object?> encode() => {'name': name, 'uri': uri.toString()};

  static ForgeExplorerRoot? decode(Object? value) {
    if (value is! Map) return null;
    final name = value['name'];
    final uri = Uri.tryParse('${value['uri']}');
    if (name is! String || name.isEmpty || uri == null) return null;
    return ForgeExplorerRoot(name: name, uri: uri);
  }
}

/// One root's filter choice: the preset chosen and, when the rules were
/// edited after choosing it, the edited rules (D36 §4.5).
class ForgeExplorerFilterChoice {
  /// The preset's name, or null for rules that came from no preset.
  final String? preset;

  /// The edited rules, or null: the preset's own.
  final ForgeFilter? rules;

  const ForgeExplorerFilterChoice({this.preset, this.rules});

  Map<String, Object?> encode() => {
    if (preset != null) 'preset': preset,
    if (rules != null) 'rules': rules!.encode(),
  };

  static ForgeExplorerFilterChoice? decode(Object? value) {
    if (value is! Map) return null;
    final preset = value['preset'];
    final rules = value['rules'];
    return ForgeExplorerFilterChoice(
      preset: preset is String ? preset : null,
      rules: rules is List ? ForgeFilter.decode(rules) : null,
    );
  }
}

/// [filter] as text, one rule per line in the form
/// [ForgeFilterRule.describe] writes it.
String forgeExplorerRulesText(ForgeFilter filter) =>
    filter.rules.map((r) => r.describe()).join('\n');

/// The rules of [text], one per line (blank lines and lines starting with
/// `#` skipped), or the problems, each naming its line.
///
/// A line is `include: <glob>`, `exclude: <glob>`,
/// `include extensions: md, yaml`, `exclude extensions: ...`, or one of the
/// switches `hidden: show|hide`, `gitignored: show|hide`,
/// `todo siblings: show|hide` — and the same in the words
/// [ForgeFilterRule.describe] uses (`hidden entries: hide`, ...).
({ForgeFilter? filter, List<String> problems}) forgeExplorerParseRules(
  String text,
) {
  final rules = <ForgeFilterRule>[];
  final problems = <String>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final colon = line.indexOf(':');
    if (colon == -1) {
      problems.add('Line ${i + 1}: no ":" in "$line"');
      continue;
    }
    final head = line.substring(0, colon).trim().toLowerCase();
    final value = line.substring(colon + 1).trim();
    bool? switchValue() => switch (value.toLowerCase()) {
      'show' => true,
      'hide' => false,
      _ => null,
    };
    List<String> list() => [
      for (final e in value.split(RegExp(r'[,\s]+')))
        if (e.isNotEmpty) e,
    ];
    ForgeFilterRule? rule;
    String? problem;
    switch (head) {
      case 'include' || 'exclude':
        if (value.isEmpty) {
          problem = 'a glob is missing';
        } else {
          rule = ForgeGlobRule(value, include: head == 'include');
        }
      case 'include extensions' || 'exclude extensions':
        if (list().isEmpty) {
          problem = 'no extension is given';
        } else {
          rule = ForgeExtensionRule(
            list(),
            include: head == 'include extensions',
          );
        }
      case 'hidden' || 'hidden entries':
        final show = switchValue();
        if (show != null) rule = ForgeHiddenRule(show: show);
      case 'gitignored' || 'gitignored entries':
        final show = switchValue();
        if (show != null) rule = ForgeGitignoredRule(show: show);
      case 'todo siblings' ||
          'todosiblings' ||
          'archived and deleted todo files':
        final show = switchValue();
        if (show != null) rule = ForgeTodoSiblingsRule(show: show);
      default:
        problem = 'unknown rule "$head"';
    }
    if (rule != null) {
      rules.add(rule);
    } else {
      problems.add('Line ${i + 1}: ${problem ?? 'say "show" or "hide"'}');
    }
  }
  return (
    filter: problems.isEmpty ? ForgeFilter(rules) : null,
    problems: problems,
  );
}
