import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/text_types.dart'
    show ForgeTextDefaults, ForgeTextSettings;
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeSearchConfig;

import '../actions/forge_shortcut_binding.dart';
import '../files/forge_content_item.dart';
import '../kit/forge_coalesced_state_writer.dart';
import '../kit/forge_editor_picker.dart';
import '../kit/forge_shared_preferences_state_store.dart';
import '../kit/forge_state_store.dart';

/// The preferences every Forge application keeps, whatever its layout: the
/// text settings and editor-specific configuration per editor type, the
/// default editor per file type and per content type, the shortcut and chord overrides and the
/// deleted bindings, the search configuration and the external tools' paths.
///
/// Read and written **only** through [stateStore] (default: a
/// [ForgeSharedPreferencesStateStore], the `forge.*` shared_preferences keys
/// as they always were); with a store given, no shared_preferences call is
/// made. Each key holds what it always held: the maps and lists as JSON
/// text, the external tool paths (`forge.tools.<toolId>.path`) as strings.
///
/// **Restore, then write once per gesture.** [load] reads every key (the
/// start's restore). A setter changes the value in memory and stores its key
/// through a [ForgeCoalescedStateWriter]: the writes of one key within a
/// microtask become one store write of the last value. A value set before
/// [load] has finished is kept in memory only and **dropped** — the restore
/// reads the stored value over it — and nothing is written before it.
/// [save] writes every key (once each, coalesced); [flushed] waits for the
/// writes.
///
/// The panel shell's `ForgePreferencesService` extends this class with its
/// own keys (layout snapshot, panel sizes, dimensions, terminal, startup),
/// through the same store and rule: it reads them in its [load] between
/// [beginRestore] and [finishRestore] and writes them with
/// [writePreference] / [persistPreference].
class ForgeKitPreferences extends ChangeNotifier
    implements ForgeEditorDefaults {
  /// Preferences over [stateStore] (default: shared_preferences).
  ForgeKitPreferences({ForgeStateStore? stateStore})
    : stateStore = stateStore ?? ForgeSharedPreferencesStateStore() {
    _writer = ForgeCoalescedStateWriter(this.stateStore);
  }

  static bool debugEnabled = false;

  static const _keyEditorTextSettings = 'forge.editor.textSettings';
  static const _keyFileTypeDefaults = 'forge.files.typeDefaults';
  static const _keyContentTypeDefaults = 'forge.files.contentTypeDefaults';
  static const _keyShortcutOverrides = 'forge.shortcuts.overrides';
  static const _keyChordOverrides = 'forge.shortcuts.chordOverrides';
  static const _keyDeletedBindings = 'forge.shortcuts.deletedBindings';
  static const _keySearchConfig = 'forge.search.config';
  static const _keyEditorSpecificConfig = 'forge.editor.specificConfig';

  /// The prefix every preference key starts with.
  static const keyPrefix = 'forge.';

  /// The path setting of an external tool: `forge.tools.<toolId>.path`.
  static String externalToolPathKey(String toolId) =>
      'forge.tools.$toolId.path';

  static final RegExp _externalToolPathKey = RegExp(
    r'^forge\.tools\.([a-z0-9_]+)\.path$',
  );

  /// Where the preferences are read from and written to.
  final ForgeStateStore stateStore;

  late final ForgeCoalescedStateWriter _writer;

  /// The stored values during a restore ([beginRestore] .. [finishRestore]).
  Map<String, Object?> _stored = const {};

  final Map<String, ForgeTextSettings> _editorTextSettings =
      <String, ForgeTextSettings>{};
  final Map<String, String> _fileTypeDefaultEditors = <String, String>{};
  final Map<String, String> _contentTypeDefaultEditors = <String, String>{};
  final Map<String, ForgeShortcutKey> _shortcutOverrides =
      <String, ForgeShortcutKey>{};
  final Map<String, ForgeChordKey> _chordOverrides = <String, ForgeChordKey>{};
  final Set<String> _deletedBindings = <String>{};
  ForgeSearchConfig _searchConfig = const ForgeSearchConfig();
  final Map<String, Map<String, dynamic>> _editorSpecificConfig =
      <String, Map<String, dynamic>>{};

  /// External tools' paths: tool id → path (absent: search).
  final Map<String, String> _externalToolPaths = <String, String>{};

  static void _log(String message) {
    if (debugEnabled) {
      debugPrint('[ForgeKitPreferences] $message');
    }
  }

  /// Whether the start's restore has finished: from then on, changes are
  /// written.
  bool get isRestored => _writer.isOpen;

  /// Reads the preferences from [stateStore] (the start's restore) and
  /// notifies. Values set before are replaced by the stored ones.
  Future<void> load() async {
    await beginRestore();
    try {
      loadKitPreferences();
    } finally {
      finishRestore();
    }
    notifyListeners();
  }

  /// Writes every preference (each key once); restores first when [load]
  /// has not run, as the shell's service always did.
  Future<void> save() async {
    if (!isRestored) await load();
    await saveKitPreferences();
  }

  /// Completes when every write started before is stored.
  Future<void> flushed() => _writer.flushed();

  // ── Restore and write, for the subclasses ──

  /// Starts a restore: waits for the writes in flight (after the first
  /// restore) and reads every `forge.*` key of [stateStore], for
  /// [loadKitPreferences] and the stored* readers until [finishRestore].
  @protected
  Future<void> beginRestore() async {
    if (_writer.isOpen) await _writer.flushed();
    final stored = <String, Object?>{};
    for (final key in await stateStore.keys(prefix: keyPrefix)) {
      stored[key] = await stateStore.read(key);
    }
    _stored = stored;
  }

  /// Ends a restore: changes are written from now on.
  @protected
  void finishRestore() {
    _stored = const {};
    _writer.open();
  }

  /// The stored value of [key] during a restore.
  @protected
  Object? storedValue(String key) => _stored[key];

  /// The stored String of [key] during a restore, or null.
  @protected
  String? storedString(String key) {
    final value = _stored[key];
    return value is String ? value : null;
  }

  /// The stored bool of [key] during a restore, or null.
  @protected
  bool? storedBool(String key) {
    final value = _stored[key];
    return value is bool ? value : null;
  }

  /// The stored int of [key] during a restore, or null.
  @protected
  int? storedInt(String key) {
    final value = _stored[key];
    return value is num ? value.toInt() : null;
  }

  /// The stored double of [key] during a restore, or null.
  @protected
  double? storedDouble(String key) {
    final value = _stored[key];
    return value is num ? value.toDouble() : null;
  }

  /// The stored JSON text of [key] during a restore, or null: a String as
  /// it is, a map or list (a store that keeps documents) encoded.
  @protected
  String? storedJson(String key) {
    final value = _stored[key];
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return null;
  }

  /// Writes [value] under [key] (null removes it), coalesced; completes
  /// when stored. Before the restore has finished, writes nothing.
  @protected
  Future<void> writePreference(String key, Object? value) =>
      _writer.write(key, value);

  /// [writePreference] without waiting: a failure is reported, not thrown.
  @protected
  void persistPreference(String key, Object? value) {
    unawaited(
      _writer.write(key, value).catchError((Object error) {
        debugPrint('[ForgeKitPreferences] write $key failed: $error');
      }),
    );
  }

  /// Reads the kit's preferences from the values [beginRestore] read. Does
  /// not notify: the caller does once it has read its own.
  @protected
  void loadKitPreferences() {
    _externalToolPaths.clear();
    for (final key in _stored.keys) {
      final match = _externalToolPathKey.firstMatch(key);
      final value = match == null ? null : storedString(key);
      if (value != null && value.isNotEmpty) {
        _externalToolPaths[match!.group(1)!] = value;
      }
    }
    _editorTextSettings
      ..clear()
      ..addAll(_loadEditorTextSettings());
    _fileTypeDefaultEditors
      ..clear()
      ..addAll(_loadFileTypeDefaults());
    _contentTypeDefaultEditors
      ..clear()
      ..addAll(_loadContentTypeDefaults());
    _shortcutOverrides
      ..clear()
      ..addAll(_loadShortcutOverrides());
    _chordOverrides
      ..clear()
      ..addAll(_loadChordOverrides());
    _deletedBindings
      ..clear()
      ..addAll(_loadDeletedBindings());
    _searchConfig = _loadSearchConfig();
    _editorSpecificConfig
      ..clear()
      ..addAll(_loadEditorSpecificConfig());
  }

  /// Writes the kit's preferences, each key once.
  @protected
  Future<void> saveKitPreferences() async {
    await Future.wait([
      _saveEditorTextSettings(),
      _saveFileTypeDefaults(),
      _saveContentTypeDefaults(),
      _saveShortcutOverrides(),
      _saveChordOverrides(),
      _saveDeletedBindings(),
      _saveSearchConfig(),
      _saveEditorSpecificConfig(),
    ]);
  }

  /// The path the user set for the external tool [toolId]
  /// (`forge.tools.<toolId>.path`), or `null` when unset: the tool's
  /// detection searches then.
  String? externalToolPath(String toolId) => _externalToolPaths[toolId];

  /// Sets (or with `null` / empty, clears) the path of the external tool
  /// [toolId] and stores it; completes when stored (at once before the
  /// restore, which drops it).
  Future<void> setExternalToolPath(String toolId, String? path) async {
    final value = path?.trim() ?? '';
    final old = _externalToolPaths[toolId];
    if (value.isEmpty) {
      _externalToolPaths.remove(toolId);
    } else {
      _externalToolPaths[toolId] = value;
    }
    if (old != _externalToolPaths[toolId]) notifyListeners();
    await writePreference(
      externalToolPathKey(toolId),
      value.isEmpty ? null : value,
    );
    _log('external tool $toolId path ${value.isEmpty ? 'cleared' : 'set'}');
  }

  /// Snapshot of all persisted editor settings keyed by editor type id.
  Map<String, ForgeTextSettings> get editorTextSettings =>
      Map<String, ForgeTextSettings>.unmodifiable(_editorTextSettings);

  /// Reads text settings for the given editor type.
  ForgeTextSettings getEditorTextSettings(String editorTypeId) {
    return _editorTextSettings[editorTypeId] ?? const ForgeTextSettings();
  }

  /// Stores text settings for an editor type.
  void setEditorTextSettings(String editorTypeId, ForgeTextSettings settings) {
    final previous = _editorTextSettings[editorTypeId];
    if (previous == settings) {
      return;
    }
    _editorTextSettings[editorTypeId] = settings;
    _log('updated editor settings for $editorTypeId');
    _persist(_saveEditorTextSettings);
    notifyListeners();
  }

  /// Reads editor-specific configuration map for the given editor type.
  Map<String, dynamic> getEditorSpecificConfig(String editorTypeId) {
    return Map<String, dynamic>.from(
      _editorSpecificConfig[editorTypeId] ?? <String, dynamic>{},
    );
  }

  /// Stores editor-specific configuration map for an editor type.
  void setEditorSpecificConfig(
    String editorTypeId,
    Map<String, dynamic> config,
  ) {
    _editorSpecificConfig[editorTypeId] = Map<String, dynamic>.from(config);
    _log('updated editor specific config for $editorTypeId');
    _persist(_saveEditorSpecificConfig);
    notifyListeners();
  }

  /// Preferred default editor ids keyed by file extension (for example: .md),
  /// stored under `forge.files.typeDefaults`.
  @override
  Map<String, String> get fileTypeDefaultEditors =>
      Map<String, String>.unmodifiable(_fileTypeDefaultEditors);

  /// Sets preferred editor id for a file extension.
  @override
  void setFileTypeDefaultEditor(String extension, String editorTypeId) {
    final normalized = _normalizeExtension(extension);
    if (normalized.isEmpty) {
      return;
    }
    if (_fileTypeDefaultEditors[normalized] == editorTypeId) {
      return;
    }
    _fileTypeDefaultEditors[normalized] = editorTypeId;
    _persist(_saveFileTypeDefaults);
    notifyListeners();
  }

  /// Clears preferred editor id for a file extension.
  @override
  void clearFileTypeDefaultEditor(String extension) {
    final normalized = _normalizeExtension(extension);
    if (normalized.isEmpty) {
      return;
    }
    if (_fileTypeDefaultEditors.remove(normalized) != null) {
      _persist(_saveFileTypeDefaults);
      notifyListeners();
    }
  }

  /// Preferred default editor ids keyed by content type (for example:
  /// `text/markdown`), stored under `forge.files.contentTypeDefaults`.
  @override
  Map<String, String> get contentTypeDefaultEditors =>
      Map<String, String>.unmodifiable(_contentTypeDefaultEditors);

  /// Sets the preferred editor id for a content type (lower case, without
  /// parameters).
  @override
  void setContentTypeDefaultEditor(String contentType, String editorTypeId) {
    final normalized = forgeNormalizeContentType(contentType);
    if (normalized == null) return;
    if (_contentTypeDefaultEditors[normalized] == editorTypeId) return;
    _contentTypeDefaultEditors[normalized] = editorTypeId;
    _persist(_saveContentTypeDefaults);
    notifyListeners();
  }

  /// Clears the preferred editor id for a content type.
  @override
  void clearContentTypeDefaultEditor(String contentType) {
    final normalized = forgeNormalizeContentType(contentType);
    if (normalized == null) return;
    if (_contentTypeDefaultEditors.remove(normalized) != null) {
      _persist(_saveContentTypeDefaults);
      notifyListeners();
    }
  }

  /// Shortcut overrides keyed by action id.
  Map<String, ForgeShortcutKey> get shortcutOverrides =>
      Map<String, ForgeShortcutKey>.unmodifiable(_shortcutOverrides);

  /// Sets a shortcut override for a specific action id.
  void setShortcutOverride(String actionId, ForgeShortcutKey key) {
    if (_shortcutOverrides[actionId] == key) {
      return;
    }
    _shortcutOverrides[actionId] = key;
    _persist(_saveShortcutOverrides);
    notifyListeners();
  }

  /// Removes a shortcut override for an action id.
  void removeShortcutOverride(String actionId) {
    if (_shortcutOverrides.remove(actionId) != null) {
      _persist(_saveShortcutOverrides);
      notifyListeners();
    }
  }

  /// Clears all shortcut overrides.
  void clearShortcutOverrides() {
    if (_shortcutOverrides.isEmpty) {
      return;
    }
    _shortcutOverrides.clear();
    _persist(_saveShortcutOverrides);
    notifyListeners();
  }

  /// Chord overrides keyed by action id.
  Map<String, ForgeChordKey> get chordOverrides =>
      Map<String, ForgeChordKey>.unmodifiable(_chordOverrides);

  /// Sets a chord override for a specific action id.
  void setChordOverride(String actionId, ForgeChordKey chord) {
    _chordOverrides[actionId] = chord;
    _persist(_saveChordOverrides);
    notifyListeners();
  }

  /// Removes a chord override for an action id.
  void removeChordOverride(String actionId) {
    if (_chordOverrides.remove(actionId) != null) {
      _persist(_saveChordOverrides);
      notifyListeners();
    }
  }

  /// Clears all chord overrides.
  void clearChordOverrides() {
    if (_chordOverrides.isEmpty) return;
    _chordOverrides.clear();
    _persist(_saveChordOverrides);
    notifyListeners();
  }

  /// Action IDs that were explicitly deleted by the user.
  Set<String> get deletedBindings => Set.unmodifiable(_deletedBindings);

  /// Marks a binding as deleted so it is not re-registered on restart.
  void addDeletedBinding(String actionId) {
    if (_deletedBindings.add(actionId)) {
      _persist(_saveDeletedBindings);
      notifyListeners();
    }
  }

  /// Removes a binding from the deleted set (un-deletes it).
  void removeDeletedBinding(String actionId) {
    if (_deletedBindings.remove(actionId)) {
      _persist(_saveDeletedBindings);
      notifyListeners();
    }
  }

  /// Stores one key's value (see the class: coalesced, not before the
  /// restore) without waiting.
  void _persist(Future<void> Function() save) {
    unawaited(
      save().catchError((Object error) {
        debugPrint('[ForgeKitPreferences] write failed: $error');
      }),
    );
  }

  // ── Search configuration ──

  /// The current search configuration.
  ForgeSearchConfig get searchConfig => _searchConfig;

  /// Updates the search configuration and persists it.
  set searchConfig(ForgeSearchConfig value) {
    _searchConfig = value;
    _persist(_saveSearchConfig);
    notifyListeners();
  }

  ForgeSearchConfig _loadSearchConfig() {
    final jsonStr = storedJson(_keySearchConfig);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return const ForgeSearchConfig();
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return ForgeSearchConfig.fromJson(decoded);
      }
      if (decoded is Map) {
        return ForgeSearchConfig.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const ForgeSearchConfig();
  }

  Future<void> _saveSearchConfig() async {
    await writePreference(_keySearchConfig, jsonEncode(_searchConfig.toJson()));
  }

  Map<String, Map<String, dynamic>> _loadEditorSpecificConfig() {
    final jsonStr = storedJson(_keyEditorSpecificConfig);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, Map<String, dynamic>>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(
            k.toString(),
            v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
          ),
        );
      }
    } catch (_) {}
    return <String, Map<String, dynamic>>{};
  }

  Future<void> _saveEditorSpecificConfig() async {
    await writePreference(
      _keyEditorSpecificConfig,
      jsonEncode(_editorSpecificConfig),
    );
  }

  Map<String, ForgeTextSettings> _loadEditorTextSettings() {
    final jsonStr = storedJson(_keyEditorTextSettings);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, ForgeTextSettings>{};
    }

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return <String, ForgeTextSettings>{};
      }

      final result = <String, ForgeTextSettings>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is Map<String, dynamic>) {
          result[key] = _textSettingsFromMap(value);
        } else if (key is String && value is Map) {
          result[key] = _textSettingsFromMap(Map<String, dynamic>.from(value));
        }
      }
      return result;
    } catch (error, stackTrace) {
      debugPrint(
        '[ForgePreferencesService] parse editor settings failed: $error',
      );
      debugPrint('$stackTrace');
      return <String, ForgeTextSettings>{};
    }
  }

  Future<void> _saveEditorTextSettings() async {
    final serializable = <String, Map<String, dynamic>>{};
    for (final entry in _editorTextSettings.entries) {
      serializable[entry.key] = _textSettingsToMap(entry.value);
    }
    await writePreference(_keyEditorTextSettings, jsonEncode(serializable));
  }

  Map<String, String> _loadFileTypeDefaults() {
    final jsonStr = storedJson(_keyFileTypeDefaults);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return <String, String>{};
      }
      final result = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String) {
          result[_normalizeExtension(key)] = value;
        }
      }
      return result;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveFileTypeDefaults() async {
    await writePreference(
      _keyFileTypeDefaults,
      jsonEncode(_fileTypeDefaultEditors),
    );
  }

  Map<String, String> _loadContentTypeDefaults() {
    final jsonStr = storedJson(_keyContentTypeDefaults);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return <String, String>{};
      }
      final result = <String, String>{};
      for (final MapEntry(:key, :value) in decoded.entries) {
        final type = key is String ? forgeNormalizeContentType(key) : null;
        if (type != null && value is String) result[type] = value;
      }
      return result;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _saveContentTypeDefaults() async {
    await writePreference(
      _keyContentTypeDefaults,
      jsonEncode(_contentTypeDefaultEditors),
    );
  }

  Map<String, ForgeShortcutKey> _loadShortcutOverrides() {
    final jsonStr = storedJson(_keyShortcutOverrides);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, ForgeShortcutKey>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) {
        return <String, ForgeShortcutKey>{};
      }
      final result = <String, ForgeShortcutKey>{};
      for (final entry in decoded.entries) {
        final actionId = entry.key;
        final value = entry.value;
        if (actionId is String && value is Map) {
          final parsed = _shortcutKeyFromMap(Map<String, dynamic>.from(value));
          if (parsed != null) {
            result[actionId] = parsed;
          }
        }
      }
      return result;
    } catch (_) {
      return <String, ForgeShortcutKey>{};
    }
  }

  Future<void> _saveShortcutOverrides() async {
    final serializable = <String, Map<String, dynamic>>{};
    for (final entry in _shortcutOverrides.entries) {
      serializable[entry.key] = _shortcutKeyToMap(entry.value);
    }
    await writePreference(_keyShortcutOverrides, jsonEncode(serializable));
  }

  Map<String, ForgeChordKey> _loadChordOverrides() {
    final jsonStr = storedJson(_keyChordOverrides);
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      return <String, ForgeChordKey>{};
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return <String, ForgeChordKey>{};
      final result = <String, ForgeChordKey>{};
      for (final entry in decoded.entries) {
        final actionId = entry.key;
        final value = entry.value;
        if (actionId is String && value is Map<String, dynamic>) {
          final first = value['firstKey'];
          final second = value['secondKey'];
          if (first is Map && second is Map) {
            final firstKey = _shortcutKeyFromMap(
              Map<String, dynamic>.from(first),
            );
            final secondKey = _shortcutKeyFromMap(
              Map<String, dynamic>.from(second),
            );
            if (firstKey != null && secondKey != null) {
              result[actionId] = ForgeChordKey(
                firstKey: firstKey,
                secondKey: secondKey,
              );
            }
          }
        }
      }
      return result;
    } catch (_) {
      return <String, ForgeChordKey>{};
    }
  }

  Future<void> _saveChordOverrides() async {
    final serializable = <String, Map<String, dynamic>>{};
    for (final entry in _chordOverrides.entries) {
      serializable[entry.key] = {
        'firstKey': _shortcutKeyToMap(entry.value.firstKey),
        'secondKey': _shortcutKeyToMap(entry.value.secondKey),
      };
    }
    await writePreference(_keyChordOverrides, jsonEncode(serializable));
  }

  Set<String> _loadDeletedBindings() {
    final jsonStr = storedJson(_keyDeletedBindings);
    if (jsonStr == null || jsonStr.trim().isEmpty) return <String>{};
    try {
      final list = jsonDecode(jsonStr);
      if (list is List) {
        return list.cast<String>().toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  Future<void> _saveDeletedBindings() async {
    await writePreference(
      _keyDeletedBindings,
      jsonEncode(_deletedBindings.toList()),
    );
  }

  Map<String, dynamic> _shortcutKeyToMap(ForgeShortcutKey key) {
    return <String, dynamic>{
      'keyId': key.key.keyId,
      'primaryModifier': key.primaryModifier,
      'control': key.control,
      'shift': key.shift,
      'alt': key.alt,
    };
  }

  ForgeShortcutKey? _shortcutKeyFromMap(Map<String, dynamic> map) {
    final keyId = map['keyId'];
    if (keyId is! num) {
      return null;
    }
    final logicalKey = LogicalKeyboardKey.findKeyByKeyId(keyId.toInt());
    if (logicalKey == null) {
      return null;
    }
    return ForgeShortcutKey(
      key: logicalKey,
      primaryModifier: map['primaryModifier'] as bool? ?? false,
      control: map['control'] as bool? ?? false,
      shift: map['shift'] as bool? ?? false,
      alt: map['alt'] as bool? ?? false,
    );
  }

  String _normalizeExtension(String extension) {
    final trimmed = extension.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed.startsWith('.') ? trimmed : '.$trimmed';
  }

  ForgeTextSettings _textSettingsFromMap(Map<String, dynamic> json) {
    return ForgeTextSettings(
      fontFamily:
          (json['fontFamily'] as String?) ??
          ForgeTextDefaults.defaultFontFamily,
      uiFontFamily: json['uiFontFamily'] as String?,
      fontSize:
          (json['fontSize'] as num?)?.toDouble() ??
          ForgeTextDefaults.defaultFontSize,
      lineHeight:
          (json['lineHeight'] as num?)?.toDouble() ??
          ForgeTextDefaults.defaultLineHeight,
      tabSize:
          (json['tabSize'] as num?)?.toInt() ??
          ForgeTextDefaults.defaultTabSize,
      insertSpaces: json['insertSpaces'] as bool? ?? true,
      showWhitespace: json['showWhitespace'] as bool? ?? false,
      wordWrap: json['wordWrap'] as bool? ?? true,
      showLineNumbers: json['showLineNumbers'] as bool? ?? true,
      highlightCurrentLine: json['highlightCurrentLine'] as bool? ?? true,
      maxUndoHistory:
          (json['maxUndoHistory'] as num?)?.toInt() ??
          ForgeTextDefaults.defaultMaxUndoHistory,
    );
  }

  Map<String, dynamic> _textSettingsToMap(ForgeTextSettings settings) {
    return <String, dynamic>{
      'fontFamily': settings.fontFamily,
      'uiFontFamily': settings.uiFontFamily,
      'fontSize': settings.fontSize,
      'lineHeight': settings.lineHeight,
      'tabSize': settings.tabSize,
      'insertSpaces': settings.insertSpaces,
      'showWhitespace': settings.showWhitespace,
      'wordWrap': settings.wordWrap,
      'showLineNumbers': settings.showLineNumbers,
      'highlightCurrentLine': settings.highlightCurrentLine,
      'maxUndoHistory': settings.maxUndoHistory,
    };
  }
}
