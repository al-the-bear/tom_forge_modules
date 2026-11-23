import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../defaults/default_shell_api.dart';

/// A VS Code-style command palette overlay.
///
/// Shows a searchable list of available commands/actions.
class ForgeCommandPalette extends StatefulWidget {
  static bool debugEnabled = false;

  final DefaultShellApi shellApi;
  final VoidCallback onDismiss;

  const ForgeCommandPalette({
    super.key,
    required this.shellApi,
    required this.onDismiss,
  });

  @override
  State<ForgeCommandPalette> createState() => _ForgeCommandPaletteState();
}

class _ForgeCommandPaletteState extends State<ForgeCommandPalette> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _listFocusNode = FocusNode();
  List<_CommandItem> _allCommands = [];
  List<_CommandItem> _filteredCommands = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _buildCommandList();
    _filteredCommands = _allCommands;
    _focusNode.requestFocus();
  }

  void _buildCommandList() {
    try {
      if (ForgeCommandPalette.debugEnabled) {
        debugPrint('[ForgeCommandPalette] building command list');
      }

      final commandsById = <String, _CommandItem>{};

      void putAction(ForgeAction action) {
        final binding = widget.shellApi.shortcuts.getBinding(action.id);
        final shortcutText = binding != null
            ? binding.displayString
            : _formatShortcut(action.defaultShortcut);
        commandsById[action.id] = _CommandItem(
          id: action.id,
          label: action.label,
          shortcut: shortcutText,
          icon: action.icon ?? Icons.play_arrow,
          onExecute: () {
            if (!widget.shellApi.executeAction(action.id)) {
              action.execute({});
            }
          },
        );
      }

      for (final action in widget.shellApi.actionRegistry.allActions) {
        putAction(action);
      }

      // Include module actions that may not yet be in registry.
      for (final module in widget.shellApi.modules.allModules) {
        for (final action in module.actions) {
          commandsById.putIfAbsent(action.id, () {
            final binding = widget.shellApi.shortcuts.getBinding(action.id);
            final shortcutText = binding != null
                ? binding.displayString
                : _formatShortcut(action.defaultShortcut);
            return _CommandItem(
              id: action.id,
              label: action.label,
              shortcut: shortcutText,
              icon: action.icon ?? Icons.play_arrow,
              onExecute: () {
                if (!widget.shellApi.executeAction(action.id)) {
                  action.execute({});
                }
              },
            );
          });
        }
      }

      // Add built-in commands
      final commands = <_CommandItem>[
        ...commandsById.values,
        _CommandItem(
          id: 'palette.close',
          label: 'Close Command Palette',
          shortcut: 'Escape',
          icon: Icons.close,
          onExecute: widget.onDismiss,
        ),
        _CommandItem(
          id: 'view.toggleLeftPanel',
          label: 'Toggle Left Panel',
          shortcut: _primaryLabel(LogicalKeyboardKey.keyL),
          icon: Icons.view_sidebar,
          onExecute: () {
            widget.shellApi.layout.togglePanel(ForgePanelLocation.left);
            widget.onDismiss();
          },
        ),
        _CommandItem(
          id: 'view.toggleRightPanel',
          label: 'Toggle Right Panel',
          shortcut: _primaryLabel(LogicalKeyboardKey.keyR),
          icon: Icons.view_sidebar_outlined,
          onExecute: () {
            widget.shellApi.layout.togglePanel(ForgePanelLocation.right);
            widget.onDismiss();
          },
        ),
      ];

      _allCommands = commands;

      if (ForgeCommandPalette.debugEnabled) {
        debugPrint('[ForgeCommandPalette] command count: ${_allCommands.length}');
      }
    } catch (error, stackTrace) {
      debugPrint('[ForgeCommandPalette] build list failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  String? _formatShortcut(ForgeShortcutKey? key) {
    if (key == null) return null;

    final parts = <String>[];
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    if (key.control && mac) parts.add('⌃');
    if (key.primaryModifier || (key.control && !mac)) {
      parts.add(mac ? '⌘' : 'Ctrl');
    }
    if (key.alt) parts.add('Alt');
    if (key.shift) parts.add('Shift');
    parts.add(_formatKey(key.key));
    return parts.join('+');
  }

  String _primaryLabel(LogicalKeyboardKey key) {
    final modifier =
        defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Ctrl';
    return '$modifier+${_formatKey(key)}';
  }

  String _formatKey(LogicalKeyboardKey key) {
    // Return readable key name
    final label = key.keyLabel;
    if (label.isNotEmpty) return label.toUpperCase();
    return key.debugName ?? '?';
  }

  void _filterCommands(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCommands = _allCommands;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredCommands = _allCommands.where((cmd) {
          return cmd.label.toLowerCase().contains(lowerQuery) ||
              cmd.id.toLowerCase().contains(lowerQuery);
        }).toList();
      }
      _selectedIndex = 0;
    });
  }

  void _executeSelected() {
    if (_filteredCommands.isNotEmpty && _selectedIndex < _filteredCommands.length) {
      final cmd = _filteredCommands[_selectedIndex];
      cmd.onExecute();
      widget.onDismiss();
    }
  }

  void _moveSelection(int delta) {
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _filteredCommands.length - 1);
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _executeSelected();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _listFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: const Alignment(0, -0.3),
          child: GestureDetector(
            onTap: () {}, // Prevent dismiss when tapping palette
            child: FocusScope(
              autofocus: true,
              child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: Container(
                width: 500,
                constraints: const BoxConstraints(maxHeight: 400),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252526) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search field
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type a command...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        onChanged: _filterCommands,
                        onSubmitted: (_) => _executeSelected(),
                      ),
                    ),
                    // Command list
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _filteredCommands.length,
                        itemBuilder: (context, index) {
                          final cmd = _filteredCommands[index];
                          final isSelected = index == _selectedIndex;

                          return InkWell(
                            onTap: () {
                              cmd.onExecute();
                              widget.onDismiss();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              color: isSelected
                                  ? (isDark
                                      ? const Color(0xFF094771)
                                      : Colors.blue.withValues(alpha: 0.1))
                                  : null,
                              child: Row(
                                children: [
                                  Icon(
                                    cmd.icon,
                                    size: 18,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      cmd.label,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (cmd.shortcut != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[700]
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        cmd.shortcut!,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_filteredCommands.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No commands found',
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandItem {
  final String id;
  final String label;
  final String? shortcut;
  final IconData icon;
  final VoidCallback onExecute;

  _CommandItem({
    required this.id,
    required this.label,
    this.shortcut,
    required this.icon,
    required this.onExecute,
  });
}
