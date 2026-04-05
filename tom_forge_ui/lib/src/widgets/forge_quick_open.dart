import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeSearchConfig, GitIgnoreMatcher;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../defaults/default_shell_api.dart';

/// Operating modes for the unified quick-open search bar.
enum QuickOpenMode {
  /// Search across files, actions, and configuration settings.
  all,

  /// Search only actions / commands (triggered by Ctrl+P).
  actions,

  /// Show chord second-key completions (triggered by chord system).
  chord,
}

/// Result item types for display categorization.
enum _ResultType { file, action, setting }

/// A single result item in the quick-open dropdown.
class _QuickOpenItem {
  final String id;
  final String label;
  final String? detail;
  final String? shortcut;
  final IconData icon;
  final _ResultType type;
  final VoidCallback onExecute;

  /// The actual chord second key for matching key events (chord mode only).
  final ForgeShortcutKey? chordSecondKey;

  _QuickOpenItem({
    required this.id,
    required this.label,
    this.detail,
    this.shortcut,
    required this.icon,
    required this.type,
    required this.onExecute,
    this.chordSecondKey,
  });
}

/// Unified quick-open dropdown that hangs below the search field in the
/// title bar.
///
/// Operates in three modes:
/// - [QuickOpenMode.all]: searches files, actions, and settings
/// - [QuickOpenMode.actions]: searches only actions (Ctrl+P)
/// - [QuickOpenMode.chord]: shows chord second-key options
class ForgeQuickOpen extends StatefulWidget {
  static bool debugEnabled = false;

  final DefaultShellApi shellApi;
  final QuickOpenMode mode;
  final VoidCallback onDismiss;

  /// Initial query text (e.g. from the title bar text field).
  final String initialQuery;

  /// Chord state when [mode] is [QuickOpenMode.chord].
  final ForgeShortcutKey? chordFirstKey;
  final List<ForgeShortcutBinding> chordCompletions;

  /// Called when the user opens a file result.
  final void Function(Uri uri)? onOpenFile;

  /// Called when the user wants to open the help document.
  final VoidCallback? onOpenHelp;

  /// Controller for the search field in the title bar.
  final TextEditingController searchController;

  /// Focus node for the search field.
  final FocusNode searchFocusNode;

  /// Configuration for file search behavior (extensions, directories, limits).
  final ForgeSearchConfig searchConfig;

  const ForgeQuickOpen({
    super.key,
    required this.shellApi,
    this.mode = QuickOpenMode.all,
    required this.onDismiss,
    this.initialQuery = '',
    this.chordFirstKey,
    this.chordCompletions = const [],
    this.onOpenFile,
    this.onOpenHelp,
    required this.searchController,
    required this.searchFocusNode,
    this.searchConfig = const ForgeSearchConfig(),
  });

  @override
  State<ForgeQuickOpen> createState() => _ForgeQuickOpenState();
}

class _ForgeQuickOpenState extends State<ForgeQuickOpen> {
  List<_QuickOpenItem> _results = [];
  int _selectedIndex = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _buildResults(widget.initialQuery);
    widget.searchController.addListener(_onSearchChanged);
    // Handle keyboard navigation via a raw keyboard listener on the search field.
    widget.searchFocusNode.onKeyEvent = _onSearchFieldKeyEvent;
    widget.searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    widget.searchFocusNode.onKeyEvent = null;
    _searchDebounce?.cancel();
    super.dispose();
  }

  KeyEventResult _onSearchFieldKeyEvent(FocusNode node, KeyEvent event) {
    return handleKeyEvent(event);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = widget.searchController.text;
    if (widget.mode == QuickOpenMode.chord) {
      // Instant filter for chord completions.
      _buildResults(query);
    } else {
      // Debounce file search.
      _searchDebounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) _buildResults(query);
      });
    }
  }

  void _buildResults(String query) {
    switch (widget.mode) {
      case QuickOpenMode.all:
        _buildAllResults(query);
      case QuickOpenMode.actions:
        _buildActionResults(query);
      case QuickOpenMode.chord:
        _buildChordResults(query);
    }
  }

  // ── Mode: all ──

  void _buildAllResults(String query) {
    final items = <_QuickOpenItem>[];
    final lowerQuery = query.toLowerCase();

    // Actions.
    items.addAll(_getActionItems(lowerQuery));

    // Settings.
    items.addAll(_getSettingItems(lowerQuery));

    // Files (async, but we start it and update when done).
    if (query.isNotEmpty) {
      _searchFiles(query);
    }

    setState(() {
      _results = items;
      _selectedIndex = 0;
    });
  }

  // ── Mode: actions ──

  void _buildActionResults(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _results = _getActionItems(lowerQuery);
      _selectedIndex = 0;
    });
  }

  // ── Mode: chord ──

  void _buildChordResults(String query) {
    final lowerQuery = query.toLowerCase();
    final items = <_QuickOpenItem>[];

    // "?" help is always first.
    items.add(_QuickOpenItem(
      id: 'chord.help',
      label: 'Help',
      detail: 'Show keyboard shortcut help',
      shortcut: '?',
      icon: Icons.help_outline,
      type: _ResultType.action,
      onExecute: () {
        widget.onOpenHelp?.call();
        widget.onDismiss();
      },
    ));

    for (final binding in widget.chordCompletions) {
      final secondKey = binding.chord?.secondKey;
      final label = binding.action.label;
      if (lowerQuery.isNotEmpty && !label.toLowerCase().contains(lowerQuery)) {
        continue;
      }
      items.add(_QuickOpenItem(
        id: binding.action.id,
        label: label,
        shortcut: secondKey?.toDisplayString(),
        chordSecondKey: secondKey,
        icon: binding.action.icon ?? Icons.keyboard,
        type: _ResultType.action,
        onExecute: () {
          widget.shellApi.executeAction(binding.action.id);
          widget.onDismiss();
        },
      ));
    }

    setState(() {
      _results = items;
      _selectedIndex = 0;
    });
  }

  // ── Helpers ──

  List<_QuickOpenItem> _getActionItems(String lowerQuery) {
    final commandsById = <String, _QuickOpenItem>{};

    void addAction(ForgeAction action) {
      final binding = widget.shellApi.shortcuts.getBinding(action.id);
      final shortcutText = binding?.displayString ?? _formatShortcut(action.defaultShortcut);
      commandsById[action.id] = _QuickOpenItem(
        id: action.id,
        label: action.label,
        shortcut: shortcutText,
        icon: action.icon ?? Icons.play_arrow,
        type: _ResultType.action,
        onExecute: () {
          if (!widget.shellApi.executeAction(action.id)) {
            action.execute({});
          }
          widget.onDismiss();
        },
      );
    }

    for (final action in widget.shellApi.actionRegistry.allActions) {
      addAction(action);
    }
    for (final module in widget.shellApi.modules.allModules) {
      for (final action in module.actions) {
        if (!commandsById.containsKey(action.id)) addAction(action);
      }
    }

    if (lowerQuery.isEmpty) return commandsById.values.toList();

    return commandsById.values.where((item) {
      return item.label.toLowerCase().contains(lowerQuery) ||
          item.id.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  List<_QuickOpenItem> _getSettingItems(String lowerQuery) {
    // Build searchable setting entries from known preference keys.
    final settings = <_QuickOpenItem>[
      _settingItem('Theme Mode', 'forge.appearance.themeMode', Icons.palette),
      _settingItem('Auto Save', 'forge.editor.autoSave', Icons.save),
      _settingItem('Font Size', 'forge.editor.fontSize', Icons.format_size),
      _settingItem('Font Family', 'forge.editor.fontFamily', Icons.font_download),
      _settingItem('Terminal Shell', 'forge.terminal.defaultShell', Icons.terminal),
      _settingItem('Terminal Font Size', 'forge.terminal.fontSize', Icons.text_fields),
      _settingItem('Terminal Scrollback', 'forge.terminal.scrollbackLines', Icons.swap_vert),
      _settingItem('Word Wrap', 'forge.editor.wordWrap', Icons.wrap_text),
      _settingItem('Tab Size', 'forge.editor.tabSize', Icons.space_bar),
      _settingItem('Line Numbers', 'forge.editor.lineNumbers', Icons.format_list_numbered),
      _settingItem('Minimap', 'forge.editor.minimap', Icons.map),
      _settingItem('File Type Defaults', 'forge.editor.fileTypeDefaults', Icons.file_copy),
      _settingItem('Search: Excluded Extensions', 'forge.search.excludedExtensions', Icons.extension_off),
      _settingItem('Search: Excluded Directories', 'forge.search.excludedDirectories', Icons.folder_off),
      _settingItem('Search: File Size Limit', 'forge.search.fileSizeLimit', Icons.data_usage),
      _settingItem('Search: Hide Hidden Directories', 'forge.search.excludeHiddenDirectories', Icons.visibility_off),
      _settingItem('Search: Hide Git-Ignored Files', 'forge.search.excludeGitIgnored', Icons.rule),
      _settingItem('Search: Max File Results', 'forge.search.maxFileResults', Icons.format_list_numbered),
    ];

    if (lowerQuery.isEmpty) return settings;

    return settings.where((item) {
      return item.label.toLowerCase().contains(lowerQuery) ||
          (item.detail ?? '').toLowerCase().contains(lowerQuery);
    }).toList();
  }

  _QuickOpenItem _settingItem(String label, String key, IconData icon) {
    return _QuickOpenItem(
      id: 'setting.$key',
      label: label,
      detail: key,
      icon: icon,
      type: _ResultType.setting,
      onExecute: () {
        // Open configuration dialog — dismiss quick-open first.
        widget.onDismiss();
      },
    );
  }

  Future<void> _searchFiles(String query) async {
    try {
      final workspaceRoot = widget.shellApi.systemState.workspaceRootPath;
      final config = widget.searchConfig;

      final rootDir = Directory(workspaceRoot);
      if (!rootDir.existsSync()) return;

      // Load .gitignore rules when enabled.
      GitIgnoreMatcher? gitIgnore;
      if (config.excludeGitIgnored) {
        gitIgnore = GitIgnoreMatcher();
        await gitIgnore.loadFromRoot(workspaceRoot);
      }

      final lowerQuery = query.toLowerCase();
      final fileItems = <_QuickOpenItem>[];
      var count = 0;

      await for (final entity in rootDir.list(recursive: true)) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          final relativePath = entity.path.substring(workspaceRoot.length);
          // Relative path without leading slash for gitignore matching.
          final relPathClean = relativePath.startsWith('/')
              ? relativePath.substring(1)
              : relativePath;

          // Check excluded directories in path segments.
          final segments = relativePath.split('/');
          final skipDir = segments.any((seg) {
            if (seg.isEmpty) return false;
            return config.isDirectoryExcluded(seg);
          });
          if (skipDir) continue;

          // Check excluded extensions.
          final dotIndex = name.lastIndexOf('.');
          if (dotIndex != -1) {
            final ext = name.substring(dotIndex + 1);
            if (config.isExtensionExcluded(ext)) continue;
          }

          // Check .gitignore rules.
          if (gitIgnore != null &&
              gitIgnore.isIgnored(relPathClean, isDirectory: false)) {
            continue;
          }

          // Check file size limit.
          try {
            final stat = entity.statSync();
            if (stat.size > config.fileSizeLimit) continue;
          } catch (_) {
            continue;
          }

          if (name.toLowerCase().contains(lowerQuery) ||
              relativePath.toLowerCase().contains(lowerQuery)) {
            fileItems.add(_QuickOpenItem(
              id: 'file:${entity.path}',
              label: name,
              detail: relativePath,
              icon: _fileIcon(name),
              type: _ResultType.file,
              onExecute: () {
                widget.onOpenFile?.call(entity.uri);
                widget.onDismiss();
              },
            ));
            count++;
            if (count >= config.maxFileResults) break;
          }
        } else if (entity is Directory) {
          // Skip excluded directories eagerly by name.
          final dirName = entity.uri.pathSegments
              .lastWhere((s) => s.isNotEmpty, orElse: () => '');
          if (config.isDirectoryExcluded(dirName)) continue;
          // Also skip git-ignored directories.
          if (gitIgnore != null) {
            final relDir = entity.path.substring(workspaceRoot.length);
            final relDirClean =
                relDir.startsWith('/') ? relDir.substring(1) : relDir;
            if (gitIgnore.isIgnored(relDirClean, isDirectory: true)) continue;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        // Merge file results: files first, then existing non-file results.
        final nonFileResults =
            _results.where((r) => r.type != _ResultType.file).toList();
        _results = [...fileItems, ...nonFileResults];
        _selectedIndex = 0;
      });
    } catch (e) {
      // Silently ignore file search errors.
    }
  }

  IconData _fileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.code;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.data_object;
    if (name.endsWith('.md')) return Icons.description;
    if (name.endsWith('.json')) return Icons.data_array;
    if (name.endsWith('.txt')) return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  String? _formatShortcut(ForgeShortcutKey? key) {
    if (key == null) return null;
    final parts = <String>[];
    if (key.primaryModifier) {
      parts.add(defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Ctrl');
    }
    if (key.alt) parts.add('Alt');
    if (key.shift) parts.add('Shift');
    parts.add(key.key.keyLabel.toUpperCase());
    return parts.join('+');
  }

  void _executeSelected() {
    if (_results.isNotEmpty && _selectedIndex < _results.length) {
      _results[_selectedIndex].onExecute();
    }
  }

  void _moveSelection(int delta) {
    setState(() {
      _selectedIndex =
          (_selectedIndex + delta).clamp(0, _results.length - 1);
    });
  }

  /// Handle keyboard events in quick-open mode.
  ///
  /// In chord mode, bare key presses (without modifiers) that match a
  /// second-key completion are executed directly.
  KeyEventResult handleKeyEvent(KeyEvent event) {
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

    // In chord mode, match the pressed key against chord second-keys.
    if (widget.mode == QuickOpenMode.chord) {
      final pressedKey = ForgeShortcutKey(
        key: event.logicalKey,
        primaryModifier: HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed,
        shift: HardwareKeyboard.instance.isShiftPressed,
        alt: HardwareKeyboard.instance.isAltPressed,
      );
      for (final item in _results) {
        if (item.chordSecondKey != null && item.chordSecondKey == pressedKey) {
          item.onExecute();
          return KeyEventResult.handled;
        }
        // Also match bare key label for simple single-character shortcuts.
        if (item.chordSecondKey == null &&
            item.shortcut != null &&
            item.shortcut!.length == 1 &&
            item.shortcut!.toLowerCase() ==
                event.logicalKey.keyLabel.toLowerCase()) {
          item.onExecute();
          return KeyEventResult.handled;
        }
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _buildDropdown(context, isDark, theme);
  }

  Widget _buildDropdown(BuildContext context, bool isDark, ThemeData theme) {
    final bgColor = isDark ? const Color(0xFF252526) : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    return Container(
      constraints: const BoxConstraints(maxHeight: 350),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _results.isEmpty
          ? _buildEmpty(isDark)
          : _buildResultList(isDark, theme),
    );
  }

  Widget _buildEmpty(bool isDark) {
    final label = switch (widget.mode) {
      QuickOpenMode.all => 'No matching files, actions, or settings',
      QuickOpenMode.actions => 'No matching actions',
      QuickOpenMode.chord => 'No matching shortcuts',
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildResultList(bool isDark, ThemeData theme) {
    // Group results by type when in 'all' mode.
    final grouped = widget.mode == QuickOpenMode.all;

    if (!grouped) {
      return _buildFlatList(isDark, theme);
    }

    // Build grouped list: files → actions → settings.
    final files = _results.where((r) => r.type == _ResultType.file).toList();
    final actions =
        _results.where((r) => r.type == _ResultType.action).toList();
    final settings =
        _results.where((r) => r.type == _ResultType.setting).toList();

    final sections = <Widget>[];
    var runningIndex = 0;

    if (files.isNotEmpty) {
      sections.add(_buildSectionHeader('Files', isDark));
      sections.add(_buildItemGroup(files, runningIndex, isDark, theme));
      runningIndex += files.length;
    }
    if (actions.isNotEmpty) {
      sections.add(_buildSectionHeader('Actions', isDark));
      sections.add(_buildItemGroup(actions, runningIndex, isDark, theme));
      runningIndex += actions.length;
    }
    if (settings.isNotEmpty) {
      sections.add(_buildSectionHeader('Settings', isDark));
      sections.add(_buildItemGroup(settings, runningIndex, isDark, theme));
    }

    return Flexible(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: sections,
      ),
    );
  }

  Widget _buildFlatList(bool isDark, ThemeData theme) {
    return Flexible(
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          return _buildResultRow(
            _results[index],
            index,
            index == _selectedIndex,
            isDark,
            theme,
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildItemGroup(
    List<_QuickOpenItem> items,
    int startIndex,
    bool isDark,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          _buildResultRow(
            items[i],
            startIndex + i,
            (startIndex + i) == _selectedIndex,
            isDark,
            theme,
          ),
      ],
    );
  }

  Widget _buildResultRow(
    _QuickOpenItem item,
    int index,
    bool isSelected,
    bool isDark,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: item.onExecute,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: isSelected
            ? (isDark
                ? const Color(0xFF094771)
                : Colors.blue.withValues(alpha: 0.1))
            : null,
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.detail != null)
                    Text(
                      item.detail!,
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (item.shortcut != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.shortcut!,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
