import 'dart:io' show Directory, FileSystemEntity;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../services/forge_file_system.dart';
import '../shell/forge_layout_controller.dart';

/// File explorer tree view.
///
/// Lists files from [ForgeFileSystem], with collapsible directories
/// and clickable files that open via [ForgeLayoutController].
class ForgeFileExplorerView extends ForgeView {
  final ForgeFileSystem fileSystem;
  final ForgeLayoutController layoutController;
  final Uri rootUri;

  final _title = ValueNotifier<String>('Explorer');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeFileExplorerView({
    required this.fileSystem,
    required this.layoutController,
    required this.rootUri,
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
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _FileExplorerContent extends StatefulWidget {
  final ForgeFileSystem fileSystem;
  final ForgeLayoutController layoutController;
  final Uri rootUri;

  const _FileExplorerContent({
    required this.fileSystem,
    required this.layoutController,
    required this.rootUri,
  });

  @override
  State<_FileExplorerContent> createState() => _FileExplorerContentState();
}

class _FileExplorerContentState extends State<_FileExplorerContent> {
  List<FileSystemEntity> _rootEntries = [];
  final Map<String, List<FileSystemEntity>> _directoryChildren = {};
  final Set<String> _loadingDirectories = {};
  final Set<String> _expandedDirs = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEntries();
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
    final isDirectory = entry is Directory;
    final path = entry.path;
    final name = _nameForPath(path);
    final isExpanded = _expandedDirs.contains(path);
    final childEntries = _directoryChildren[path] ?? const <FileSystemEntity>[];
    final isLoading = _loadingDirectories.contains(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () async {
            if (isDirectory) {
              await _toggleDirectory(path, isExpanded);
            } else {
              widget.layoutController.openFile(Uri.file(path));
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: 8.0 + depth * 16.0, top: 2, bottom: 2),
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
                  color: isDirectory
                      ? Colors.amber
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
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
        if (isDirectory && isExpanded)
          for (final child in childEntries)
            _buildEntry(context, child, depth + 1),
      ],
    );
  }

  List<FileSystemEntity> _sortEntries(List<FileSystemEntity> entries) {
    final sorted = List<FileSystemEntity>.of(entries);
    sorted.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;
      if (aIsDir != bIsDir) {
        return aIsDir ? -1 : 1;
      }
      return _nameForPath(a.path).compareTo(_nameForPath(b.path));
    });
    return sorted;
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
