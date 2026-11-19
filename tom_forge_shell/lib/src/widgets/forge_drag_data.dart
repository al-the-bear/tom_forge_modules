import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../components/forge_component.dart';
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

/// Identifies which auxiliary panel area a tab belongs to.
enum PanelArea {
  left,
  right,
  bottom,
}

/// Base class for all forge layout drag data.
///
/// Using a sealed class allows drop targets to accept any drag data
/// from the forge layout system and pattern-match on the specific
/// type to determine the appropriate handling.
sealed class ForgeDragData {
  /// The component being dragged (editor or view).
  ForgeComponent get component;

  const ForgeDragData();
}

/// Data transferred during editor tab drag operations.
///
/// Carries the editor being dragged and its source panel index
/// so drop targets can determine valid operations.
class TabDragData extends ForgeDragData {
  final ForgeEditor editor;
  final int sourcePanelIndex;

  const TabDragData({required this.editor, required this.sourcePanelIndex});

  @override
  ForgeComponent get component => editor;
}

/// Data transferred during accordeon section drag operations.
///
/// Carries the section view, its source index within the tab,
/// and optional source panel/tab info for cross-panel moves.
class SectionDragData extends ForgeDragData {
  final ForgeView section;
  final int sourceIndex;

  /// Which panel area this section came from (for cross-panel moves).
  final PanelArea? sourceArea;

  /// Tab index within the source panel.
  final int? sourceTabIndex;

  /// Optional callback invoked when this section is removed from its source.
  /// Used by components that manage their own internal lists (e.g. terminals)
  /// instead of relying on the panel sections list.
  final VoidCallback? onRemoved;

  const SectionDragData({
    required this.section,
    required this.sourceIndex,
    this.sourceArea,
    this.sourceTabIndex,
    this.onRemoved,
  });

  @override
  ForgeComponent get component => section;
}

/// Data transferred when dragging an entire panel tab between areas.
///
/// Used for moving complete tabs (with all their sections) between
/// left, right, and bottom panel areas.
class PanelTabDragData extends ForgeDragData {
  /// Display title of the tab being dragged.
  final String title;

  /// Tab index in the source panel.
  final int tabIndex;

  /// Which panel area this tab is being dragged from.
  final PanelArea sourceArea;

  /// Sections contained in this tab (for reconstruction at target).
  final List<ForgeView> sections;

  const PanelTabDragData({
    required this.title,
    required this.tabIndex,
    required this.sourceArea,
    this.sections = const [],
  });

  @override
  ForgeComponent get component =>
      sections.isNotEmpty ? sections.first : _PlaceholderComponent();
}

/// Placeholder for PanelTabDragData when sections list is empty.
class _PlaceholderComponent extends ForgeView {
  @override
  IconData get icon => throw UnimplementedError();
  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();
  @override
  ValueListenable<String> get title => throw UnimplementedError();
  @override
  ValueListenable<String?> get titleExtension => throw UnimplementedError();
  @override
  Widget buildMain(BuildContext context) => throw UnimplementedError();
  @override
  Widget buildCopy(BuildContext context) => throw UnimplementedError();
}
