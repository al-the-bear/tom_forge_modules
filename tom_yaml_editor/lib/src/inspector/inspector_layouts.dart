import 'package:flutter/material.dart';

import '../yaml_editor_controller.dart';
import '../yaml_editor_theme.dart';
import 'subtree_inspector.dart';

/// Side panel layout: tree view and subtree inspector side by side
/// with a resizable horizontal divider.
///
/// ```dart
/// InspectorSidePanel(
///   controller: controller,
///   path: ['prompt', 'meta-data'],
///   theme: YamlEditorTheme.dark(),
///   treeView: myTreeWidget,
///   onClose: () { /* close inspector */ },
/// )
/// ```
class InspectorSidePanel extends StatefulWidget {
  /// The YAML editor controller.
  final YamlEditorController controller;

  /// Path to the inspected subtree.
  final List<String> path;

  /// Visual theme.
  final YamlEditorTheme theme;

  /// The tree view widget to display in the left panel.
  final Widget treeView;

  /// Called when the inspector is closed (apply or cancel).
  final VoidCallback? onClose;

  /// Whether the inspector is read-only.
  final bool readOnly;

  /// Initial fraction of width allocated to the tree view (0.0–1.0).
  final double initialTreeFraction;

  /// Minimum width for either panel in pixels.
  final double minPanelWidth;

  const InspectorSidePanel({
    super.key,
    required this.controller,
    required this.path,
    required this.treeView,
    this.theme = const YamlEditorTheme(),
    this.onClose,
    this.readOnly = false,
    this.initialTreeFraction = 0.5,
    this.minPanelWidth = 200,
  });

  @override
  State<InspectorSidePanel> createState() => _InspectorSidePanelState();
}

class _InspectorSidePanelState extends State<InspectorSidePanel> {
  late double _treeFraction;

  @override
  void initState() {
    super.initState();
    _treeFraction = widget.initialTreeFraction;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var totalWidth = constraints.maxWidth;
        var dividerWidth = 8.0;
        var availableWidth = totalWidth - dividerWidth;

        // Clamp tree fraction to respect minimum panel widths
        var minFraction = widget.minPanelWidth / availableWidth;
        var maxFraction = 1.0 - minFraction;
        var clampedFraction = _treeFraction.clamp(minFraction, maxFraction);

        var treeWidth = availableWidth * clampedFraction;
        var inspectorWidth = availableWidth * (1.0 - clampedFraction);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tree view
            SizedBox(
              width: treeWidth,
              child: widget.treeView,
            ),

            // Resizable divider
            _ResizableDivider(
              width: dividerWidth,
              isVertical: true,
              color: widget.theme.colors.separatorColor.withAlpha(80),
              hoverColor: widget.theme.structureColors.addButton,
              onDrag: (delta) {
                setState(() {
                  _treeFraction += delta / availableWidth;
                  _treeFraction = _treeFraction.clamp(minFraction, maxFraction);
                });
              },
            ),

            // Inspector
            SizedBox(
              width: inspectorWidth,
              child: SubtreeInspector(
                controller: widget.controller,
                path: widget.path,
                theme: widget.theme,
                readOnly: widget.readOnly,
                onApply: widget.onClose,
                onCancel: widget.onClose,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bottom sheet layout: tree view on top and subtree inspector on bottom
/// with a resizable vertical divider.
///
/// ```dart
/// InspectorBottomSheet(
///   controller: controller,
///   path: ['prompt', 'meta-data'],
///   theme: YamlEditorTheme.dark(),
///   treeView: myTreeWidget,
///   onClose: () { /* close inspector */ },
/// )
/// ```
class InspectorBottomSheet extends StatefulWidget {
  /// The YAML editor controller.
  final YamlEditorController controller;

  /// Path to the inspected subtree.
  final List<String> path;

  /// Visual theme.
  final YamlEditorTheme theme;

  /// The tree view widget to display in the top panel.
  final Widget treeView;

  /// Called when the inspector is closed (apply or cancel).
  final VoidCallback? onClose;

  /// Whether the inspector is read-only.
  final bool readOnly;

  /// Initial fraction of height allocated to the tree view (0.0–1.0).
  final double initialTreeFraction;

  /// Minimum height for either panel in pixels.
  final double minPanelHeight;

  const InspectorBottomSheet({
    super.key,
    required this.controller,
    required this.path,
    required this.treeView,
    this.theme = const YamlEditorTheme(),
    this.onClose,
    this.readOnly = false,
    this.initialTreeFraction = 0.6,
    this.minPanelHeight = 150,
  });

  @override
  State<InspectorBottomSheet> createState() => _InspectorBottomSheetState();
}

class _InspectorBottomSheetState extends State<InspectorBottomSheet> {
  late double _treeFraction;

  @override
  void initState() {
    super.initState();
    _treeFraction = widget.initialTreeFraction;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var totalHeight = constraints.maxHeight;
        var dividerHeight = 8.0;
        var availableHeight = totalHeight - dividerHeight;

        // Clamp tree fraction to respect minimum panel heights
        var minFraction = widget.minPanelHeight / availableHeight;
        var maxFraction = 1.0 - minFraction;
        var clampedFraction = _treeFraction.clamp(minFraction, maxFraction);

        var treeHeight = availableHeight * clampedFraction;
        var inspectorHeight = availableHeight * (1.0 - clampedFraction);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tree view
            SizedBox(
              height: treeHeight,
              child: widget.treeView,
            ),

            // Resizable divider
            _ResizableDivider(
              width: dividerHeight,
              isVertical: false,
              color: widget.theme.colors.separatorColor.withAlpha(80),
              hoverColor: widget.theme.structureColors.addButton,
              onDrag: (delta) {
                setState(() {
                  _treeFraction += delta / availableHeight;
                  _treeFraction = _treeFraction.clamp(minFraction, maxFraction);
                });
              },
            ),

            // Inspector
            SizedBox(
              height: inspectorHeight,
              child: SubtreeInspector(
                controller: widget.controller,
                path: widget.path,
                theme: widget.theme,
                readOnly: widget.readOnly,
                onApply: widget.onClose,
                onCancel: widget.onClose,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A resizable divider that can be dragged to resize adjacent panels.
///
/// Shared between side panel (vertical divider) and bottom sheet
/// (horizontal divider) modes.
class _ResizableDivider extends StatefulWidget {
  final double width;
  final bool isVertical;
  final Color color;
  final Color hoverColor;
  final ValueChanged<double> onDrag;

  const _ResizableDivider({
    required this.width,
    required this.isVertical,
    required this.color,
    required this.hoverColor,
    required this.onDrag,
  });

  @override
  State<_ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<_ResizableDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    var isActive = _isHovered || _isDragging;

    return MouseRegion(
      cursor: widget.isVertical
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanEnd: (_) => setState(() => _isDragging = false),
        onPanUpdate: (details) {
          widget.onDrag(
            widget.isVertical ? details.delta.dx : details.delta.dy,
          );
        },
        child: Container(
          width: widget.isVertical ? widget.width : null,
          height: widget.isVertical ? null : widget.width,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: widget.isVertical ? 2 : null,
              height: widget.isVertical ? null : 2,
              color: isActive ? widget.hoverColor : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}
