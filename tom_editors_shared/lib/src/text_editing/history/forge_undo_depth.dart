import 'package:flutter/widgets.dart';

import '../forge_editor_integration.dart';

/// Keeps an editor's history depth at its integration's
/// `ForgeTextSettings.maxUndoHistory` — the one undo depth setting, for
/// every editor — now and whenever the host's settings change.
///
/// Calls [setDepth] at once and on every [ForgeEditorIntegration.textSettingsChanged];
/// returns the function that stops following.
VoidCallback forgeFollowUndoDepth(
  ForgeEditorIntegration integration,
  void Function(int depth) setDepth,
) {
  void apply() => setDepth(integration.textSettings.maxUndoHistory);
  apply();
  integration.textSettingsChanged.addListener(apply);
  return () => integration.textSettingsChanged.removeListener(apply);
}
