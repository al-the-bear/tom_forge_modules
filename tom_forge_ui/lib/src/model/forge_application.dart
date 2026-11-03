import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../components/forge_editor.dart';
import '../components/forge_view.dart';

/// Configuration for a side/bottom panel.
class PanelConfig {
  final double initialSize;
  final List<PanelTabConfig> tabs;

  const PanelConfig({
    this.initialSize = 250,
    this.tabs = const [],
  });
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

  const MiddlePanelConfig({
    this.flex = 1.0,
    this.tabs = const [],
  });
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

/// Makes the applications of one [kind]: when one is opened at run time
/// ([ForgeApplicationRegistry.open]) and when the shell recreates the ones
/// that were open at the last exit. A module registers its factories with
/// [ForgeApplicationRegistry.registerFactory] when it is activated.
abstract class ForgeApplicationFactory {
  /// The kind this factory makes, unique among the registered factories
  /// (e.g. `quest`).
  String get kind;

  /// The application with [id], [title] and [payload]; its [ForgeApplication.kind]
  /// must be [kind] and its [ForgeApplication.payload] what it needs to be
  /// recreated.
  ForgeApplication create({
    required String id,
    required String title,
    required Map<String, Object?> payload,
  });
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

  /// Removes the open application [id] and its stored state. Removing the
  /// active one activates the one active before it; the last application
  /// cannot be removed.
  void remove(String id);

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
