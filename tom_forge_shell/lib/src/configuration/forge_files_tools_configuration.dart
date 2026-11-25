import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/material.dart' show BuildContext, Icons, Widget;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../services/forge_preferences_service.dart';

/// The shell's file type associations as a configuration description: the
/// *File Types* section, one association table from file extension to the
/// editor it opens in, with `*` for every other extension.
///
/// Kept where the shell always kept it, through
/// [ForgeFileTypesSettingBinding]: `forge.files.typeDefaults`, a map of
/// extension (`.md`) to editor id. The built-in associations are the
/// table's defaults, the stored entries laid over them. The editors a row
/// offers come from the [editorChoicesProvider] hook ([hooks]): the editors
/// the shell's editor picker has for that extension and the built-in ones.
abstract final class ForgeFileTypesConfiguration {
  /// The description's id.
  static const descriptionId = 'forge.files';

  /// The id of the *File Types* section.
  static const sectionId = 'fileTypes';

  /// `<description>/<section>` of the *File Types* section.
  static const sectionRef = '$descriptionId/$sectionId';

  /// The id of the choices provider asked for a row's editors.
  static const editorChoicesProvider = 'forge.shell.editorChoices';

  /// The editors every row offers.
  static const builtInEditors = {
    'md': 'Markdown',
    'dart': 'Dart',
    'yaml': 'YAML',
    'plaintext': 'Plain Text',
  };

  /// The associations while nothing is stored, as the shell always had
  /// them; `*` (every other extension) opens as plain text.
  static const defaultAssociations = {
    '*': 'plaintext',
    '.md': 'md',
    '.markdown': 'md',
    '.dart': 'dart',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.json': 'yaml',
  };

  /// The association table.
  static final associations = ForgeStringMapSetting(
    id: 'associations',
    storage: const ForgeSettingStorage(
      ForgeFileTypesSettingBinding.typeDefaultsKey,
      binding: ForgeFileTypesSettingBinding.bindingId,
    ),
    label: const ForgeText(
      'forge.config.fileTypes.associations.label',
      'File Type Associations',
    ),
    defaultValue: defaultAssociations,
    keyLabel: const ForgeText('forge.config.fileTypes.extension', 'Extension'),
    valueLabel: const ForgeText('forge.config.fileTypes.editor', 'Editor'),
    keyPattern: r'\.[a-z0-9_.+-]+',
    valueChoicesProvider: editorChoicesProvider,
    keyNormalizer: ForgeMapKeyNormalizer.fileExtension,
    mergeDefaults: true,
    defaultKey: '*',
    defaultKeyLabel: const ForgeText(
      'forge.config.fileTypes.default',
      'Default Editor (unmapped extensions)',
    ),
  );

  /// The *File Types* section.
  static final section = ForgeSettingsSection(
    id: sectionId,
    title: const ForgeText('forge.config.fileTypes.title', 'File Types'),
    icon: ForgeIconRef(Icons.folder_open.codePoint),
    order: 7,
    settings: [associations],
  );

  /// The description: [section].
  static final description = ForgeConfigurationDescription(
    id: descriptionId,
    title: const ForgeText('forge.config.fileTypes.description', 'File Types'),
    sections: [section],
  );

  /// The hooks the description names: a row's editors ([shell]'s editor
  /// picker for a file of that extension, then [builtInEditors]).
  static ForgeSettingHooks hooks(ForgeKitApi shell) => ForgeSettingHooks(
    choices: [
      ForgeCallbackChoicesProvider(
        id: editorChoicesProvider,
        onChoices: (context) async {
          final extension = context.key ?? '';
          final out = <ForgeSettingChoice>[];
          final seen = <String>{};
          if (extension.isNotEmpty && extension != '*') {
            final choices = await shell.editorPicker.choicesFor(
              ForgeContentItem(Uri.file('/forge-file-type$extension')),
            );
            for (final choice in choices.choices) {
              if (seen.add(choice.id)) {
                out.add(
                  ForgeSettingChoice(
                    choice.id,
                    ForgeText.literal(choice.label),
                  ),
                );
              }
            }
          }
          for (final entry in builtInEditors.entries) {
            if (seen.add(entry.key)) {
              out.add(
                ForgeSettingChoice(
                  entry.key,
                  ForgeText(
                    'forge.config.fileTypes.editor.${entry.key}',
                    entry.value,
                  ),
                ),
              );
            }
          }
          return out;
        },
      ),
    ],
  );
}

/// The [ForgeSettingBinding] of the file type associations in the
/// [ForgePreferencesService] (`forge.files.typeDefaults`): a write sets and
/// clears the service's entries and the [shell]'s file type defaults, as the
/// hand-written section did. The service keeps the default key (every other
/// extension) as `.*`, the shell as `*`.
class ForgeFileTypesSettingBinding extends ForgeSettingBinding {
  ForgeFileTypesSettingBinding(this.preferences, {this.shell});

  /// The binding's id.
  static const bindingId = 'forge.files';

  /// `forge.files.typeDefaults`: extension → editor id.
  static const typeDefaultsKey = 'forge.files.typeDefaults';

  /// The service the associations are read from and written to.
  final ForgePreferencesService preferences;

  /// The shell whose file type defaults follow; null: only the preferences.
  final ForgeKitApi? shell;

  StreamController<String>? _changes;
  int _writing = 0;
  String? _reported;

  @override
  String get id => bindingId;

  @override
  Future<Object?> read(String key) async =>
      key == typeDefaultsKey ? preferences.fileTypeDefaultEditors : null;

  @override
  Future<void> write(String key, Object? document) {
    if (key != typeDefaultsKey) return Future.value();
    _writing++;
    try {
      final p = preferences;
      // The preferences keep the default key as `.*`, the shell as `*`.
      final wanted = <String, String>{
        if (document is Map)
          for (final entry in document.entries)
            _preferenceKey('${entry.key}'): '${entry.value}',
      };
      for (final extension in p.fileTypeDefaultEditors.keys.toList()) {
        if (wanted.containsKey(_preferenceKey(extension))) continue;
        p.clearFileTypeDefaultEditor(extension);
        shell?.clearFileTypeDefault(_shellKey(extension));
      }
      for (final entry in wanted.entries) {
        if (p.fileTypeDefaultEditors[entry.key] != entry.value) {
          p.setFileTypeDefaultEditor(entry.key, entry.value);
        }
        shell?.setFileTypeDefault(_shellKey(entry.key), entry.value);
      }
    } finally {
      _writing--;
      _reported = _encoded();
    }
    return preferences.flushed();
  }

  static bool _isDefaultKey(String key) => key == '*' || key == '.*';

  static String _preferenceKey(String key) => _isDefaultKey(key) ? '.*' : key;

  static String _shellKey(String key) => _isDefaultKey(key) ? '*' : key;

  String _encoded() => jsonEncode(preferences.fileTypeDefaultEditors);

  @override
  Stream<String> watch() {
    final changes = _changes ??= StreamController<String>.broadcast(
      onListen: () {
        _reported = _encoded();
        preferences.addListener(_onPreferencesChanged);
      },
      onCancel: () => preferences.removeListener(_onPreferencesChanged),
    );
    return changes.stream;
  }

  void _onPreferencesChanged() {
    final changes = _changes;
    if (changes == null || !changes.hasListener || _writing > 0) return;
    final now = _encoded();
    if (now == _reported) return;
    _reported = now;
    changes.add(typeDefaultsKey);
  }

  @override
  Future<void> flushed() => preferences.flushed();
}

/// The external tools the modules registered, as a configuration
/// description: the *External Tools* section, one tool path setting per tool
/// (`forge.tools.<id>.path`, empty: *find it*), in the tools' order.
///
/// A tool is a descriptor (`ForgeExternalTool`) only its module knows; the
/// shell builds the description from the tools it is given ([description])
/// and their behaviour from the same tools ([hooks]): each tool's check and
/// its wider search are the setting's detector, its help (how to get or
/// repair it) the setting's help panel ([buildHelpPanel]).
abstract final class ForgeExternalToolsConfiguration {
  /// The description's id.
  static const descriptionId = 'forge.tools';

  /// The id of the *External Tools* section.
  static const sectionId = 'tools';

  /// `<description>/<section>` of the *External Tools* section.
  static const sectionRef = '$descriptionId/$sectionId';

  /// The detector id of [tool].
  static String detectorOf(ForgeExternalTool tool) => 'forge.tools.${tool.id}';

  /// The help panel id of [tool].
  static String helpPanelOf(ForgeExternalTool tool) =>
      'forge.tools.${tool.id}.help';

  /// The path setting of [tool].
  static ForgeToolPathSetting settingOf(ForgeExternalTool tool) =>
      ForgeToolPathSetting(
        id: tool.id,
        storage: ForgeSettingStorage(
          ForgeKitPreferences.externalToolPathKey(tool.id),
          binding: ForgeExternalToolsSettingBinding.bindingId,
        ),
        label: ForgeText.literal(tool.name),
        detector: detectorOf(tool),
        pathKind: tool.pathIsDirectory
            ? ForgePathKind.folder
            : ForgePathKind.file,
        hint: ForgeText.literal(tool.pathHint),
        helpPanel: helpPanelOf(tool),
      );

  /// The description of [tools], ordered by their `order`.
  static ForgeConfigurationDescription description(
    List<ForgeExternalTool> tools,
  ) {
    final ordered = [...tools]..sort((a, b) => a.order.compareTo(b.order));
    return ForgeConfigurationDescription(
      id: descriptionId,
      title: const ForgeText(
        'forge.config.externalTools.description',
        'External Tools',
      ),
      sections: [
        ForgeSettingsSection(
          id: sectionId,
          title: const ForgeText(
            'forge.config.externalTools.title',
            'External Tools',
          ),
          icon: ForgeIconRef(Icons.build_outlined.codePoint),
          order: 8,
          settings: [for (final tool in ordered) settingOf(tool)],
        ),
      ],
    );
  }

  static final Expando<ForgeToolCopy> _lastCopy = Expando('lastToolCopy');

  /// The copy [tool]'s last check found, or null before the first.
  static ForgeToolCopy? lastCopyOf(ForgeExternalTool tool) => _lastCopy[tool];

  /// Each tool's check and wider search as its setting's detector.
  static ForgeSettingHooks hooks(List<ForgeExternalTool> tools) =>
      ForgeSettingHooks(
        detectors: [
          for (final tool in tools)
            ForgeCallbackDetector(
              id: detectorOf(tool),
              onCheck: (context, value, hints) async {
                final copy = await tool.check(
                  value.trim().isEmpty ? null : value.trim(),
                );
                _lastCopy[tool] = copy;
                return candidateOf(tool, copy);
              },
              onDetect: (context, hints) async => [
                for (final copy in await tool.autoDetect())
                  candidateOf(tool, copy),
              ],
            ),
        ],
      );

  /// [copy] of [tool] as a detection result: its state as a level, with
  /// where to get the tool when it is missing or too old.
  static ForgeDetectedCandidate candidateOf(
    ForgeExternalTool tool,
    ForgeToolCopy copy,
  ) {
    final level = switch (copy.state) {
      ForgeToolState.found => ForgeStatusLevel.ok,
      ForgeToolState.tooOld => ForgeStatusLevel.warning,
      ForgeToolState.missing ||
      ForgeToolState.damaged ||
      ForgeToolState.quarantined => ForgeStatusLevel.error,
    };
    final url = tool.downloadUrl;
    final offerDownload =
        url != null &&
        (copy.state == ForgeToolState.missing ||
            copy.state == ForgeToolState.tooOld);
    return ForgeDetectedCandidate(
      value: copy.path,
      level: level,
      version: copy.version,
      reason: copy.reason ?? copy.state.name,
      message: offerDownload
          ? ForgeText(
              'forge.config.externalTools.download',
              'Download: {url}',
              params: {'url': url},
            )
          : null,
    );
  }

  /// The help panel of the tool [panelId] names, while its copy is not
  /// usable: the tool's own help (`ForgeExternalTool.buildHelp`), null when
  /// it has none (the row shows its download link then).
  static Widget? buildHelpPanel(
    List<ForgeExternalTool> tools,
    BuildContext context,
    String panelId,
    VoidCallback recheck,
  ) {
    for (final tool in tools) {
      if (helpPanelOf(tool) != panelId) continue;
      final copy = lastCopyOf(tool) ?? const ForgeToolCopy.missing();
      return tool.buildHelp(context, copy, checkAgain: () async => recheck());
    }
    return null;
  }
}

/// The [ForgeSettingBinding] of the external tools' paths in the
/// [ForgePreferencesService] (`forge.tools.<id>.path`, removed while empty),
/// through the service's `setExternalToolPath`, so its own value stays
/// current for the modules that read it.
class ForgeExternalToolsSettingBinding extends ForgeSettingBinding {
  ForgeExternalToolsSettingBinding(this.preferences);

  /// The binding's id.
  static const bindingId = 'forge.tools';

  /// The service the paths are read from and written to.
  final ForgePreferencesService preferences;

  static final RegExp _key = RegExp(r'^forge\.tools\.([a-z0-9_]+)\.path$');

  StreamController<String>? _changes;
  int _writing = 0;
  Map<String, String> _reported = const {};

  @override
  String get id => bindingId;

  static String? _toolOf(String key) => _key.firstMatch(key)?.group(1);

  @override
  Future<Object?> read(String key) async {
    final tool = _toolOf(key);
    return tool == null ? null : preferences.externalToolPath(tool);
  }

  @override
  Future<void> write(String key, Object? document) async {
    final tool = _toolOf(key);
    if (tool == null) return;
    _writing++;
    try {
      await preferences.setExternalToolPath(
        tool,
        document is String ? document : null,
      );
    } finally {
      _writing--;
      _reported = _snapshot();
    }
  }

  Map<String, String> _snapshot() => {
    for (final entry in preferences.externalToolPaths.entries)
      ForgeKitPreferences.externalToolPathKey(entry.key): entry.value,
  };

  @override
  Stream<String> watch() {
    final changes = _changes ??= StreamController<String>.broadcast(
      onListen: () {
        _reported = _snapshot();
        preferences.addListener(_onPreferencesChanged);
      },
      onCancel: () => preferences.removeListener(_onPreferencesChanged),
    );
    return changes.stream;
  }

  void _onPreferencesChanged() {
    final changes = _changes;
    if (changes == null || !changes.hasListener || _writing > 0) return;
    final now = _snapshot();
    for (final key in {...now.keys, ..._reported.keys}) {
      if (now[key] != _reported[key]) changes.add(key);
    }
    _reported = now;
  }

  @override
  Future<void> flushed() => preferences.flushed();
}
