import 'package:tom_forge_core/tom_forge_core.dart' show ForgeText;

/// The strings the tiles show themselves, as [ForgeText]s under
/// `forge.configuration.ui.*` (English fallbacks), resolved through Tom Core's
/// text resources like every label ([ForgeConfigurationLabels]).
///
/// | Key | Fallback |
/// | --- | --- |
/// | `forge.configuration.ui.reset` | `Reset to default` |
/// | `forge.configuration.ui.help` | `Show help` |
/// | `forge.configuration.ui.browse` | `Browse…` |
/// | `forge.configuration.ui.add` | `Add` |
/// | `forge.configuration.ui.remove` | `Remove` |
/// | `forge.configuration.ui.newItem` | `New item` |
/// | `forge.configuration.ui.key` | `Key` |
/// | `forge.configuration.ui.value` | `Value` |
/// | `forge.configuration.ui.unknownKind` | `No editor for settings of the kind "{kind}".` |
abstract final class ForgeConfigurationUiTexts {
  /// The tooltip of an entry's reset button.
  static const reset = ForgeText(
    'forge.configuration.ui.reset',
    'Reset to default',
  );

  /// The tooltip of the button that shows an entry's or a section's help.
  static const help = ForgeText('forge.configuration.ui.help', 'Show help');

  /// The button that opens the application's file or folder picker.
  static const browse = ForgeText('forge.configuration.ui.browse', 'Browse…');

  /// The button that adds an item or a row.
  static const add = ForgeText('forge.configuration.ui.add', 'Add');

  /// The tooltip of the button that removes an item or a row.
  static const remove = ForgeText('forge.configuration.ui.remove', 'Remove');

  /// The hint of the field a new list item is typed into.
  static const newItem = ForgeText(
    'forge.configuration.ui.newItem',
    'New item',
  );

  /// The default heading of a map's keys.
  static const key = ForgeText('forge.configuration.ui.key', 'Key');

  /// The default heading of a map's values.
  static const value = ForgeText('forge.configuration.ui.value', 'Value');

  /// Shown in place of a setting whose kind has no editor registered.
  static ForgeText unknownKind(String kind) => ForgeText(
    'forge.configuration.ui.unknownKind',
    'No editor for settings of the kind "{kind}".',
    params: {'kind': kind},
  );
}
