import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../services/forge_preferences_service.dart';

/// The shell's key bindings as a configuration description: the
/// *Shortcuts* section (single keys) and the *Chord Shortcuts* section
/// (chords), each one key binding table over the shell's actions.
///
/// The tables keep what the shell always kept, through
/// [ForgeShortcutsSettingBinding]: the overrides (`forge.shortcuts.overrides`),
/// the chord overrides (`forge.shortcuts.chordOverrides`) and the actions the
/// user deleted (`forge.shortcuts.deletedBindings`), in their encodings. The
/// actions come from the [actionsCatalogue] hook ([hooks]): every registered
/// action with the binding its module gave it.
abstract final class ForgeShortcutConfiguration {
  /// The description's id.
  static const descriptionId = 'forge.shortcuts';

  /// The id of the *Shortcuts* section.
  static const shortcutsSectionId = 'shortcuts';

  /// The id of the *Chord Shortcuts* section.
  static const chordsSectionId = 'chords';

  /// `<description>/<section>` of the *Shortcuts* section.
  static const shortcutsSectionRef = '$descriptionId/$shortcutsSectionId';

  /// `<description>/<section>` of the *Chord Shortcuts* section.
  static const chordsSectionRef = '$descriptionId/$chordsSectionId';

  /// The id of the action catalogue both tables list.
  static const actionsCatalogue = 'forge.shell.actions';

  /// The editors whose actions may be bound for every editor (`*.<suffix>`).
  static const wildcardPrefixes = ['dart', 'yaml', 'md'];

  static const _binding = ForgeShortcutsSettingBinding.bindingId;

  /// The actions the user deleted; both tables keep it.
  static final deletedBindings = ForgeStringListSetting(
    id: 'deletedBindings',
    storage: const ForgeSettingStorage(
      ForgeShortcutsSettingBinding.deletedBindingsKey,
      binding: _binding,
    ),
    label: const ForgeText(
      'forge.config.shortcuts.deletedBindings.label',
      'Deleted bindings',
    ),
  );

  /// The single-key bindings.
  static final shortcuts = ForgeKeyBindingTableSetting(
    id: 'shortcuts',
    storage: const ForgeSettingStorage(
      ForgeShortcutsSettingBinding.overridesKey,
      binding: _binding,
    ),
    label: const ForgeText(
      'forge.config.shortcuts.shortcuts.label',
      'Shortcuts',
    ),
    catalogue: actionsCatalogue,
    deletedBindings: deletedBindings,
    wildcardPrefixes: wildcardPrefixes,
  );

  /// The chord bindings.
  static final chords = ForgeKeyBindingTableSetting(
    id: 'chords',
    storage: const ForgeSettingStorage(
      ForgeShortcutsSettingBinding.chordOverridesKey,
      binding: _binding,
    ),
    label: const ForgeText(
      'forge.config.shortcuts.chords.label',
      'Chord shortcuts',
    ),
    catalogue: actionsCatalogue,
    chords: true,
    deletedBindings: deletedBindings,
    allowReset: false,
  );

  /// The *Shortcuts* section.
  static final shortcutsSection = ForgeSettingsSection(
    id: shortcutsSectionId,
    title: const ForgeText('forge.config.shortcuts.title', 'Shortcuts'),
    icon: ForgeIconRef(Icons.keyboard.codePoint),
    order: 5,
    settings: [shortcuts],
  );

  /// The *Chord Shortcuts* section.
  static final chordsSection = ForgeSettingsSection(
    id: chordsSectionId,
    title: const ForgeText('forge.config.chords.title', 'Chord Shortcuts'),
    icon: ForgeIconRef(Icons.piano.codePoint),
    order: 6,
    settings: [chords],
  );

  /// The description: [shortcutsSection] and [chordsSection].
  static final description = ForgeConfigurationDescription(
    id: descriptionId,
    title: const ForgeText('forge.config.shortcuts.description', 'Shortcuts'),
    sections: [shortcutsSection, chordsSection],
  );

  /// The hooks the description names: the catalogue of [shell]'s actions
  /// ([actionsCatalogue]), with the bindings their modules gave them,
  /// announced again whenever the shortcuts change.
  static ForgeSettingHooks hooks(ForgeKitApi shell) => ForgeSettingHooks(
    catalogues: [
      ForgeCallbackActionCatalogue(
        id: actionsCatalogue,
        onActions: (_) async => catalogueActions(shell),
        changes: _changesOf(shell.shortcuts.onBindingsChanged),
      ),
    ],
  );

  /// [shell]'s actions as catalogue entries: each with its scope (the
  /// binding's context) and its default binding (the module's key or
  /// chord, else the action's own default shortcut).
  static List<ForgeCatalogueAction> catalogueActions(ForgeKitApi shell) {
    final shortcuts = shell.shortcuts;
    final manager = shortcuts is DefaultShortcutManager ? shortcuts : null;
    final contexts = {
      for (final binding in shortcuts.allBindings)
        binding.action.id: binding.context,
    };
    final out = <ForgeCatalogueAction>[];
    final seen = <String>{};
    for (final action in shell.actionRegistry.allActions) {
      if (action.id.startsWith('*.') || !seen.add(action.id)) continue;
      final chord = manager?.defaultChordOf(action.id);
      final key = manager?.defaultKeyOf(action.id) ?? action.defaultShortcut;
      out.add(
        ForgeCatalogueAction(
          id: action.id,
          label: action.label,
          scope: contexts[action.id],
          group: contexts[action.id],
          defaultBinding: chord != null
              ? chordOf(chord)
              : key == null
              ? null
              : ForgeKeyChord([strokeOf(key)]),
        ),
      );
    }
    return out;
  }

  /// A shortcut key as a key stroke (the same stored form).
  static ForgeKeyStroke strokeOf(ForgeShortcutKey key) => ForgeKeyStroke(
    key.key.keyId,
    primaryModifier: key.primaryModifier,
    control: key.control,
    shift: key.shift,
    alt: key.alt,
  );

  /// A chord key as a key chord.
  static ForgeKeyChord chordOf(ForgeChordKey chord) =>
      ForgeKeyChord([strokeOf(chord.firstKey), strokeOf(chord.secondKey)]);

  /// A key stroke as a shortcut key; null for no key.
  static ForgeShortcutKey? shortcutKeyOf(ForgeKeyStroke stroke) {
    if (stroke.keyId == 0) return null;
    return ForgeShortcutKey(
      key: LogicalKeyboardKey(stroke.keyId),
      primaryModifier: stroke.primaryModifier,
      control: stroke.control,
      shift: stroke.shift,
      alt: stroke.alt,
    );
  }

  static Stream<void> _changesOf(Listenable listenable) {
    late final StreamController<void> controller;
    void notify() => controller.add(null);
    controller = StreamController<void>.broadcast(
      onListen: () => listenable.addListener(notify),
      onCancel: () => listenable.removeListener(notify),
    );
    return controller.stream;
  }
}

/// The [ForgeSettingBinding] of the shell's key bindings: the overrides,
/// chord overrides and deleted actions in the [ForgePreferencesService],
/// under the keys and in the encodings the service always used.
///
/// A write goes through the service's setters, which store the key and
/// notify; the panel shell follows the notification and binds the overrides
/// (`_applyPreferenceShortcutOverrides`). What that does not undo, the
/// binding does on the shell's [shortcuts] itself: an override removed puts
/// the action's default key back, an action deleted loses its binding, an
/// action no longer deleted gets its default back. [watch] reports a key
/// when its document changed through someone else.
class ForgeShortcutsSettingBinding extends ForgeSettingBinding {
  ForgeShortcutsSettingBinding(this.preferences, {this.shell});

  /// The binding's id, which the key binding tables name in their storage.
  static const bindingId = 'forge.shortcuts';

  /// `forge.shortcuts.overrides`: action id → key map.
  static const overridesKey = 'forge.shortcuts.overrides';

  /// `forge.shortcuts.chordOverrides`: action id → chord map.
  static const chordOverridesKey = 'forge.shortcuts.chordOverrides';

  /// `forge.shortcuts.deletedBindings`: the deleted actions' ids.
  static const deletedBindingsKey = 'forge.shortcuts.deletedBindings';

  /// The keys this binding keeps.
  static const keys = [overridesKey, chordOverridesKey, deletedBindingsKey];

  /// The service the documents are read from and written to.
  final ForgePreferencesService preferences;

  /// The shell whose live bindings follow; null: only the preferences.
  final ForgeKitApi? shell;

  StreamController<String>? _changes;
  int _writing = 0;
  final Map<String, String> _reported = {};

  @override
  String get id => bindingId;

  @override
  Future<Object?> read(String key) async => _documentOf(key);

  Object? _documentOf(String key) {
    final p = preferences;
    return switch (key) {
      overridesKey => {
        for (final entry in p.shortcutOverrides.entries)
          entry.key: ForgeShortcutConfiguration.strokeOf(entry.value).toJson(),
      },
      chordOverridesKey => {
        for (final entry in p.chordOverrides.entries)
          entry.key: ForgeShortcutConfiguration.chordOf(
            entry.value,
          ).toChordJson(),
      },
      deletedBindingsKey => p.deletedBindings.toList()..sort(),
      _ => null,
    };
  }

  @override
  Future<void> write(String key, Object? document) {
    _writing++;
    try {
      switch (key) {
        case overridesKey:
          _writeOverrides(document);
        case chordOverridesKey:
          _writeChordOverrides(document);
        case deletedBindingsKey:
          _writeDeleted(document);
      }
    } finally {
      _writing--;
      if (keys.contains(key)) _reported[key] = _encoded(key);
    }
    return preferences.flushed();
  }

  void _writeOverrides(Object? document) {
    final p = preferences;
    final wanted = <String, ForgeShortcutKey>{};
    if (document is Map) {
      for (final entry in document.entries) {
        final stroke = ForgeKeyStroke.fromJson(entry.value);
        final key = stroke == null
            ? null
            : ForgeShortcutConfiguration.shortcutKeyOf(stroke);
        if (key != null) wanted['${entry.key}'] = key;
      }
    }
    for (final id in p.shortcutOverrides.keys.toList()) {
      if (wanted.containsKey(id)) continue;
      p.removeShortcutOverride(id);
      _restoreDefault(id);
    }
    for (final entry in wanted.entries) {
      p.setShortcutOverride(entry.key, entry.value);
    }
  }

  void _writeChordOverrides(Object? document) {
    final p = preferences;
    final wanted = <String, ForgeChordKey>{};
    if (document is Map) {
      for (final entry in document.entries) {
        final chord = ForgeKeyChord.fromChordJson(entry.value);
        if (chord == null || chord.strokes.length < 2) continue;
        final first = ForgeShortcutConfiguration.shortcutKeyOf(
          chord.strokes[0],
        );
        final second = ForgeShortcutConfiguration.shortcutKeyOf(
          chord.strokes[1],
        );
        if (first == null || second == null) continue;
        wanted['${entry.key}'] = ForgeChordKey(
          firstKey: first,
          secondKey: second,
        );
      }
    }
    for (final id in p.chordOverrides.keys.toList()) {
      if (wanted.containsKey(id)) continue;
      p.removeChordOverride(id);
      _restoreDefault(id);
    }
    for (final entry in wanted.entries) {
      if (p.chordOverrides[entry.key] == entry.value) continue;
      p.setChordOverride(entry.key, entry.value);
    }
  }

  void _writeDeleted(Object? document) {
    final p = preferences;
    final wanted = {
      if (document is List)
        for (final id in document) '$id',
    };
    for (final id in p.deletedBindings.toList()) {
      if (wanted.contains(id)) continue;
      p.removeDeletedBinding(id);
      final shortcuts = shell?.shortcuts;
      if (shortcuts is DefaultShortcutManager) {
        shortcuts.unsuppressAction(id);
      }
      _restoreDefault(id);
    }
    for (final id in wanted) {
      if (p.deletedBindings.contains(id)) continue;
      shell?.shortcuts.removeBinding(id);
      p.addDeletedBinding(id);
    }
  }

  /// Puts [actionId]'s default binding back on the live shortcuts.
  void _restoreDefault(String actionId) {
    final api = shell;
    if (api == null) return;
    final shortcuts = api.shortcuts;
    final action = api.actionRegistry.getAction(actionId);
    if (action == null) return;
    final manager = shortcuts is DefaultShortcutManager ? shortcuts : null;
    final chord = manager?.defaultChordOf(actionId);
    if (chord != null) {
      shortcuts.rebindChord(action, chord);
      return;
    }
    final key = manager?.defaultKeyOf(actionId) ?? action.defaultShortcut;
    if (key != null) {
      shortcuts.rebind(action, key);
    } else {
      shortcuts.unbind(actionId);
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
