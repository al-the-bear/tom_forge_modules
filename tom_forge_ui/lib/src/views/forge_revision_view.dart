import 'dart:async';

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
  final Stream<Uri>? onDidSave;

  final _title = ValueNotifier<String>('Revisions');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeRevisionView({
    required this.workspaceState,
    required this.systemState,
    required this.layoutController,
    this.onDidSave,
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
      onDidSave: onDidSave,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _RevisionContent extends StatefulWidget {
  final ForgeWorkspaceStateManager workspaceState;
  final DefaultSystemState systemState;
  final ForgeLayoutController layoutController;
  final Stream<Uri>? onDidSave;

  const _RevisionContent({
    required this.workspaceState,
    required this.systemState,
    required this.layoutController,
    this.onDidSave,
  });

  @override
  State<_RevisionContent> createState() => _RevisionContentState();
}

class _RevisionContentState extends State<_RevisionContent> {
  List<String> _revisions = [];
  Uri? _currentUri;
  bool _loading = false;
  StreamSubscription<Uri>? _saveSubscription;

  @override
  void initState() {
    super.initState();
    widget.systemState.activeEditorListenable.addListener(_onActiveEditorChanged);
    _saveSubscription = widget.onDidSave?.listen(_onFileSaved);
    _onActiveEditorChanged();
  }

  @override
  void dispose() {
    _saveSubscription?.cancel();
    widget.systemState.activeEditorListenable.removeListener(_onActiveEditorChanged);
    super.dispose();
  }

  void _onFileSaved(Uri uri) {
    // Reload revisions when the currently displayed file is saved.
    if (uri == _currentUri) {
      _loadRevisions();
    }
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
    // Revision IDs are millisecondsSinceEpoch strings.
    final millis = int.tryParse(id);
    if (millis != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(millis);
      final y = dt.year.toString();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min:$s';
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
