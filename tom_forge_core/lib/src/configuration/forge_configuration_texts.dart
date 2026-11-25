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
/// | `forge.configuration.validation.keyRequired` | `Press a key.` | — |
/// | `forge.configuration.validation.modifierRequired` | `Hold a modifier key with it.` | — |
/// | `forge.configuration.validation.chordLength` | `A chord of {min} to {max} keys.` | `min`, `max` |
/// | `forge.configuration.validation.notBefore` | `Not before {limit}.` | `limit` |
/// | `forge.configuration.validation.notAfter` | `Not after {limit}.` | `limit` |
/// | `forge.configuration.validation.noBinding` | `Cannot be kept: the storage "{binding}" is not available.` | `binding` |
/// | `forge.configuration.hook.missing` | `Not available here.` | `hook` |
/// | `forge.configuration.hook.failed` | `Failed: {message}` | `message` |
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

  /// A key binding without a key where one is required.
  static const keyRequired = ForgeText(
    'forge.configuration.validation.keyRequired',
    'Press a key.',
  );

  /// A key binding without a modifier where one is required.
  static const modifierRequired = ForgeText(
    'forge.configuration.validation.modifierRequired',
    'Hold a modifier key with it.',
  );

  /// A chord with too few or too many keys.
  static ForgeText chordLength(int min, int max) => ForgeText(
    'forge.configuration.validation.chordLength',
    'A chord of {min} to {max} keys.',
    params: {'min': min, 'max': max},
  );

  /// A date or time before the earliest allowed ([limit], as text).
  static ForgeText notBefore(String limit) => ForgeText(
    'forge.configuration.validation.notBefore',
    'Not before {limit}.',
    params: {'limit': limit},
  );

  /// A date or time after the latest allowed ([limit], as text).
  static ForgeText notAfter(String limit) => ForgeText(
    'forge.configuration.validation.notAfter',
    'Not after {limit}.',
    params: {'limit': limit},
  );

  /// A setting whose storage binding the application has not supplied.
  static ForgeText noBinding(String binding) => ForgeText(
    'forge.configuration.validation.noBinding',
    'Cannot be kept: the storage "{binding}" is not available.',
    params: {'binding': binding},
  );

  /// A hook the setting names that the application has not supplied.
  static ForgeText hookMissing(String hook) => ForgeText(
    'forge.configuration.hook.missing',
    'Not available here.',
    params: {'hook': hook},
  );

  /// A hook run that threw ([message]: what it threw).
  static ForgeText hookFailed(String message) => ForgeText(
    'forge.configuration.hook.failed',
    'Failed: {message}',
    params: {'message': message},
  );
}
