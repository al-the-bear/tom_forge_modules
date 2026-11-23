import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../shell/forge_system_state.dart';

/// Outline view showing symbol tree for the active editor.
///
/// Updates when the active editor changes. Shows "No outline available"
/// when no provider matches.
class ForgeOutlineView extends ForgeView {
  final DefaultOutlineManager outlineManager;
  final ForgeSystemState systemState;

  final _title = ValueNotifier<String>('Outline');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeOutlineView({
    required this.outlineManager,
    required this.systemState,
  });

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.account_tree;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(220, 400),
      );

  @override
  Widget buildMain(BuildContext context) {
    return _OutlineContent(
      outlineManager: outlineManager,
      systemState: systemState,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _OutlineContent extends StatefulWidget {
  final DefaultOutlineManager outlineManager;
  final ForgeSystemState systemState;

  const _OutlineContent({
    required this.outlineManager,
    required this.systemState,
  });

  @override
  State<_OutlineContent> createState() => _OutlineContentState();
}

class _OutlineContentState extends State<_OutlineContent> {
  List<ForgeOutlineItem> _items = [];
  StreamSubscription<EditorListChangeEvent>? _editorSubscription;
  StreamSubscription<void>? _outlineChangeSubscription;
  StreamSubscription<FocusChangeEvent>? _focusSubscription;

  @override
  void initState() {
    super.initState();
    _loadOutline();
    _editorSubscription =
        widget.systemState.onEditorsChanged.listen((_) => _loadOutline());
    _focusSubscription =
      widget.systemState.onFocusChanged.listen((_) => _loadOutline());
    // Listen for outline provider content changes.
    _outlineChangeSubscription =
        widget.outlineManager.onDidChange.listen((_) => _loadOutline());
  }

  @override
  void dispose() {
    _editorSubscription?.cancel();
    _focusSubscription?.cancel();
    _outlineChangeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOutline() async {
    final activeEditor = widget.systemState.activeEditor;
    if (activeEditor == null) {
      if (mounted) setState(() => _items = []);
      return;
    }

    try {
      final items = await widget.outlineManager.provideOutline(activeEditor);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _items = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return Center(
        child: Text(
          'No outline available',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        for (final item in _items) _buildItem(context, item, 0),
      ],
    );
  }

  Widget _buildItem(BuildContext context, ForgeOutlineItem item, int depth) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              EdgeInsets.only(left: 8.0 + depth * 16.0, top: 2, bottom: 2),
          child: Row(
            children: [
              Icon(_iconForKind(item.kind), size: 14,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.detail != null)
                Text(
                  item.detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        for (final child in item.children)
          _buildItem(context, child, depth + 1),
      ],
    );
  }

  IconData _iconForKind(ForgeSymbolKind kind) {
    return switch (kind) {
      ForgeSymbolKind.classKind => Icons.class_outlined,
      ForgeSymbolKind.method => Icons.functions,
      ForgeSymbolKind.function => Icons.functions,
      ForgeSymbolKind.property => Icons.edit_note,
      ForgeSymbolKind.field => Icons.text_fields,
      ForgeSymbolKind.variable => Icons.abc,
      ForgeSymbolKind.constant => Icons.lock_outline,
      ForgeSymbolKind.enumKind => Icons.list,
      ForgeSymbolKind.constructor => Icons.build_outlined,
      ForgeSymbolKind.interface => Icons.integration_instructions,
      ForgeSymbolKind.section => Icons.title,
      _ => Icons.code,
    };
  }
}
