import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_agentic/tom_core_agentic.dart';

/// Basic editor preferences surfaced through the Forge config section
/// (`tom_specs_editor_specification.md` §12 — "Basic prefs → Forge config
/// section": theme, font, default app). The default **profile** lives in
/// [AgentSettings] (single source of truth); the basic-prefs panel reads/writes
/// it there.
///
/// Held in the spec workspace as YAML, out of the document `*.docspecs.yaml`
/// pass — mirrors the agent stores' resolve/load/save shape.
class EditorPreferences {
  const EditorPreferences({
    this.themeMode = 'dark',
    this.fontFamily = 'system',
    this.defaultApplication = 'DocSpecs',
    this.strictHeadlineEditing = true,
  });

  /// `system` | `light` | `dark`.
  final String themeMode;

  /// Editor font family (`system` = platform default).
  final String fontFamily;

  /// Application shown on launch: `DocSpecs` | `CodeSpecs` | `Implementation`.
  final String defaultApplication;

  /// Editor "strict" mode (YRD9): when `true`, headline/id inputs are editable
  /// only on list-entry sections; fixed sections render their stored or
  /// `@Headline`-default headline read-only. When `false`, headlines are
  /// editable everywhere. Defaults to strict so every document of a given type
  /// keeps a consistent fixed-section headline structure.
  final bool strictHeadlineEditing;

  EditorPreferences copyWith({
    String? themeMode,
    String? fontFamily,
    String? defaultApplication,
    bool? strictHeadlineEditing,
  }) =>
      EditorPreferences(
        themeMode: themeMode ?? this.themeMode,
        fontFamily: fontFamily ?? this.fontFamily,
        defaultApplication: defaultApplication ?? this.defaultApplication,
        strictHeadlineEditing:
            strictHeadlineEditing ?? this.strictHeadlineEditing,
      );

  factory EditorPreferences.fromYaml(Map<String, dynamic> yaml) =>
      EditorPreferences(
        themeMode: yaml['themeMode'] as String? ?? 'dark',
        fontFamily: yaml['fontFamily'] as String? ?? 'system',
        defaultApplication: yaml['defaultApplication'] as String? ?? 'DocSpecs',
        strictHeadlineEditing: yaml['strictHeadlineEditing'] as bool? ?? true,
      );

  Map<String, dynamic> toYaml() => <String, dynamic>{
        'themeMode': themeMode,
        'fontFamily': fontFamily,
        'defaultApplication': defaultApplication,
        'strictHeadlineEditing': strictHeadlineEditing,
      };
}

/// Loads/saves the singleton [EditorPreferences] as YAML.
class EditorPreferencesStore {
  EditorPreferencesStore(this.file);

  final File file;

  /// Resolves the prefs file. Honors `TOM_SPECS_PREFS_FILE`; falls back to
  /// `<cwd>/.tom/editor_preferences.yaml`.
  factory EditorPreferencesStore.resolveDefault() {
    final override = Platform.environment['TOM_SPECS_PREFS_FILE'];
    final path = (override != null && override.isNotEmpty)
        ? override
        : p.join(Directory.current.path, '.tom', 'editor_preferences.yaml');
    return EditorPreferencesStore(File(path));
  }

  EditorPreferences load() {
    try {
      if (!file.existsSync()) return const EditorPreferences();
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return const EditorPreferences();
      final root = decodeAgentYaml(content);
      final prefs = root['preferences'];
      if (prefs is! Map) return const EditorPreferences();
      return EditorPreferences.fromYaml(prefs.cast<String, dynamic>());
    } on FileSystemException {
      return const EditorPreferences();
    } on FormatException {
      return const EditorPreferences();
    }
  }

  void save(EditorPreferences prefs) {
    final yaml = encodeAgentYaml(<String, dynamic>{
      'version': 1,
      'preferences': prefs.toYaml(),
    });
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(yaml);
  }
}
