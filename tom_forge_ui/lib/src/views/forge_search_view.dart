import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../components/forge_component.dart';
import '../components/forge_view.dart';
import '../services/forge_search_manager.dart';
import '../shell/forge_layout_controller.dart';

/// Search view with query input, toggle options, and results grouped by file.
///
/// Clicking a match opens the file at the match location.
class ForgeSearchView extends ForgeView {
  final ForgeSearchManager searchManager;
  final ForgeLayoutController layoutController;

  final _title = ValueNotifier<String>('Search');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeSearchView({
    required this.searchManager,
    required this.layoutController,
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
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _SearchContent extends StatefulWidget {
  final ForgeSearchManager searchManager;
  final ForgeLayoutController layoutController;

  const _SearchContent({
    required this.searchManager,
    required this.layoutController,
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

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final query = _queryController.text;
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await widget.searchManager.search(
        query,
        isCaseSensitive: _isCaseSensitive,
        isWordMatch: _isWordMatch,
        isRegExp: _isRegExp,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
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
              _buildToggle('Aa', _isCaseSensitive,
                  () => setState(() => _isCaseSensitive = !_isCaseSensitive)),
              _buildToggle('W', _isWordMatch,
                  () => setState(() => _isWordMatch = !_isWordMatch)),
              _buildToggle('.*', _isRegExp,
                  () => setState(() => _isRegExp = !_isRegExp)),
            ],
          ),
        ),
        if (_isSearching)
          const LinearProgressIndicator()
        else
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
          _buildFileHeader(context, result.uri),
          for (final match in result.matches)
            _buildMatch(context, result.uri, match),
        ],
      ],
    );
  }

  Widget _buildFileHeader(BuildContext context, Uri uri) {
    final name =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.path;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 6, bottom: 2),
      child: Text(
        name,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildMatch(
      BuildContext context, Uri uri, ForgeSearchMatch match) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => widget.layoutController.openFile(uri),
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
              child: Text(
                match.lineText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
