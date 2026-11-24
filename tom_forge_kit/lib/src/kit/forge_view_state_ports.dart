import 'package:flutter/foundation.dart' show ValueListenable;

/// A state that keeps the file explorer's selection and hovered row, so the
/// application can reveal a file in the explorer (`revealInExplorer`) and
/// act on what is selected.
///
/// The panel shell's `DefaultSystemState` is one; a view asks
/// `state is ForgeExplorerSelection` and keeps its selection to itself
/// otherwise.
abstract interface class ForgeExplorerSelection {
  /// The selected items, the first the one to reveal.
  List<Uri> get selectedExplorerItems;

  /// The selected items, notifying when the application or the explorer
  /// changes them.
  ValueListenable<List<Uri>> get selectedExplorerItemsListenable;

  /// Selects [items].
  void setSelectedExplorerItems(List<Uri> items);

  /// Records the row under the pointer, null when none.
  void setHoveredExplorerItem(Uri? item);
}

/// A state that records the Search view's query, so the application knows
/// what is searched for.
///
/// The panel shell's `DefaultSystemState` is one; the Search view asks
/// `state is ForgeSearchQueryState`.
abstract interface class ForgeSearchQueryState {
  /// Records the query typed into the Search view.
  void setSearchQuery(String query);

  /// Records whether a search is on (a query is typed).
  void setSearchActive(bool active);
}

/// A state that knows the workspace folder the application works in.
///
/// The panel shell's `DefaultSystemState` is one; a view that shows the
/// workspace (the file explorer, paths relative to it in the Search view)
/// takes its folder from it unless it is given one.
abstract interface class ForgeWorkspaceRoot {
  /// The workspace folder, as a file path.
  String get workspaceRootPath;
}
