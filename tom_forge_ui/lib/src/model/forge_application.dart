import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuContribution;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../actions/status_bar_item.dart';
import '../components/forge_editor.dart';
import '../components/forge_view.dart';

/// Configuration for a side/bottom panel.
class PanelConfig {
  final double initialSize;
  final List<PanelTabConfig> tabs;

  const PanelConfig({this.initialSize = 250, this.tabs = const []});
}

/// A tab within a panel.
class PanelTabConfig {
  final String title;
  final IconData icon;
  final List<ForgeView> sections;

  const PanelTabConfig({
    required this.title,
    required this.icon,
    this.sections = const [],
  });
}

/// Configuration for a middle (editor) panel.
class MiddlePanelConfig {
  final double flex;
  final List<MiddleTabConfig> tabs;

  const MiddlePanelConfig({this.flex = 1.0, this.tabs = const []});
}

/// A tab in a middle panel pointing to an editor.
class MiddleTabConfig {
  final ForgeEditor editor;
  final Uri? uri;

  const MiddleTabConfig({required this.editor, this.uri});
}

/// How an application fills the shell's content area.
///
/// The shell keeps its title bar — with the application switcher and the
/// command search — and its status bar for every application; the layout
/// decides what lies between them.
sealed class ApplicationLayout {
  const ApplicationLayout();
}

/// The panel shell: side, bottom and middle (editor) panels.
class PanelLayout extends ApplicationLayout {
  final PanelConfig leftPanel;
  final PanelConfig rightPanel;
  final PanelConfig bottomPanel;
  final List<MiddlePanelConfig> middlePanels;

  const PanelLayout({
    this.leftPanel = const PanelConfig(),
    this.rightPanel = const PanelConfig(),
    this.bottomPanel = const PanelConfig(),
    this.middlePanels = const [],
  });
}

/// One view filling the content area: no side, bottom or middle panels and
/// no in-window menu bar.
///
/// The view runs in a focus scope of its own, which takes the focus when the
/// application becomes active and gets it back when the application is
/// activated again. A key the view does not handle bubbles up to the shell,
/// so the shell's global shortcuts and command palette stay reachable. The
/// shell keeps the view in the widget tree while another application is
/// shown, so switching away and back keeps its state.
class FullScreenLayout extends ApplicationLayout {
  /// The view filling the content area.
  final ForgeView view;

  const FullScreenLayout({required this.view});
}

/// An application within the shell: a title, an icon and a layout, switched
/// to through the application switcher.
///
/// Applications live in the shell's [ForgeApplicationRegistry]
/// (`ForgeShellApi.applications`) and come and go at run time. A **static**
/// application ([kind] null) is added by its module or host on every start. A
/// **restorable** one is made by the [ForgeApplicationFactory] of its [kind]
/// from its [id], [title] and [payload]; the shell writes the restorable
/// applications that are open at exit and has their factories recreate them
/// at the next start. Several applications of one kind may be open at once:
/// [id] tells them apart.
class ForgeApplication {
  /// Stable identity: per-application state and persistence are keyed by it,
  /// so it must not change across starts. Unique within the registry.
  final String id;

  final IconData? icon;
  final ApplicationLayout layout;

  /// Optional workspace folder name for display in the application switcher.
  final String? workspaceFolder;

  /// The [ForgeApplicationFactory.kind] that can recreate this application,
  /// or null for a static application.
  final String? kind;

  /// What [kind]'s factory needs to recreate this application — a small
  /// JSON-encodable map (for a quest application, the quest id).
  final Map<String, Object?> payload;

  /// What this application adds to the shell while it is the active one:
  /// actions, shortcuts, status-bar items and context-menu entries.
  final ForgeApplicationContributions contributions;

  /// Its lifecycle: the hooks the registry calls as the application is
  /// created, activated, deactivated, closed, and what it reports while it
  /// runs. [ForgeApplicationLifecycle.none] when it has nothing to say.
  final ForgeApplicationLifecycle lifecycle;

  /// Whether this is the active application; maintained by the registry.
  bool isActive;

  String _title;

  ForgeApplication({
    required this.id,
    required String title,
    this.icon,
    this.layout = const PanelLayout(),
    this.workspaceFolder,
    this.kind,
    Map<String, Object?> payload = const {},
    this.lifecycle = ForgeApplicationLifecycle.none,
    this.contributions = const ForgeApplicationContributions(),
    this.isActive = false,
  }) : _title = title,
       payload = Map.unmodifiable(payload);

  /// Display title. Changed through [ForgeApplicationRegistry.rename].
  String get title => _title;

  /// Sets [title]. Called by the registry, which also tells its listeners;
  /// use [ForgeApplicationRegistry.rename] instead.
  void renameTo(String title) => _title = title;

  /// Whether [kind]'s factory can recreate this application at the next start.
  bool get isRestorable => kind != null;

  /// The panels this application declares: its [PanelLayout], or none for a
  /// [FullScreenLayout].
  PanelLayout get panelLayout => switch (layout) {
    final PanelLayout panels => panels,
    FullScreenLayout() => const PanelLayout(),
  };

  /// Whether this application fills the content area with one view.
  bool get isFullScreen => layout is FullScreenLayout;

  /// Display text for the application switcher.
  ///
  /// If [workspaceFolder] is set, returns `<title> - <workspaceFolder>`.
  /// Otherwise returns just [title].
  String get displayTitle =>
      workspaceFolder != null ? '$title - $workspaceFolder' : title;
}

/// What an application does as it comes and goes, and what it reports while
/// it runs. The registry calls the hooks in this order: [created] when the
/// application is added (opened, restored or added statically), [activated]
/// and [deactivated] as it is switched to and away from, [closing] when it is
/// asked to close, and — once closing is allowed — [deactivated] if it was
/// active, then [closed] after it has left the registry.
///
/// An application with work that runs while it is not shown — a quest
/// application's queue and timers — says so through [hasBackgroundWork]: its
/// state is then never evicted from memory, and it is closed only after its
/// [closing] veto is answered. [busy] is what the application switcher shows
/// as its badge.
///
/// Every hook has a default that does nothing, so a lifecycle overrides only
/// what it needs.
class ForgeApplicationLifecycle {
  const ForgeApplicationLifecycle();

  /// The lifecycle of an application with nothing to report.
  static const ForgeApplicationLifecycle none = ForgeApplicationLifecycle();

  /// The application was added to the registry.
  void created(ForgeApplication application) {}

  /// The application became the active one.
  void activated(ForgeApplication application) {}

  /// Another application became active, or this one is closing.
  void deactivated(ForgeApplication application) {}

  /// The application is asked to close. Null lets it close; a reason vetoes
  /// it — the shell then asks the user, with the reason, whether to close it
  /// anyway (e.g. "The queue is still sending three prompts").
  Future<String?> closing(ForgeApplication application) async => null;

  /// The application has left the registry; release what it holds.
  void closed(ForgeApplication application) {}

  /// Whether the application has work running while it is not shown. While
  /// true, its state is never evicted from memory.
  ValueListenable<bool> get hasBackgroundWork => const _Fixed(false);

  /// What the application switcher shows as this application's badge (e.g.
  /// "Queue running"), or null for none.
  ValueListenable<String?> get busy => const _Fixed<String?>(null);
}

/// A value that never changes.
class _Fixed<T> implements ValueListenable<T> {
  const _Fixed(this.value);

  @override
  final T value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Asks the user whether to close [application] although its lifecycle
/// vetoed with [reason]; true closes it.
typedef ForgeCloseConfirmer =
    Future<bool> Function(ForgeApplication application, String reason);

/// What one open application has against quitting now: its lifecycle's
/// [ForgeApplicationLifecycle.closing] veto, its editors with unsaved
/// changes, or both.
@immutable
class ForgeQuitObjection {
  const ForgeQuitObjection({
    required this.application,
    this.reason,
    this.unsavedEditors = const [],
  });

  /// The application that objects.
  final ForgeApplication application;

  /// Its lifecycle's veto (e.g. "The queue is still sending three prompts"),
  /// or null when only its editors object.
  final String? reason;

  /// Its open editors with unsaved changes, in tab order.
  final List<ForgeEditor> unsavedEditors;
}

/// Asks the user whether to quit although [objections] (never empty) stand;
/// true quits.
typedef ForgeQuitConfirmer =
    Future<bool> Function(List<ForgeQuitObjection> objections);

/// What an application adds to the shell while it is the active one.
///
/// Module contributions (`ForgeModule.actions` and the rest) are there for
/// every application; these follow the active one. Two applications of one
/// kind — two quest applications — contribute the same action ids, each
/// bound to its own [ForgeApplicationContext], and the shell resolves an id
/// to the active application's: switching rebinds them, so a keystroke, a
/// menu entry or the command palette runs the action of the application on
/// show. An application action id must not also be a module action's: such
/// an action is not bound (the module keeps the id) and the collision is
/// reported as a Flutter error.
class ForgeApplicationContributions {
  /// Actions registered while the application is active.
  final List<ForgeAction> actions;

  /// Key bindings for [actions], bound while the application is active.
  final List<ForgeShortcutBinding> shortcuts;

  /// Status-bar items shown while the application is active.
  final List<StatusBarItem> statusBarItems;

  /// Context-menu entries offered while the application is active; each
  /// names one of [actions] or a module action.
  final List<ForgeContextMenuContribution> contextMenus;

  const ForgeApplicationContributions({
    this.actions = const [],
    this.shortcuts = const [],
    this.statusBarItems = const [],
    this.contextMenus = const [],
  });
}

/// The application a factory is making, as its views, editors and
/// contributions see it: what to bind to so that two applications of one kind
/// show the same views with different content.
///
/// Handed to [ForgeApplicationFactory.create]; the factory passes it to the
/// view, editor and action instances it makes for that application.
class ForgeApplicationContext {
  /// The application's id ([ForgeApplication.id]).
  final String id;

  /// The factory kind that made it.
  final String kind;

  /// What it was opened with (e.g. the quest id).
  final Map<String, Object?> payload;

  final ForgeApplicationRegistry _registry;

  ForgeApplicationContext({
    required this.id,
    required this.kind,
    required Map<String, Object?> payload,
    required ForgeApplicationRegistry registry,
  }) : payload = Map.unmodifiable(payload),
       _registry = registry;

  /// The application, once the registry holds it; null while the factory is
  /// still making it and after it closed.
  ForgeApplication? get application => _registry.byId(id);

  /// Whether the application is the active one — what a view bound to it
  /// checks before reacting to shell-wide events.
  bool get isActive => _registry.active?.id == id;

  /// The registry, notifying on every add, rename, activation and close.
  ValueListenable<List<ForgeApplication>> get registry => _registry.listenable;
}

/// Makes the applications of one [kind]: when one is opened at run time
/// ([ForgeApplicationRegistry.open]) and when the shell recreates the ones
/// that were open at the last exit. A module registers its factories with
/// [ForgeApplicationRegistry.registerFactory] when it is activated.
abstract class ForgeApplicationFactory {
  /// The kind this factory makes, unique among the registered factories
  /// (e.g. `quest`).
  String get kind;

  /// The application for [context], titled [title]: its id and payload are
  /// the context's, its [ForgeApplication.kind] is [kind], and the views,
  /// editors and contributions it lays out are made for [context].
  ForgeApplication create(ForgeApplicationContext context, String title);
}

/// The shell's applications (`ForgeShellApi.applications`): the open ones,
/// the active one, and the operations that change them at run time.
abstract class ForgeApplicationRegistry {
  /// The open applications in switcher order; notifies on every add, remove,
  /// rename and activation.
  ValueListenable<List<ForgeApplication>> get listenable;

  /// The open applications in switcher order.
  List<ForgeApplication> get all;

  /// The active application, or null before the first one is added.
  ForgeApplication? get active;

  /// The open application with [id], or null.
  ForgeApplication? byId(String id);

  /// Registers [factory] for its kind; a second factory of one kind is
  /// refused.
  void registerFactory(ForgeApplicationFactory factory);

  /// Whether a factory for [kind] is registered — so a module activated a
  /// second time on one shell registers its factory once.
  bool hasFactory(String kind);

  /// Adds [application]; the first one added becomes active, as does any
  /// added with [activate]. An id already open is refused.
  void add(ForgeApplication application, {bool activate = false});

  /// Opens a new application of [kind] with a fresh id, made by that kind's
  /// factory, and adds it; activated unless [activate] is false.
  ForgeApplication open(
    String kind, {
    required String title,
    Map<String, Object?> payload = const {},
    bool activate = true,
  });

  /// Renames the open application [id].
  void rename(String id, String title);

  /// Asks the shell before a vetoed close: set by the shell that shows the
  /// applications. Without one a veto stands.
  ForgeCloseConfirmer? confirmClose;

  /// Closes the open application [id]: asks its lifecycle ([closing]), and on
  /// a veto [confirmClose] with the reason; then removes it and its stored
  /// state, activating the application active before it when it was active,
  /// and tells its lifecycle [closed]. Answers whether it closed. The last
  /// application cannot be closed.
  Future<bool> close(String id);

  /// Asks the shell before quitting while an application objects: set by
  /// the shell that shows the applications. Without one an objection stands.
  ForgeQuitConfirmer? confirmQuit;

  /// Whether the shell may quit: asks every open application's lifecycle
  /// ([ForgeApplicationLifecycle.closing]) and collects its editors with
  /// unsaved changes, and when any objects asks [confirmQuit] with every
  /// objection at once. True when nothing objects or the user quits anyway.
  /// Closes nothing: the shell's disposal tells each application
  /// [ForgeApplicationLifecycle.closed]. A second call while one is asking
  /// answers with the first.
  Future<bool> quit();

  /// Makes the open application [id] active.
  void activate(String id);

  /// The restorable open applications and the active id, as JSON — what the
  /// shell writes at exit. Entries a previous [restore] could not recreate
  /// (their module was not loaded) are kept, so they are not lost.
  Map<String, Object?> snapshot();

  /// Recreates the applications of a [snapshot] through their factories and
  /// activates the one that was active, when it is open.
  void restore(Map<String, Object?> snapshot);
}
