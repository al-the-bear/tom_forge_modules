import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../../controller/md_editor_controller.dart';
import '../../debug/md_editor_debug.dart';
import '../../models/md_search_result.dart';
import '../../theme/md_editor_theme.dart';

/// Search panel combining a search box with a results list.
class MdSearchPanel extends StatefulWidget {
  const MdSearchPanel({
    super.key,
    required this.controller,
    required this.theme,
    this.showReplace = false,
    this.onResultTapped,
  });

  final MdEditorController controller;
  final MdEditorTheme theme;
  final bool showReplace;
  final ValueChanged<MdSearchResult>? onResultTapped;

  @override
  State<MdSearchPanel> createState() => _MdSearchPanelState();
}

class _MdSearchPanelState extends State<MdSearchPanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(MdSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final basic = widget.theme.basic;
    final results = widget.controller.searchResults;
    final currentIdx = widget.controller.currentSearchIndex;

    return Container(
      color: basic.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SearchBox(
              onSearch: (q) => widget.controller.search(q),
              onNext: widget.controller.nextSearchResult,
              onPrevious: widget.controller.previousSearchResult,
              showReplace: widget.showReplace,
              onReplace:
                  widget.showReplace
                      ? (_, replacement) {
                        widget.controller.replaceCurrentMatch(replacement);
                      }
                      : null,
              matchCount: results.length,
              currentMatch: results.isNotEmpty ? currentIdx + 1 : null,
            ),
          ),
          if (results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (ctx, i) => _buildResultItem(
                  results[i],
                  i == currentIdx,
                  basic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultItem(
    MdSearchResult result,
    bool isCurrent,
    MdBasicTheme basic,
  ) {
    try {
      return InkWell(
        onTap: () => widget.onResultTapped?.call(result),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrent ? basic.selection : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: basic.borderSubtle,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.sectionHeadline,
                style: TextStyle(
                  color: basic.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '…${result.contextBefore}',
                      style: TextStyle(
                        color: basic.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    TextSpan(
                      text: result.matchText,
                      style: TextStyle(
                        color: basic.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        backgroundColor: basic.highlight,
                      ),
                    ),
                    TextSpan(
                      text: '${result.contextAfter}…',
                      style: TextStyle(
                        color: basic.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Line ${result.lineNumber + 1}',
                style: TextStyle(color: basic.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Error building search result item', e, st);
      return const SizedBox.shrink();
    }
  }
}
