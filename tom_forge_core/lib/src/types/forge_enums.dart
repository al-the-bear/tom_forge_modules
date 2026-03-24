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

/// Types of file system changes.
enum FileChangeType { created, modified, deleted }

/// Reasons for a file save.
enum SaveReason { manual, autoSave, focusLoss }

/// Locations for progress indicators.
enum ForgeProgressLocation { statusBar, overlay }

/// Top-level menu locations.
enum ForgeMenuLocation { file, edit, view, go, modules, help }
