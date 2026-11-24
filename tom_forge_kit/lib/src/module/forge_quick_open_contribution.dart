import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeSearchConfig;

import '../actions/forge_shortcut_binding.dart';
import '../kit/forge_kit_api.dart';
import 'forge_kit_module.dart';
import 'forge_kit_module_registry.dart';

/// What the application asks a quick-open contribution to show.
enum ForgeQuickOpenMode {
  /// Search across open editors, files, actions and settings.
  all,

  /// Search only actions.
  actions,

  /// Show the second keys that complete a pending chord shortcut.
  chord,
}

/// Everything a quick-open contribution is shown with: the application's
/// API and what the application keeps for it — the search field it hosts
/// (its controller and focus node), the chord pending, what to do when the
/// user opens a file, the help or the settings. It names no panel and no
/// layout: the application decides where the overlay goes.
class ForgeQuickOpenRequest {
  const ForgeQuickOpenRequest({
    required this.api,
    required this.mode,
    required this.onDismiss,
    required this.searchController,
    required this.searchFocusNode,
    this.initialQuery = '',
    this.chordFirstKey,
    this.chordCompletions = const [],
    this.searchConfig = const ForgeSearchConfig(),
    this.onOpenFile,
    this.onOpenHelp,
    this.onOpenSettings,
    this.configSectionTarget,
  });

  /// The application's API.
  final ForgeKitApi api;

  /// What to show.
  final ForgeQuickOpenMode mode;

  /// Closes the overlay (the application's own state).
  final VoidCallback onDismiss;

  /// The search field the application hosts for it.
  final TextEditingController searchController;

  /// The focus node of that search field.
  final FocusNode searchFocusNode;

  /// The text already typed.
  final String initialQuery;

  /// The first key of the pending chord ([ForgeQuickOpenMode.chord]).
  final ForgeShortcutKey? chordFirstKey;

  /// The bindings that complete the pending chord.
  final List<ForgeShortcutBinding> chordCompletions;

  /// How files are searched (extensions, folders, limits).
  final ForgeSearchConfig searchConfig;

  /// Opens a file the user picked; null: files open through
  /// `ForgeKitApi.openFile`.
  final void Function(Uri uri)? onOpenFile;

  /// Opens the keyboard-shortcut help.
  final VoidCallback? onOpenHelp;

  /// Opens the settings.
  final VoidCallback? onOpenSettings;

  /// The settings section to expand when a setting is picked.
  final ValueNotifier<int?>? configSectionTarget;
}

/// Builds the quick-open overlay for [request], keyed by [key].
typedef ForgeQuickOpenBuilder =
    Widget Function(Key? key, ForgeQuickOpenRequest request);

/// A quick-open overlay a module contributes, as a [ForgeModuleExtra]: the
/// application asks the registry ([forgeQuickOpenBuilderFor]) when the user
/// opens quick open or the command palette, and shows nothing when no module
/// offers one. [modes] are the modes it shows; of several contributions for
/// a mode the one with the highest [priority] wins, the first registered
/// breaking ties.
class ForgeQuickOpenExtra extends ForgeModuleExtra {
  ForgeQuickOpenExtra(
    ForgeQuickOpenBuilder builder, {
    Set<ForgeQuickOpenMode> modes = const {
      ForgeQuickOpenMode.all,
      ForgeQuickOpenMode.actions,
      ForgeQuickOpenMode.chord,
    },
    this.priority = 0,
  }) : modes = Set.unmodifiable(modes),
       super(kind: kindId, value: builder);

  /// The kind of this extra.
  static const kindId = 'forge.kit.quickOpen';

  /// The modes it shows.
  final Set<ForgeQuickOpenMode> modes;

  /// Which contribution wins for a mode several show: the highest.
  final int priority;

  /// Builds the overlay.
  ForgeQuickOpenBuilder get builder => value as ForgeQuickOpenBuilder;
}

/// The quick-open overlay the modules of [registry] contribute for [mode]
/// ([ForgeQuickOpenExtra]), or null when none does.
ForgeQuickOpenBuilder? forgeQuickOpenBuilderFor(
  ForgeKitModuleRegistry registry,
  ForgeQuickOpenMode mode,
) {
  ForgeQuickOpenExtra? best;
  for (final module in registry.allKitModules) {
    for (final extra in module.extras.whereType<ForgeQuickOpenExtra>()) {
      if (!extra.modes.contains(mode)) continue;
      if (best == null || extra.priority > best.priority) best = extra;
    }
  }
  return best?.builder;
}
