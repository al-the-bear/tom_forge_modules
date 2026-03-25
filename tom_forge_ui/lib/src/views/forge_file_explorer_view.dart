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
  List<FileSystemEntity> _entries = [];
  final Set<String> _expandedDirs = {};

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final entries =
          await widget.fileSystem.list(widget.rootUri, recursive: true);
      if (mounted) {
        setState(() => _entries = entries);
      }
    } catch (e) {
      // Silently handle.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return const Center(child: Text('No files'));
    }

    final tree = _buildTree(_entries);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        for (final node in tree) _buildNode(context, node, 0),
      ],
    );
  }

  Widget _buildNode(BuildContext context, _TreeNode node, int depth) {
    final theme = Theme.of(context);
    final isExpanded = _expandedDirs.contains(node.path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            if (node.isDirectory) {
              setState(() {
                if (isExpanded) {
                  _expandedDirs.remove(node.path);
                } else {
                  _expandedDirs.add(node.path);
                }
              });
            } else {
              widget.layoutController
                  .openFile(Uri.parse('file://${node.path}'));
            }
          },
          child: Padding(
            padding: EdgeInsets.only(left: 8.0 + depth * 16.0, top: 2, bottom: 2),
            child: Row(
              children: [
                if (node.isDirectory)
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
                  node.isDirectory
                      ? (isExpanded
                          ? Icons.folder_open_outlined
                          : Icons.folder_outlined)
                      : _iconForExtension(node.name),
                  size: 16,
                  color: node.isDirectory
                      ? Colors.amber
                      : theme.colorScheme.onSurface,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (node.isDirectory && isExpanded)
          for (final child in node.children)
            _buildNode(context, child, depth + 1),
      ],
    );
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

  List<_TreeNode> _buildTree(List<FileSystemEntity> entities) {
    final Map<String, _TreeNode> nodes = {};
    final roots = <_TreeNode>[];

    // Sort: directories first, then alphabetical.
    final sorted = List.of(entities)
      ..sort((a, b) {
        final aIsDir = a.path.endsWith('/') ||
            entities.any((e) =>
                e.path.startsWith('${a.path}/') && e.path != a.path);
        final bIsDir = b.path.endsWith('/') ||
            entities.any((e) =>
                e.path.startsWith('${b.path}/') && e.path != b.path);
        if (aIsDir != bIsDir) return aIsDir ? -1 : 1;
        return a.path.compareTo(b.path);
      });

    for (final entity in sorted) {
      final path = entity.path;
      final name = path.split('/').where((s) => s.isNotEmpty).last;
      final isDir = entity is Directory ||
          entities.any((e) =>
              e.path.startsWith('$path/') && e.path != path);
      final node = _TreeNode(path: path, name: name, isDirectory: isDir);
      nodes[path] = node;

      // Find parent.
      final parentPath = path.contains('/')
          ? path.substring(0, path.lastIndexOf('/'))
          : '';
      final parent = nodes[parentPath];
      if (parent != null) {
        parent.children.add(node);
      } else {
        roots.add(node);
      }
    }

    return roots;
  }
}

class _TreeNode {
  final String path;
  final String name;
  final bool isDirectory;
  final List<_TreeNode> children = [];

  _TreeNode({
    required this.path,
    required this.name,
    required this.isDirectory,
  });
}
