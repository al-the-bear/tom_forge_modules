import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_file_system/tom_file_system.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../defaults/default_system_state.dart';
import '../defaults/stub_services.dart';
import '../shell/forge_context_menu_controller.dart';
import '../shell/forge_layout_controller.dart';
import '../widgets/forge_context_menu.dart';

/// File explorer tree view.
///
/// Lists files from [TomFileSystem], with collapsible directories
/// and clickable files that open via [ForgeLayoutController].
/// Supports selection, hover, rename, delete, and file decoration rendering.
class ForgeFileExplorerView extends ForgeView {
  final TomFileSystem fileSystem;
  final ForgeLayoutController layoutController;
  final Uri rootUri;
  final DefaultSystemState? systemState;
  final DefaultFileDecorationManager? fileDecorationManager;

  /// Module context-menu contributions for the rows
  /// ([ForgeContextTarget.explorerFileKind],
  /// [ForgeContextTarget.explorerDirectoryKind]), drawn after the explorer's
  /// own entries. Null draws the explorer's entries alone.
  final ForgeContextMenuController? contextMenus;

  final _title = ValueNotifier<String>('Explorer');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeFileExplorerView({
    required this.fileSystem,
    required this.layoutController,
    required this.rootUri,
    this.systemState,
    this.fileDecorationManager,
    this.contextMenus,
  });

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.folder_outlined;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(250, 400),
      );

  @override
  Widget buildMain(BuildContext context) {
    return _FileExplorerContent(
      fileSystem: fileSystem,
      layoutController: layoutController,
      rootUri: rootUri,
      systemState: systemState,
      fileDecorationManager: fileDecorationManager,
      contextMenus: contextMenus,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _FileExplorerContent extends StatefulWidget {
  final TomFileSystem fileSystem;
  final ForgeLayoutController layoutController;
  final Uri rootUri;
  final DefaultSystemState? systemState;
  final DefaultFileDecorationManager? fileDecorationManager;
  final ForgeContextMenuController? contextMenus;

  const _FileExplorerContent({
    required this.fileSystem,
    required this.layoutController,
    required this.rootUri,
    this.systemState,
    this.fileDecorationManager,
    this.contextMenus,
  });

  @override
  State<_FileExplorerContent> createState() => _FileExplorerContentState();
}

class _FileExplorerContentState extends State<_FileExplorerContent> {
  List<TomFileEntry> _rootEntries = [];
  final Map<String, List<TomFileEntry>> _directoryChildren = {};
  final Set<String> _loadingDirectories = {};
  final Set<String> _expandedDirs = {};
  Uri? _selectedUri;
  Uri? _hoveredUri;
  String? _errorMessage;
  StreamSubscription<Uri?>? _decorationSubscription;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    // Listen for reveal-in-explorer triggers from system state.
    widget.systemState?.selectedExplorerItemsListenable
        .addListener(_onSystemStateChanged);
    // Listen for decoration changes to refresh display.
    _decorationSubscription =
        widget.fileDecorationManager?.onDidChange.listen(_onDecorationChanged);
  }

  @override
  void dispose() {
    _decorationSubscription?.cancel();
    widget.systemState?.selectedExplorerItemsListenable
        .removeListener(_onSystemStateChanged);
    super.dispose();
  }

  void _onDecorationChanged(Uri? uri) {
    // Rebuild to reflect updated decorations.
    if (mounted) setState(() {});
  }

  void _onSystemStateChanged() {
    final items = widget.systemState?.selectedExplorerItems ?? [];
    if (items.isNotEmpty && items.first != _selectedUri) {
      _revealUri(items.first);
    }
  }

  /// Auto-expand directories to reveal [uri] in the tree.
  Future<void> _revealUri(Uri uri) async {
    final rootPath = widget.rootUri.toFilePath();
    var filePath = uri.toFilePath();
    if (!filePath.startsWith(rootPath)) return;

    // Build list of ancestor directories to expand.
    final segments = <String>[];
    var current = filePath;
    while (current != rootPath && current.contains('/')) {
      current = current.substring(0, current.lastIndexOf('/'));
      if (current.length >= rootPath.length) {
        segments.insert(0, current);
      }
    }

    for (final dirPath in segments) {
      if (!_expandedDirs.contains(dirPath)) {
        _expandedDirs.add(dirPath);
        if (!_directoryChildren.containsKey(dirPath)) {
          await _loadDirectoryChildren(dirPath);
        }
      }
    }

    if (mounted) {
      setState(() => _selectedUri = uri);
    }
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await widget.fileSystem.list(widget.rootUri);
      if (mounted) {
        setState(() {
          _rootEntries = _sortEntries(entries);
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to read workspace files.';
        });
      }
    }
  }

  Future<void> _loadDirectoryChildren(String directoryPath) async {
    if (_loadingDirectories.contains(directoryPath)) {
      return;
    }

    setState(() => _loadingDirectories.add(directoryPath));
    try {
      final entries =
          await widget.fileSystem.list(Uri.file(directoryPath));
      if (mounted) {
        setState(() {
          _directoryChildren[directoryPath] = _sortEntries(entries);
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _directoryChildren[directoryPath] = const [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDirectories.remove(directoryPath));
      }
    }
  }

  Future<void> _toggleDirectory(String path, bool isExpanded) async {
    if (isExpanded) {
      setState(() => _expandedDirs.remove(path));
      return;
    }

    setState(() => _expandedDirs.add(path));
    if (!_directoryChildren.containsKey(path)) {
      await _loadDirectoryChildren(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_rootEntries.isEmpty) {
      return const Center(child: Text('No files'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        for (final entry in _rootEntries) _buildEntry(context, entry, 0),
      ],
    );
  }

  Widget _buildEntry(BuildContext context, TomFileEntry entry, int depth) {
    final theme = Theme.of(context);
    final isDirectory = _isDirectoryEntry(entry);
    final path = _absolutePath(entry);
    final name = _nameForPath(path);
    final isExpanded = _expandedDirs.contains(path);
    final childEntries = _directoryChildren[path] ?? const <TomFileEntry>[];
    final isLoading = _loadingDirectories.contains(path);
    final entryUri = Uri.file(path);
    final isSelected = _selectedUri == entryUri;
    final isHovered = _hoveredUri == entryUri;

    // File decorations.
    final decoration = widget.fileDecorationManager?.getDecoration(entryUri);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) {
            setState(() => _hoveredUri = entryUri);
            widget.systemState?.setHoveredExplorerItem(entryUri);
          },
          onExit: (_) {
            if (_hoveredUri == entryUri) {
              setState(() => _hoveredUri = null);
              widget.systemState?.setHoveredExplorerItem(null);
            }
          },
          child: InkWell(
            key: ValueKey<String>('forge-explorer-entry:$path'),
            onTap: () async {
              setState(() => _selectedUri = entryUri);
              widget.systemState?.setSelectedExplorerItems([entryUri]);
              if (isDirectory) {
                await _toggleDirectory(path, isExpanded);
              }
            },
            // Only files react to a double tap (open). Leaving [onDoubleTap]
            // null for directories lets their single-tap toggle fire
            // immediately, instead of waiting out the double-tap disambiguation
            // delay — matching the instant expand/collapse users expect.
            onDoubleTap: isDirectory
                ? null
                : () => widget.layoutController.openFile(entryUri),
            onSecondaryTapDown: (details) {
              _showContextMenu(context, details.globalPosition, entry);
            },
            child: Container(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : isHovered
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                      : null,
              padding:
                  EdgeInsets.only(left: 8.0 + depth * 16.0, top: 2, bottom: 2),
              child: Row(
                children: [
                  if (isDirectory)
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 16,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 2),
                  Icon(
                    isDirectory
                        ? (isExpanded
                            ? Icons.folder_open_outlined
                            : Icons.folder_outlined)
                        : _iconForExtension(name),
                    size: 16,
                    color: decoration?.color ??
                        (isDirectory
                            ? Colors.amber
                            : theme.colorScheme.onSurface),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: decoration?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (decoration?.badge != null)
                    Tooltip(
                      message: decoration!.tooltip ?? '',
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: (decoration.color ?? theme.colorScheme.primary)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          decoration.badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: decoration.color,
                          ),
                        ),
                      ),
                    ),
                  if (isDirectory && isLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isDirectory && isExpanded)
          for (final child in childEntries)
            _buildEntry(context, child, depth + 1),
      ],
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    TomFileEntry entry,
  ) {
    final isDirectory = _isDirectoryEntry(entry);
    final entryUri = entry.uri;
    final path = _absolutePath(entry);
    // The row as a context target, for the modules' contributions: drawn
    // after the explorer's own entries, each enabled by its predicate.
    final contributed = widget.contextMenus?.entriesFor(ForgeContextTarget(
          kind: isDirectory
              ? ForgeContextTarget.explorerDirectoryKind
              : ForgeContextTarget.explorerFileKind,
          data: entryUri,
        )) ??
        const <ForgeContextMenuEntry>[];
    showMenu<Object>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        if (!isDirectory)
          const PopupMenuItem(value: 'open', child: Text('Open')),
        const PopupMenuItem(value: 'rename', child: Text('Rename...')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'newFile', child: Text('New File...')),
        const PopupMenuItem(value: 'newFolder', child: Text('New Folder...')),
        if (contributed.isNotEmpty) ...[
          const PopupMenuDivider(),
          ...forgeContextMenuItems(contributed),
        ],
      ],
    ).then((value) {
      if (value == null || !mounted) return;
      if (value is ForgeContextMenuEntry) {
        value.run();
        return;
      }
      switch (value) {
        case 'open':
          widget.layoutController.openFile(entryUri);
        case 'rename':
          _showRenameDialog(entry);
        case 'delete':
          _showDeleteConfirmation(entry);
        case 'newFile':
          _showNewFileDialog(isDirectory ? path : _parentPath(path));
        case 'newFolder':
          _showNewFolderDialog(isDirectory ? path : _parentPath(path));
      }
    });
  }

  Future<void> _showRenameDialog(TomFileEntry entry) async {
    final name = _nameForPath(_absolutePath(entry));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextPromptDialog(
        title: 'Rename',
        hintText: 'New name',
        confirmLabel: 'Rename',
        initialValue: name,
        selectBaseName: true,
      ),
    );

    if (newName == null || newName.isEmpty || newName == name || !mounted) return;

    try {
      final parentDir = _parentPath(_absolutePath(entry));
      final newPath = '$parentDir/$newName';
      await forgeApplyWorkspaceEdit(widget.fileSystem, ForgeWorkspaceEdit(
          fileOperations: [
            ForgeRenameFileOperation(
              oldUri: entry.uri,
              newUri: Uri.file(newPath),
            ),
          ],
        ),
      );
      await _loadEntries();
      // Reload affected directory children.
      if (_directoryChildren.containsKey(parentDir)) {
        await _loadDirectoryChildren(parentDir);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rename failed: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(TomFileEntry entry) async {
    final name = _nameForPath(_absolutePath(entry));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.fileSystem.delete(entry.uri);
      final parentDir = _parentPath(_absolutePath(entry));
      await _loadEntries();
      if (_directoryChildren.containsKey(parentDir)) {
        await _loadDirectoryChildren(parentDir);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _showNewFileDialog(String parentDir) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _TextPromptDialog(
        title: 'New File',
        hintText: 'filename.dart',
        confirmLabel: 'Create',
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    try {
      final uri = Uri.file('$parentDir/$name');
      await widget.fileSystem.writeText(uri, '');
      if (_directoryChildren.containsKey(parentDir)) {
        await _loadDirectoryChildren(parentDir);
      } else {
        await _loadEntries();
      }
      widget.layoutController.openFile(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create file failed: $e')),
        );
      }
    }
  }

  Future<void> _showNewFolderDialog(String parentDir) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _TextPromptDialog(
        title: 'New Folder',
        hintText: 'folder name',
        confirmLabel: 'Create',
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    try {
      await widget.fileSystem
          .create(Uri.file('$parentDir/$name'), directory: true);
      if (_directoryChildren.containsKey(parentDir)) {
        await _loadDirectoryChildren(parentDir);
      } else {
        await _loadEntries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create folder failed: $e')),
        );
      }
    }
  }

  String _parentPath(String path) {
    final idx = path.lastIndexOf('/');
    return idx > 0 ? path.substring(0, idx) : path;
  }

  /// The entries the explorer shows: hidden ones (a name starting with `.`)
  /// left out, folders first, then by name.
  List<TomFileEntry> _sortEntries(List<TomFileEntry> entries) {
    final sorted = [
      for (final entry in entries)
        if (!entry.name.startsWith('.')) entry,
    ];
    sorted.sort((a, b) {
      final aIsDir = _isDirectoryEntry(a);
      final bIsDir = _isDirectoryEntry(b);
      if (aIsDir != bIsDir) {
        return aIsDir ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  bool _isDirectoryEntry(TomFileEntry entry) => entry.isDirectory;

  String _absolutePath(TomFileEntry entry) => entry.uri.toFilePath();

  String _nameForPath(String path) {
    final parts = path.split('/').where((segment) => segment.isNotEmpty);
    if (parts.isEmpty) {
      return path;
    }
    return parts.last;
  }

  IconData _iconForExtension(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'dart' => Icons.code,
      'yaml' || 'yml' => Icons.settings,
      'md' || 'markdown' => Icons.description,
      'json' => Icons.data_object,
      'txt' => Icons.text_snippet,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

/// A small text-input dialog used by the explorer's New File / New Folder /
/// Rename actions.
///
/// It owns its [TextEditingController] and disposes it in [State.dispose], so
/// the controller stays alive for the whole route lifetime — including the
/// dismiss transition. Creating the controller in the caller and disposing it
/// as soon as `showDialog` returns is unsafe: the route is still animating out
/// and rebuilds the field against the (now disposed) controller.
///
/// Pops the entered text on confirm/submit, or `null` on cancel.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    this.initialValue = '',
    this.selectBaseName = false,
  });

  final String title;
  final String hintText;
  final String confirmLabel;
  final String initialValue;

  /// When true, preselects the name up to (but excluding) its last `.` so a
  /// rename edits the base name while keeping the extension.
  final bool selectBaseName;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.selectBaseName) {
      final name = widget.initialValue;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: name.lastIndexOf('.').clamp(0, name.length),
      );
    }
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      // A `Focus` wrapper submits on Enter even when the field itself does not
      // deliver an `onSubmitted` action (e.g. under a raw hardware key event),
      // matching the input-box overlay's behaviour.
      content: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            _submit();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: widget.hintText,
            isDense: true,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
