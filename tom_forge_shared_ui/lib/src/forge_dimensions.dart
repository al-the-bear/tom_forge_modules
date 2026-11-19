/// Dimension constants for shell layout.
class ForgeDimensions {
  // Panels – no upper limits; users may drag to any size.
  static const double panelMinSize = 50;
  static const double leftPanelDefaultWidth = 280;
  static const double rightPanelDefaultWidth = 280;
  static const double bottomPanelDefaultHeight = 200;
  static const double middlePanelMinWidth = 200;

  /// Minimum width at which panel content stops shrinking and gets clipped.
  static const double panelContentMinWidth = 400;

  // Fixed elements
  static const double titleBarHeight = 48;
  static const double menuBarHeight = 32;
  static const double statusBarHeight = 24;
  static const double tabBarHeight = 36;
  static const double sectionHeaderHeight = 32;
  static const double sideTabBarCollapsed = 48;
  static const double sideTabBarExpanded = 200;

  // Interactive
  static const double dividerHitTarget = 14;
  static const double dividerVisual = 2;

  // Icons
  static const double iconTab = 20;
  static const double iconToolbar = 18;
}
