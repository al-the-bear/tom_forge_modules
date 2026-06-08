import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'website_structure_controller.dart';
import 'website_structure_node.dart';

/// Forge view for the §6b website-structure explorer: a filesystem-driven tree
/// of the active website's `content/` directory on the left, and a detail pane
/// on the right naming the editor a selected file routes to.
///
/// All tree state lives in the [WebsiteStructureController]; this view renders it
/// and (on tap of a file node) shows which editor opens it — `.yaml` →
/// `tom_yaml_editor`, `.md` → `tom_md_editor`. The rich editor widgets are
/// embedded in a later step (§9.6); for now the pane is a functional routing
/// summary. When the active website has no `content:` block the view shows a
/// disabled state. The controller is owned by the module (created in `activate`,
/// disposed in `deactivate`) — the view does not dispose it.
class WebsiteStructureExplorer extends ForgeView {
  WebsiteStructureExplorer({required this.controller});

  /// Owns the structure tree, refresh, and copy-file creation.
  final WebsiteStructureController controller;

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
      _StructureExplorerBody(controller: controller);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _StructureExplorerBody extends StatefulWidget {
  const _StructureExplorerBody({required this.controller});

  final WebsiteStructureController controller;

  @override
  State<_StructureExplorerBody> createState() => _StructureExplorerBodyState();
}

class _StructureExplorerBodyState extends State<_StructureExplorerBody> {
  StructureNode? _selection;

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
              SizedBox(width: 280, child: _buildTree(context)),
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

  Widget _buildTree(BuildContext context) {
    final nodes = widget.controller.nodes;
    if (nodes.isEmpty) {
      return const Center(child: Text('No content found.'));
    }
    return ListView(
      children: [for (final node in nodes) _buildNode(node)],
    );
  }

  Widget _buildNode(StructureNode node) {
    if (node.children.isEmpty) {
      return ListTile(
        dense: true,
        leading: Icon(_iconFor(node), size: 18),
        title: Text(node.label),
        selected: identical(_selection, node),
        onTap: node.isOpenable
            ? () => setState(() => _selection = node)
            : null,
      );
    }
    return ExpansionTile(
      dense: true,
      initiallyExpanded: true,
      leading: Icon(_iconFor(node), size: 18),
      title: Text(node.label),
      childrenPadding: const EdgeInsets.only(left: 12),
      children: [for (final child in node.children) _buildNode(child)],
    );
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
