import 'package:tom_editors_shared/text_types.dart';

import '../components/forge_editor.dart';

/// Whether a save was asked for by the user or by the host on its own.
enum ForgeSaveTrigger {
  /// Save, Save All, a keyboard shortcut.
  explicit,

  /// Auto-save on a timer or on focus loss.
  automatic,
}

/// Saves [editor] if it **owns its model** — the step every host save path
/// takes before writing content of its own.
///
/// An editor whose content is not one string (a multi-part container) returns
/// null from `getContent()` and advertises
/// [StandardEditingActions.saveActionId]. An explicit save is handed to it
/// through `executeAction`; an automatic one leaves it alone, since when such a
/// write happens — and whether it needs to ask the user something first — is
/// the editor's call. Either way the host writes nothing and **never marks it
/// clean**: the editor clears its own state when its write lands, and a clean
/// indicator over unsaved work is the one outcome a save must not produce.
///
/// Returns null when [editor] does not own its saving, so the caller's own
/// content path applies unchanged; otherwise whether a save was started.
bool? saveOwnedEditor(
  ForgeEditor editor, {
  ForgeSaveTrigger trigger = ForgeSaveTrigger.explicit,
}) {
  if (!editor.supportedActionIds.contains(StandardEditingActions.saveActionId)) {
    return null;
  }
  if (trigger == ForgeSaveTrigger.automatic) return false;
  return editor.executeAction(StandardEditingActions.saveActionId);
}
