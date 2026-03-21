import '../constants/md_constants.dart';
import '../debug/md_editor_debug.dart';
import 'md_document.dart';
import 'md_section.dart';

/// Parses raw markdown into an [MdDocument] model.
class MdParser {
  MdParser._();

  /// Parse markdown string into structured [MdDocument].
  static MdDocument parse(String markdown) {
    try {
      MdEditorDebug.logger.info('Parsing markdown (${markdown.length} chars)');
      final lines = markdown.split('\n');
      final sections = <MdSection>[];
      String? schemaId;

      var i = 0;
      // Scan leading non-heading lines for schema annotation.
      while (i < lines.length) {
        final line = lines[i].trim();
        if (line.isEmpty) {
          i++;
          continue;
        }
        if (_headingRegex.hasMatch(line)) break;
        final schemaMatch = MdConstants.schemaPattern.firstMatch(line);
        if (schemaMatch != null) {
          schemaId = schemaMatch.group(1);
          i++;
          continue;
        }
        final docspecMatch = MdConstants.docspecPattern.firstMatch(line);
        if (docspecMatch != null) {
          schemaId = docspecMatch.group(1);
          i++;
          continue;
        }
        break;
      }
      while (i < lines.length) {
        final headingMatch = _headingRegex.firstMatch(lines[i]);
        if (headingMatch != null) {
          final level = headingMatch.group(1)!.length;
          var headlineRaw = headingMatch.group(2)!.trim();

          // Detect schema on first heading.
          if (sections.isEmpty && schemaId == null) {
            final schemaMatch = MdConstants.schemaPattern.firstMatch(headlineRaw);
            if (schemaMatch != null) {
              schemaId = schemaMatch.group(1);
              headlineRaw = headlineRaw
                  .replaceFirst(MdConstants.schemaPattern, '')
                  .trim();
            }
          }

          // Extract optional section ID.
          String? sectionId;
          final idMatch = _sectionIdRegex.firstMatch(headlineRaw);
          if (idMatch != null) {
            sectionId = idMatch.group(1) ?? idMatch.group(2);
            headlineRaw =
                headlineRaw.replaceFirst(_sectionIdRegex, '').trim();
          }

          final sectionStart = i;
          i++;

          // Collect body text until the next heading of equal or higher level.
          final bodyLines = <String>[];
          while (i < lines.length) {
            final nextHeading = _headingRegex.firstMatch(lines[i]);
            if (nextHeading != null) break;
            bodyLines.add(lines[i]);
            i++;
          }

          final bodyText = _trimBody(bodyLines);

          sections.add(MdSection(
            headline: headlineRaw,
            level: level,
            id: sectionId,
            text: bodyText,
            sourceLineStart: sectionStart,
            sourceLineEnd: i,
          ));
        } else {
          i++;
        }
      }

      // Build hierarchy from flat list.
      final root = _buildHierarchy(sections);
      final title =
          root.isNotEmpty ? root.first.headline : null;

      MdEditorDebug.logger.info(
        'Parsed ${root.length} top-level sections, '
        '${sections.length} total',
      );

      return MdDocument(
        sections: root,
        title: title,
        schemaId: schemaId,
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Failed to parse markdown', e, st);
      rethrow;
    }
  }

  /// Rebuild markdown string from an [MdDocument].
  static String toMarkdown(MdDocument document) {
    try {
      final buffer = StringBuffer();
      for (var i = 0; i < document.sections.length; i++) {
        if (i > 0) buffer.write('\n\n');
        buffer.write(document.sections[i].toMarkdown());
      }
      return buffer.toString();
    } catch (e, st) {
      MdEditorDebug.logger.error('Failed to generate markdown', e, st);
      rethrow;
    }
  }

  // ── Private helpers ──

  static final RegExp _headingRegex = RegExp(r'^(#{1,6})\s+(.+)$');
  static final RegExp _sectionIdRegex = RegExp(
    r'(?:\[([^\]]+)\]|<!--\s*\[([^\]]+)\]\s*-->)',
  );

  /// Trim leading/trailing blank lines from body text.
  static String _trimBody(List<String> lines) {
    // Remove leading blank lines.
    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }
    // Remove trailing blank lines.
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
  }

  /// Convert a flat list of sections into a nested hierarchy based on levels.
  static List<MdSection> _buildHierarchy(List<MdSection> flat) {
    if (flat.isEmpty) return [];

    final root = <MdSection>[];
    final stack = <MdSection>[];

    for (final section in flat) {
      // Pop stack until we find a parent with a lower level.
      while (stack.isNotEmpty && stack.last.level >= section.level) {
        stack.removeLast();
      }

      if (stack.isEmpty) {
        root.add(section);
      } else {
        stack.last.subsections.add(section);
      }
      stack.add(section);
    }

    return root;
  }
}
