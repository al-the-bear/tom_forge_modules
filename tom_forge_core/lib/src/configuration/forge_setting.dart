import 'forge_configuration_texts.dart';
import 'forge_text.dart';

/// Where a setting's value is kept: the [key] of a document in the kit's
/// state-store port (`ForgeStateStore`), and inside it the [path] of map keys
/// down to the value.
///
/// With an empty [path] the document itself is the value (a bool, a number,
/// a string, a list or a map). With a path the document is a map and the
/// value sits at the path in it: several settings share one document, as
/// Forge's per-editor text settings do (`forge.editor.textSettings` →
/// `dart` → `fontSize`).
class ForgeSettingStorage {
  /// The value at [path] in the document under [key].
  const ForgeSettingStorage(this.key, {this.path = const []});

  /// The state-store key, e.g. `forge.appearance.themeMode`.
  final String key;

  /// The map keys from the document down to the value; empty: the document.
  final List<String> path;

  /// `key` or `key/a/b`, for messages and as a map key.
  String get location => path.isEmpty ? key : '$key/${path.join('/')}';

  @override
  bool operator ==(Object other) =>
      other is ForgeSettingStorage && other.location == location;

  @override
  int get hashCode => location.hashCode;

  @override
  String toString() => 'ForgeSettingStorage($location)';
}

/// A condition on another setting of the same description: a setting is
/// shown (`visibleWhen`) or editable (`enabledWhen`) only while it holds.
class ForgeSettingCondition {
  /// Holds while the setting [settingId] has one of [values].
  const ForgeSettingCondition.oneOf(this.settingId, this.values)
    : _single = null;

  /// Holds while the setting [settingId] equals [value].
  const ForgeSettingCondition.equals(this.settingId, Object value)
    : values = const [],
      _single = value;

  /// Holds while the bool setting [settingId] is true.
  const ForgeSettingCondition.isTrue(this.settingId)
    : values = const [],
      _single = true;

  /// The setting the condition reads, by id.
  final String settingId;

  /// The values it holds for (with [ForgeSettingCondition.oneOf]).
  final List<Object> values;

  final Object? _single;

  /// Whether the condition holds for [value] of [settingId].
  bool holds(Object? value) =>
      _single != null ? value == _single : values.contains(value);
}

/// The outcome of reading a stored value: the [value] in effect and, when
/// the stored one was refused, why ([problem]).
class ForgeSettingRead<T extends Object> {
  const ForgeSettingRead(this.value, {this.stored = false, this.problem});

  /// The value in effect: the stored one, else the default.
  final T value;

  /// Whether [value] came from the store (false: the default).
  final bool stored;

  /// Why a stored value was refused (the default is in effect then).
  final ForgeText? problem;
}

/// One setting of a component: a typed entry of a configuration
/// description.
///
/// The kind ([kind]) names the editor that edits it; [decode] and [encode]
/// translate between the value and its JSON-compatible stored form, and
/// [validate] checks a value against the constraints. A new kind is a new
/// subclass with its own kind id, plus an editor registered under that id
/// in `tom_configuration_ui` — nothing else changes.
abstract class ForgeSetting<T extends Object> {
  const ForgeSetting({
    required this.id,
    required this.storage,
    required this.label,
    required this.defaultValue,
    this.help,
    this.visibleWhen,
    this.enabledWhen,
  });

  /// The id, unique within its description (a condition names it).
  final String id;

  /// Where the value is kept in the state-store port.
  final ForgeSettingStorage storage;

  /// The label.
  final ForgeText label;

  /// What the setting does, shown on request.
  final ForgeText? help;

  /// The value in effect while nothing is stored (and after a reset).
  final T defaultValue;

  /// The setting is shown only while this holds.
  final ForgeSettingCondition? visibleWhen;

  /// The setting can be changed only while this holds.
  final ForgeSettingCondition? enabledWhen;

  /// The kind id, which names the editor (`ForgeSettingKinds`).
  String get kind;

  /// [stored] as a value of this kind, or null when it is none.
  T? decode(Object? stored);

  /// [value] as stored: JSON-compatible.
  Object? encode(T value) => value;

  /// Why [value] breaks a constraint, or null when it keeps them all.
  ForgeText? validate(T value) => null;

  /// Whether [a] and [b] are the same value (lists and maps by content).
  bool sameValue(T a, T b) => a == b;

  /// Why [value] — any object, as an editor hands it over — is not a valid
  /// value of this setting, or null when it is.
  ForgeText? check(Object? value) {
    final typed = decode(value);
    if (typed == null) return ForgeConfigurationTexts.wrongType;
    return validate(typed);
  }

  /// The value in effect for [stored] (null: nothing stored): the decoded
  /// value when it is valid, else the default with the [ForgeSettingRead.problem].
  ForgeSettingRead<T> read(Object? stored) {
    if (stored == null) return ForgeSettingRead(defaultValue);
    final typed = decode(stored);
    if (typed == null) {
      return ForgeSettingRead(
        defaultValue,
        problem: ForgeConfigurationTexts.wrongType,
      );
    }
    final problem = validate(typed);
    if (problem != null) {
      return ForgeSettingRead(defaultValue, problem: problem);
    }
    return ForgeSettingRead(typed, stored: true);
  }

  @override
  String toString() => '$runtimeType($id @ ${storage.location})';
}
