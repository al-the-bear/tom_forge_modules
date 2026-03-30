import '../components/forge_editor.dart';
import '../components/forge_view.dart';

/// Position within a drop zone overlay where the editor can be dropped.
enum DropPosition {
  /// Add to the existing tab bar (center of panel).
  center,

  /// Split and create a new panel to the left.
  left,

  /// Split and create a new panel to the right.
  right,
}

/// Data transferred during editor tab drag operations.
///
/// Carries the editor being dragged and its source panel index
/// so drop targets can determine valid operations.
class TabDragData {
  final ForgeEditor editor;
  final int sourcePanelIndex;

  const TabDragData({required this.editor, required this.sourcePanelIndex});
}

/// Data transferred during accordeon section reorder drags.
///
/// Carries the section view and its source index within the tab.
class SectionDragData {
  final ForgeView section;
  final int sourceIndex;

  const SectionDragData({required this.section, required this.sourceIndex});
}

/// Identifies which auxiliary panel area a tab belongs to.
enum PanelArea {
  left,
  right,
  bottom,
}

/// Data transferred when dragging an entire panel tab between areas.
///
/// Used for moving complete tabs (with all their sections) between
/// left, right, and bottom panel areas.
class PanelTabDragData {
  /// Display title of the tab being dragged.
  final String title;

  /// Icon of the tab.
  final int tabIndex;

  /// Which panel area this tab is being dragged from.
  final PanelArea sourceArea;

  const PanelTabDragData({
    required this.title,
    required this.tabIndex,
    required this.sourceArea,
  });
}
