import 'dart:async';

import 'package:flutter/material.dart';

import '../actions/forge_shortcut_binding.dart';
import '../services/forge_shortcut_manager.dart';
import '../theme/forge_shell_theme.dart';
import 'forge_shell_scaffold.dart';

/// Overlay that appears when the first key of a chord shortcut is pressed.
///
/// Shows the pending first key and lists available second-key completions.
/// Dismissed on chord completion, cancellation, or timeout.
class ForgeChordOverlay extends StatefulWidget {
  /// The shortcut manager to listen for chord events.
  final ForgeShortcutManager shortcutManager;

  const ForgeChordOverlay({
    super.key,
    required this.shortcutManager,
  });

  @override
  State<ForgeChordOverlay> createState() => _ForgeChordOverlayState();
}

class _ForgeChordOverlayState extends State<ForgeChordOverlay>
    with SingleTickerProviderStateMixin {
  ForgeShortcutKey? _firstKey;
  List<ForgeShortcutBinding> _completions = const [];
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  StreamSubscription<ForgeChordEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: ForgeAnimations.shortcutPopupIn,
      reverseDuration: ForgeAnimations.shortcutPopupOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: ForgeAnimations.popupCurve,
    );
    _subscription = widget.shortcutManager.onChordStateChanged.listen(_onChord);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onChord(ForgeChordEvent event) {
    switch (event.state) {
      case ForgeChordState.entered:
        setState(() {
          _firstKey = event.firstKey;
          _completions = event.completions;
        });
        _animController.forward();
      case ForgeChordState.completed:
      case ForgeChordState.cancelled:
        _animController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _firstKey = null;
              _completions = const [];
            });
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firstKey == null && !_animController.isAnimating) {
      return const SizedBox.shrink();
    }

    final shellTheme = Theme.of(context).extension<ForgeShellTheme>();
    final bgColor =
        shellTheme?.chordPopupBackground ?? const Color(0xFF252526);
    final fgColor =
        shellTheme?.chordPopupForeground ?? const Color(0xFFCCCCCC);
    final accentColor = shellTheme?.activeTab ?? const Color(0xFF007ACC);

    return Positioned(
      top: ForgeDimensions.titleBarHeight +
          ForgeDimensions.menuBarHeight +
          8,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: bgColor,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 280,
                maxWidth: 400,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: "Waiting for second key..."
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _firstKey?.toDisplayString() ?? '',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'was pressed. Waiting for second key...',
                        style: TextStyle(
                          color: fgColor.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (_completions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      color: fgColor.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 8),
                    // List available completions.
                    ..._completions.map(
                      (binding) => _ChordCompletionRow(
                        binding: binding,
                        fgColor: fgColor,
                        accentColor: accentColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChordCompletionRow extends StatelessWidget {
  final ForgeShortcutBinding binding;
  final Color fgColor;
  final Color accentColor;

  const _ChordCompletionRow({
    required this.binding,
    required this.fgColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final secondKey = binding.chord?.secondKey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 60,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: fgColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              secondKey?.toDisplayString() ?? '',
              style: TextStyle(
                color: accentColor,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              binding.action.label,
              style: TextStyle(color: fgColor, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
