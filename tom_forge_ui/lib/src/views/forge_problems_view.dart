import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../shell/forge_layout_controller.dart';

/// Problems panel showing diagnostics grouped by file.
///
/// Severity icon, message, and source location. Clicking a diagnostic
/// navigates to the file at the diagnostic position.
class ForgeProblemsView extends ForgeView {
  final ForgeDiagnosticManager diagnosticManager;
  final ForgeLayoutController layoutController;

  final _title = ValueNotifier<String>('Problems');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeProblemsView({
    required this.diagnosticManager,
    required this.layoutController,
  }) {
    // Keep the title extension in sync with diagnostic count.
    if (diagnosticManager is DefaultDiagnosticManager) {
      final dm = diagnosticManager as DefaultDiagnosticManager;
      dm.allNotifier.addListener(_updateTitleExtension);
      _updateTitleExtension();
    }
  }

  void _updateTitleExtension() {
    final count = diagnosticManager.all.length;
    _titleExtension.value = count > 0 ? '($count)' : null;
  }

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.error_outline;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(400, 200),
      );

  @override
  Widget buildMain(BuildContext context) {
    return _ProblemsContent(
      diagnosticManager: diagnosticManager,
      layoutController: layoutController,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// Filter mode for the problems panel.
enum _SeverityFilter { all, errors, warnings }

class _ProblemsContent extends StatefulWidget {
  final ForgeDiagnosticManager diagnosticManager;
  final ForgeLayoutController layoutController;

  const _ProblemsContent({
    required this.diagnosticManager,
    required this.layoutController,
  });

  @override
  State<_ProblemsContent> createState() => _ProblemsContentState();
}

class _ProblemsContentState extends State<_ProblemsContent> {
  _SeverityFilter _filter = _SeverityFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _searchIsRegex = false;
  bool _searchFullWord = false;
  bool _searchCaseSensitive = false;
  final Set<ForgeDiagnostic> _selected = {};

  @override
  void initState() {
    super.initState();
    if (widget.diagnosticManager is DefaultDiagnosticManager) {
      final dm = widget.diagnosticManager as DefaultDiagnosticManager;
      dm.allNotifier.addListener(_onDiagnosticsChanged);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.diagnosticManager is DefaultDiagnosticManager) {
      final dm = widget.diagnosticManager as DefaultDiagnosticManager;
      dm.allNotifier.removeListener(_onDiagnosticsChanged);
    }
    super.dispose();
  }

  void _onDiagnosticsChanged() {
    if (mounted) setState(() {});
  }

  List<ForgeDiagnostic> get _filteredDiags {
    // Only show analysis diagnostics (tool results), not system messages.
    var diags = widget.diagnosticManager.all
        .where((d) => d.category == DiagnosticCategory.analysis)
        .toList();
    diags = switch (_filter) {
      _SeverityFilter.all => diags,
      _SeverityFilter.errors =>
        diags.where((d) => d.severity == ForgeSeverity.error).toList(),
      _SeverityFilter.warnings => diags
          .where((d) =>
              d.severity == ForgeSeverity.error ||
              d.severity == ForgeSeverity.warning)
          .toList(),
    };
    if (_searchQuery.isEmpty) return diags;
    final RegExp? pattern = _buildSearchPattern();
    if (pattern == null) return diags;
    return diags.where((d) {
      final fileName = d.uri.pathSegments.isNotEmpty
          ? d.uri.pathSegments.last
          : d.uri.path;
      return pattern.hasMatch(d.message) || pattern.hasMatch(fileName);
    }).toList();
  }

  RegExp? _buildSearchPattern() {
    if (_searchQuery.isEmpty) return null;
    try {
      if (_searchIsRegex) {
        return RegExp(
          _searchQuery,
          caseSensitive: _searchCaseSensitive,
        );
      }
      var query = RegExp.escape(_searchQuery);
      if (_searchFullWord) {
        query = '\\b$query\\b';
      }
      return RegExp(query, caseSensitive: _searchCaseSensitive);
    } catch (_) {
      return null; // Invalid regex
    }
  }

  @override
  Widget build(BuildContext context) {
    final allDiags = _filteredDiags;

    return Column(
      children: [
        _buildToolBar(context),
        Expanded(
          child: allDiags.isEmpty
              ? Center(
                  child: Text(
                    'No problems detected',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                        ),
                  ),
                )
              : _buildDiagnosticList(context, allDiags),
        ),
      ],
    );
  }

  /// Combined filter chips + search bar.
  /// Shows them in one row when wide enough, wraps to two rows when narrow.
  Widget _buildToolBar(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Below 400px, stack vertically.
        final inline = constraints.maxWidth >= 400;
        if (inline) {
          return Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                ..._buildFilterChips(context),
                const SizedBox(width: 8),
                Expanded(child: _buildSearchField(context)),
                const SizedBox(width: 4),
                ..._buildSearchToggles(context),
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterBar(context),
            _buildSearchBar(context),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.diagnosticManager.all;
    final errorCount =
        all.where((d) => d.severity == ForgeSeverity.error).length;
    final warningCount =
        all.where((d) => d.severity == ForgeSeverity.warning).length;
    final infoCount =
        all.where((d) => d.severity == ForgeSeverity.info).length;

    Widget chip(
        _SeverityFilter f, IconData icon, Color color, String label) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => _filter = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          chip(_SeverityFilter.all, Icons.list, theme.colorScheme.onSurface,
              'All (${all.length})'),
          chip(_SeverityFilter.errors, Icons.error, theme.colorScheme.error,
              'Errors ($errorCount)'),
          chip(_SeverityFilter.warnings, Icons.warning_amber, Colors.orange,
              'Warnings ($warningCount)'),
          const Spacer(),
          Text(
            '$infoCount info',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Filter chips for inline toolbar use (no Container wrapper).
  List<Widget> _buildFilterChips(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.diagnosticManager.all;
    final errorCount =
        all.where((d) => d.severity == ForgeSeverity.error).length;
    final warningCount =
        all.where((d) => d.severity == ForgeSeverity.warning).length;

    Widget chip(
        _SeverityFilter f, IconData icon, Color color, String label) {
      final selected = _filter == f;
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => _filter = f),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return [
      chip(_SeverityFilter.all, Icons.list, theme.colorScheme.onSurface,
          'All (${all.length})'),
      chip(_SeverityFilter.errors, Icons.error, theme.colorScheme.error,
          'Errors ($errorCount)'),
      chip(_SeverityFilter.warnings, Icons.warning_amber, Colors.orange,
          'Warnings ($warningCount)'),
    ];
  }

  /// Search text field for inline toolbar use (no Container wrapper).
  Widget _buildSearchField(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 22,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Filter problems...',
          hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          border: const OutlineInputBorder(),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 6, right: 4),
            child: Icon(Icons.search,
                size: 14,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 24, minHeight: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                  }),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.close,
                        size: 14,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5)),
                  ),
                )
              : null,
          suffixIconConstraints:
              const BoxConstraints(minWidth: 22, minHeight: 22),
        ),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  /// Search toggle buttons for inline toolbar use.
  List<Widget> _buildSearchToggles(BuildContext context) {
    final theme = Theme.of(context);

    Widget toggle(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 22,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : null,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return [
      toggle('.*', _searchIsRegex, () {
        setState(() => _searchIsRegex = !_searchIsRegex);
      }),
      toggle('W', _searchFullWord, () {
        setState(() => _searchFullWord = !_searchFullWord);
      }),
      toggle('Aa', _searchCaseSensitive, () {
        setState(() => _searchCaseSensitive = !_searchCaseSensitive);
      }),
    ];
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    Widget toggle(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 22,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color:
                active ? theme.colorScheme.primary.withValues(alpha: 0.2) : null,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 22,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Filter problems...',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: const OutlineInputBorder(),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 4),
                    child: Icon(Icons.search, size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 24, minHeight: 22),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          }),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.close, size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                          ),
                        )
                      : null,
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 22, minHeight: 22),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(width: 4),
          toggle('.*', _searchIsRegex, () {
            setState(() => _searchIsRegex = !_searchIsRegex);
          }),
          toggle('W', _searchFullWord, () {
            setState(() => _searchFullWord = !_searchFullWord);
          }),
          toggle('Aa', _searchCaseSensitive, () {
            setState(() => _searchCaseSensitive = !_searchCaseSensitive);
          }),
        ],
      ),
    );
  }

  Widget _buildDiagnosticList(
      BuildContext context, List<ForgeDiagnostic> diags) {
    // Group by URI.
    final grouped = <Uri, List<ForgeDiagnostic>>{};
    for (final diag in diags) {
      grouped.putIfAbsent(diag.uri, () => []).add(diag);
    }

    // Flatten into a list of display items for virtualized rendering.
    // Each item is either a file header or a diagnostic row.
    final items = <_DiagListItem>[];
    for (final entry in grouped.entries) {
      items.add(_DiagListItem.header(entry.key, entry.value.length));
      for (final diag in entry.value) {
        items.add(_DiagListItem.diagnostic(diag));
      }
    }

    // Show truncation warning for very large diagnostic sets.
    const scalabilityLimit = 10000;
    final truncated = items.length > scalabilityLimit;
    final displayItems =
        truncated ? items.take(scalabilityLimit).toList() : items;

    return Column(
      children: [
        if (truncated)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.orange.withValues(alpha: 0.15),
            child: Text(
              'Showing $scalabilityLimit of ${items.length} items. '
              'Use filters to narrow results.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: displayItems.length,
            itemExtent: null,
            itemBuilder: (context, index) {
              final item = displayItems[index];
              if (item.isHeader) {
                return _buildFileHeader(
                    context, item.uri!, item.headerCount!);
              }
              return _buildDiagnostic(context, item.diagnostic!);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileHeader(BuildContext context, Uri uri, int count) {
    final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.path;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6, bottom: 2),
      child: Row(
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnostic(BuildContext context, ForgeDiagnostic diag) {
    final theme = Theme.of(context);
    final isSelected = _selected.contains(diag);
    final iconData = switch (diag.severity) {
      ForgeSeverity.error => Icons.error,
      ForgeSeverity.warning => Icons.warning_amber,
      ForgeSeverity.info => Icons.info_outline,
      ForgeSeverity.hint => Icons.lightbulb_outline,
    };
    final iconColor = switch (diag.severity) {
      ForgeSeverity.error => theme.colorScheme.error,
      ForgeSeverity.warning => Colors.orange,
      ForgeSeverity.info => theme.colorScheme.primary,
      ForgeSeverity.hint => Colors.grey,
    };

    return GestureDetector(
      onSecondaryTapUp: (details) {
        // Right-click context menu.
        if (!_selected.contains(diag)) {
          setState(() {
            _selected
              ..clear()
              ..add(diag);
          });
        }
        _showContextMenu(context, details.globalPosition);
      },
      child: InkWell(
        onTap: () {
          final isCtrl = HardwareKeyboard.instance.logicalKeysPressed
              .any((k) =>
                  k == LogicalKeyboardKey.controlLeft ||
                  k == LogicalKeyboardKey.controlRight ||
                  k == LogicalKeyboardKey.metaLeft ||
                  k == LogicalKeyboardKey.metaRight);
          if (isCtrl) {
            setState(() {
              if (_selected.contains(diag)) {
                _selected.remove(diag);
              } else {
                _selected.add(diag);
              }
            });
          } else {
            setState(() {
              _selected
                ..clear()
                ..add(diag);
            });
            widget.layoutController.openFile(
              diag.uri,
              line: diag.range.start.line,
              column: diag.range.start.column,
            );
          }
        },
        child: Container(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Icon(iconData, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  diag.message,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (diag.source.isNotEmpty) ...[
                Text(
                  diag.source,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${diag.range.start.line + 1}:${diag.range.start.column + 1}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'copy',
          child: Text('Copy'),
        ),
      ],
    ).then((value) {
      if (value == 'copy' && _selected.isNotEmpty) {
        _copySelectedAsJson();
      }
    });
  }

  void _copySelectedAsJson() {
    final items = _selected.map((diag) {
      final line = diag.range.start.line + 1;
      final column = diag.range.start.column + 1;
      return {
        'file': diag.uri.path,
        'line': line,
        'column': column,
        'message': diag.message,
        'issueType': diag.severity.name,
        'source': diag.source,
      };
    }).toList();

    final json = const JsonEncoder.withIndent('  ').convert(
      items.length == 1 ? items.first : items,
    );
    Clipboard.setData(ClipboardData(text: json));
  }
}

/// Display item for the virtualized problems list.
/// Either a file header or a diagnostic row.
class _DiagListItem {
  final bool isHeader;
  final Uri? uri;
  final int? headerCount;
  final ForgeDiagnostic? diagnostic;

  _DiagListItem._({
    required this.isHeader,
    this.uri,
    this.headerCount,
    this.diagnostic,
  });

  factory _DiagListItem.header(Uri uri, int count) =>
      _DiagListItem._(isHeader: true, uri: uri, headerCount: count);

  factory _DiagListItem.diagnostic(ForgeDiagnostic diag) =>
      _DiagListItem._(isHeader: false, diagnostic: diag);
}
