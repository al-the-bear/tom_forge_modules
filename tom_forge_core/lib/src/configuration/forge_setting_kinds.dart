import 'dart:convert';

import 'forge_configuration_texts.dart';
import 'forge_setting.dart';
import 'forge_text.dart';

/// The kind ids of the settings `tom_forge_core` defines; each names the
/// editor `tom_configuration_ui` shows for it. An application or component
/// adds a kind with a [ForgeSetting] subclass of its own id and an editor
/// registered under it.
abstract final class ForgeSettingKinds {
  /// [ForgeBoolSetting].
  static const boolean = 'bool';

  /// [ForgeIntSetting].
  static const integer = 'int';

  /// [ForgeDoubleSetting].
  static const decimal = 'double';

  /// [ForgeStringSetting].
  static const string = 'string';

  /// [ForgeChoiceSetting].
  static const choice = 'choice';

  /// [ForgeStringListSetting].
  static const stringList = 'stringList';

  /// [ForgePathSetting].
  static const path = 'path';

  /// [ForgeColorSetting].
  static const color = 'color';

  /// [ForgeStringMapSetting].
  static const stringMap = 'stringMap';

  /// Every kind defined here.
  static const all = [
    boolean,
    integer,
    decimal,
    string,
    choice,
    stringList,
    path,
    color,
    stringMap,
  ];
}

/// An on/off setting.
class ForgeBoolSetting extends ForgeSetting<bool> {
  const ForgeBoolSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = false,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  @override
  String get kind => ForgeSettingKinds.boolean;

  @override
  bool? decode(Object? stored) => stored is bool ? stored : null;
}

/// A whole number, optionally between [min] and [max] (inclusive).
class ForgeIntSetting extends ForgeSetting<int> {
  const ForgeIntSetting({
    required super.id,
    required super.storage,
    required super.label,
    required super.defaultValue,
    this.min,
    this.max,
    this.unit,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  /// The smallest value allowed, or null.
  final int? min;

  /// The largest value allowed, or null.
  final int? max;

  /// The unit shown beside the value (e.g. `s`, `px`), or null.
  final ForgeText? unit;

  @override
  String get kind => ForgeSettingKinds.integer;

  @override
  int? decode(Object? stored) {
    if (stored is int) return stored;
    if (stored is double && stored == stored.roundToDouble()) {
      return stored.toInt();
    }
    return null;
  }

  @override
  ForgeText? validate(int value) {
    if (min != null && value < min!) return ForgeConfigurationTexts.min(min!);
    if (max != null && value > max!) return ForgeConfigurationTexts.max(max!);
    return null;
  }
}

/// A number, optionally between [min] and [max] (inclusive).
class ForgeDoubleSetting extends ForgeSetting<double> {
  const ForgeDoubleSetting({
    required super.id,
    required super.storage,
    required super.label,
    required super.defaultValue,
    this.min,
    this.max,
    this.decimals,
    this.unit,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  /// The smallest value allowed, or null.
  final double? min;

  /// The largest value allowed, or null.
  final double? max;

  /// The decimals an editor shows, or null for as many as the value has.
  final int? decimals;

  /// The unit shown beside the value, or null.
  final ForgeText? unit;

  @override
  String get kind => ForgeSettingKinds.decimal;

  @override
  double? decode(Object? stored) {
    if (stored is num && stored.isFinite) return stored.toDouble();
    return null;
  }

  @override
  ForgeText? validate(double value) {
    if (min != null && value < min!) return ForgeConfigurationTexts.min(min!);
    if (max != null && value > max!) return ForgeConfigurationTexts.max(max!);
    return null;
  }
}

/// Text: one line unless [multiline], optionally required, bounded in length
/// or of a [pattern]'s form.
class ForgeStringSetting extends ForgeSetting<String> {
  const ForgeStringSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = '',
    this.allowEmpty = true,
    this.multiline = false,
    this.maxLength,
    this.pattern,
    this.patternMessage,
    this.hint,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  /// Whether the empty text is a value.
  final bool allowEmpty;

  /// Whether the text may hold line breaks.
  final bool multiline;

  /// The most characters allowed, or null.
  final int? maxLength;

  /// A regular expression the whole text must match, or null.
  final String? pattern;

  /// The message for a text that does not match [pattern] (default:
  /// [ForgeConfigurationTexts.pattern]).
  final ForgeText? patternMessage;

  /// A hint shown in the empty editor.
  final ForgeText? hint;

  @override
  String get kind => ForgeSettingKinds.string;

  @override
  String? decode(Object? stored) => stored is String ? stored : null;

  @override
  ForgeText? validate(String value) {
    if (value.isEmpty) {
      return allowEmpty ? null : ForgeConfigurationTexts.required;
    }
    if (!multiline && value.contains('\n')) {
      return ForgeConfigurationTexts.multiline;
    }
    if (maxLength != null && value.length > maxLength!) {
      return ForgeConfigurationTexts.maxLength(maxLength!);
    }
    if (pattern != null && !RegExp('^(?:${pattern!})\$').hasMatch(value)) {
      return patternMessage ?? ForgeConfigurationTexts.pattern(pattern!);
    }
    return null;
  }
}

/// One choice of a [ForgeChoiceSetting] (or the values of a
/// [ForgeStringMapSetting]): the stored [value] and its [label].
class ForgeSettingChoice {
  const ForgeSettingChoice(this.value, this.label);

  /// The value stored when it is chosen.
  final String value;

  /// What the user sees.
  final ForgeText label;
}

/// How an editor offers a [ForgeChoiceSetting]'s choices.
enum ForgeChoiceDisplay {
  /// The editor decides: side by side for up to three choices, else a list.
  auto,

  /// A drop-down list.
  dropdown,

  /// The choices side by side.
  segmented,
}

/// One of a fixed set of values ([choices]), stored as the chosen value.
class ForgeChoiceSetting extends ForgeSetting<String> {
  const ForgeChoiceSetting({
    required super.id,
    required super.storage,
    required super.label,
    required super.defaultValue,
    required this.choices,
    this.display = ForgeChoiceDisplay.auto,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  /// The choices, in the order they are offered.
  final List<ForgeSettingChoice> choices;

  /// How they are offered.
  final ForgeChoiceDisplay display;

  /// The choice of [value], or null.
  ForgeSettingChoice? choiceOf(String value) {
    for (final choice in choices) {
      if (choice.value == value) return choice;
    }
    return null;
  }

  @override
  String get kind => ForgeSettingKinds.choice;

  @override
  String? decode(Object? stored) => stored is String ? stored : null;

  @override
  ForgeText? validate(String value) =>
      choiceOf(value) == null ? ForgeConfigurationTexts.choice : null;
}

/// A list of texts — free items (each of [itemPattern]'s form when given) or,
/// with [choices], a selection among them.
class ForgeStringListSetting extends ForgeSetting<List<String>> {
  const ForgeStringListSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = const [],
    this.choices,
    this.itemPattern,
    this.allowDuplicates = false,
    this.hint,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  /// The items to choose from, or null for free items.
  final List<ForgeSettingChoice>? choices;

  /// A regular expression every free item must match, or null.
  final String? itemPattern;

  /// Whether an item may be listed twice.
  final bool allowDuplicates;

  /// A hint shown in the field a new item is typed into.
  final ForgeText? hint;

  @override
  String get kind => ForgeSettingKinds.stringList;

  @override
  List<String>? decode(Object? stored) {
    var source = stored;
    if (source is String) source = _tryJson(source);
    if (source is! List) return null;
    if (source.any((item) => item is! String)) return null;
    return List<String>.unmodifiable(source.cast<String>());
  }

  @override
  ForgeText? validate(List<String> value) {
    final seen = <String>{};
    final pattern = itemPattern == null
        ? null
        : RegExp('^(?:${itemPattern!})\$');
    for (final item in value) {
      if (item.isEmpty) {
        return ForgeConfigurationTexts.item(
          item,
          ForgeConfigurationTexts.required,
        );
      }
      if (!allowDuplicates && !seen.add(item)) {
        return ForgeConfigurationTexts.duplicate(item);
      }
      final allowed = choices;
      if (allowed != null && !allowed.any((c) => c.value == item)) {
        return ForgeConfigurationTexts.item(
          item,
          ForgeConfigurationTexts.choice,
        );
      }
      if (pattern != null && !pattern.hasMatch(item)) {
        return ForgeConfigurationTexts.item(
          item,
          ForgeConfigurationTexts.pattern(itemPattern!),
        );
      }
    }
    return null;
  }

  @override
  bool sameValue(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Whether a [ForgePathSetting] names a file or a folder.
enum ForgePathKind { file, folder }

/// A path of a file or a folder, typed or chosen with the application's
/// picker.
class ForgePathSetting extends ForgeSetting<String> {
  const ForgePathSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = '',
    this.pathKind = ForgePathKind.file,
    this.allowEmpty = true,
    this.hint,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  /// A file or a folder.
  final ForgePathKind pathKind;

  /// Whether the empty path (none) is a value.
  final bool allowEmpty;

  /// A hint shown in the empty editor.
  final ForgeText? hint;

  @override
  String get kind => ForgeSettingKinds.path;

  @override
  String? decode(Object? stored) => stored is String ? stored : null;

  @override
  ForgeText? validate(String value) {
    if (value.isEmpty && !allowEmpty) return ForgeConfigurationTexts.required;
    if (value.contains('\n')) return ForgeConfigurationTexts.multiline;
    return null;
  }
}

/// A colour as a 32-bit ARGB value (`0xAARRGGBB`), stored as that number.
/// Without [allowAlpha] it must be opaque.
class ForgeColorSetting extends ForgeSetting<int> {
  const ForgeColorSetting({
    required super.id,
    required super.storage,
    required super.label,
    required super.defaultValue,
    this.allowAlpha = false,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  /// Whether a translucent colour is a value.
  final bool allowAlpha;

  @override
  String get kind => ForgeSettingKinds.color;

  @override
  int? decode(Object? stored) {
    if (stored is int) return stored;
    if (stored is String) return parseHex(stored);
    return null;
  }

  @override
  ForgeText? validate(int value) {
    if (value < 0 || value > 0xFFFFFFFF) {
      return ForgeConfigurationTexts.wrongType;
    }
    if (!allowAlpha && (value >> 24) != 0xFF) {
      return ForgeConfigurationTexts.wrongType;
    }
    return null;
  }

  /// `#RRGGBB` (opaque) or `#AARRGGBB` as an ARGB value, or null.
  static int? parseHex(String text) {
    var hex = text.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (!RegExp(r'^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(hex)) {
      return null;
    }
    final value = int.parse(hex, radix: 16);
    return hex.length == 6 ? 0xFF000000 | value : value;
  }

  /// [value] as `#RRGGBB`, or `#AARRGGBB` when it is translucent.
  static String toHex(int value) {
    final alpha = (value >> 24) & 0xFF;
    final rgb = (value & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    if (alpha == 0xFF) return '#${rgb.toUpperCase()}';
    return '#${alpha.toRadixString(16).padLeft(2, '0')}$rgb'.toUpperCase();
  }
}

/// A map from texts to texts — an association table (a file extension to
/// the editor it opens in) — with values free or one of [valueChoices].
class ForgeStringMapSetting extends ForgeSetting<Map<String, String>> {
  const ForgeStringMapSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = const {},
    this.keyLabel,
    this.valueLabel,
    this.keyPattern,
    this.valueChoices,
    this.allowEmptyValues = false,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
  });

  /// The heading of the keys' column, or null.
  final ForgeText? keyLabel;

  /// The heading of the values' column, or null.
  final ForgeText? valueLabel;

  /// A regular expression every key must match, or null.
  final String? keyPattern;

  /// The values to choose from, or null for free values.
  final List<ForgeSettingChoice>? valueChoices;

  /// Whether the empty text is a value.
  final bool allowEmptyValues;

  @override
  String get kind => ForgeSettingKinds.stringMap;

  @override
  Map<String, String>? decode(Object? stored) {
    var source = stored;
    if (source is String) source = _tryJson(source);
    if (source is! Map) return null;
    final out = <String, String>{};
    for (final entry in source.entries) {
      if (entry.key is! String || entry.value is! String) return null;
      out[entry.key as String] = entry.value as String;
    }
    return Map<String, String>.unmodifiable(out);
  }

  @override
  ForgeText? validate(Map<String, String> value) {
    final pattern = keyPattern == null ? null : RegExp('^(?:${keyPattern!})\$');
    for (final entry in value.entries) {
      if (entry.key.isEmpty) {
        return ForgeConfigurationTexts.item(
          entry.key,
          ForgeConfigurationTexts.required,
        );
      }
      if (pattern != null && !pattern.hasMatch(entry.key)) {
        return ForgeConfigurationTexts.item(
          entry.key,
          ForgeConfigurationTexts.pattern(keyPattern!),
        );
      }
      if (entry.value.isEmpty && !allowEmptyValues) {
        return ForgeConfigurationTexts.item(
          entry.key,
          ForgeConfigurationTexts.required,
        );
      }
      final allowed = valueChoices;
      if (allowed != null &&
          entry.value.isNotEmpty &&
          !allowed.any((c) => c.value == entry.value)) {
        return ForgeConfigurationTexts.item(
          entry.key,
          ForgeConfigurationTexts.choice,
        );
      }
    }
    return null;
  }

  @override
  bool sameValue(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

Object? _tryJson(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
