import 'package:flutter/widgets.dart' show BuildContext;
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show TomTextResourceProvider;
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeText;
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show
        ForgeTextScope,
        ForgeTextScopeWidget,
        forgeTextLookup,
        forgeTextResourcesInstalled;

import 'configuration_ui_trail.dart';

/// Resolves the configuration's [ForgeText]s through Tom Core's text
/// resources (the application's `TomTextResourceProvider` bundle).
///
/// A tile shows a description's texts under the scope of the module that
/// contributed it (the workspace guideline `i18n.md`): the tile puts the
/// description's `ForgeTextScope` above its editors
/// (`ForgeTextScopeWidget`), and every widget below resolves with
/// [resolveIn], in its build. A [ForgeText.id] is read as
/// `<scope path>.<id>`; a key with an English fallback (a package not
/// migrated yet) is tried under the scope, then alone, then its fallback is
/// shown. [resolve] reads at the root scope, where no context is at hand.
///
/// An application installs its bundle with
/// `TomTextResourceProvider.setAppResourceProvider(...)`; the tiles re-read
/// their labels whenever it changes
/// (`TomTextResourceProvider.appResourcesRevision`).
///
/// **Defensive:** with no bundle installed, `getAppResources()` throws; a
/// lookup then answers null, so every label shows its fallback, and the
/// lookups of the same revision do not ask again (`forgeTextLookup`; the
/// exception logs itself once, not once per label).
abstract final class ForgeConfigurationLabels {
  /// [text] read at the root scope: its key alone, else its fallback.
  static String resolve(ForgeText text) => ForgeTextScope.root.resolve(text);

  /// [text] resolved, or null when [text] is null.
  static String? resolveOrNull(ForgeText? text) =>
      text == null ? null : resolve(text);

  /// [text] read under the text scope above [context] (the owning module's,
  /// put there by the tile).
  static String resolveIn(BuildContext context, ForgeText text) =>
      ForgeTextScopeWidget.resolve(context, text);

  /// [text] resolved under the text scope above [context], or null when
  /// [text] is null.
  static String? resolveOrNullIn(BuildContext context, ForgeText? text) =>
      text == null ? null : resolveIn(context, text);

  /// The installed bundle's text under [key], or null (none, or no bundle).
  static String? lookup(String key) => forgeTextLookup(key);

  /// Whether the application has installed a text bundle.
  static bool get resourcesInstalled => forgeTextResourcesInstalled;

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
