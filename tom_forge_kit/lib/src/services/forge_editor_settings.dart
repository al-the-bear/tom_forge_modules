import 'dart:async';
import 'dart:convert';

import 'package:tom_editors_shared/text_types.dart'
    show ForgeTextDefaults, ForgeTextSettings;
import 'package:tom_forge_core/tom_forge_core.dart';

import 'forge_kit_preferences.dart';

/// The [ForgeSettingBinding] of the editors' settings in the kit's
/// preferences: the text settings of every editor type
/// ([textSettingsKey], `forge.editor.textSettings`) and their
/// editor-specific configuration ([specificConfigKey],
/// `forge.editor.specificConfig`), under the keys and in the encodings the
/// preferences always used, so an existing user's settings are read
/// unchanged.
///
/// Each document is a map by editor type id: the text settings as
/// `ForgeKitPreferences.textSettingsToJson` writes them, the configuration as
/// stored. A setting reaches its field with the path (editor type, field) ([ForgeEditorSettings.text], [ForgeEditorSettings.specific]).
/// A write goes through the preferences (`setEditorTextSettings`,
/// `setEditorSpecificConfig`), which store the key and notify; the panel
/// shell follows that notification and hands the values to its open
/// editors. [watch] reports a key when its document changed through someone
/// else.
class ForgeEditorSettingBinding extends ForgeSettingBinding {
  ForgeEditorSettingBinding(this.preferences);

  /// The binding's id, which the editors' settings name in their storage.
  static const bindingId = 'forge.editors';

  /// `forge.editor.textSettings`: editor type id → text settings map.
  static const textSettingsKey = 'forge.editor.textSettings';

  /// `forge.editor.specificConfig`: editor type id → configuration map.
  static const specificConfigKey = 'forge.editor.specificConfig';

  /// The keys this binding keeps.
  static const keys = [textSettingsKey, specificConfigKey];

  /// The preferences the documents are read from and written to.
  final ForgeKitPreferences preferences;

  StreamController<String>? _changes;
  int _writing = 0;

  /// The documents as last reported, JSON-encoded, by key.
  final Map<String, String> _reported = {};

  @override
  String get id => bindingId;

  @override
  Future<Object?> read(String key) async => _documentOf(key);

  Object? _documentOf(String key) => switch (key) {
    textSettingsKey => {
      for (final entry in preferences.editorTextSettings.entries)
        entry.key: ForgeKitPreferences.textSettingsToJson(entry.value),
    },
    specificConfigKey => preferences.editorSpecificConfigs,
    _ => null,
  };

  @override
  Future<void> write(String key, Object? document) {
    _writing++;
    try {
      _write(key, document);
    } finally {
      _writing--;
      if (keys.contains(key)) _reported[key] = _encoded(key);
    }
    return preferences.flushed();
  }

  void _write(String key, Object? document) {
    final p = preferences;
    final map = document is Map ? document : const {};
    switch (key) {
      case textSettingsKey:
        final types = {
          ...p.editorTextSettings.keys,
          ...map.keys.map((k) => '$k'),
        };
        for (final type in types) {
          final value = map[type];
          // A type no longer in the document is back at its defaults.
          final settings = value is Map
              ? ForgeKitPreferences.textSettingsFromJson(
                  Map<String, dynamic>.from(value),
                )
              : const ForgeTextSettings();
          p.setEditorTextSettings(type, settings);
        }
      case specificConfigKey:
        final types = {
          ...p.editorSpecificConfigs.keys,
          ...map.keys.map((k) => '$k'),
        };
        for (final type in types) {
          final value = map[type];
          final config = value is Map
              ? Map<String, dynamic>.from(value)
              : <String, dynamic>{};
          if (jsonEncode(config) ==
              jsonEncode(p.getEditorSpecificConfig(type))) {
            continue;
          }
          p.setEditorSpecificConfig(type, config);
        }
    }
  }

  String _encoded(String key) => jsonEncode(_documentOf(key));

  @override
  Stream<String> watch() {
    final changes = _changes ??= StreamController<String>.broadcast(
      onListen: () {
        for (final key in keys) {
          _reported[key] = _encoded(key);
        }
        preferences.addListener(_onPreferencesChanged);
      },
      onCancel: () => preferences.removeListener(_onPreferencesChanged),
    );
    return changes.stream;
  }

  void _onPreferencesChanged() {
    final changes = _changes;
    if (changes == null || !changes.hasListener || _writing > 0) return;
    for (final key in keys) {
      final now = _encoded(key);
      if (_reported[key] == now) continue;
      _reported[key] = now;
      changes.add(key);
    }
  }

  @override
  Future<void> flushed() => preferences.flushed();
}

/// The settings every text editor type shares, as configuration entries an
/// editor type's description ([ForgeKitEditorType.configuration]) puts into
/// its section, and the storages of its own settings.
///
/// The text settings are stored per editor type through the
/// [ForgeEditorSettingBinding] (`forge.editor.textSettings` → type → field),
/// an editor type's own options in its editor-specific configuration
/// (`forge.editor.specificConfig` → type → key). Labels share their keys
/// (`forge.config.editor.<field>.label`) across editor types.
abstract final class ForgeEditorSettings {
  static const _binding = ForgeEditorSettingBinding.bindingId;

  /// The storage of the text setting [field] of [editorTypeId].
  static ForgeSettingStorage text(String editorTypeId, String field) =>
      ForgeSettingStorage(
        ForgeEditorSettingBinding.textSettingsKey,
        path: [editorTypeId, field],
        binding: _binding,
      );

  /// The storage of [key] in [editorTypeId]'s editor-specific configuration.
  static ForgeSettingStorage specific(String editorTypeId, String key) =>
      ForgeSettingStorage(
        ForgeEditorSettingBinding.specificConfigKey,
        path: [editorTypeId, key],
        binding: _binding,
      );

  static ForgeText _label(String field, String text) =>
      ForgeText('forge.config.editor.$field.label', text);

  /// Code fonts offered first.
  static const codeFonts = [
    'monospace',
    'Menlo',
    'Monaco',
    'SF Mono',
    'Courier New',
    'Consolas',
    'Cascadia Code',
    'JetBrains Mono',
    'Fira Code',
  ];

  /// The *Font*, *Indentation*, *Display* and *Undo* groups of
  /// [editorTypeId]'s text settings, with the defaults of
  /// [ForgeTextSettings].
  static List<ForgeSectionEntry> textGroups(String editorTypeId) {
    ForgeSettingStorage t(String field) => text(editorTypeId, field);
    return [
      ForgeSettingsGroup(
        id: 'font',
        title: const ForgeText('forge.config.editor.font', 'Font'),
        settings: [
          ForgeFontFamilySetting(
            id: 'fontFamily',
            storage: t('fontFamily'),
            label: _label('fontFamily', 'Font Family'),
            defaultValue: ForgeTextDefaults.defaultFontFamily,
            monospace: true,
            suggestions: codeFonts,
            allowEmpty: false,
          ),
          ForgeDoubleSetting(
            id: 'fontSize',
            storage: t('fontSize'),
            label: _label('fontSize', 'Size'),
            defaultValue: ForgeTextDefaults.defaultFontSize,
            min: 1,
            max: 200,
            decimals: 0,
          ),
          ForgeDoubleSetting(
            id: 'lineHeight',
            storage: t('lineHeight'),
            label: _label('lineHeight', 'Height'),
            defaultValue: ForgeTextDefaults.defaultLineHeight,
            min: 0.5,
            max: 5,
            decimals: 1,
          ),
        ],
      ),
      ForgeSettingsGroup(
        id: 'indentation',
        title: const ForgeText(
          'forge.config.editor.indentation',
          'Indentation',
        ),
        settings: [
          ForgeIntSetting(
            id: 'tabSize',
            storage: t('tabSize'),
            label: _label('tabSize', 'Tab'),
            defaultValue: ForgeTextDefaults.defaultTabSize,
            min: 1,
            max: 16,
          ),
          ForgeBoolSetting(
            id: 'insertSpaces',
            storage: t('insertSpaces'),
            label: _label('insertSpaces', 'Spaces'),
            defaultValue: true,
          ),
        ],
      ),
      ForgeSettingsGroup(
        id: 'display',
        title: const ForgeText('forge.config.editor.display', 'Display'),
        settings: [
          ForgeBoolSetting(
            id: 'showLineNumbers',
            storage: t('showLineNumbers'),
            label: _label('showLineNumbers', 'Line numbers'),
            defaultValue: true,
          ),
          ForgeBoolSetting(
            id: 'wordWrap',
            storage: t('wordWrap'),
            label: _label('wordWrap', 'Word wrap'),
            defaultValue: true,
          ),
          ForgeBoolSetting(
            id: 'highlightCurrentLine',
            storage: t('highlightCurrentLine'),
            label: _label('highlightCurrentLine', 'Highlight line'),
            defaultValue: true,
          ),
          ForgeBoolSetting(
            id: 'showWhitespace',
            storage: t('showWhitespace'),
            label: _label('showWhitespace', 'Whitespace'),
          ),
        ],
      ),
      ForgeSettingsGroup(
        id: 'undo',
        title: const ForgeText('forge.config.editor.undo', 'Undo'),
        settings: [
          ForgeIntSetting(
            id: 'maxUndoHistory',
            storage: t('maxUndoHistory'),
            label: _label('maxUndoHistory', 'Max undo'),
            defaultValue: ForgeTextDefaults.defaultMaxUndoHistory,
            min: 1,
          ),
        ],
      ),
    ];
  }

  /// A switch in [editorTypeId]'s editor-specific configuration under
  /// [key]; its label key is `forge.config.<editorTypeId>.<id>.label`.
  static ForgeBoolSetting toggle(
    String editorTypeId,
    String key,
    String label, {
    String? id,
    bool defaultValue = true,
  }) => ForgeBoolSetting(
    id: id ?? key,
    storage: specific(editorTypeId, key),
    label: ForgeText('forge.config.$editorTypeId.${id ?? key}.label', label),
    defaultValue: defaultValue,
  );
}
