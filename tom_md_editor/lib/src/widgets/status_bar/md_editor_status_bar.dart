import 'package:flutter/material.dart';

import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../../controller/md_editor_controller.dart';
import '../../models/md_document.dart';
import '../../models/md_section.dart';
import '../../theme/md_editor_theme.dart';

/// Status bar displaying document metadata and validation state.
///
/// Shows current section path, word/character/line counts,
/// validation error count, and read-only status.
class MdEditorStatusBar extends StatelessWidget {
  const MdEditorStatusBar({
    super.key,
    required this.controller,
    required this.theme,
    this.readOnly = false,
    this.validationErrors = const [],
  });

  final MdEditorController controller;
  final MdEditorTheme theme;
  final bool readOnly;
  final List<ValidationError> validationErrors;

  @override
  Widget build(BuildContext context) {
    final basic = theme.basic;
    final doc = controller.document;
    final selected = controller.selectedSection;
    final stats = _computeStats(doc);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: basic.surfaceVariant,
        border: Border(
          top: BorderSide(color: basic.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (selected != null) ...[
            Icon(Icons.segment, size: 14, color: basic.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _sectionPath(selected, doc),
                style: TextStyle(fontSize: 12, color: basic.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Text(
            '${stats.words} words',
            style: TextStyle(fontSize: 12, color: basic.textMuted),
          ),
          const SizedBox(width: 12),
          Text(
            '${stats.chars} chars',
            style: TextStyle(fontSize: 12, color: basic.textMuted),
          ),
          const SizedBox(width: 12),
          Text(
            '${stats.lines} lines',
            style: TextStyle(fontSize: 12, color: basic.textMuted),
          ),
          const Spacer(),
          if (validationErrors.isNotEmpty) ...[
            Icon(Icons.warning_amber, size: 14, color: basic.error),
            const SizedBox(width: 4),
            Text(
              '${validationErrors.length} issue${validationErrors.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: basic.error),
            ),
            const SizedBox(width: 12),
          ],
          if (readOnly) ...[
            Icon(Icons.lock, size: 14, color: basic.textMuted),
            const SizedBox(width: 4),
            Text(
              'Read-only',
              style: TextStyle(fontSize: 12, color: basic.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the breadcrumb path for the selected section.
  String _sectionPath(MdSection section, MdDocument doc) {
    final parts = <String>[];
    _collectParentPath(section, doc.sections, parts);
    return parts.reversed.join(' > ');
  }

  void _collectParentPath(
    MdSection target,
    List<MdSection> sections,
    List<String> parts,
  ) {
    for (final s in sections) {
      if (s.id == target.id) {
        parts.add(s.headline);
        return;
      }
      if (s.subsections.isNotEmpty) {
        final before = parts.length;
        _collectParentPath(target, s.subsections, parts);
        if (parts.length > before) {
          parts.add(s.headline);
          return;
        }
      }
    }
  }

  _DocStats _computeStats(MdDocument doc) {
    final all = doc.allSections;
    var words = 0;
    var chars = 0;
    var lines = 0;
    for (final s in all) {
      final text = '${s.headline}\n${s.text}';
      chars += text.length;
      lines += '\n'.allMatches(text).length + 1;
      words += text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
    }
    return _DocStats(words: words, chars: chars, lines: lines);
  }
}

class _DocStats {
  const _DocStats({
    required this.words,
    required this.chars,
    required this.lines,
  });

  final int words;
  final int chars;
  final int lines;
}
