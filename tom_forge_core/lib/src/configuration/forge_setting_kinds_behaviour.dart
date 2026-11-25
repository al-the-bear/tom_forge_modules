import 'forge_configuration_texts.dart';
import 'forge_setting.dart';
import 'forge_setting_hooks.dart';
import 'forge_setting_kinds.dart';
import 'forge_text.dart';

/// A font family's name, chosen among the fonts the system has (a
/// `ForgeChoicesProvider`, [fontsProvider], answered by the application:
/// Flutter cannot list the system's fonts itself) and the [suggestions], or
/// typed. With [monospace] the editor offers fixed-width fonts first (a
/// provider is asked with the key `monospace`). Stored as the name.
class ForgeFontFamilySetting extends ForgeSetting<String> {
  const ForgeFontFamilySetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = '',
    this.monospace = false,
    this.fontsProvider = systemFonts,
    this.suggestions = const [],
    this.allowEmpty = true,
    this.allowCustom = true,
    this.hint,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  /// The conventional id of the provider of the system's font families.
  static const systemFonts = 'forge.fonts.system';

  /// Fonts every platform resolves (generic names), offered when no provider
  /// answers.
  static const genericFamilies = ['monospace', 'sans-serif', 'serif'];

  /// Whether the setting is for code (fixed-width fonts first).
  final bool monospace;

  /// The id of the `ForgeChoicesProvider` listing the fonts; null: only
  /// [suggestions] and the generic families.
  final String? fontsProvider;

  /// Fonts offered first (the application's bundled fonts).
  final List<String> suggestions;

  /// Whether the empty name (the application's default font) is a value.
  final bool allowEmpty;

  /// Whether a name no list offers may be typed.
  final bool allowCustom;

  /// A hint shown in the empty editor.
  final ForgeText? hint;

  @override
  String get kind => ForgeSettingKinds.fontFamily;

  @override
  Iterable<String> get hookIds => [...actions, ?fontsProvider];

  @override
  String? decode(Object? stored) => stored is String ? stored : null;

  @override
  ForgeText? validate(String value) {
    if (value.trim().isEmpty) {
      return allowEmpty ? null : ForgeConfigurationTexts.required;
    }
    if (value.contains('\n')) return ForgeConfigurationTexts.multiline;
    return null;
  }
}

/// The path of an external tool (a program, an app bundle, an SDK folder)
/// that the application can find by itself: empty means *find it* (the
/// [detector]'s usual search), a path is checked and its state shown.
///
/// - [detector]: the `ForgeSettingDetector` that checks the value
///   (*Check again*) and searches widely (*Detect*: every candidate with its
///   version and state, for the user to pick one), given [hints] (where to
///   look: candidate paths, search roots, executable names, environment
///   variables, `PATH`).
/// - `actions`: further buttons (*Download*, *Install*), and
///   [helpPanel]: the id of a panel the UI shows while the tool is not
///   usable (Forge's LibreOffice install help), supplied to the UI by the
///   application.
///
/// Stored as the path text; the empty path is not stored (Forge's
/// `forge.tools.<id>.path`, removed while empty).
class ForgeToolPathSetting extends ForgeSetting<String> {
  const ForgeToolPathSetting({
    required super.id,
    required super.storage,
    required super.label,
    required this.detector,
    super.defaultValue = '',
    this.hints = const ForgeDetectionHints(),
    this.pathKind = ForgePathKind.file,
    this.helpPanel,
    this.hint,
    this.checkWhenShown = true,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  /// The id of the `ForgeSettingDetector`.
  final String detector;

  /// Where the detector looks.
  final ForgeDetectionHints hints;

  /// A file (an executable) or a folder (an app bundle on macOS, an SDK).
  final ForgePathKind pathKind;

  /// The id of the panel shown while the tool is not usable, or null.
  final String? helpPanel;

  /// A hint shown in the empty editor (*found automatically*).
  final ForgeText? hint;

  /// Whether the value is checked when the setting is shown (else on
  /// *Check again* only).
  final bool checkWhenShown;

  @override
  String get kind => ForgeSettingKinds.toolPath;

  @override
  Iterable<String> get hookIds => [...actions, detector];

  @override
  String? decode(Object? stored) => stored is String ? stored.trim() : null;

  @override
  Object? encode(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  ForgeText? validate(String value) =>
      value.contains('\n') ? ForgeConfigurationTexts.multiline : null;
}

/// The value of a setting that keeps none ([ForgeActionSetting],
/// [ForgeStatusSetting]).
final class ForgeNoValue {
  const ForgeNoValue._();

  /// The one value.
  static const instance = ForgeNoValue._();

  @override
  String toString() => 'ForgeNoValue';
}

/// A setting that keeps no value: [ForgeSettingStorage.none], the value
/// [ForgeNoValue.instance].
abstract class ForgeValuelessSetting extends ForgeSetting<ForgeNoValue> {
  const ForgeValuelessSetting({
    required super.id,
    required super.label,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  }) : super(
         storage: const ForgeSettingStorage.none(),
         defaultValue: ForgeNoValue.instance,
       );

  @override
  bool get hasValue => false;

  @override
  ForgeNoValue? decode(Object? stored) => ForgeNoValue.instance;

  @override
  Object? encode(ForgeNoValue value) => null;
}

/// A button entry: runs the action ([action], a `ForgeSettingAction`) or
/// starts the flow ([flow], a `ForgeSettingFlow`) it names — *Edit
/// configuration*, *Reload configuration*, *Sign in to GitHub*. Keeps no
/// value. The label is the entry's; the button's is the hook's (or
/// [buttonLabel]).
class ForgeActionSetting extends ForgeValuelessSetting {
  const ForgeActionSetting({
    required super.id,
    required super.label,
    this.action,
    this.flow,
    this.buttonLabel,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  }) : assert(
         (action == null) != (flow == null),
         'an action setting names an action or a flow',
       );

  /// The id of the action it runs, or null.
  final String? action;

  /// The id of the flow it starts, or null.
  final String? flow;

  /// The button's label in place of the hook's.
  final ForgeText? buttonLabel;

  @override
  String get kind => ForgeSettingKinds.action;

  @override
  Iterable<String> get hookIds => [...actions, ?action, ?flow];
}

/// A read-only line: the status a `ForgeSettingStatusProvider` ([status])
/// answers — a level, a message, a detail and items (a list of issues) —
/// followed while shown when the provider streams it. Keeps no value.
class ForgeStatusSetting extends ForgeValuelessSetting {
  const ForgeStatusSetting({
    required super.id,
    required super.label,
    required this.status,
    this.showItems = true,
    this.maxItems = 20,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  /// The id of the status provider.
  final String status;

  /// Whether the status's items are listed.
  final bool showItems;

  /// The most items listed (the rest counted).
  final int maxItems;

  @override
  String get kind => ForgeSettingKinds.status;

  @override
  Iterable<String> get hookIds => [...actions, status];
}
