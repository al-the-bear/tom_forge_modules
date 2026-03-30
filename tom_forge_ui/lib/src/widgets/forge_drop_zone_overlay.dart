import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/forge_shell_theme.dart';
import 'forge_drag_data.dart';
import 'forge_shell_scaffold.dart';

/// Callback when an editor is dropped on a zone in the overlay.
typedef DropZoneCallback = void Function(
  TabDragData data,
  DropPosition position, {
  bool isCopy,
});

/// Overlay that appears on editor panels during drag operations.
///
/// Shows directional drop zones (left, center, right) using themed
/// colors from [ForgeShellTheme]. The overlay activates only when
/// a [TabDragData] drag enters the area, with a subtle delayed
/// reveal for each zone to prevent accidental drops.
class EditorDropZoneOverlay extends StatefulWidget {
  /// The child widget (the editor panel content).
  final Widget child;

  /// Index of this panel (used to reject self-drops).
  final int panelIndex;

  /// Called when a valid drop occurs on a zone.
  final DropZoneCallback? onDrop;

  /// Whether split zones (left/right) are available.
  /// Disabled when panel count is at maximum (4).
  final bool canSplit;

  const EditorDropZoneOverlay({
    super.key,
    required this.child,
    required this.panelIndex,
    this.onDrop,
    this.canSplit = true,
  });

  @override
  State<EditorDropZoneOverlay> createState() => _EditorDropZoneOverlayState();
}

class _EditorDropZoneOverlayState extends State<EditorDropZoneOverlay> {
  DropPosition? _hoveredZone;
  bool _isDragActive = false;
  bool _zonesRevealed = false;
  Timer? _revealTimer;

  /// Delay before drop zones become visible (prevents accidental drops).
  static const _revealDelay = Duration(milliseconds: 200);

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<TabDragData>(
      onWillAcceptWithDetails: (details) {
        // Accept from any panel (including same panel for split).
        if (!_isDragActive) {
          setState(() => _isDragActive = true);
          // Start delayed reveal timer.
          _revealTimer?.cancel();
          _revealTimer = Timer(_revealDelay, () {
            if (mounted && _isDragActive) {
              setState(() => _zonesRevealed = true);
            }
          });
        }
        return true;
      },
      onLeave: (_) {
        _revealTimer?.cancel();
        setState(() {
          _isDragActive = false;
          _zonesRevealed = false;
          _hoveredZone = null;
        });
      },
      onAcceptWithDetails: (details) {
        _revealTimer?.cancel();
        final position = _hoveredZone ?? DropPosition.center;
        final isCopy =
            HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.shiftLeft) ||
            HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.shiftRight);
        setState(() {
          _isDragActive = false;
          _zonesRevealed = false;
          _hoveredZone = null;
        });
        widget.onDrop?.call(details.data, position, isCopy: isCopy);
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            widget.child,
            if (_isDragActive && _zonesRevealed) _buildDropZones(context),
            if (_isDragActive && !_zonesRevealed) _buildSubtleOverlay(context),
          ],
        );
      },
    );
  }

  /// Subtle overlay shown before zones are fully revealed.
  Widget _buildSubtleOverlay(BuildContext context) {
    final shellTheme = Theme.of(context).extension<ForgeShellTheme>();
    final highlightColor = shellTheme?.dropZoneHighlight ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
    return Positioned.fill(
      child: AnimatedContainer(
        duration: ForgeAnimations.dropZoneFade,
        color: highlightColor.withValues(alpha: 0.05),
      ),
    );
  }

  Widget _buildDropZones(BuildContext context) {
    final shellTheme = Theme.of(context).extension<ForgeShellTheme>();
    final highlightColor = shellTheme?.dropZoneHighlight ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
    final validColor = shellTheme?.dropZoneValid ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.35);
    final invalidColor = shellTheme?.dropZoneInvalid ??
        Theme.of(context).colorScheme.error.withValues(alpha: 0.35);

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final zoneWidth = constraints.maxWidth * 0.22;
          return Stack(
            children: [
              // Left split zone
              if (widget.canSplit)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: zoneWidth,
                  child: _DropZone(
                    position: DropPosition.left,
                    isHovered: _hoveredZone == DropPosition.left,
                    highlightColor: highlightColor,
                    borderColor: validColor,
                    invalidColor: invalidColor,
                    icon: Icons.vertical_split,
                    label: 'Split Left',
                    onEnter: () =>
                        setState(() => _hoveredZone = DropPosition.left),
                  ),
                ),

              // Right split zone
              if (widget.canSplit)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: zoneWidth,
                  child: _DropZone(
                    position: DropPosition.right,
                    isHovered: _hoveredZone == DropPosition.right,
                    highlightColor: highlightColor,
                    borderColor: validColor,
                    invalidColor: invalidColor,
                    icon: Icons.vertical_split,
                    label: 'Split Right',
                    onEnter: () =>
                        setState(() => _hoveredZone = DropPosition.right),
                  ),
                ),

              // Center add-to-tab zone
              Positioned(
                left: widget.canSplit ? zoneWidth : 0,
                right: widget.canSplit ? zoneWidth : 0,
                top: 0,
                bottom: 0,
                child: _DropZone(
                  position: DropPosition.center,
                  isHovered: _hoveredZone == DropPosition.center,
                  highlightColor: highlightColor,
                  borderColor: validColor,
                  invalidColor: invalidColor,
                  icon: Icons.tab,
                  label: 'Add to Tab Bar',
                  onEnter: () =>
                      setState(() => _hoveredZone = DropPosition.center),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DropZone extends StatefulWidget {
  final DropPosition position;
  final bool isHovered;
  final Color highlightColor;
  final Color borderColor;
  final Color invalidColor;
  final IconData icon;
  final String label;
  final VoidCallback onEnter;

  const _DropZone({
    required this.position,
    required this.isHovered,
    required this.highlightColor,
    required this.borderColor,
    required this.invalidColor,
    required this.icon,
    required this.label,
    required this.onEnter,
  });

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(_DropZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Flash when first hovering over this zone.
    if (widget.isHovered && !oldWidget.isHovered) {
      _flashController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => widget.onEnter(),
      child: AnimatedBuilder(
        animation: _flashController,
        builder: (context, child) {
          // Flash effect: briefly intensifies the border and background.
          final flashOpacity = (1.0 - _flashController.value) * 0.3;
          return AnimatedContainer(
            duration: ForgeAnimations.dropZoneFade,
            decoration: BoxDecoration(
              color: widget.isHovered
                  ? Color.lerp(
                      widget.highlightColor,
                      widget.borderColor,
                      flashOpacity,
                    )
                  : Colors.transparent,
              border: widget.isHovered
                  ? Border.all(color: widget.borderColor, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            margin: const EdgeInsets.all(4),
            child: widget.isHovered
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 28, color: widget.borderColor),
                        const SizedBox(height: 4),
                        Text(
                          widget.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// An empty panel placeholder that acts as a valid drop target.
///
/// Shown when a middle panel has no editors, allowing tabs to be
/// dragged into the empty panel space.
class EmptyPanelDropTarget extends StatefulWidget {
  final int panelIndex;
  final DropZoneCallback? onDrop;

  const EmptyPanelDropTarget({
    super.key,
    required this.panelIndex,
    this.onDrop,
  });

  @override
  State<EmptyPanelDropTarget> createState() => _EmptyPanelDropTargetState();
}

class _EmptyPanelDropTargetState extends State<EmptyPanelDropTarget> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellTheme = theme.extension<ForgeShellTheme>();
    final highlightColor = shellTheme?.dropZoneHighlight ??
        theme.colorScheme.primary.withValues(alpha: 0.2);
    final borderColor = shellTheme?.dropZoneValid ??
        theme.colorScheme.primary.withValues(alpha: 0.35);

    return DragTarget<TabDragData>(
      onWillAcceptWithDetails: (_) {
        setState(() => _isDragOver = true);
        return true;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        widget.onDrop?.call(
          details.data,
          DropPosition.center,
          isCopy: false,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: ForgeAnimations.dropZoneFade,
          decoration: BoxDecoration(
            color: _isDragOver ? highlightColor : Colors.transparent,
            border: _isDragOver
                ? Border.all(color: borderColor, width: 2)
                : Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.3),
                    width: 1,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isDragOver ? Icons.add_circle : Icons.add_circle_outline,
                  size: 36,
                  color: _isDragOver
                      ? borderColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 8),
                Text(
                  _isDragOver ? 'Drop here' : 'Drop a tab here',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _isDragOver
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
