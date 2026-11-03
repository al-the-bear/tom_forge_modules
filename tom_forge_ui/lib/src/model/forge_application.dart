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

/// An application context within the shell.
class ForgeApplication {
  final String title;
  final IconData? icon;
  final ApplicationLayout layout;

  /// Optional workspace folder name for display in the application switcher.
  final String? workspaceFolder;
  bool isActive;

  ForgeApplication({
    required this.title,
    this.icon,
    this.layout = const PanelLayout(),
    this.workspaceFolder,
    this.isActive = false,
  });

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
