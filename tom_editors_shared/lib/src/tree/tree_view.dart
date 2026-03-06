import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tree_controller.dart';
import 'tree_node.dart';
import 'tree_theme.dart';

/// Signature for building the content of a single tree node row.
///
/// The builder receives the node, whether it's selected, and a callback
/// to toggle expand/collapse.
typedef TreeNodeBuilder<T> = Widget Function(
  BuildContext context,
  TreeNode<T> node,
  bool isSelected,
);

/// A generic tree view widget that renders [TreeNode] hierarchies.
///
/// Supports:
/// - Expand/collapse with animated toggle
/// - Keyboard navigation (arrow keys, Enter to toggle, Space to select)
/// - Custom node rendering via [nodeBuilder]
/// - Tree line guides
/// - Selection and focus highlighting
///
/// ```dart
/// TreeView<YamlNodeData>(
///   controller: treeController,
///   nodeBuilder: (context, node, isSelected) {
///     return Text(node.data.label);
///   },
/// )
/// ```
class TreeView<T> extends StatefulWidget {
  /// Controller managing expand/collapse, selection, and focus.
  final TreeController<T> controller;

  /// Builder for individual node content.
  final TreeNodeBuilder<T> nodeBuilder;

  /// Visual theme.
  final TreeTheme theme;

  /// Callback when a node is tapped.
  final ValueChanged<TreeNode<T>>? onNodeTap;

  /// Callback when a node is double-tapped.
  final ValueChanged<TreeNode<T>>? onNodeDoubleTap;

  /// Whether keyboard navigation is enabled.
  final bool enableKeyboardNavigation;

  const TreeView({
    super.key,
    required this.controller,
    required this.nodeBuilder,
    this.theme = const TreeTheme(),
    this.onNodeTap,
    this.onNodeDoubleTap,
    this.enableKeyboardNavigation = true,
  });

  @override
  State<TreeView<T>> createState() => _TreeViewState<T>();
}

class _TreeViewState<T> extends State<TreeView<T>> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String? _hoveredId;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(TreeView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Defer setState to avoid calling it while the widget tree is locked
    // (e.g. during element unmount when a gesture recognizer fires select).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    var visible = widget.controller.visibleNodes;
    var guides = widget.theme.showTreeLines ? _computeGuides(visible) : null;

    Widget list = ListView.builder(
      controller: _scrollController,
      itemCount: visible.length,
      itemExtent: widget.theme.rowHeight,
      shrinkWrap: widget.theme.rowHeight == null,
      itemBuilder: (context, index) {
        return _buildRow(visible[index], guides?[index] ?? const []);
      },
    );

    if (widget.enableKeyboardNavigation) {
      list = KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: list,
      );
    }

    return list;
  }

  Widget _buildRow(TreeNode<T> node, List<_GuideType> guides) {
    var isSelected = node.id == widget.controller.selectedId;
    var isFocused = node.id == widget.controller.focusedId;
    var isHovered = node.id == _hoveredId;

    Color? bgColor;
    if (isSelected) {
      bgColor = widget.theme.selectionColor;
    } else if (isFocused) {
      bgColor = widget.theme.focusColor;
    } else if (isHovered) {
      bgColor = widget.theme.hoverColor;
    }

    var indentPx = node.depth * widget.theme.indentWidth;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredId = node.id),
      onExit: (_) => setState(() => _hoveredId = null),
      child: GestureDetector(
        onTap: () {
          widget.controller.select(node.id);
          widget.controller.focus(node.id);
          widget.onNodeTap?.call(node);
        },
        onDoubleTap: () {
          widget.onNodeDoubleTap?.call(node);
        },
        child: Container(
          height: widget.theme.rowHeight,
          color: bgColor,
          child: Stack(
            children: [
              // Indent guide lines (painted behind row content)
              if (guides.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: indentPx,
                  child: CustomPaint(
                    painter: _IndentGuidePainter(
                      guides: guides,
                      indentWidth: widget.theme.indentWidth,
                      color: widget.theme.treeLineColor,
                    ),
                  ),
                ),

              // Row content
              Row(
                children: [
                  SizedBox(width: indentPx),

                  // Expand/collapse toggle
                  if (!node.isLeaf)
                    GestureDetector(
                      onTap: () => widget.controller.toggle(node.id),
                      child: Icon(
                        node.isExpanded
                            ? widget.theme.expandedIcon
                            : widget.theme.collapsedIcon,
                        size: widget.theme.toggleIconSize,
                        color: widget.theme.treeLineColor,
                      ),
                    )
                  else
                    SizedBox(width: widget.theme.toggleIconSize),

                  const SizedBox(width: 4),

                  // Node content
                  Expanded(
                    child: widget.nodeBuilder(context, node, isSelected),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        widget.controller.focusNext();
      case LogicalKeyboardKey.arrowUp:
        widget.controller.focusPrevious();
      case LogicalKeyboardKey.arrowRight:
        var id = widget.controller.focusedId;
        if (id != null) widget.controller.expand(id);
      case LogicalKeyboardKey.arrowLeft:
        var id = widget.controller.focusedId;
        if (id != null) widget.controller.collapse(id);
      case LogicalKeyboardKey.enter:
        var id = widget.controller.focusedId;
        if (id != null) widget.controller.toggle(id);
      case LogicalKeyboardKey.space:
        var id = widget.controller.focusedId;
        if (id != null) widget.controller.select(id);
    }
  }

  /// Compute indent guide types for every (row, level) pair.
  ///
  /// For each visible node at depth D the result contains a list of length D
  /// describing the guide type at each level 0 … D-1.
  ///
  /// Uses a bottom-to-top scan per level — O(N × maxDepth).
  List<List<_GuideType>> _computeGuides(List<TreeNode<T>> visible) {
    if (visible.isEmpty) return [];

    var maxDepth = 0;
    for (var node in visible) {
      if (node.depth > maxDepth) maxDepth = node.depth;
    }

    var result = List.generate(
      visible.length,
      (i) => List<_GuideType>.filled(visible[i].depth, _GuideType.none),
    );

    for (var level = 0; level < maxDepth; level++) {
      var hasMore = false;
      for (var i = visible.length - 1; i >= 0; i--) {
        if (visible[i].depth <= level) {
          hasMore = false;
        } else if (level < result[i].length) {
          result[i][level] =
              hasMore ? _GuideType.continues : _GuideType.lastChild;
          hasMore = true;
        }
      }
    }

    return result;
  }
}

// ---------------------------------------------------------------------------
// Indent guide painting
// ---------------------------------------------------------------------------

/// Guide line type at a given depth level for one row.
enum _GuideType {
  /// No guide line at this level.
  none,

  /// Full vertical line — more descendants follow at this level.
  continues,

  /// Half vertical (top→centre) — last descendant at this level.
  lastChild,
}

/// Paints VS Code-style indent guide lines for a single tree row.
///
/// One thin vertical line per nesting level. At the deepest level a
/// horizontal branch extends toward the node's toggle / content.
class _IndentGuidePainter extends CustomPainter {
  final List<_GuideType> guides;
  final double indentWidth;
  final Color color;

  _IndentGuidePainter({
    required this.guides,
    required this.indentWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    for (var i = 0; i < guides.length; i++) {
      var guide = guides[i];
      if (guide == _GuideType.none) continue;

      var x = (i + 0.5) * indentWidth;
      var centerY = size.height / 2;
      var isLast = (i == guides.length - 1);

      switch (guide) {
        case _GuideType.continues:
          // │ — full vertical line
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
          if (isLast) {
            // ├ — T-branch toward the node
            canvas.drawLine(
                Offset(x, centerY), Offset(size.width, centerY), paint);
          }
        case _GuideType.lastChild:
          // top → centre
          canvas.drawLine(Offset(x, 0), Offset(x, centerY), paint);
          if (isLast) {
            // └ — L-branch toward the node
            canvas.drawLine(
                Offset(x, centerY), Offset(size.width, centerY), paint);
          }
        case _GuideType.none:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(_IndentGuidePainter oldDelegate) {
    if (oldDelegate.indentWidth != indentWidth || oldDelegate.color != color) {
      return true;
    }
    if (oldDelegate.guides.length != guides.length) return true;
    for (var i = 0; i < guides.length; i++) {
      if (oldDelegate.guides[i] != guides[i]) return true;
    }
    return false;
  }
}
