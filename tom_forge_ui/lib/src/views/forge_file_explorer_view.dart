import 'dart:async';
import 'dart:io' show Directory, FileSystemEntity, FileSystemEntityType;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../defaults/default_system_state.dart';
import '../defaults/stub_services.dart';
import '../shell/forge_layout_controller.dart';

/// File explorer tree view.
///
/// Lists files from [ForgeFileSystem], with collapsible directories
/// and clickable files that open via [ForgeLayoutController].
/// Supports selection, hover, rename, delete, and file decoration rendering.
class ForgeFileExplorerView extends ForgeView {
  final ForgeFileSystem fileSystem;
  final ForgeLayoutController layoutController;
  final Uri rootUri;
  final DefaultSystemState? systemState;
  final DefaultFileDecorationManager? fileDecorationManager;

  final _title = ValueNotifier<String>('Explorer');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeFileExplorerView({
    required this.fileSystem,
    required this.layoutController,
    required this.rootUri,
    this.systemState,
    this.fileDecorationManager,
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
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _FileExplorerContent extends StatefulWidget {
  final ForgeFileSystem fileSystem;
  final ForgeLayoutController layoutController;
  final Uri rootUri;
  final DefaultSystemState? systemState;
  final DefaultFileDecorationManager? fileDecorationManager;

  const _FileExplorerContent({
    required this.fileSystem,
    required this.layoutController,
    required this.rootUri,
    this.systemState,
    this.fileDecorationManager,
  });

  @override
  State<_FileExplorerContent> createState() => _FileExplorerContentState();
}

class _FileExplorerContentState extends State<_FileExplorerContent> {
  List<FileSystemEntity> _rootEntries = [];
  final Map<String, List<FileSystemEntity>> _directoryChildren = {};
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
      final entries = await widget.fileSystem.list(
        widget.rootUri,
        recursive: false,
      );
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
      final entries = await widget.fileSystem.list(
        Uri.file(directoryPath),
        recursive: false,
      );
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

  Widget _buildEntry(BuildContext context, FileSystemEntity entry, int depth) {
    final theme = Theme.of(context);
    final isDirectory = _isDirectoryEntry(entry);
    final path = entry.path;
    final name = _nameForPath(path);
    final isExpanded = _expandedDirs.contains(path);
    final childEntries = _directoryChildren[path] ?? const <FileSystemEntity>[];
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
            onDoubleTap: () {
              if (!isDirectory) {
                widget.layoutController.openFile(entryUri);
              }
            },
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
    FileSystemEntity entry,
  ) {
    final isDirectory = _isDirectoryEntry(entry);
    final entryUri = Uri.file(entry.path);
    showMenu<String>(
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
      ],
    ).then((value) {
      if (value == null || !mounted) return;
      switch (value) {
        case 'open':
          widget.layoutController.openFile(entryUri);
        case 'rename':
          _showRenameDialog(entry);
        case 'delete':
          _showDeleteConfirmation(entry);
        case 'newFile':
          _showNewFileDialog(
            isDirectory ? entry.path : _parentPath(entry.path),
          );
        case 'newFolder':
          _showNewFolderDialog(
            isDirectory ? entry.path : _parentPath(entry.path),
          );
      }
    });
  }

  Future<void> _showRenameDialog(FileSystemEntity entry) async {
    final name = _nameForPath(entry.path);
    final controller = TextEditingController(text: name);
    controller.selection =
        TextSelection(baseOffset: 0, extentOffset: name.lastIndexOf('.').clamp(0, name.length));

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'New name',
            isDense: true,
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Rename')),
        ],
      ),
    );
    controller.dispose();

    if (newName == null || newName.isEmpty || newName == name || !mounted) return;

    try {
      final parentDir = _parentPath(entry.path);
      final newPath = '$parentDir/$newName';
      await widget.fileSystem.applyWorkspaceEdit(
        ForgeWorkspaceEdit(
          fileOperations: [
            ForgeRenameFileOperation(
              oldUri: Uri.file(entry.path),
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

  Future<void> _showDeleteConfirmation(FileSystemEntity entry) async {
    final name = _nameForPath(entry.path);
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
      await widget.fileSystem.delete(Uri.file(entry.path));
      final parentDir = _parentPath(entry.path);
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'filename.dart',
            isDense: true,
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || !mounted) return;

    try {
      final uri = Uri.file('$parentDir/$name');
      await widget.fileSystem.write(uri, '');
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
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'folder name',
            isDense: true,
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || !mounted) return;

    try {
      await Directory('$parentDir/$name').create();
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

  List<FileSystemEntity> _sortEntries(List<FileSystemEntity> entries) {
    final sorted = List<FileSystemEntity>.of(entries);
    sorted.sort((a, b) {
      final aIsDir = _isDirectoryEntry(a);
      final bIsDir = _isDirectoryEntry(b);
      if (aIsDir != bIsDir) {
        return aIsDir ? -1 : 1;
      }
      return _nameForPath(a.path).compareTo(_nameForPath(b.path));
    });
    return sorted;
  }

  bool _isDirectoryEntry(FileSystemEntity entry) {
    try {
      return entry.statSync().type == FileSystemEntityType.directory;
    } catch (_) {
      return false;
    }
  }

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
