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
/// | `forge.configuration.ui.none` | `None` |
/// | `forge.configuration.ui.loading` | `Loading…` |
/// | `forge.configuration.ui.search` | `Search…` |
/// | `forge.configuration.ui.noMatches` | `Nothing matches.` |
/// | `forge.configuration.ui.chooseFont` | `Choose a font` |
/// | `forge.configuration.ui.defaultFont` | `Default font` |
/// | `forge.configuration.ui.monospaceOnly` | `Fixed-width fonts only` |
/// | `forge.configuration.ui.pressKeys` | `Press a key combination…` |
/// | `forge.configuration.ui.pressChord` | `Press the keys one after the other…` |
/// | `forge.configuration.ui.unbound` | `Not bound` |
/// | `forge.configuration.ui.change` | `Change` |
/// | `forge.configuration.ui.clear` | `Clear` |
/// | `forge.configuration.ui.cancel` | `Cancel` |
/// | `forge.configuration.ui.done` | `Done` |
/// | `forge.configuration.ui.ok` | `OK` |
/// | `forge.configuration.ui.resetAll` | `Reset all` |
/// | `forge.configuration.ui.resetBinding` | `Reset to the default binding` |
/// | `forge.configuration.ui.allEditors` | `All editors` |
/// | `forge.configuration.ui.bindForAll` | `Bind for every editor` |
/// | `forge.configuration.ui.removeBinding` | `Remove binding` |
/// | `forge.configuration.ui.detect` | `Detect` |
/// | `forge.configuration.ui.checkAgain` | `Check again` |
/// | `forge.configuration.ui.searching` | `Searching…` |
/// | `forge.configuration.ui.noCandidates` | `Nothing found.` |
/// | `forge.configuration.ui.use` | `Use` |
/// | `forge.configuration.ui.running` | `Running…` |
/// | `forge.configuration.ui.succeeded` | `Done.` |
/// | `forge.configuration.ui.failed` | `Failed.` |
/// | `forge.configuration.ui.cancelled` | `Cancelled.` |
/// | `forge.configuration.ui.stop` | `Stop` |
/// | `forge.configuration.ui.noDate` | `No date` |
/// | `forge.configuration.ui.pickDate` | `Pick a date` |
/// | `forge.configuration.ui.pickTime` | `Pick a time` |
/// | `forge.configuration.ui.utc` | `UTC` |
/// | `forge.configuration.ui.chooseColour` | `Choose a colour` |
/// | `forge.configuration.ui.hue` | `Hue` |
/// | `forge.configuration.ui.opacity` | `Opacity` |
/// | `forge.configuration.ui.continue` | `Continue` |
/// | `forge.configuration.ui.copy` | `Copy` |
/// | `forge.configuration.ui.showGroup` | `Show settings` |
/// | `forge.configuration.ui.hideGroup` | `Hide settings` |
/// | `forge.configuration.ui.conflict` | `Also bound to {actions}.` |
/// | `forge.configuration.ui.prefixConflict` | `Begins the chord of {actions}.` |
/// | `forge.configuration.ui.scope` | `In {scope}` |
/// | `forge.configuration.ui.version` | `Version {version}` |
/// | `forge.configuration.ui.moreItems` | `and {count} more` |
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

  /// The label of *none* in a choice or a map value that allows it.
  static const none = ForgeText('forge.configuration.ui.none', 'None');

  /// Shown while choices, rows or a status are read.
  static const loading = ForgeText(
    'forge.configuration.ui.loading',
    'Loading…',
  );

  /// The hint of a search box.
  static const search = ForgeText('forge.configuration.ui.search', 'Search…');

  /// Shown when a search keeps nothing.
  static const noMatches = ForgeText(
    'forge.configuration.ui.noMatches',
    'Nothing matches.',
  );

  /// The title of the font picker, and the tooltip of the button that opens it.
  static const chooseFont = ForgeText(
    'forge.configuration.ui.chooseFont',
    'Choose a font',
  );

  /// The empty font name: the application's default font.
  static const defaultFont = ForgeText(
    'forge.configuration.ui.defaultFont',
    'Default font',
  );

  /// The font picker's filter for a code font.
  static const monospaceOnly = ForgeText(
    'forge.configuration.ui.monospaceOnly',
    'Fixed-width fonts only',
  );

  /// Shown while a key binding is captured.
  static const pressKeys = ForgeText(
    'forge.configuration.ui.pressKeys',
    'Press a key combination…',
  );

  /// Shown while a chord is captured.
  static const pressChord = ForgeText(
    'forge.configuration.ui.pressChord',
    'Press the keys one after the other…',
  );

  /// Shown for a key binding that has no key.
  static const unbound = ForgeText(
    'forge.configuration.ui.unbound',
    'Not bound',
  );

  /// The button (or tooltip) that starts capturing a key binding.
  static const change = ForgeText('forge.configuration.ui.change', 'Change');

  /// The button that removes a value (a key binding, a date).
  static const clear = ForgeText('forge.configuration.ui.clear', 'Clear');

  /// The button that cancels a dialog or a capture.
  static const cancel = ForgeText('forge.configuration.ui.cancel', 'Cancel');

  /// The button that ends a chord's capture.
  static const done = ForgeText('forge.configuration.ui.done', 'Done');

  /// The button that confirms a dialog.
  static const ok = ForgeText('forge.configuration.ui.ok', 'OK');

  /// The button that removes every override of a key binding table.
  static const resetAll = ForgeText(
    'forge.configuration.ui.resetAll',
    'Reset all',
  );

  /// The tooltip of a key binding row's reset button.
  static const resetBinding = ForgeText(
    'forge.configuration.ui.resetBinding',
    'Reset to the default binding',
  );

  /// The badge of a wildcard row of a key binding table.
  static const allEditors = ForgeText(
    'forge.configuration.ui.allEditors',
    'All editors',
  );

  /// The tooltip of the button that binds a row's key for every editor.
  static const bindForAll = ForgeText(
    'forge.configuration.ui.bindForAll',
    'Bind for every editor',
  );

  /// The tooltip of the button that deletes a row's binding.
  static const removeBinding = ForgeText(
    'forge.configuration.ui.removeBinding',
    'Remove binding',
  );

  /// The button that searches for a tool.
  static const detect = ForgeText('forge.configuration.ui.detect', 'Detect');

  /// The button that checks a tool path again.
  static const checkAgain = ForgeText(
    'forge.configuration.ui.checkAgain',
    'Check again',
  );

  /// Shown while a tool is searched for.
  static const searching = ForgeText(
    'forge.configuration.ui.searching',
    'Searching…',
  );

  /// Shown when a detection finds no candidate.
  static const noCandidates = ForgeText(
    'forge.configuration.ui.noCandidates',
    'Nothing found.',
  );

  /// The button that takes a detected candidate.
  static const use = ForgeText('forge.configuration.ui.use', 'Use');

  /// Shown while an action runs.
  static const running = ForgeText(
    'forge.configuration.ui.running',
    'Running…',
  );

  /// Shown when an action succeeded without a message.
  static const succeeded = ForgeText(
    'forge.configuration.ui.succeeded',
    'Done.',
  );

  /// Shown when an action failed without a message.
  static const failed = ForgeText('forge.configuration.ui.failed', 'Failed.');

  /// Shown when the user stopped an action.
  static const cancelled = ForgeText(
    'forge.configuration.ui.cancelled',
    'Cancelled.',
  );

  /// The button that stops a running action.
  static const stop = ForgeText('forge.configuration.ui.stop', 'Stop');

  /// Shown for a date setting without a date.
  static const noDate = ForgeText('forge.configuration.ui.noDate', 'No date');

  /// The tooltip of the button that opens the date picker.
  static const pickDate = ForgeText(
    'forge.configuration.ui.pickDate',
    'Pick a date',
  );

  /// The tooltip of the button that opens the time picker.
  static const pickTime = ForgeText(
    'forge.configuration.ui.pickTime',
    'Pick a time',
  );

  /// Shown after a point in time kept in UTC.
  static const utc = ForgeText('forge.configuration.ui.utc', 'UTC');

  /// The colour picker's title, and the tooltip of the button that opens it.
  static const chooseColour = ForgeText(
    'forge.configuration.ui.chooseColour',
    'Choose a colour',
  );

  /// The colour picker's hue slider.
  static const hue = ForgeText('forge.configuration.ui.hue', 'Hue');

  /// The colour picker's opacity slider.
  static const opacity = ForgeText('forge.configuration.ui.opacity', 'Opacity');

  /// A flow step's default button.
  static const continueLabel = ForgeText(
    'forge.configuration.ui.continue',
    'Continue',
  );

  /// The tooltip of the button that copies a code or a link.
  static const copy = ForgeText('forge.configuration.ui.copy', 'Copy');

  /// The tooltip of a folded group's header.
  static const showGroup = ForgeText(
    'forge.configuration.ui.showGroup',
    'Show settings',
  );

  /// The tooltip of an unfolded group's header.
  static const hideGroup = ForgeText(
    'forge.configuration.ui.hideGroup',
    'Hide settings',
  );

  /// A key binding table's conflict: the other actions bound alike.
  static ForgeText conflict(String actions) => ForgeText(
    'forge.configuration.ui.conflict',
    'Also bound to {actions}.',
    params: {'actions': actions},
  );

  /// A key binding table's prefix conflict: the chords this binding begins.
  static ForgeText prefixConflict(String actions) => ForgeText(
    'forge.configuration.ui.prefixConflict',
    'Begins the chord of {actions}.',
    params: {'actions': actions},
  );

  /// Where an action of a key binding table is active.
  static ForgeText scope(String scope) => ForgeText(
    'forge.configuration.ui.scope',
    'In {scope}',
    params: {'scope': scope},
  );

  /// A detected candidate's version.
  static ForgeText version(String version) => ForgeText(
    'forge.configuration.ui.version',
    'Version {version}',
    params: {'version': version},
  );

  /// The count of a status's items not listed.
  static ForgeText moreItems(int count) => ForgeText(
    'forge.configuration.ui.moreItems',
    'and {count} more',
    params: {'count': count},
  );

  /// Shown in place of a setting whose kind has no editor registered.
  static ForgeText unknownKind(String kind) => ForgeText(
    'forge.configuration.ui.unknownKind',
    'No editor for settings of the kind "{kind}".',
    params: {'kind': kind},
  );
}
