import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_file_system/tom_file_system.dart';

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
  }) => EditorPreferences(
    themeMode: themeMode ?? this.themeMode,
    fontFamily: fontFamily ?? this.fontFamily,
    defaultApplication: defaultApplication ?? this.defaultApplication,
    strictHeadlineEditing: strictHeadlineEditing ?? this.strictHeadlineEditing,
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

/// Loads/saves the singleton [EditorPreferences] as YAML, through the
/// workspace's [TomFileSystem].
class EditorPreferencesStore {
  EditorPreferencesStore({required this.fileSystem, required this.uri});

  /// The prefs file's location: [overridePath] when given (the app passes
  /// `TOM_SPECS_PREFS_FILE`), else `.tom/editor_preferences.yaml` in the
  /// workspace [fileSystem].
  factory EditorPreferencesStore.resolveDefault(
    TomFileSystem fileSystem, {
    String? overridePath,
  }) => EditorPreferencesStore(
    fileSystem: fileSystem,
    uri: fileSystem.uriOf(
      overridePath != null && overridePath.isNotEmpty
          ? overridePath
          : '.tom/editor_preferences.yaml',
    ),
  );

  /// The file system the prefs file is read and written through.
  final TomFileSystem fileSystem;

  /// The prefs file.
  final Uri uri;

  /// The saved preferences; the defaults when the file is missing, empty,
  /// unreadable or not a preferences document.
  Future<EditorPreferences> load() async {
    final String? content;
    try {
      content = await fileSystem.readTextIfExists(uri);
    } on Exception {
      return const EditorPreferences();
    }
    if (content == null || content.trim().isEmpty) {
      return const EditorPreferences();
    }
    try {
      final prefs = decodeAgentYaml(content)['preferences'];
      if (prefs is! Map) return const EditorPreferences();
      return EditorPreferences.fromYaml(prefs.cast<String, dynamic>());
    } on FormatException {
      return const EditorPreferences();
    }
  }

  /// Writes [prefs], making the file's folder when it is missing.
  Future<void> save(EditorPreferences prefs) =>
      fileSystem.writeTextMakingFolder(
        uri,
        encodeAgentYaml(<String, dynamic>{
          'version': 1,
          'preferences': prefs.toYaml(),
        }),
      );
}
