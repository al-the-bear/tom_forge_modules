import 'forge_text.dart';

/// The messages the setting kinds validate with, as [ForgeText]s under
/// `forge.configuration.validation.*` (English fallbacks).
///
/// | Key | Fallback | Parameters |
/// | --- | --- | --- |
/// | `forge.configuration.validation.wrongType` | `Not a valid value.` | — |
/// | `forge.configuration.validation.min` | `At least {min}.` | `min` |
/// | `forge.configuration.validation.max` | `At most {max}.` | `max` |
/// | `forge.configuration.validation.required` | `A value is required.` | — |
/// | `forge.configuration.validation.pattern` | `Does not have the expected form.` | `pattern` |
/// | `forge.configuration.validation.maxLength` | `At most {max} characters.` | `max` |
/// | `forge.configuration.validation.choice` | `Not one of the choices.` | — |
/// | `forge.configuration.validation.duplicate` | `"{item}" is listed twice.` | `item` |
/// | `forge.configuration.validation.item` | `"{item}": {message}` | `item`, `message` |
/// | `forge.configuration.validation.multiline` | `One line only.` | — |
abstract final class ForgeConfigurationTexts {
  /// The stored or typed value is not of the setting's type.
  static const wrongType = ForgeText(
    'forge.configuration.validation.wrongType',
    'Not a valid value.',
  );

  /// Below the setting's minimum.
  static ForgeText min(num min) => ForgeText(
    'forge.configuration.validation.min',
    'At least {min}.',
    params: {'min': min},
  );

  /// Above the setting's maximum.
  static ForgeText max(num max) => ForgeText(
    'forge.configuration.validation.max',
    'At most {max}.',
    params: {'max': max},
  );

  /// Empty where a value is required.
  static const required = ForgeText(
    'forge.configuration.validation.required',
    'A value is required.',
  );

  /// Does not match the setting's pattern.
  static ForgeText pattern(String pattern) => ForgeText(
    'forge.configuration.validation.pattern',
    'Does not have the expected form.',
    params: {'pattern': pattern},
  );

  /// Longer than the setting allows.
  static ForgeText maxLength(int max) => ForgeText(
    'forge.configuration.validation.maxLength',
    'At most {max} characters.',
    params: {'max': max},
  );

  /// Not one of a choice setting's values.
  static const choice = ForgeText(
    'forge.configuration.validation.choice',
    'Not one of the choices.',
  );

  /// An item listed twice where duplicates are not allowed.
  static ForgeText duplicate(String item) => ForgeText(
    'forge.configuration.validation.duplicate',
    '"{item}" is listed twice.',
    params: {'item': item},
  );

  /// One item of a list or map is wrong: [message] says why (resolved with
  /// the same lookup, so it is translated too).
  static ForgeText item(String item, ForgeText message) => ForgeText(
    'forge.configuration.validation.item',
    '"{item}": {message}',
    params: {'item': item, 'message': message},
  );

  /// A line break in a single-line value.
  static const multiline = ForgeText(
    'forge.configuration.validation.multiline',
    'One line only.',
  );
}
