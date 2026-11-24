import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeSearchConfig, forgeLoadGitignores;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// Result item types for display categorization.
enum _ResultType { openEditor, file, action, setting }

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
/// - [ForgeQuickOpenMode.all]: searches open editors, files, actions, and
///   settings
/// - [ForgeQuickOpenMode.actions]: searches only actions (Ctrl+P)
/// - [ForgeQuickOpenMode.chord]: shows chord second-key options
///
/// It works on the kit alone: the actions of [api]'s action registry and of
/// its modules ([forgeKitModulesOf]), the open editors of its state, the
/// files of its file system under the workspace folder (the state's
/// [ForgeWorkspaceRoot], else the file system's root).
class ForgeQuickOpen extends StatefulWidget {
  static bool debugEnabled = false;

  /// The application's API.
  final ForgeKitApi api;
  final ForgeQuickOpenMode mode;
  final VoidCallback onDismiss;

  /// Initial query text (e.g. from the title bar text field).
  final String initialQuery;

  /// Chord state when [mode] is [ForgeQuickOpenMode.chord].
  final ForgeShortcutKey? chordFirstKey;
  final List<ForgeShortcutBinding> chordCompletions;

  /// Called when the user opens a file result.
  final void Function(Uri uri)? onOpenFile;

  /// Called when the user wants to open the help document.
  final VoidCallback? onOpenHelp;

  /// Called when the user selects a setting entry.
  final VoidCallback? onOpenSettings;

  /// Controller for the search field in the title bar.
  final TextEditingController searchController;

  /// Focus node for the search field.
  final FocusNode searchFocusNode;

  /// Configuration for file search behavior (extensions, directories, limits).
  final ForgeSearchConfig searchConfig;

  /// Target accordion section index to expand when opening settings.
  final ValueNotifier<int?>? configSectionTarget;

  const ForgeQuickOpen({
    super.key,
    required this.api,
    this.mode = ForgeQuickOpenMode.all,
    required this.onDismiss,
    this.initialQuery = '',
    this.chordFirstKey,
    this.chordCompletions = const [],
    this.onOpenFile,
    this.onOpenHelp,
    this.onOpenSettings,
    required this.searchController,
    required this.searchFocusNode,
    this.searchConfig = const ForgeSearchConfig(),
    this.configSectionTarget,
  });

  /// The quick open an application asks for with [request] (what
  /// [forgeQuickOpenModule] contributes): files open through the request's
  /// `onOpenFile`, else `ForgeKitApi.openFile`.
  factory ForgeQuickOpen.fromRequest(
    ForgeQuickOpenRequest request, {
    Key? key,
  }) => ForgeQuickOpen(
    key: key,
    api: request.api,
    mode: request.mode,
    onDismiss: request.onDismiss,
    initialQuery: request.initialQuery,
    chordFirstKey: request.chordFirstKey,
    chordCompletions: request.chordCompletions,
    searchController: request.searchController,
    searchFocusNode: request.searchFocusNode,
    searchConfig: request.searchConfig,
    onOpenFile:
        request.onOpenFile ?? (uri) => unawaited(request.api.openFile(uri)),
    onOpenHelp: request.onOpenHelp,
    onOpenSettings: request.onOpenSettings,
    configSectionTarget: request.configSectionTarget,
  );

  @override
  State<ForgeQuickOpen> createState() => _ForgeQuickOpenState();
}

class _ForgeQuickOpenState extends State<ForgeQuickOpen> {
  List<_QuickOpenItem> _results = [];
  int _selectedIndex = 0;
  Timer? _searchDebounce;
  bool _caseSensitive = false;
  bool _wholeWord = false;
  bool _useRegex = false;
  String? _regexError;
  RegExp? _activePattern;

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

  /// The workspace folder files are searched in and shown relative to:
  /// the state's [ForgeWorkspaceRoot], else the file system's root.
  String get _workspaceRootPath {
    return switch (widget.api.state) {
      final ForgeWorkspaceRoot root => root.workspaceRootPath,
      _ => widget.api.fileSystem.root.toFilePath(),
    };
  }

  KeyEventResult _onSearchFieldKeyEvent(FocusNode node, KeyEvent event) {
    return handleKeyEvent(event);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = widget.searchController.text;
    if (widget.mode == ForgeQuickOpenMode.chord) {
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
      case ForgeQuickOpenMode.all:
        _buildAllResults(query);
      case ForgeQuickOpenMode.actions:
        _buildActionResults(query);
      case ForgeQuickOpenMode.chord:
        _buildChordResults(query);
    }
  }

  // ── Mode: all ──

  void _buildAllResults(String query) {
    _preparePattern(query);

    final items = <_QuickOpenItem>[];

    // Open editors.
    items.addAll(_getOpenEditorItems(query));

    // Actions.
    items.addAll(_getActionItems(query));

    // Settings.
    items.addAll(_getSettingItems(query));

    setState(() {
      _results = items;
      _selectedIndex = 0;
    });

    // Async workspace file search (appends results below).
    if (query.length >= 2 && _regexError == null) {
      _searchFiles(query);
    }
  }

  // ── Mode: actions ──

  void _buildActionResults(String query) {
    _preparePattern(query);
    setState(() {
      _results = _getActionItems(query);
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
          final api = widget.api;
          final actionId = binding.action.id;
          widget.onDismiss();
          // Defer to next frame so the dismiss completes before the
          // action runs (avoids crash when the action re-opens the palette).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            api.executeAction(actionId);
          });
        },
      ));
    }

    setState(() {
      _results = items;
      _selectedIndex = 0;
    });
  }

  // ── Helpers ──

  List<_QuickOpenItem> _getActionItems(String query) {
    final commandsById = <String, _QuickOpenItem>{};

    void addAction(ForgeAction action) {
      final binding = widget.api.shortcuts.getBinding(action.id);
      final shortcutText = binding?.displayString ?? _formatShortcut(action.defaultShortcut);
      commandsById[action.id] = _QuickOpenItem(
        id: action.id,
        label: action.label,
        shortcut: shortcutText,
        icon: action.icon ?? Icons.play_arrow,
        type: _ResultType.action,
        onExecute: () {
          // Capture references before dismiss (which may dispose this State).
          final api = widget.api;
          final actionId = action.id;
          final actionFallback = action.execute;
          widget.onDismiss();
          // Defer to next frame so the dismiss completes before the
          // action runs (avoids crash when the action re-opens the palette).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!api.executeAction(actionId)) {
              actionFallback({});
            }
          });
        },
      );
    }

    for (final action in widget.api.actionRegistry.allActions) {
      addAction(action);
    }
    for (final module
        in forgeKitModulesOf(widget.api)?.allKitModules ??
            const <ForgeKitModule>[]) {
      for (final action in module.actions) {
        if (!commandsById.containsKey(action.id)) addAction(action);
      }
    }

    if (query.isEmpty) return commandsById.values.toList();

    return commandsById.values.where((item) {
      return _matches(item.label, query) ||
          _matches(item.id, query);
    }).toList();
  }

  List<_QuickOpenItem> _getSettingItems(String query) {
    // Build searchable setting entries from known preference keys.
    final settings = <_QuickOpenItem>[
      // Shell (section 0) — Appearance
      _settingItem('Theme Mode', 'forge.appearance.themeMode', Icons.palette, 0),
      _settingItem('Max Recent Workspaces', 'forge.startup.maxRecentWorkspaces', Icons.history, 0),
      // Shell (section 0) — Auto Save
      _settingItem('Auto Save: Enabled', 'forge.autoSave.enabled', Icons.save, 0),
      _settingItem('Auto Save: Idle Delay', 'forge.autoSave.idleDelay', Icons.timer, 0),
      _settingItem('Auto Save: On Focus Loss', 'forge.autoSave.saveOnFocusLoss', Icons.visibility_off, 0),
      // Shell (section 0) — Search
      _settingItem('Search: Excluded Extensions', 'forge.search.excludedExtensions', Icons.extension_off, 0),
      _settingItem('Search: Excluded Directories', 'forge.search.excludedDirectories', Icons.folder_off, 0),
      _settingItem('Search: File Size Limit', 'forge.search.fileSizeLimit', Icons.data_usage, 0),
      _settingItem('Search: Max File Results', 'forge.search.maxFileResults', Icons.format_list_numbered, 0),
      _settingItem('Search: Hide Hidden Directories', 'forge.search.excludeHiddenDirectories', Icons.visibility_off, 0),
      _settingItem('Search: Use .gitignore', 'forge.search.excludeGitIgnored', Icons.rule, 0),
      // Terminal (section 1)
      _settingItem('Terminal Shell', 'forge.terminal.defaultShell', Icons.terminal, 1),
      _settingItem('Terminal Start Folder', 'forge.terminal.startFolder', Icons.folder_open, 1),
      _settingItem('Terminal Font Family', 'forge.terminal.fontFamily', Icons.font_download, 1),
      _settingItem('Terminal Font Size', 'forge.terminal.fontSize', Icons.text_fields, 1),
      _settingItem('Terminal Scrollback', 'forge.terminal.scrollbackLines', Icons.swap_vert, 1),
      // Dart Editor (section 2)
      _settingItem('Dart: Font Family', 'forge.editor.dart.fontFamily', Icons.font_download, 2),
      _settingItem('Dart: Font Size', 'forge.editor.dart.fontSize', Icons.format_size, 2),
      _settingItem('Dart: Line Height', 'forge.editor.dart.lineHeight', Icons.height, 2),
      _settingItem('Dart: Tab Size', 'forge.editor.dart.tabSize', Icons.space_bar, 2),
      _settingItem('Dart: Word Wrap', 'forge.editor.dart.wordWrap', Icons.wrap_text, 2),
      _settingItem('Dart: Line Numbers', 'forge.editor.dart.lineNumbers', Icons.format_list_numbered, 2),
      _settingItem('Dart: Highlight Line', 'forge.editor.dart.highlightLine', Icons.highlight, 2),
      _settingItem('Dart: Whitespace', 'forge.editor.dart.showWhitespace', Icons.space_bar, 2),
      // YAML Editor (section 3)
      _settingItem('YAML: Font Family', 'forge.editor.yaml.fontFamily', Icons.font_download, 3),
      _settingItem('YAML: Font Size', 'forge.editor.yaml.fontSize', Icons.format_size, 3),
      _settingItem('YAML: Line Height', 'forge.editor.yaml.lineHeight', Icons.height, 3),
      _settingItem('YAML: Tab Size', 'forge.editor.yaml.tabSize', Icons.space_bar, 3),
      _settingItem('YAML: Word Wrap', 'forge.editor.yaml.wordWrap', Icons.wrap_text, 3),
      _settingItem('YAML: Line Numbers', 'forge.editor.yaml.lineNumbers', Icons.format_list_numbered, 3),
      _settingItem('YAML: Tree Lines', 'forge.editor.yaml.treeLines', Icons.account_tree, 3),
      // Markdown Editor (section 4)
      _settingItem('Markdown: Font Family', 'forge.editor.md.fontFamily', Icons.font_download, 4),
      _settingItem('Markdown: Font Size', 'forge.editor.md.fontSize', Icons.format_size, 4),
      _settingItem('Markdown: Line Height', 'forge.editor.md.lineHeight', Icons.height, 4),
      _settingItem('Markdown: Tab Size', 'forge.editor.md.tabSize', Icons.space_bar, 4),
      _settingItem('Markdown: Word Wrap', 'forge.editor.md.wordWrap', Icons.wrap_text, 4),
      _settingItem('Markdown: Line Numbers', 'forge.editor.md.lineNumbers', Icons.format_list_numbered, 4),
      _settingItem('Markdown: Mermaid', 'forge.editor.md.enableMermaid', Icons.schema, 4),
      _settingItem('Markdown: Math (KaTeX)', 'forge.editor.md.enableMath', Icons.functions, 4),
      // Shortcuts (section 5)
      _settingItem('Shortcuts', 'forge.shortcuts', Icons.keyboard, 5),
      // Chord Shortcuts (section 6)
      _settingItem('Chord Shortcuts', 'forge.shortcuts.chords', Icons.piano, 6),
      // File Types (section 7)
      _settingItem('File Type Defaults', 'forge.editor.fileTypeDefaults', Icons.file_copy, 7),
      // External Tools (section 8)
      _settingItem('External Tools', 'forge.tools', Icons.build_outlined, 8),
    ];

    if (query.isEmpty) return settings;

    return settings.where((item) {
      return _matches(item.label, query) ||
          _matches(item.detail ?? '', query);
    }).toList();
  }

  _QuickOpenItem _settingItem(
    String label,
    String key,
    IconData icon,
    int sectionIndex,
  ) {
    return _QuickOpenItem(
      id: 'setting.$key',
      label: label,
      detail: key,
      icon: icon,
      type: _ResultType.setting,
      onExecute: () {
        final api = widget.api;
        // Tell the config panel which accordion section to expand.
        widget.configSectionTarget?.value = sectionIndex;
        widget.onDismiss();
        // Defer to next frame so the dismiss completes before opening
        // settings (mirrors the action execution pattern).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          api.executeAction('forge.openSettings');
        });
      },
    );
  }

  List<_QuickOpenItem> _getOpenEditorItems(String query) {
    final editors = widget.api.state.openEditors;
    final items = <_QuickOpenItem>[];
    for (final editor in editors) {
      final title = editor.title.value;
      final uriStr = editor.uri.toFilePath();
      // Show relative path from workspace root when possible.
      final wsRoot = _workspaceRootPath;
      final detail = uriStr.startsWith(wsRoot)
          ? uriStr.substring(wsRoot.length)
          : uriStr;
      if (query.isNotEmpty &&
          !_matches(title, query) &&
          !_matches(detail, query)) {
        continue;
      }
      final isDirty = editor.isDirty.value;
      items.add(_QuickOpenItem(
        id: 'editor:${editor.uri}',
        label: isDirty ? '$title ●' : title,
        detail: detail,
        icon: _fileIcon(title),
        type: _ResultType.openEditor,
        onExecute: () {
          widget.onDismiss();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onOpenFile?.call(editor.uri);
          });
        },
      ));
    }
    // Sort by relevance: name starts-with > name contains > path only.
    if (query.isNotEmpty) {
      items.sort((a, b) =>
          _matchPriority(a.label, query).compareTo(_matchPriority(b.label, query)));
    }
    return items;
  }

  Future<void> _searchFiles(String query) async {
    try {
      final workspaceRoot = _workspaceRootPath;
      final config = widget.searchConfig;
      final rootUri = Uri.file(workspaceRoot.endsWith('/')
          ? workspaceRoot
          : '$workspaceRoot/');

      // The .gitignore rules of the workspace, read through its file system.
      final gitIgnore = config.excludeGitIgnored
          ? await forgeLoadGitignores(
              widget.api.fileSystem,
              root: rootUri,
            )
          : null;

      // Capture current search options — they may change during async iteration.
      final pattern = _activePattern;
      final caseSens = _caseSensitive;

      bool matchText(String text) {
        if (pattern != null) return pattern.hasMatch(text);
        if (caseSens) return text.contains(query);
        return text.toLowerCase().contains(query.toLowerCase());
      }

      int sortPriority(String name) {
        if (pattern != null) return pattern.hasMatch(name) ? 0 : 1;
        final n = caseSens ? name : name.toLowerCase();
        final q = caseSens ? query : query.toLowerCase();
        if (n.startsWith(q)) return 0;
        if (n.contains(q)) return 1;
        return 2;
      }

      final fileItems = <_QuickOpenItem>[];
      var count = 0;

      // The folders still to read, breadth first; a folder that is excluded
      // or git-ignored is never read, so its files are never listed.
      final fileSystem = widget.api.fileSystem;
      final folders = <Uri>[rootUri];
      while (folders.isNotEmpty && count < config.maxFileResults) {
        final List<TomFileEntry> entries;
        try {
          entries = await fileSystem.list(folders.removeAt(0));
        } catch (_) {
          continue;
        }
        for (final entity in entries) {
          final entityPath = entity.uri.toFilePath();
          final relativePath = entityPath.startsWith(workspaceRoot)
              ? entityPath.substring(workspaceRoot.length)
              : entityPath;
          // Relative path without leading slash for gitignore matching.
          final relPathClean = relativePath.startsWith('/')
              ? relativePath.substring(1)
              : relativePath;
          if (entity.isDirectory) {
            if (config.isDirectoryExcluded(entity.name)) continue;
            if (gitIgnore != null &&
                gitIgnore.isIgnored(relPathClean, isDirectory: true)) {
              continue;
            }
            if (!entity.linkLeavesRoot) folders.add(entity.uri);
            continue;
          }
          final name = entity.name;

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
          if (entity.size > config.fileSizeLimit) continue;

          if (matchText(name) || matchText(relativePath)) {
            fileItems.add(_QuickOpenItem(
              id: 'file:$entityPath',
              label: name,
              detail: relativePath,
              icon: _fileIcon(name),
              type: _ResultType.file,
              onExecute: () {
                widget.onDismiss();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onOpenFile?.call(Uri.file(entityPath));
                });
              },
            ));
            count++;
            if (count >= config.maxFileResults) break;
          }
        }
      }

      if (!mounted) return;

      // Sort by relevance: name starts-with > name contains > path only.
      fileItems.sort(
          (a, b) => sortPriority(a.label).compareTo(sortPriority(b.label)));

      setState(() {
        // Merge file results with stable section ordering used in the UI:
        // open editors -> files -> actions -> settings.
        final openEditorResults = _results
            .where((r) => r.type == _ResultType.openEditor)
            .toList();
        final actionResults = _results
            .where((r) => r.type == _ResultType.action)
            .toList();
        final settingResults = _results
            .where((r) => r.type == _ResultType.setting)
            .toList();
        _results = [
          ...openEditorResults,
          ...fileItems,
          ...actionResults,
          ...settingResults,
        ];
        // Don't reset _selectedIndex — the user may have already navigated
        // to an action result; only clamp if the list shrank.
        if (_selectedIndex >= _results.length) {
          _selectedIndex = _results.isEmpty ? 0 : _results.length - 1;
        }
      });
    } catch (e, st) {
      // Silently ignore file search errors in production, but allow
      // diagnostics in tests when explicitly enabled.
      if (ForgeQuickOpen.debugEnabled) {
        // ignore: avoid_print
        print('[ForgeQuickOpen] searchFiles error: $e');
        // ignore: avoid_print
        print(st);
      }
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
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    if (key.control && mac) parts.add('⌃');
    if (key.primaryModifier || (key.control && !mac)) {
      parts.add(mac ? '⌘' : 'Ctrl');
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

  // ── Search Options ──

  void _preparePattern(String query) {
    _regexError = null;
    _activePattern = null;
    if (query.isEmpty) return;

    if (_useRegex) {
      try {
        _activePattern = RegExp(query, caseSensitive: _caseSensitive);
      } on FormatException {
        _regexError = 'Invalid regex';
      }
      return;
    }

    if (_wholeWord) {
      final escaped = RegExp.escape(query);
      _activePattern = RegExp(
        '(?:^|[^a-zA-Z0-9])$escaped(?:[^a-zA-Z0-9]|\$)',
        caseSensitive: _caseSensitive,
      );
    }
  }

  bool _matches(String text, String query) {
    if (query.isEmpty) return true;
    if (_regexError != null) return false;
    if (_activePattern != null) return _activePattern!.hasMatch(text);
    if (_caseSensitive) return text.contains(query);
    return text.toLowerCase().contains(query.toLowerCase());
  }

  int _matchPriority(String name, String query) {
    if (query.isEmpty) return 0;
    if (_activePattern != null) {
      return _activePattern!.hasMatch(name) ? 0 : 1;
    }
    final n = _caseSensitive ? name : name.toLowerCase();
    final q = _caseSensitive ? query : query.toLowerCase();
    if (n.startsWith(q)) return 0;
    if (n.contains(q)) return 1;
    return 2;
  }

  void _toggleCaseSensitive() {
    _caseSensitive = !_caseSensitive;
    _buildResults(widget.searchController.text);
  }

  void _toggleWholeWord() {
    _wholeWord = !_wholeWord;
    if (_wholeWord) _useRegex = false;
    _buildResults(widget.searchController.text);
  }

  void _toggleRegex() {
    _useRegex = !_useRegex;
    if (_useRegex) _wholeWord = false;
    _buildResults(widget.searchController.text);
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
    if (widget.mode == ForgeQuickOpenMode.chord) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.mode == ForgeQuickOpenMode.all) _buildSearchOptions(isDark),
          Flexible(
            child: _results.isEmpty
                ? _buildEmpty(isDark)
                : _buildResultList(isDark, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    final label = switch (widget.mode) {
      ForgeQuickOpenMode.all => 'No matching editors, files, actions, or settings',
      ForgeQuickOpenMode.actions => 'No matching actions',
      ForgeQuickOpenMode.chord => 'No matching shortcuts',
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
    final grouped = widget.mode == ForgeQuickOpenMode.all;

    if (!grouped) {
      return _buildFlatList(isDark, theme);
    }

    // Build grouped list: open editors → files → actions → settings.
    final openEditors =
        _results.where((r) => r.type == _ResultType.openEditor).toList();
    final files = _results.where((r) => r.type == _ResultType.file).toList();
    final actions =
        _results.where((r) => r.type == _ResultType.action).toList();
    final settings =
        _results.where((r) => r.type == _ResultType.setting).toList();

    final sections = <Widget>[];
    var runningIndex = 0;

    if (openEditors.isNotEmpty) {
      sections.add(_buildSectionHeader('Open Editors', isDark));
      sections.add(_buildItemGroup(openEditors, runningIndex, isDark, theme));
      runningIndex += openEditors.length;
    }
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
      runningIndex += settings.length;
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: sections,
    );
  }

  Widget _buildFlatList(bool isDark, ThemeData theme) {
    return ListView.builder(
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
    final selectedColor = isDark
        ? const Color(0xFF094771)
        : Colors.blue.withValues(alpha: 0.1);
    return MouseRegion(
      onEnter: (_) => setState(() => _selectedIndex = index),
      child: InkWell(
        onTap: item.onExecute,
        hoverColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: isSelected ? selectedColor : null,
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
      ),
    );
  }

  Widget _buildSearchOptions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          _optionToggle(
            'Aa',
            'Match Case',
            _caseSensitive,
            _toggleCaseSensitive,
            isDark,
          ),
          const SizedBox(width: 4),
          _optionToggle(
            'ab',
            'Match Whole Word',
            _wholeWord,
            _toggleWholeWord,
            isDark,
          ),
          const SizedBox(width: 4),
          _optionToggle(
            '.*',
            'Use Regex',
            _useRegex,
            _toggleRegex,
            isDark,
          ),
          if (_regexError != null) ...[
            const SizedBox(width: 8),
            Text(
              _regexError!,
              style: TextStyle(
                color: Colors.red[300],
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionToggle(
    String label,
    String tooltip,
    bool active,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: active
                ? (isDark
                    ? const Color(0xFF094771)
                    : Colors.blue.withValues(alpha: 0.2))
                : Colors.transparent,
            border: Border.all(
              color: active
                  ? (isDark ? Colors.blue[300]! : Colors.blue)
                  : (isDark ? Colors.grey[600]! : Colors.grey[400]!),
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
              color: active
                  ? (isDark ? Colors.blue[200]! : Colors.blue[700]!)
                  : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
            ),
          ),
        ),
      ),
    );
  }
}
