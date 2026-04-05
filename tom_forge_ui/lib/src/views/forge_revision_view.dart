import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../defaults/default_system_state.dart';
import '../services/forge_workspace_state_manager.dart';
import '../shell/forge_layout_controller.dart';

/// Panel view showing revision history (backup saves) for the active file.
///
/// Displays a timestamped list of saved revisions; clicking one opens it
/// as a read-only editor for comparison.
class ForgeRevisionView extends ForgeView {
  final ForgeWorkspaceStateManager workspaceState;
  final DefaultSystemState systemState;
  final ForgeLayoutController layoutController;

  final _title = ValueNotifier<String>('Revisions');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeRevisionView({
    required this.workspaceState,
    required this.systemState,
    required this.layoutController,
  });

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.history;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(220, 200),
      );

  @override
  Widget buildMain(BuildContext context) {
    return _RevisionContent(
      workspaceState: workspaceState,
      systemState: systemState,
      layoutController: layoutController,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _RevisionContent extends StatefulWidget {
  final ForgeWorkspaceStateManager workspaceState;
  final DefaultSystemState systemState;
  final ForgeLayoutController layoutController;

  const _RevisionContent({
    required this.workspaceState,
    required this.systemState,
    required this.layoutController,
  });

  @override
  State<_RevisionContent> createState() => _RevisionContentState();
}

class _RevisionContentState extends State<_RevisionContent> {
  List<String> _revisions = [];
  Uri? _currentUri;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.systemState.activeEditorListenable.addListener(_onActiveEditorChanged);
    _onActiveEditorChanged();
  }

  @override
  void dispose() {
    widget.systemState.activeEditorListenable.removeListener(_onActiveEditorChanged);
    super.dispose();
  }

  void _onActiveEditorChanged() {
    final editor = widget.systemState.activeEditor;
    final uri = editor?.uri;
    if (uri == _currentUri) return;
    _currentUri = uri;
    _loadRevisions();
  }

  Future<void> _loadRevisions() async {
    final uri = _currentUri;
    if (uri == null || !widget.workspaceState.isInitialized) {
      setState(() => _revisions = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final revisions = await widget.workspaceState.listRevisions(uri);
      if (mounted && _currentUri == uri) {
        setState(() {
          _revisions = revisions;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatRevisionId(String id) {
    // Revision IDs are timestamps like "20250101_120000".
    if (id.length >= 15 && id.contains('_')) {
      final parts = id.split('_');
      if (parts.length == 2 && parts[0].length == 8 && parts[1].length >= 6) {
        final date = parts[0];
        final time = parts[1];
        return '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)} '
            '${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}';
      }
    }
    return id;
  }

  Future<void> _openRevision(String revisionId) async {
    final uri = _currentUri;
    if (uri == null) return;

    final content = await widget.workspaceState.readRevision(uri, revisionId);
    if (content == null || !mounted) return;

    // Open via a virtual revision URI so it gets a read-only editor.
    final revisionUri = Uri.parse(
      '${uri.toString()}?revision=$revisionId',
    );
    widget.layoutController.openFile(revisionUri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_currentUri == null) {
      return Center(
        child: Text(
          'No file selected',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_revisions.isEmpty) {
      return Center(
        child: Text(
          'No revisions',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _revisions.length,
      itemBuilder: (context, index) {
        final id = _revisions[index];
        return InkWell(
          onTap: () => _openRevision(id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.restore,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatRevisionId(id),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
