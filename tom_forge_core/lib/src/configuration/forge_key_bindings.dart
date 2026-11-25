import 'dart:convert';

import 'forge_configuration_texts.dart';
import 'forge_setting.dart';
import 'forge_setting_hooks.dart' show ForgeCatalogueAction;
import 'forge_setting_kinds.dart';
import 'forge_text.dart';

/// One key combination as data: a key ([keyId], Flutter's
/// `LogicalKeyboardKey.keyId`) with its modifiers.
///
/// Stored as Forge has always stored a shortcut (`forge.shortcuts.overrides`):
/// a map of `keyId` (an int) and the flags `primaryModifier`, `control`,
/// `shift` and `alt` ([toJson], [fromJson]). [primaryModifier] is Command on
/// macOS and Control elsewhere; [control] is the Control key itself.
/// [ForgeKeyStroke.none] (key id 0) is no key: an unbound shortcut.
class ForgeKeyStroke {
  const ForgeKeyStroke(
    this.keyId, {
    this.primaryModifier = false,
    this.control = false,
    this.shift = false,
    this.alt = false,
  });

  /// No key: unbound.
  static const none = ForgeKeyStroke(0);

  /// The key, as Flutter's `LogicalKeyboardKey.keyId`; 0: none.
  final int keyId;

  /// Command on macOS, Control elsewhere.
  final bool primaryModifier;

  /// The Control key itself (⌃ on macOS).
  final bool control;

  final bool shift;
  final bool alt;

  /// Whether this is no key.
  bool get isNone => keyId == 0;

  /// Whether a modifier is held.
  bool get hasModifier => primaryModifier || control || shift || alt;

  /// The stored form.
  Map<String, Object?> toJson() => {
    'keyId': keyId,
    'primaryModifier': primaryModifier,
    'control': control,
    'shift': shift,
    'alt': alt,
  };

  /// [json] (a map with `keyId`) as a stroke, or null when it is none.
  static ForgeKeyStroke? fromJson(Object? json) {
    if (json is! Map) return null;
    final keyId = json['keyId'];
    if (keyId is! num || keyId != keyId.roundToDouble()) return null;
    bool flag(String name) => json[name] == true;
    return ForgeKeyStroke(
      keyId.toInt(),
      primaryModifier: flag('primaryModifier'),
      control: flag('control'),
      shift: flag('shift'),
      alt: flag('alt'),
    );
  }

  /// Whether this and [other] are the keys a user presses alike on a
  /// platform whose primary modifier is Command ([primaryIsMeta]) or
  /// Control: on Windows and Linux a primary-modifier binding and a Control
  /// binding of one key are the same keys.
  bool pressesLike(ForgeKeyStroke other, {required bool primaryIsMeta}) =>
      keyId == other.keyId &&
      shift == other.shift &&
      alt == other.alt &&
      _meta(primaryIsMeta) == other._meta(primaryIsMeta) &&
      _control(primaryIsMeta) == other._control(primaryIsMeta);

  bool _meta(bool primaryIsMeta) => primaryModifier && primaryIsMeta;
  bool _control(bool primaryIsMeta) =>
      control || (primaryModifier && !primaryIsMeta);

  /// A key for maps grouping strokes pressed alike on that platform.
  String pressKey({required bool primaryIsMeta}) =>
      '$keyId:${_meta(primaryIsMeta) ? 'm' : ''}'
      '${_control(primaryIsMeta) ? 'c' : ''}${shift ? 's' : ''}'
      '${alt ? 'a' : ''}';

  @override
  bool operator ==(Object other) =>
      other is ForgeKeyStroke &&
      other.keyId == keyId &&
      other.primaryModifier == primaryModifier &&
      other.control == control &&
      other.shift == shift &&
      other.alt == alt;

  @override
  int get hashCode => Object.hash(keyId, primaryModifier, control, shift, alt);

  @override
  String toString() =>
      'ForgeKeyStroke(${[if (primaryModifier) 'primary', if (control) 'ctrl', if (shift) 'shift', if (alt) 'alt', '0x${keyId.toRadixString(16)}'].join('+')})';
}

/// A key binding of one stroke or a chord of two or more pressed one after
/// the other ([strokes]); [ForgeKeyChord.none] (no strokes) is unbound.
///
/// A chord of two or more is stored as Forge has always stored a chord
/// (`forge.shortcuts.chordOverrides`): a map of `firstKey` and `secondKey`,
/// each a stroke's map, a third and later stroke as a list under `moreKeys`
/// (a reader that knows only two keys reads the first two).
class ForgeKeyChord {
  const ForgeKeyChord(this.strokes);

  /// One stroke.
  ForgeKeyChord.single(ForgeKeyStroke stroke)
    : strokes = stroke.isNone ? const [] : [stroke];

  /// Unbound.
  static const none = ForgeKeyChord([]);

  /// The strokes, in the order they are pressed.
  final List<ForgeKeyStroke> strokes;

  bool get isNone => strokes.isEmpty;

  /// Whether this is a chord (two strokes or more).
  bool get isChord => strokes.length >= 2;

  /// The first stroke ([ForgeKeyStroke.none] when unbound).
  ForgeKeyStroke get first =>
      strokes.isEmpty ? ForgeKeyStroke.none : strokes[0];

  /// The chord's stored form (`firstKey`, `secondKey`, `moreKeys`); `{}`
  /// when unbound; a single stroke as `firstKey` alone.
  Map<String, Object?> toChordJson() => {
    if (strokes.isNotEmpty) 'firstKey': strokes[0].toJson(),
    if (strokes.length > 1) 'secondKey': strokes[1].toJson(),
    if (strokes.length > 2)
      'moreKeys': [for (final s in strokes.skip(2)) s.toJson()],
  };

  /// [json] in the chord's stored form as a chord, or null when it is none.
  static ForgeKeyChord? fromChordJson(Object? json) {
    if (json is! Map) return null;
    if (json.isEmpty) return ForgeKeyChord.none;
    final first = ForgeKeyStroke.fromJson(json['firstKey']);
    if (first == null) return null;
    final strokes = [first];
    if (json.containsKey('secondKey')) {
      final second = ForgeKeyStroke.fromJson(json['secondKey']);
      if (second == null) return null;
      strokes.add(second);
    }
    final more = json['moreKeys'];
    if (more is List) {
      for (final item in more) {
        final stroke = ForgeKeyStroke.fromJson(item);
        if (stroke == null) return null;
        strokes.add(stroke);
      }
    }
    return ForgeKeyChord(List.unmodifiable(strokes));
  }

  /// Whether this and [other] are pressed alike (see
  /// [ForgeKeyStroke.pressesLike]).
  bool pressesLike(ForgeKeyChord other, {required bool primaryIsMeta}) {
    if (strokes.length != other.strokes.length) return false;
    for (var i = 0; i < strokes.length; i++) {
      if (!strokes[i].pressesLike(
        other.strokes[i],
        primaryIsMeta: primaryIsMeta,
      )) {
        return false;
      }
    }
    return true;
  }

  /// Whether this binding's strokes begin [other]'s (pressing this one
  /// would run before [other] could be completed).
  bool isPrefixOf(ForgeKeyChord other, {required bool primaryIsMeta}) {
    if (isNone || strokes.length >= other.strokes.length) return false;
    for (var i = 0; i < strokes.length; i++) {
      if (!strokes[i].pressesLike(
        other.strokes[i],
        primaryIsMeta: primaryIsMeta,
      )) {
        return false;
      }
    }
    return true;
  }

  /// A key for maps grouping bindings pressed alike.
  String pressKey({required bool primaryIsMeta}) => [
    for (final s in strokes) s.pressKey(primaryIsMeta: primaryIsMeta),
  ].join(' ');

  @override
  bool operator ==(Object other) {
    if (other is! ForgeKeyChord || other.strokes.length != strokes.length) {
      return false;
    }
    for (var i = 0; i < strokes.length; i++) {
      if (other.strokes[i] != strokes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(strokes);

  @override
  String toString() => 'ForgeKeyChord(${strokes.join(' ')})';
}

/// The overrides of a key binding table: action id → binding, as the user
/// set them. The bindings in effect are the catalogue's defaults with these
/// laid over them ([forgeKeyBindingRows]).
class ForgeKeyBindingTable {
  const ForgeKeyBindingTable([this.overrides = const {}]);

  /// No overrides.
  static const empty = ForgeKeyBindingTable();

  final Map<String, ForgeKeyChord> overrides;

  /// [actionId] bound to [binding].
  ForgeKeyBindingTable withOverride(String actionId, ForgeKeyChord binding) =>
      ForgeKeyBindingTable(Map.unmodifiable({...overrides, actionId: binding}));

  /// [actionId]'s override removed: its default is in effect.
  ForgeKeyBindingTable withoutOverride(String actionId) =>
      ForgeKeyBindingTable(Map.unmodifiable({...overrides}..remove(actionId)));

  /// Every override removed (*Reset all*).
  ForgeKeyBindingTable resetAll() => empty;

  /// [binding] for every editor offering [actionId]'s action: bound to the
  /// wildcard id `*.<suffix>` ([forgeWildcardActionId]) instead of
  /// [actionId], whose own override is removed. [actionId] itself when it
  /// has no `<prefix>.` to replace.
  ForgeKeyBindingTable withWildcard(String actionId, ForgeKeyChord binding) {
    final wildcard = forgeWildcardActionId(actionId);
    if (wildcard == null) return withOverride(actionId, binding);
    return ForgeKeyBindingTable(
      Map.unmodifiable({...overrides, wildcard: binding}..remove(actionId)),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! ForgeKeyBindingTable ||
        other.overrides.length != overrides.length) {
      return false;
    }
    for (final entry in overrides.entries) {
      if (other.overrides[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    overrides.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// The wildcard id of [actionId] (`md.bold` → `*.bold`), or null when it has
/// no `<prefix>.` or is a wildcard already.
String? forgeWildcardActionId(String actionId) {
  final dot = actionId.indexOf('.');
  if (dot <= 0 || actionId.startsWith('*')) return null;
  return '*.${actionId.substring(dot + 1)}';
}

/// Whether [a] and [b] are one action for the table: equal, or one is the
/// other's wildcard (`*.bold` and `md.bold`).
bool forgeSameActionFamily(String a, String b) {
  if (a == b) return true;
  if (a.startsWith('*.')) return b.endsWith(a.substring(1));
  if (b.startsWith('*.')) return a.endsWith(b.substring(1));
  return false;
}

/// One row of a key binding table: the action, its binding in effect and
/// where the binding comes from.
class ForgeKeyBindingRow {
  const ForgeKeyBindingRow({
    required this.action,
    required this.binding,
    required this.overridden,
    this.deleted = false,
    this.wildcard = false,
  });

  /// The action (for a wildcard row, the catalogue action it was made for,
  /// under the wildcard id).
  final ForgeCatalogueAction action;

  /// The binding in effect ([ForgeKeyChord.none] when unbound or deleted).
  final ForgeKeyChord binding;

  /// Whether the user set it (an override), not the default.
  final bool overridden;

  /// Whether the user deleted the action's binding.
  final bool deleted;

  /// Whether the row is a wildcard override (`*.<suffix>`) for every
  /// editor.
  final bool wildcard;
}

/// The rows of a key binding table: every [actions] entry with its binding
/// in effect — the [table]'s override, else its default, none when
/// [deleted] — and a row for each override of an action the catalogue lacks
/// (a wildcard `*.<suffix>` row takes the label of an action of that
/// suffix). [chords] keeps the rows whose binding (in effect or default) is
/// a chord, else those whose binding is not.
List<ForgeKeyBindingRow> forgeKeyBindingRows(
  List<ForgeCatalogueAction> actions,
  ForgeKeyBindingTable table, {
  Set<String> deleted = const {},
  bool chords = false,
}) {
  bool fits(ForgeKeyChord? binding) =>
      binding == null || binding.isNone || binding.isChord == chords;
  final rows = <ForgeKeyBindingRow>[];
  final known = <String>{};
  for (final action in actions) {
    known.add(action.id);
    final override = table.overrides[action.id];
    final isDeleted = deleted.contains(action.id);
    final binding = isDeleted
        ? ForgeKeyChord.none
        : override ?? action.defaultBinding ?? ForgeKeyChord.none;
    if (override == null && !fits(action.defaultBinding)) continue;
    if (override != null && !fits(override)) continue;
    rows.add(
      ForgeKeyBindingRow(
        action: action,
        binding: binding,
        overridden: override != null,
        deleted: isDeleted,
      ),
    );
  }
  for (final entry in table.overrides.entries) {
    if (known.contains(entry.key) || !fits(entry.value)) continue;
    final wildcard = entry.key.startsWith('*.');
    ForgeCatalogueAction? base;
    if (wildcard) {
      for (final action in actions) {
        if (forgeSameActionFamily(entry.key, action.id)) {
          base = action;
          break;
        }
      }
    }
    rows.add(
      ForgeKeyBindingRow(
        action: ForgeCatalogueAction(
          id: entry.key,
          label: base?.label ?? entry.key,
          group: base?.group,
        ),
        binding: entry.value,
        overridden: true,
        wildcard: wildcard,
      ),
    );
  }
  return rows;
}

/// Why two or more actions collide on one binding.
enum ForgeKeyConflictKind {
  /// They have the same binding in overlapping scopes.
  same,

  /// One's binding begins the other's chord: the shorter one runs first.
  prefix,
}

/// Actions whose bindings collide ([kind]).
class ForgeKeyBindingConflict {
  const ForgeKeyBindingConflict({
    required this.kind,
    required this.binding,
    required this.actionIds,
  });

  final ForgeKeyConflictKind kind;

  /// The binding they collide on (the shorter one for a prefix).
  final ForgeKeyChord binding;

  /// The actions, in row order.
  final List<String> actionIds;
}

/// The conflicts among [rows]' bindings in effect: two actions bound alike
/// ([ForgeKeyChord.pressesLike] on a platform whose primary modifier is
/// Command, [primaryIsMeta], or Control) in overlapping scopes (equal, or
/// one of them everywhere — scope null), and a binding that begins another's
/// chord in overlapping scopes. Actions of one family (`*.bold` and
/// `md.bold`) never conflict with each other.
List<ForgeKeyBindingConflict> forgeKeyBindingConflicts(
  List<ForgeKeyBindingRow> rows, {
  required bool primaryIsMeta,
}) {
  bool overlap(String? a, String? b) => a == null || b == null || a == b;
  final bound = [
    for (final row in rows)
      if (!row.binding.isNone) row,
  ];
  final groups = <String, List<ForgeKeyBindingRow>>{};
  for (final row in bound) {
    groups
        .putIfAbsent(
          row.binding.pressKey(primaryIsMeta: primaryIsMeta),
          () => [],
        )
        .add(row);
  }
  final out = <ForgeKeyBindingConflict>[];
  for (final group in groups.values) {
    if (group.length < 2) continue;
    final colliding = <String>{};
    for (var i = 0; i < group.length; i++) {
      for (var j = i + 1; j < group.length; j++) {
        final a = group[i];
        final b = group[j];
        if (forgeSameActionFamily(a.action.id, b.action.id)) continue;
        if (!overlap(a.action.scope, b.action.scope)) continue;
        colliding
          ..add(a.action.id)
          ..add(b.action.id);
      }
    }
    if (colliding.length > 1) {
      out.add(
        ForgeKeyBindingConflict(
          kind: ForgeKeyConflictKind.same,
          binding: group.first.binding,
          actionIds: [
            for (final row in group)
              if (colliding.contains(row.action.id)) row.action.id,
          ],
        ),
      );
    }
  }
  for (final short in bound) {
    final longer = [
      for (final other in bound)
        if (short.binding.isPrefixOf(
              other.binding,
              primaryIsMeta: primaryIsMeta,
            ) &&
            overlap(short.action.scope, other.action.scope) &&
            !forgeSameActionFamily(short.action.id, other.action.id))
          other.action.id,
    ];
    if (longer.isEmpty) continue;
    out.add(
      ForgeKeyBindingConflict(
        kind: ForgeKeyConflictKind.prefix,
        binding: short.binding,
        actionIds: [short.action.id, ...longer],
      ),
    );
  }
  return out;
}

// ── The settings ──

Object? _jsonOrSelf(Object? stored) {
  if (stored is! String) return stored;
  try {
    return jsonDecode(stored);
  } on FormatException {
    return null;
  }
}

/// One key combination, captured from the keyboard; [ForgeKeyStroke.none]
/// is unbound (when [allowNone]). Stored as `{"keyId": ..., "primaryModifier":
/// ..., ...}` ([ForgeKeyStroke.toJson]); unbound as `{"keyId": 0}`.
class ForgeKeyBindingSetting extends ForgeSetting<ForgeKeyStroke> {
  const ForgeKeyBindingSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = ForgeKeyStroke.none,
    this.allowNone = true,
    this.requireModifier = false,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  /// Whether unbound is a value.
  final bool allowNone;

  /// Whether a key without modifier is refused.
  final bool requireModifier;

  @override
  String get kind => ForgeSettingKinds.keyBinding;

  @override
  ForgeKeyStroke? decode(Object? stored) {
    if (stored is ForgeKeyStroke) return stored;
    return ForgeKeyStroke.fromJson(_jsonOrSelf(stored));
  }

  @override
  Object? encode(ForgeKeyStroke value) =>
      value.isNone ? const {'keyId': 0} : value.toJson();

  @override
  ForgeText? validate(ForgeKeyStroke value) {
    if (value.isNone) {
      return allowNone ? null : ForgeConfigurationTexts.keyRequired;
    }
    if (requireModifier && !value.hasModifier) {
      return ForgeConfigurationTexts.modifierRequired;
    }
    return null;
  }
}

/// A chord: two or more key combinations pressed one after the other
/// ([minStrokes]..[maxStrokes]); [ForgeKeyChord.none] is unbound (when
/// [allowNone]). Stored as `{"firstKey": ..., "secondKey": ..., "moreKeys":
/// [...]}`; unbound as `{}`.
class ForgeKeyChordSetting extends ForgeSetting<ForgeKeyChord> {
  const ForgeKeyChordSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = ForgeKeyChord.none,
    this.minStrokes = 2,
    this.maxStrokes = 4,
    this.allowNone = true,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  final int minStrokes;
  final int maxStrokes;
  final bool allowNone;

  @override
  String get kind => ForgeSettingKinds.keyChord;

  @override
  ForgeKeyChord? decode(Object? stored) {
    if (stored is ForgeKeyChord) return stored;
    return ForgeKeyChord.fromChordJson(_jsonOrSelf(stored));
  }

  @override
  Object? encode(ForgeKeyChord value) => value.toChordJson();

  @override
  ForgeText? validate(ForgeKeyChord value) {
    if (value.isNone) {
      return allowNone ? null : ForgeConfigurationTexts.keyRequired;
    }
    if (value.strokes.length < minStrokes) {
      return ForgeConfigurationTexts.chordLength(minStrokes, maxStrokes);
    }
    if (value.strokes.length > maxStrokes) {
      return ForgeConfigurationTexts.chordLength(minStrokes, maxStrokes);
    }
    if (value.strokes.any((s) => s.isNone)) {
      return ForgeConfigurationTexts.keyRequired;
    }
    return null;
  }
}

/// A table of key bindings: the actions of an action catalogue supplied at
/// run time ([catalogue], a `ForgeActionCatalogue` id), each with its
/// binding in effect, the user's overrides as the value
/// ([ForgeKeyBindingTable]), conflicts marked, *Reset all*, and — for
/// actions of an editor named in [wildcardPrefixes] — the choice to bind a
/// key for every editor (`*.<suffix>`).
///
/// Single keys ([chords] false) are stored as Forge stores its shortcut
/// overrides (`forge.shortcuts.overrides`): action id → the stroke's map
/// ([ForgeKeyStroke.toJson]); chords as its chord overrides
/// (`forge.shortcuts.chordOverrides`): action id → the chord's map
/// ([ForgeKeyChord.toChordJson]). A malformed
/// entry is skipped when read, as Forge always did. The actions the user
/// deleted are kept beside it in [deletedBindings] (Forge's
/// `forge.shortcuts.deletedBindings`, a list of action ids), a companion
/// setting the values service keeps.
class ForgeKeyBindingTableSetting extends ForgeSetting<ForgeKeyBindingTable> {
  const ForgeKeyBindingTableSetting({
    required super.id,
    required super.storage,
    required super.label,
    required this.catalogue,
    super.defaultValue = ForgeKeyBindingTable.empty,
    this.chords = false,
    this.deletedBindings,
    this.wildcardPrefixes = const [],
    this.allowReset = true,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  /// The id of the `ForgeActionCatalogue` that lists the actions.
  final String catalogue;

  /// Whether the table binds chords (else single keys).
  final bool chords;

  /// Where the deleted actions are kept, or null when deleting is not
  /// offered.
  final ForgeStringListSetting? deletedBindings;

  /// The action id prefixes (`md`, `dart`) whose actions may be bound for
  /// every editor at once (`*.<suffix>`).
  final List<String> wildcardPrefixes;

  /// Whether *Reset all* is offered.
  final bool allowReset;

  /// Whether [actionId] may be bound for every editor.
  bool offersWildcard(String actionId) {
    final dot = actionId.indexOf('.');
    return dot > 0 && wildcardPrefixes.contains(actionId.substring(0, dot));
  }

  @override
  String get kind => ForgeSettingKinds.keyBindingTable;

  @override
  List<ForgeSetting<Object>> get companions => [?deletedBindings];

  @override
  Iterable<String> get hookIds => [...actions, catalogue];

  @override
  ForgeKeyBindingTable? decode(Object? stored) {
    if (stored is ForgeKeyBindingTable) return stored;
    final source = _jsonOrSelf(stored);
    if (source is! Map) return null;
    final out = <String, ForgeKeyChord>{};
    for (final entry in source.entries) {
      final key = entry.key;
      if (key is! String) continue;
      final binding = chords
          ? ForgeKeyChord.fromChordJson(entry.value)
          : _single(entry.value);
      // Skipped as Forge's reader skips them: malformed, unbound, or a
      // chord entry without its second key.
      if (binding == null || binding.isNone) continue;
      if (chords && !binding.isChord) continue;
      out[key] = binding;
    }
    return ForgeKeyBindingTable(Map.unmodifiable(out));
  }

  static ForgeKeyChord? _single(Object? json) {
    final stroke = ForgeKeyStroke.fromJson(json);
    return stroke == null ? null : ForgeKeyChord.single(stroke);
  }

  @override
  Object? encode(ForgeKeyBindingTable value) => {
    for (final entry in value.overrides.entries)
      entry.key: chords
          ? entry.value.toChordJson()
          : entry.value.first.toJson(),
  };

  @override
  ForgeText? validate(ForgeKeyBindingTable value) {
    for (final entry in value.overrides.entries) {
      final binding = entry.value;
      if (binding.isNone) {
        return ForgeConfigurationTexts.item(
          entry.key,
          ForgeConfigurationTexts.keyRequired,
        );
      }
      if (chords ? !binding.isChord : binding.strokes.length != 1) {
        return ForgeConfigurationTexts.item(
          entry.key,
          chords
              ? ForgeConfigurationTexts.chordLength(2, 99)
              : ForgeConfigurationTexts.wrongType,
        );
      }
    }
    return null;
  }

  @override
  bool sameValue(ForgeKeyBindingTable a, ForgeKeyBindingTable b) => a == b;
}
