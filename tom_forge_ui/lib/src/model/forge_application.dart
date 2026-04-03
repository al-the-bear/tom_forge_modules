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

/// Layout of an application (panels arrangement).
class ApplicationLayout {
  final PanelConfig leftPanel;
  final PanelConfig rightPanel;
  final PanelConfig bottomPanel;
  final List<MiddlePanelConfig> middlePanels;

  const ApplicationLayout({
    this.leftPanel = const PanelConfig(),
    this.rightPanel = const PanelConfig(),
    this.bottomPanel = const PanelConfig(),
    this.middlePanels = const [],
  });
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
    this.layout = const ApplicationLayout(),
    this.workspaceFolder,
    this.isActive = false,
  });

  /// Display text for the application switcher.
  ///
  /// If [workspaceFolder] is set, returns `<title> - <workspaceFolder>`.
  /// Otherwise returns just [title].
  String get displayTitle =>
      workspaceFolder != null ? '$title - $workspaceFolder' : title;
}
