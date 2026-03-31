import 'dart:async';

import 'package:flutter/material.dart';

import '../actions/forge_shortcut_menu.dart';
import '../services/forge_shortcut_manager.dart';
import '../theme/forge_shell_theme.dart';
import 'forge_shell_scaffold.dart';

/// Popup overlay for custom shortcut menus (concept §11.4).
///
/// Appears when the user presses `Shift+Cmd/Ctrl+<trigger>`. Shows
/// follow-up entries with key badges. The user can press a bare key,
/// click an entry, use arrow keys + Enter, or press ESC to cancel.
class ForgeShortcutMenuPopup extends StatefulWidget {
  final ForgeShortcutManager shortcutManager;

  const ForgeShortcutMenuPopup({
    super.key,
    required this.shortcutManager,
  });

  @override
  State<ForgeShortcutMenuPopup> createState() => _ForgeShortcutMenuPopupState();
}

class _ForgeShortcutMenuPopupState extends State<ForgeShortcutMenuPopup>
    with SingleTickerProviderStateMixin {
  ForgeShortcutMenu? _menu;
  int _highlightedIndex = -1;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  StreamSubscription<ForgeShortcutMenuEvent>? _subscription;

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
    _subscription =
        widget.shortcutManager.onMenuStateChanged.listen(_onMenuEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onMenuEvent(ForgeShortcutMenuEvent event) {
    switch (event.state) {
      case ForgeShortcutMenuState.opened:
        setState(() {
          _menu = event.menu;
          _highlightedIndex = -1;
        });
        _animController.forward();
      case ForgeShortcutMenuState.selected:
      case ForgeShortcutMenuState.closed:
        _animController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _menu = null;
              _highlightedIndex = -1;
            });
          }
        });
    }
  }

  void _onEntryTap(ForgeShortcutMenuEntry entry) {
    widget.shortcutManager.handleMenuKey(entry.key);
  }

  @override
  Widget build(BuildContext context) {
    if (_menu == null && !_animController.isAnimating) {
      return const SizedBox.shrink();
    }

    final shellTheme = Theme.of(context).extension<ForgeShellTheme>();
    final bgColor =
        shellTheme?.chordPopupBackground ?? const Color(0xFF252526);
    final fgColor =
        shellTheme?.chordPopupForeground ?? const Color(0xFFCCCCCC);
    final keyBgColor =
        shellTheme?.shortcutKeyBackground ?? const Color(0xFF616161);

    final menu = _menu;

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
                  // Header row.
                  Text(
                    menu?.label ?? '',
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (menu != null && menu.entries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 1,
                      color: fgColor.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 8),
                    // Entry rows.
                    ...menu.entries.asMap().entries.map(
                      (e) => _ShortcutMenuEntryRow(
                        entry: e.value,
                        fgColor: fgColor,
                        keyBgColor: keyBgColor,
                        isHighlighted: e.key == _highlightedIndex,
                        onTap: () => _onEntryTap(e.value),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Footer hint.
                    Text(
                      'Press key or ESC to cancel',
                      style: TextStyle(
                        color: fgColor.withValues(alpha: 0.5),
                        fontSize: 11,
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

class _ShortcutMenuEntryRow extends StatelessWidget {
  final ForgeShortcutMenuEntry entry;
  final Color fgColor;
  final Color keyBgColor;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _ShortcutMenuEntryRow({
    required this.entry,
    required this.fgColor,
    required this.keyBgColor,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          decoration: isHighlighted
              ? BoxDecoration(
                  color: fgColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: keyBgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.keyLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.action.label,
                  style: TextStyle(color: fgColor, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
