import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/forge_dialog_manager.dart';

/// A VS Code-style quick-pick overlay for selecting from a list of items.
///
/// Shown as a modal overlay at the top center of the shell, similar to the
/// command palette. Supports search filtering and keyboard navigation.
class ForgeQuickPickOverlay<T> extends StatefulWidget {
  final List<ForgeQuickPickItem<T>> items;
  final String? placeholder;
  final bool canSelectMany;
  final Completer<T?> completer;

  const ForgeQuickPickOverlay({
    super.key,
    required this.items,
    this.placeholder,
    this.canSelectMany = false,
    required this.completer,
  });

  @override
  State<ForgeQuickPickOverlay<T>> createState() =>
      _ForgeQuickPickOverlayState<T>();
}

class _ForgeQuickPickOverlayState<T> extends State<ForgeQuickPickOverlay<T>> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<ForgeQuickPickItem<T>> _filtered = [];
  final Set<int> _selected = {};
  int _highlightIndex = 0;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.items;
      } else {
        final lower = query.toLowerCase();
        _filtered = widget.items
            .where((item) =>
                item.label.toLowerCase().contains(lower) ||
                (item.description?.toLowerCase().contains(lower) ?? false))
            .toList();
      }
      _highlightIndex = 0;
    });
  }

  void _dismiss() {
    if (!widget.completer.isCompleted) {
      widget.completer.complete(null);
    }
  }

  void _selectItem(ForgeQuickPickItem<T> item) {
    if (!widget.completer.isCompleted) {
      widget.completer.complete(item.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black26,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: GestureDetector(
              onTap: () {}, // Prevent dismiss on inner tap.
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(6),
                color: theme.colorScheme.surface,
                child: SizedBox(
                  width: 480,
                  child: FocusScope(
                    autofocus: true,
                    child: Focus(
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent &&
                            event is! KeyRepeatEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.escape) {
                          _dismiss();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          setState(() {
                            _highlightIndex =
                                (_highlightIndex + 1).clamp(0, _filtered.length - 1);
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          setState(() {
                            _highlightIndex =
                                (_highlightIndex - 1).clamp(0, _filtered.length - 1);
                          });
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          if (_filtered.isNotEmpty) {
                            _selectItem(_filtered[_highlightIndex]);
                          }
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText:
                                    widget.placeholder ?? 'Select an item...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: _filtered.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'No matching items',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filtered.length,
                                    itemBuilder: (context, index) {
                                      final item = _filtered[index];
                                      final isHighlighted =
                                          index == _highlightIndex;
                                      return _buildItem(
                                        context,
                                        item,
                                        isHighlighted,
                                        index,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    ForgeQuickPickItem<T> item,
    bool isHighlighted,
    int index,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _selectItem(item),
      child: Container(
        color: isHighlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            if (widget.canSelectMany)
              Checkbox(
                value: _selected.contains(index),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(index);
                    } else {
                      _selected.remove(index);
                    }
                  });
                },
                visualDensity: VisualDensity.compact,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isHighlighted ? FontWeight.w600 : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description != null)
                    Text(
                      item.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (item.detail != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  item.detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
