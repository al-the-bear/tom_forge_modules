import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'copy_naming.dart';
import 'website_structure_controller.dart';
import 'website_structure_node.dart';

/// Forge view for the §6b website-structure explorer: a filesystem-driven tree
/// of the active website's `content/` directory on the left, and a detail pane
/// on the right naming the editor a selected file routes to.
///
/// All tree state lives in the [WebsiteStructureController]; this view renders
/// it. Tapping a file node opens its backing file through [onOpenFile] (§6b
/// navigation); editor routing is then automatic via each editor's `canHandle`
/// (`.yaml` → `tom_yaml_editor`, `.md` → `tom_md_editor`), so no per-extension
/// branching lives here. The detail pane names the routing target and offers an
/// **Open in editor** button that re-opens the selected file through the same
/// seam. When [onOpenFile] is `null` (e.g. the view rendered in isolation) taps
/// only update the detail pane. When the active website has no `content:` block
/// the view shows a disabled state. The controller is owned by the module
/// (created in `activate`, disposed in `deactivate`) — the view does not dispose
/// it.
class WebsiteStructureExplorer extends ForgeView {
  WebsiteStructureExplorer({required this.controller, this.onOpenFile});

  /// Owns the structure tree, refresh, and copy-file creation.
  final WebsiteStructureController controller;

  /// Open-file seam: the host wires this to `ForgeLayoutController.openFile`
  /// so a tap on a file node routes it to the matching editor.
  final void Function(Uri uri)? onOpenFile;

  final _title = ValueNotifier<String>('Structure');
  final _titleExtension = ValueNotifier<String?>(null);

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.account_tree_outlined;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        minSize: Size(480, 360),
        preferredSize: Size(720, 640),
      );

  @override
  Widget buildMain(BuildContext context) =>
      _StructureExplorerBody(controller: controller, onOpenFile: onOpenFile);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _StructureExplorerBody extends StatefulWidget {
  const _StructureExplorerBody({required this.controller, this.onOpenFile});

  final WebsiteStructureController controller;
  final void Function(Uri uri)? onOpenFile;

  @override
  State<_StructureExplorerBody> createState() => _StructureExplorerBodyState();
}

class _StructureExplorerBodyState extends State<_StructureExplorerBody> {
  StructureNode? _selection;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    // A refresh rebuilds nodes, so a stale selection must be dropped.
    setState(() => _selection = null);
  }

  bool get _canOpen => widget.onOpenFile != null;

  void _open(Uri uri) => widget.onOpenFile?.call(uri);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.isEnabled) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This website has no "content:" block — the structure explorer is '
            'disabled. Add a content section to tom.website-editor.yaml to '
            'browse its content/ tree.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final error = controller.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) _buildErrorBanner(context, error),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: _buildTreePane(context)),
              const VerticalDivider(width: 1),
              Expanded(child: _buildDetail(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildTreePane(BuildContext context) {
    final allNodes = widget.controller.nodes;
    final nodes = filterStructureNodes(allNodes, _query);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Filter files',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(child: _buildTreeList(context, allNodes, nodes)),
      ],
    );
  }

  Widget _buildTreeList(BuildContext context, List<StructureNode> allNodes,
      List<StructureNode> nodes) {
    if (allNodes.isEmpty) {
      return const Center(child: Text('No content found.'));
    }
    if (nodes.isEmpty) {
      return const Center(child: Text('No files match the filter.'));
    }
    return ListView(
      children: [for (final node in nodes) _buildNode(context, node)],
    );
  }

  Widget _buildNode(BuildContext context, StructureNode node) {
    if (node.kind == StructureNodeKind.file) {
      return ListTile(
        dense: true,
        leading: Icon(_iconFor(node), size: 18),
        title: Text(node.label),
        selected: identical(_selection, node),
        trailing: _fileActions(context, node),
        onTap: node.isOpenable
            ? () {
                setState(() => _selection = node);
                _open(node.uri!);
              }
            : null,
      );
    }
    return ExpansionTile(
      dense: true,
      initiallyExpanded: true,
      leading: Icon(_iconFor(node), size: 18),
      title: Row(
        children: [
          Expanded(child: Text(node.label)),
          if (node.uri != null)
            IconButton(
              icon: const Icon(Icons.add, size: 16),
              tooltip: 'New file in ${node.label}',
              visualDensity: VisualDensity.compact,
              onPressed: () => _createIn(context, node),
            ),
        ],
      ),
      childrenPadding: const EdgeInsets.only(left: 12),
      children: [for (final child in node.children) _buildNode(context, child)],
    );
  }

  Widget? _fileActions(BuildContext context, StructureNode node) {
    if (node.uri == null) return null;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16),
      tooltip: 'File actions',
      onSelected: (value) {
        if (value == 'rename') _renameFile(context, node);
        if (value == 'delete') _deleteFile(context, node);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _createIn(BuildContext context, StructureNode dir) async {
    // The `copy/` section is the grouped node (§16). There a plain file name is
    // not enough — we offer the site-level copy files (home.md, news.md) as
    // one-tap quick-creates so the convention is discoverable, plus a free-form
    // name for everything else.
    if (dir.kind == StructureNodeKind.group) {
      await _createCopy(context, dir);
      return;
    }
    final name = await _promptName(context, title: 'New file', initial: '');
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.controller.createFile(dir.uri!.resolve(name.trim()));
    } catch (e) {
      _showError('Could not create file: $e');
    }
  }

  Future<void> _createCopy(BuildContext context, StructureNode copyGroup) async {
    final existing = copyGroup.children.map((n) => n.label).toSet();
    final result = await showDialog<_CopyCreateResult>(
      context: context,
      builder: (_) => _CopyCreateDialog(existingLabels: existing),
    );
    if (result == null) return;
    try {
      final kind = result.kind;
      if (kind != null) {
        await widget.controller.createCopyFile(kind);
      } else {
        final name = result.name!.trim();
        if (name.isEmpty) return;
        await widget.controller.createFile(copyGroup.uri!.resolve(name));
      }
    } catch (e) {
      _showError('Could not create copy file: $e');
    }
  }

  Future<void> _renameFile(BuildContext context, StructureNode node) async {
    final name =
        await _promptName(context, title: 'Rename file', initial: node.label);
    if (name == null) return;
    try {
      await widget.controller.renameFile(node.uri!, name);
    } catch (e) {
      _showError('Could not rename file: $e');
    }
  }

  Future<void> _deleteFile(BuildContext context, StructureNode node) async {
    if (!await _confirmDelete(context, node.label)) return;
    try {
      await widget.controller.deleteFile(node.uri!);
    } catch (e) {
      _showError('Could not delete file: $e');
    }
  }

  Future<String?> _promptName(BuildContext context,
      {required String title, required String initial}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file'),
        content: Text('Delete "$label"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildDetail(BuildContext context) {
    final node = _selection;
    if (node == null) {
      return const Center(child: Text('Select a file to open it.'));
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(node.label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Opens in ${_editorName(node.editorKind)}',
              style: theme.textTheme.bodySmall),
          if (node.uri != null) ...[
            const SizedBox(height: 8),
            SelectableText(node.uri!.path,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _canOpen ? () => _open(node.uri!) : null,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open in editor'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(StructureNode node) => switch (node.kind) {
        StructureNodeKind.directory => Icons.folder_outlined,
        StructureNodeKind.group => Icons.folder_special_outlined,
        StructureNodeKind.file => switch (node.editorKind) {
            FileEditorKind.yaml => Icons.data_object,
            FileEditorKind.markdown => Icons.article_outlined,
            _ => Icons.insert_drive_file_outlined,
          },
      };

  static String _editorName(FileEditorKind? kind) => switch (kind) {
        FileEditorKind.yaml => 'the YAML editor',
        FileEditorKind.markdown => 'the Markdown editor',
        _ => 'a read-only viewer',
      };
}

/// A small file-name prompt that owns its [TextEditingController] so it is
/// disposed only after the dialog route is fully removed (avoids using a
/// disposed controller during the dialog's exit animation).
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _field =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _field,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'File name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(_field.text),
              child: const Text('OK')),
        ],
      );
}

/// The outcome of [_CopyCreateDialog]: either a site-level copy [kind] to create
/// at its convention path, or a free-form [name] for any other copy file.
class _CopyCreateResult {
  const _CopyCreateResult.kind(this.kind) : name = null;
  const _CopyCreateResult.named(this.name) : kind = null;

  final CopyFileKind? kind;
  final String? name;
}

/// The §16 copy-file creation dialog: site-level copy files (home.md, news.md)
/// as one-tap quick-creates (disabled when they already exist), plus a free-form
/// name field for per-entity and other copy files.
class _CopyCreateDialog extends StatefulWidget {
  const _CopyCreateDialog({required this.existingLabels});

  /// Labels already present in the copy group (e.g. `home`, `news`), used to
  /// disable a quick-create chip for a file that already exists.
  final Set<String> existingLabels;

  @override
  State<_CopyCreateDialog> createState() => _CopyCreateDialogState();
}

class _CopyCreateDialogState extends State<_CopyCreateDialog> {
  late final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('New copy file'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Site-level copy', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in siteLevelCopyKinds)
                ActionChip(
                  key: ValueKey('new-copy-${kind.name}'),
                  avatar: const Icon(Icons.article_outlined, size: 16),
                  label: Text(copyFileName(kind)),
                  onPressed: widget.existingLabels.contains(kind.name)
                      ? null
                      : () => Navigator.of(context)
                          .pop(_CopyCreateResult.kind(kind)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Custom name', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _field,
            decoration: const InputDecoration(labelText: 'File name'),
            onSubmitted: (value) =>
                Navigator.of(context).pop(_CopyCreateResult.named(value)),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_CopyCreateResult.named(_field.text)),
            child: const Text('OK')),
      ],
    );
  }
}
