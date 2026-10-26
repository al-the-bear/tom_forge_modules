/// Panel locations in the shell layout.
enum ForgePanelLocation { left, right, bottom, middle }

/// Types of layout changes.
enum LayoutChangeType {
  panelOpened,
  panelClosed,
  panelResized,
  middlePanelSplit,
  middlePanelMerged,
}

/// Locations for progress indicators.
enum ForgeProgressLocation { statusBar, overlay }

/// Top-level menu locations.
enum ForgeMenuLocation { file, edit, view, go, modules, help }
