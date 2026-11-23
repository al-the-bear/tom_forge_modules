import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuContribution;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../actions/forge_shortcut_menu.dart';
import '../components/forge_editor.dart';
import '../components/forge_editor_choice.dart';
import '../components/forge_view.dart';
import '../kit/forge_kit_api.dart';
import '../model/forge_kit_status_item.dart';

/// The contract of a module: what it contributes to the application it runs
/// in — editors, views, actions, shortcuts, context-menu entries — free of
/// any layout.
///
/// A module is activated with the [ForgeKitApi] of its host and deactivated
/// when the host shuts down. Where its editors and views appear is the
/// application's decision, never the module's. What an application may offer
/// beyond this contract (a settings section, status items, ...) a module
/// hands over as [ForgeModuleExtra]s, which the application reads as it
/// decides (see [ForgeModuleExtras]).
abstract class ForgeKitModule {
  /// Display name for the module.
  String get displayName;

  /// Called when the module is activated, with the API of its host.
  ///
  /// A host narrows the type (the panel shell passes its own API, which is a
  /// [ForgeKitApi]); a module written against the kit takes [ForgeKitApi].
  void activate(covariant ForgeKitApi api);

  /// Called when the module is deactivated (shutdown).
  void deactivate();

  /// All editors this module provides.
  List<ForgeEditor> get editors;

  /// All views this module provides.
  List<ForgeView> get views;

  /// Actions this module contributes to menus and the command palette.
  List<ForgeAction> get actions;

  /// Shortcut bindings this module contributes.
  List<ForgeShortcutBinding> get shortcuts;

  /// Context-menu contributions: where this module's actions are offered as
  /// menu entries, keyed by the target kind they apply at.
  ///
  /// Each contribution names one of this module's [actions] by id, says
  /// whether it applies at a given target and why it cannot run there; the
  /// host resolves them into entries (`ForgeContextMenuController`).
  List<ForgeContextMenuContribution> get contextMenus => [];

  /// Custom shortcut menus activated by `Shift+Cmd/Ctrl+<key>`.
  List<ForgeShortcutMenu> get shortcutMenus => [];

  /// Opens [uri] itself, when this module owns documents of that kind, and
  /// answers whether it did.
  ///
  /// The host asks every module **before** it reads a file as text
  /// ([ForgeKitApi.openFile]): a document that is not one string — a
  /// directory bundle, an encrypted container, an archive — cannot survive
  /// the text read. A module that opens it creates its own editor and hands it
  /// to the host's editor host. The default claims nothing.
  bool openUri(Uri uri) => false;

  /// The editors this module has for [uri], as an **Open With** choice
  /// offers them. The default offers none.
  List<ForgeKitEditorChoice> editorChoicesFor(Uri uri) => const [];
}

/// One contribution of a module beyond the [ForgeKitModule] contract: a
/// [kind] that says what it is and the [value] itself.
///
/// The kit defines one kind, [ForgeKitStatusItemsExtra] (status items as
/// data, which name no place); an application defines the others it reads
/// (the panel shell's settings sections and external tools are extras of its
/// own kinds) and ignores the kinds it does not know. Open for subclassing,
/// so an application can give its kinds a typed value.
class ForgeModuleExtra {
  const ForgeModuleExtra({required this.kind, required this.value});

  /// What the extra is, e.g. `forge.statusItems`.
  final String kind;

  /// The extra itself; its type is the kind's.
  final Object? value;

  @override
  String toString() => 'ForgeModuleExtra($kind)';
}

/// A module's status items as data ([ForgeKitStatusItem]s), the one extra
/// kind the kit defines: an application with a status bar shows the active
/// ones as it decides (the panel shell beside its own modules' items).
class ForgeKitStatusItemsExtra extends ForgeModuleExtra {
  const ForgeKitStatusItemsExtra(List<ForgeKitStatusItem> items)
    : super(kind: kindId, value: items);

  /// The kind of this extra.
  static const kindId = 'forge.kit.statusItems';

  /// The items.
  List<ForgeKitStatusItem> get items => value as List<ForgeKitStatusItem>;
}

/// A module that carries [ForgeModuleExtra]s of its own.
///
/// It declares them as [ownExtras]; readers ask `module.extras`
/// ([ForgeKitModuleExtras]), which adds what the host's resolvers find, so
/// the answer is the same whatever the reader's static type.
abstract interface class ForgeModuleExtrasProvider {
  /// The module's own extras, in the order it declares them.
  List<ForgeModuleExtra> get ownExtras;
}

/// Finds the [ForgeModuleExtra]s of a module.
///
/// A module carries extras by implementing [ForgeModuleExtrasProvider]. A
/// host whose module contract adds members of its own (the panel shell's
/// `ForgeModule`) registers a resolver that wraps them as extras, so a reader
/// typed on [ForgeKitModule] sees them as well: [of] answers the provider's
/// extras followed by every resolver's.
abstract final class ForgeModuleExtras {
  static final List<List<ForgeModuleExtra>? Function(ForgeKitModule module)>
  _resolvers = [];

  /// Adds [resolver] once (adding the same function again does nothing).
  static void addResolver(
    List<ForgeModuleExtra>? Function(ForgeKitModule module) resolver,
  ) {
    if (!_resolvers.contains(resolver)) _resolvers.add(resolver);
  }

  /// Removes a resolver added with [addResolver].
  static void removeResolver(
    List<ForgeModuleExtra>? Function(ForgeKitModule module) resolver,
  ) {
    _resolvers.remove(resolver);
  }

  /// The extras of [module]; empty when it has none.
  static List<ForgeModuleExtra> of(ForgeKitModule module) {
    final own = module is ForgeModuleExtrasProvider
        ? (module as ForgeModuleExtrasProvider).ownExtras
        : const <ForgeModuleExtra>[];
    final resolved = [for (final resolver in _resolvers) ...?resolver(module)];
    if (resolved.isEmpty) return own;
    return [...own, ...resolved];
  }
}

/// `module.extras` on any [ForgeKitModule] (the CMP-26 hook): the module's
/// [ForgeModuleExtra]s, as [ForgeModuleExtras.of] finds them.
extension ForgeKitModuleExtras on ForgeKitModule {
  /// The module's extras; empty when it has none.
  List<ForgeModuleExtra> get extras => ForgeModuleExtras.of(this);
}
