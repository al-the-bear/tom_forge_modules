import 'package:tom_core_kernel/tom_core_kernel.dart'
    show TomResourceException, TomTextResourceProvider;
import 'package:tom_flutter_ui/tom_flutter_ui.dart' show TomCtr;
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeText;

import 'configuration_ui_trail.dart';

/// Resolves the configuration's [ForgeText]s through Tom Core's text
/// resources: the application's `TomTextResourceProvider` bundle, looked up
/// as `tom_flutter_ui`'s `TomFormLabels` and `TomCtr` look it up (the key
/// alone, no field scope), else the English fallback.
///
/// An application installs its bundle with
/// `TomTextResourceProvider.setAppResourceProvider(...)`; the tiles re-read
/// their labels whenever it changes
/// (`TomTextResourceProvider.appResourcesRevision`).
///
/// **Defensive:** with no bundle installed, `getAppResources()` throws; a
/// lookup then answers null, so every label shows its fallback, and the
/// lookups of the same revision do not ask again (the exception logs itself
/// once, not once per label).
abstract final class ForgeConfigurationLabels {
  /// The revision at which no bundle was installed, or null.
  static int? _missingAt;

  /// [text] in the installed bundle's words, else its fallback.
  static String resolve(ForgeText text) => text.resolve(lookup);

  /// [text] resolved, or null when [text] is null.
  static String? resolveOrNull(ForgeText? text) =>
      text == null ? null : resolve(text);

  /// The installed bundle's text under [key], or null (none, or no bundle).
  static String? lookup(String key) {
    final revision = TomTextResourceProvider.appResourcesRevision.get();
    if (_missingAt == revision) return null;
    try {
      return TomCtr.textOrNull(key);
    } on TomResourceException {
      _missingAt = revision;
      return null;
    }
  }

  /// Whether the application has installed a text bundle.
  static bool get resourcesInstalled {
    final revision = TomTextResourceProvider.appResourcesRevision.get();
    if (_missingAt == revision) return false;
    try {
      TomTextResourceProvider.getAppResources();
      return true;
    } on TomResourceException {
      _missingAt = revision;
      return false;
    }
  }

  /// Installs an empty text bundle when the application has installed none.
  ///
  /// `tom_flutter_ui`'s fields, which the editors are built on, read the
  /// bundle while they build and cannot be built without one, so the first
  /// tile calls this before it builds an editor (an empty bundle makes every
  /// label show its fallback — Tom Core's intended degradation). An
  /// application installs its own bundle at start; then this does nothing.
  static void ensureResources() {
    if (resourcesInstalled) return;
    configurationUiTrail('no text bundle installed: installing an empty one');
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  }
}
