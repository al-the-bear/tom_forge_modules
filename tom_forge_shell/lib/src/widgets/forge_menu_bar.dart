import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../actions/forge_action.dart';
import '../adapters/tom_forge_shell_module.dart';
import '../defaults/default_shell_api.dart';
import '../defaults/default_system_state.dart';

/// A VS Code-style menu bar with File | Edit | View | Help menus.
class ForgeMenuBar extends StatelessWidget {
  static const String _actionFileNew = 'file.new';
  static const String _actionFileOpenFolder = 'file.openFolder';
  static const String _actionFileSave = 'file.save';
  static const String _actionFileSaveAll = 'file.saveAll';
  static const String _actionFileClose = 'file.close';
  static const String _actionEditCut = 'edit.cut';
  static const String _actionEditCopy = 'edit.copy';
  static const String _actionEditPaste = 'edit.paste';
  static const String _actionEditFind = 'edit.find';
  static const String _actionEditReplace = 'edit.replace';
  static const String _actionEditUndo = 'edit.undo';
  static const String _actionEditRedo = 'edit.redo';

  final DefaultShellApi shellApi;
  final VoidCallback onCommandPalette;
  final VoidCallback? onSettings;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  /// Whether the High Contrast item is checked.
  final bool highContrast;

  /// Called with the new value when High Contrast is toggled.
  final ValueChanged<bool>? onHighContrastChanged;

  const ForgeMenuBar({
    super.key,
    required this.shellApi,
    required this.onCommandPalette,
    this.onSettings,
    this.currentThemeMode = ThemeMode.dark,
    this.onThemeModeChanged,
    this.highContrast = false,
    this.onHighContrastChanged,
  });

  DefaultSystemState get _systemState =>
      shellApi.systemState as DefaultSystemState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 28,
      color: isDark ? const Color(0xFF3C3C3C) : const Color(0xFFE8E8E8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _MenuButton(
            label: 'File',
            items: [
              _MenuItem(
                label: 'New File',
                shortcut: '⌘N',
                onTap: () =>
                    _executeActionOrInform(context, _actionFileNew, 'New File'),
              ),
              _MenuItem(
                label: 'Open Folder...',
                shortcut: '⌘O',
                onTap: () => _executeActionOrInform(
                  context,
                  _actionFileOpenFolder,
                  'Open Folder',
                ),
              ),
              const _MenuDivider(),
              _MenuItem(
                label: 'Save',
                shortcut: '⌘S',
                onTap: () =>
                    _executeActionOrInform(context, _actionFileSave, 'Save'),
              ),
              _MenuItem(
                label: 'Save All',
                shortcut: '⇧⌘S',
                onTap: () => _executeActionOrInform(
                  context,
                  _actionFileSaveAll,
                  'Save All',
                ),
              ),
              const _MenuDivider(),
              _MenuItem(
                label: 'Close Editor',
                shortcut: '⌘W',
                onTap: () => _executeActionOrInform(
                  context,
                  _actionFileClose,
                  'Close Editor',
                ),
              ),
              const _MenuDivider(),
              _MenuItem(
                label: 'Settings...',
                shortcut: '⌘,',
                onTap:
                    onSettings ??
                    () => _showNotImplemented(context, 'Settings'),
              ),
            ],
            isDark: isDark,
          ),
          _MenuButton(
            label: 'Edit',
            items: [
              _MenuItem(
                label: 'Undo',
                shortcut: '⌘Z',
                onTap: () =>
                    _executeActionOrInform(context, _actionEditUndo, 'Undo'),
              ),
              _MenuItem(
                label: 'Redo',
                shortcut: '⇧⌘Z',
                onTap: () =>
                    _executeActionOrInform(context, _actionEditRedo, 'Redo'),
              ),
              const _MenuDivider(),
              _MenuItem(
                label: 'Cut',
                shortcut: '⌘X',
                onTap: () =>
                    _executeActionOrInform(context, _actionEditCut, 'Cut'),
              ),
              _MenuItem(
                label: 'Copy',
                shortcut: '⌘C',
                onTap: () =>
                    _executeActionOrInform(context, _actionEditCopy, 'Copy'),
              ),
              _MenuItem(
                label: 'Paste',
                shortcut: '⌘V',
                onTap: () =>
                    _executeActionOrInform(context, _actionEditPaste, 'Paste'),
              ),
              const _MenuDivider(),
              _MenuItem(
                label: 'Find',
                shortcut: '⌘F',
                onTap: () =>
                    _executeActionOrInform(context, _actionEditFind, 'Find'),
              ),
              _MenuItem(
                label: 'Replace',
                shortcut: '⌥⌘F',
                onTap: () => _executeActionOrInform(
                  context,
                  _actionEditReplace,
                  'Replace',
                ),
              ),
            ],
            isDark: isDark,
          ),
          _MenuButton(
            label: 'View',
            items: [
              _MenuItem(
                label: 'Command Palette...',
                shortcut: '⌘P',
                onTap: onCommandPalette,
              ),
              const _MenuDivider(),
              _MenuItem(
                label: 'Toggle Left Panel',
                shortcut: '⌘L',
                onTap: () =>
                    shellApi.layout.togglePanel(ForgePanelLocation.left),
              ),
              _MenuItem(
                label: 'Toggle Right Panel',
                shortcut: '⌘R',
                onTap: () =>
                    shellApi.layout.togglePanel(ForgePanelLocation.right),
              ),
              const _MenuDivider(),
              _MenuItem(
                label: 'Middle Panel 1',
                shortcut: '⌘1',
                onTap: () {
                  if (_systemState.middlePanelCount > 0) {
                    shellApi.layout.setActiveMiddlePanelIndex(0);
                  }
                  _systemState.setFocusedPanelLocation(
                    ForgePanelLocation.middle,
                  );
                },
              ),
              _MenuItem(
                label: 'Middle Panel 2',
                shortcut: '⌘2',
                onTap: () {
                  if (_systemState.middlePanelCount > 1) {
                    shellApi.layout.setActiveMiddlePanelIndex(1);
                  }
                  _systemState.setFocusedPanelLocation(
                    ForgePanelLocation.middle,
                  );
                },
              ),
              _MenuItem(
                label: 'Middle Panel 3',
                shortcut: '⌘3',
                onTap: () {
                  if (_systemState.middlePanelCount > 2) {
                    shellApi.layout.setActiveMiddlePanelIndex(2);
                  }
                  _systemState.setFocusedPanelLocation(
                    ForgePanelLocation.middle,
                  );
                },
              ),
              _MenuItem(
                label: 'Middle Panel 4',
                shortcut: '⌘4',
                onTap: () {
                  if (_systemState.middlePanelCount > 3) {
                    shellApi.layout.setActiveMiddlePanelIndex(3);
                  }
                  _systemState.setFocusedPanelLocation(
                    ForgePanelLocation.middle,
                  );
                },
              ),
              const _MenuDivider(),
              _MenuSubHeader(label: 'Appearance'),
              _MenuItem(
                label: 'Dark Theme',
                shortcut: currentThemeMode == ThemeMode.dark ? '✓' : '',
                onTap: () => onThemeModeChanged?.call(ThemeMode.dark),
              ),
              _MenuItem(
                label: 'Light Theme',
                shortcut: currentThemeMode == ThemeMode.light ? '✓' : '',
                onTap: () => onThemeModeChanged?.call(ThemeMode.light),
              ),
              _MenuItem(
                label: 'System Theme',
                shortcut: currentThemeMode == ThemeMode.system ? '✓' : '',
                onTap: () => onThemeModeChanged?.call(ThemeMode.system),
              ),
              _MenuItem(
                label: 'High Contrast',
                shortcut: highContrast ? '✓' : '',
                onTap: () => onHighContrastChanged?.call(!highContrast),
              ),
            ],
            isDark: isDark,
          ),
          _MenuButton(
            label: 'Go',
            items: [
              _actionItem('Back', TomForgeShellModule.navigateBackActionId),
              _actionItem(
                'Forward',
                TomForgeShellModule.navigateForwardActionId,
              ),
              const _MenuDivider(),
              _MenuItem(
                label: 'Go to File...',
                shortcut: '⌘P',
                onTap: onCommandPalette,
              ),
              _MenuItem(
                label: 'Go to Symbol...',
                onTap: () => _showNotImplemented(context, 'Go to Symbol'),
              ),
              _MenuItem(
                label: 'Go to Line...',
                onTap: () => _showNotImplemented(context, 'Go to Line'),
              ),
            ],
            isDark: isDark,
          ),
          _MenuButton(
            label: 'Tools',
            items: _buildToolsMenuItems(context),
            isDark: isDark,
          ),
          _MenuButton(
            label: 'Help',
            items: [
              _MenuItem(
                label: 'Welcome',
                onTap: () => _showNotImplemented(context, 'Welcome'),
              ),
              _MenuItem(
                label: 'Documentation',
                onTap: () => _showNotImplemented(context, 'Documentation'),
              ),
              const _MenuDivider(),
              _MenuItem(label: 'About', onTap: () => _showAbout(context)),
            ],
            isDark: isDark,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  List<_MenuItemBase> _buildToolsMenuItems(BuildContext context) {
    final grouped = <String, List<ForgeAction>>{};

    for (final module in shellApi.modules.allModules) {
      final actions =
          module.actions
              .where(
                (action) => action.menu == ForgeMenuLocation.tools,
              )
              .where((action) => action.isVisible())
              .toList(growable: false)
            ..sort((a, b) {
              final priority = a.priority.compareTo(b.priority);
              if (priority != 0) return priority;
              return a.label.compareTo(b.label);
            });
      if (actions.isNotEmpty) {
        grouped[module.displayName] = actions;
      }
    }

    if (grouped.isEmpty) {
      return [
        _MenuItem(
          label: 'No Tools Available',
          onTap: () => _showNotImplemented(context, 'Tools'),
        ),
      ];
    }

    final items = <_MenuItemBase>[];
    var groupIndex = 0;
    final showModuleHeaders = grouped.length > 1;

    for (final entry in grouped.entries) {
      if (groupIndex > 0) {
        items.add(const _MenuDivider());
      }
      if (showModuleHeaders) {
        items.add(_MenuSubHeader(label: entry.key));
      }
      for (final action in entry.value) {
        items.add(
          _MenuItem(
            label: action.label,
            onTap: () =>
                _executeActionOrInform(context, action.id, action.label),
          ),
        );
      }
      groupIndex++;
    }

    return items;
  }

  void _executeActionOrInform(
    BuildContext context,
    String actionId,
    String actionName,
  ) {
    final executed = shellApi.executeAction(actionId);
    if (executed) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$actionName is currently unavailable'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// A menu entry running the shell action [actionId], showing the key the
  /// shell's table binds it to.
  _MenuItem _actionItem(String label, String actionId) => _MenuItem(
    label: label,
    shortcut: shellApi.shortcuts.getBinding(actionId)?.key.toDisplayString(),
    onTap: () => shellApi.executeAction(actionId),
  );

  void _showNotImplemented(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature: Not implemented yet'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tom Forge'),
        content: const Text('Visual IDE Shell Framework\nVersion 0.1.0'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String label;
  final List<_MenuItemBase> items;
  final bool isDark;

  const _MenuButton({
    required this.label,
    required this.items,
    required this.isDark,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  static OverlayEntry? _currentOverlay;
  static _MenuButtonState? _currentButton;

  bool _isHovered = false;
  bool _isOpen = false;

  void _showMenu() {
    _hideCurrentMenu();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    _currentOverlay = OverlayEntry(
      builder: (context) => _MenuOverlay(
        position: Offset(position.dx, position.dy + 28),
        items: widget.items,
        isDark: widget.isDark,
        onDismiss: _hideMenu,
      ),
    );

    overlay.insert(_currentOverlay!);
    _currentButton = this;
    setState(() => _isOpen = true);
  }

  void _hideMenu() {
    if (_currentOverlay != null) {
      _currentOverlay!.remove();
      _currentOverlay = null;
    }
    if (_currentButton == this) {
      _currentButton = null;
      if (mounted) {
        setState(() => _isOpen = false);
      }
    }
  }

  static void _hideCurrentMenu() {
    if (_currentOverlay != null) {
      _currentOverlay!.remove();
      _currentOverlay = null;
    }
    if (_currentButton != null && _currentButton!.mounted) {
      _currentButton!.setState(() => _currentButton!._isOpen = false);
    }
    _currentButton = null;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isHovered || _isOpen;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        // If another menu is open, switch to this one
        if (_currentOverlay != null && _currentButton != this) {
          _showMenu();
        }
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (_isOpen) {
            _hideMenu();
          } else {
            _showMenu();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 28,
          alignment: Alignment.center,
          color: isActive
              ? (widget.isDark ? Colors.grey[600] : Colors.grey[300])
              : null,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isDark ? Colors.white : Colors.black87,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuOverlay extends StatelessWidget {
  final Offset position;
  final List<_MenuItemBase> items;
  final bool isDark;
  final VoidCallback onDismiss;

  const _MenuOverlay({
    required this.position,
    required this.items,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dismiss layer
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu
        Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(4),
            color: isDark ? const Color(0xFF252526) : Colors.white,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: items.map((item) {
                  if (item is _MenuDivider) {
                    return Divider(
                      height: 1,
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                    );
                  }
                  if (item is _MenuSubHeader) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 6,
                        bottom: 2,
                      ),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }
                  final menuItem = item as _MenuItem;
                  return _MenuItemWidget(
                    item: menuItem,
                    isDark: isDark,
                    onTap: () {
                      onDismiss();
                      menuItem.onTap();
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItemWidget extends StatefulWidget {
  final _MenuItem item;
  final bool isDark;
  final VoidCallback onTap;

  const _MenuItemWidget({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_MenuItemWidget> createState() => _MenuItemWidgetState();
}

class _MenuItemWidgetState extends State<_MenuItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          color: _isHovered
              ? (widget.isDark
                    ? const Color(0xFF094771)
                    : Colors.blue.withValues(alpha: 0.1))
              : null,
          child: Row(
            children: [
              Text(
                widget.item.label,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 40),
              if (widget.item.shortcut != null)
                Text(
                  widget.item.shortcut!,
                  style: TextStyle(
                    color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract class _MenuItemBase {
  const _MenuItemBase();
}

class _MenuItem extends _MenuItemBase {
  final String label;
  final String? shortcut;
  final VoidCallback onTap;

  _MenuItem({required this.label, this.shortcut, required this.onTap})
    : super();
}

class _MenuDivider extends _MenuItemBase {
  const _MenuDivider() : super();
}

class _MenuSubHeader extends _MenuItemBase {
  final String label;
  const _MenuSubHeader({required this.label}) : super();
}
