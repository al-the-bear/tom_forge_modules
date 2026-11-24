import 'package:tom_forge_core/tom_forge_core.dart' show ForgeContextMenuEntry;

import '../components/forge_editor_choice.dart';
import 'forge_editor_picker.dart';

/// The id of the **Open With ▸** entry ([forgeOpenWithMenuEntry]).
const String forgeOpenWithMenuId = 'forge.openWith';

/// The id of the inner **Set default for … ▸** entry.
const String forgeOpenWithSetDefaultMenuId = 'forge.openWith.setDefault';

/// The id of the **Open With** entry that opens the item once in the editor
/// [choiceId].
String forgeOpenWithChoiceMenuId(String choiceId) =>
    '$forgeOpenWithMenuId.open.$choiceId';

/// The id of the **Set default for … ▸** entry that makes [choiceId] the
/// default.
String forgeOpenWithDefaultMenuId(String choiceId) =>
    '$forgeOpenWithSetDefaultMenuId.$choiceId';

/// What a default for the item of [choices] is set by from the menu: the
/// scope of the default in force, else [ForgeEditorPicker.scopeFor]; with
/// its key as the menu names it (`.md`, `text/markdown`); null when the item
/// has neither an extension nor a content type.
(ForgeEditorDefaultScope, String)? forgeOpenWithDefaultScope(
  ForgeEditorPicker picker,
  ForgeEditorChoices choices,
) {
  final item = choices.item;
  final scope = choices.defaultScope ?? picker.scopeFor(item);
  final contentType = item.contentType;
  return switch (scope) {
    ForgeEditorDefaultScope.contentType when contentType != null => (
      ForgeEditorDefaultScope.contentType,
      contentType,
    ),
    ForgeEditorDefaultScope.extension when item.extension.isNotEmpty => (
      ForgeEditorDefaultScope.extension,
      item.extension,
    ),
    _ => null,
  };
}

/// The **Open With ▸** context-menu entry for the item of [choices], as
/// data any application draws (`tom_forge_shared_ui` draws its submenus):
///
/// ```text
/// Open With ▸   ✓ Markdown editor (default for .md)
///                 MD Browser
///                 Plain text
///               ───────────────
///               Set default for .md ▸   ✓ Markdown editor
///                                         MD Browser
///                                         Plain text
/// ```
///
/// A click on an editor opens the item in it once ([open], default
/// [ForgeEditorPicker.openOnce]), leaving the default; the checked entry of
/// the inner submenu is the default, and a click on another makes that one
/// the default ([ForgeEditorPicker.setDefault], by
/// [forgeOpenWithDefaultScope]) without opening anything. Null when the
/// item has fewer than two editors: there is nothing to choose.
ForgeContextMenuEntry? forgeOpenWithMenuEntry(
  ForgeEditorPicker picker,
  ForgeEditorChoices choices, {
  void Function(ForgeKitEditorChoice choice)? open,
  String? group,
}) {
  if (choices.choices.length < 2) return null;
  final item = choices.item;
  final defaultScope = forgeOpenWithDefaultScope(picker, choices);
  final key = defaultScope?.$2;
  return ForgeContextMenuEntry(
    id: forgeOpenWithMenuId,
    label: 'Open With',
    enabled: true,
    group: group,
    run: () async {},
    children: [
      for (final choice in choices.choices)
        ForgeContextMenuEntry(
          id: forgeOpenWithChoiceMenuId(choice.id),
          label: choices.isDefault(choice) && key != null
              ? '${choice.label} (default for $key)'
              : choice.label,
          enabled: true,
          group: 'editors',
          checked: choices.isDefault(choice),
          run: () async {
            if (open != null) {
              open(choice);
            } else {
              picker.openOnce(item, choice);
            }
          },
        ),
      if (defaultScope case (final scope, final key))
        ForgeContextMenuEntry(
          id: forgeOpenWithSetDefaultMenuId,
          label: 'Set default for $key',
          enabled: true,
          group: 'default',
          run: () async {},
          children: [
            for (final choice in choices.choices)
              ForgeContextMenuEntry(
                id: forgeOpenWithDefaultMenuId(choice.id),
                label: choice.label,
                enabled: true,
                checked: choices.isDefault(choice),
                run: () async {
                  picker.setDefault(item, choice, scope: scope);
                },
              ),
          ],
        ),
    ],
  );
}
