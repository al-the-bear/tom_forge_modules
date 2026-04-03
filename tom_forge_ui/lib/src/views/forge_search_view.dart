import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../defaults/default_system_state.dart';
import '../services/forge_search_manager.dart';
import '../shell/forge_layout_controller.dart';

/// Search view with query input, toggle options, and results grouped by file.
///
/// Uses streaming search for progressive results: files appear as they are
/// found rather than waiting for the entire search to complete. Clicking a
/// match opens the file at the match location.
class ForgeSearchView extends ForgeView {
  final ForgeSearchManager searchManager;
  final ForgeLayoutController layoutController;
  final DefaultSystemState? systemState;

  /// Workspace root path for displaying relative file paths.
  final String? workspaceRoot;

  final _title = ValueNotifier<String>('Search');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeSearchView({
    required this.searchManager,
    required this.layoutController,
    this.systemState,
    this.workspaceRoot,
  });

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.search;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints(
        preferredSize: Size(400, 300),
      );

  @override
  Widget buildMain(BuildContext context) {
    return _SearchContent(
      searchManager: searchManager,
      layoutController: layoutController,
      systemState: systemState,
      workspaceRoot: workspaceRoot,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _SearchContent extends StatefulWidget {
  final ForgeSearchManager searchManager;
  final ForgeLayoutController layoutController;
  final DefaultSystemState? systemState;
  final String? workspaceRoot;

  const _SearchContent({
    required this.searchManager,
    required this.layoutController,
    this.systemState,
    this.workspaceRoot,
  });

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  final _queryController = TextEditingController();
  bool _isCaseSensitive = false;
  bool _isWordMatch = false;
  bool _isRegExp = false;
  List<ForgeSearchResult> _results = [];
  bool _isSearching = false;
  Timer? _debounceTimer;
  int _totalMatchCount = 0;
  String? _searchError;
  StreamSubscription<ForgeSearchResult>? _searchSubscription;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _cancelSearch();
    _debounceTimer?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _cancelSearch() {
    _searchSubscription?.cancel();
    _searchSubscription = null;
  }

  void _onQueryChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _doSearch();
    });
  }

  Future<void> _doSearch() async {
    final query = _queryController.text;

    // Sync with system state.
    widget.systemState?.setSearchQuery(query);
    widget.systemState?.setSearchActive(query.isNotEmpty);

    // Cancel any in-progress search.
    _cancelSearch();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _totalMatchCount = 0;
        _isSearching = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _results = [];
      _totalMatchCount = 0;
      _searchError = null;
    });

    try {
      final stream = widget.searchManager.searchStream(
        query,
        isCaseSensitive: _isCaseSensitive,
        isWordMatch: _isWordMatch,
        isRegExp: _isRegExp,
      );

      _searchSubscription = stream.listen(
        (result) {
          if (!mounted) return;
          setState(() {
            _results.add(result);
            _totalMatchCount += result.matches.length;
          });
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _searchError = error.toString();
            _isSearching = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isSearching = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  /// Make a file URI relative to the workspace root.
  String _relativePath(Uri uri) {
    final root = widget.workspaceRoot;
    if (root != null) {
      final filePath = uri.toFilePath();
      if (filePath.startsWith(root)) {
        var relative = filePath.substring(root.length);
        if (relative.startsWith('/')) relative = relative.substring(1);
        return relative;
      }
    }
    // Fallback: show full path segments.
    return uri.pathSegments.isNotEmpty
        ? uri.pathSegments.skip(uri.pathSegments.length > 3 ? uri.pathSegments.length - 3 : 0).join('/')
        : uri.path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      style: theme.textTheme.bodySmall,
                      onSubmitted: (_) => _doSearch(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildToggle('Aa', _isCaseSensitive, () {
                    setState(() => _isCaseSensitive = !_isCaseSensitive);
                    _doSearch();
                  }),
                  _buildToggle('W', _isWordMatch, () {
                    setState(() => _isWordMatch = !_isWordMatch);
                    _doSearch();
                  }),
                  _buildToggle('.*', _isRegExp, () {
                    setState(() => _isRegExp = !_isRegExp);
                    _doSearch();
                  }),
                ],
              ),
              if (_results.isNotEmpty || _isSearching || _searchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _searchError != null
                              ? 'Error: $_searchError'
                              : _isSearching
                                  ? '$_totalMatchCount matches in ${_results.length} files (searching...)'
                                  : '$_totalMatchCount matches in ${_results.length} files',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _searchError != null
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isSearching)
                        InkWell(
                          onTap: () {
                            _cancelSearch();
                            setState(() => _isSearching = false);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.stop,
                              size: 14,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_isSearching)
          const LinearProgressIndicator(),
        Expanded(child: _buildResults(context)),
      ],
    );
  }

  Widget _buildToggle(String label, bool active, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        margin: const EdgeInsets.only(left: 2),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primary.withValues(alpha: 0.2) : null,
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
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _queryController.text.isEmpty
              ? 'Type to search'
              : 'No results found',
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
        for (final result in _results) ...[
          _buildFileHeader(context, result),
          for (final match in result.matches)
            _buildMatch(context, result.uri, match),
        ],
      ],
    );
  }

  Widget _buildFileHeader(BuildContext context, ForgeSearchResult result) {
    final theme = Theme.of(context);
    final relativePath = _relativePath(result.uri);
    final name = result.uri.pathSegments.isNotEmpty
        ? result.uri.pathSegments.last
        : result.uri.path;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6, bottom: 2, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (relativePath != name)
                  Text(
                    relativePath,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '${result.matches.length}',
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatch(
      BuildContext context, Uri uri, ForgeSearchMatch match) {
    final theme = Theme.of(context);
    final query = _queryController.text;
    return InkWell(
      onTap: () => widget.layoutController.openFile(
        uri,
        line: match.range.start.line,
        column: match.range.start.column,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
        child: Row(
          children: [
            Text(
              '${match.range.start.line + 1}: ',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
            Expanded(
              child: _buildHighlightedText(
                match.lineText,
                query,
                theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
      String text, String query, ThemeData theme) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    final lowerText = _isCaseSensitive ? text : text.toLowerCase();
    final lowerQuery = _isCaseSensitive ? query : query.toLowerCase();
    var start = 0;

    while (start < text.length) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.2),
          color: theme.colorScheme.primary,
        ),
      ));
      start = idx + query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        children: spans,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
