/// A Markdown file's leading YAML front matter: a `---` line on the file's
/// first line, the lines after it, and a closing `---` (or `...`) line.
///
/// A Markdown parser that does not know the convention reads it as a
/// thematic break followed by a setext heading — `title: Garden overview`
/// above the closing `---` becomes a level-2 heading — so the editor finds
/// the block first and keeps it out of the parse: it is shown verbatim, is
/// not a section and is not in the outline.
class MdFrontMatter {
  const MdFrontMatter._({required this.body, required this.end});

  /// The lines between the two delimiter lines, joined with `\n`.
  final String body;

  /// The offset in the source just after the closing delimiter line,
  /// including its line break when there is one.
  final int end;

  /// The front matter at the start of [markdown], or null when it has none.
  ///
  /// The opening `---` must be the first line (after an optional byte-order
  /// mark), and a closing `---` or `...` line must follow; an unclosed
  /// opening is not front matter. Trailing whitespace on a delimiter line is
  /// allowed, and `\r\n` line endings are read like `\n`.
  static MdFrontMatter? of(String markdown) {
    var offset = markdown.startsWith('﻿') ? 1 : 0;
    final firstEnd = _lineEnd(markdown, offset);
    if (markdown.substring(offset, firstEnd).trimRight() != '---') return null;
    offset = _nextLine(markdown, firstEnd);
    final bodyStart = offset;
    while (offset < markdown.length) {
      final lineEnd = _lineEnd(markdown, offset);
      final line = markdown.substring(offset, lineEnd).trimRight();
      if (line == '---' || line == '...') {
        final body = bodyStart >= offset
            ? ''
            : markdown
                  .substring(bodyStart, offset)
                  .replaceAll('\r\n', '\n')
                  .replaceFirst(RegExp(r'\n$'), '');
        return MdFrontMatter._(body: body, end: _nextLine(markdown, lineEnd));
      }
      offset = _nextLine(markdown, lineEnd);
    }
    return null;
  }

  /// [markdown] with its front matter replaced by a fenced block whose info
  /// string is [infoString], or [markdown] itself when it has none.
  ///
  /// The fence is longer than any backtick run in the body, so a body that
  /// holds backticks cannot close it early.
  static String fence(String markdown, {required String infoString}) {
    final front = of(markdown);
    if (front == null) return markdown;
    var longest = 0;
    for (final run in RegExp('`+').allMatches(front.body)) {
      if (run.group(0)!.length > longest) longest = run.group(0)!.length;
    }
    final fence = '`' * (longest < 3 ? 3 : longest + 1);
    return '$fence$infoString\n${front.body}\n$fence\n\n'
        '${markdown.substring(front.end)}';
  }

  static int _lineEnd(String s, int from) {
    final i = s.indexOf('\n', from);
    final end = i == -1 ? s.length : i;
    return end > from && s.codeUnitAt(end - 1) == 0x0D ? end - 1 : end;
  }

  static int _nextLine(String s, int lineEnd) {
    if (lineEnd < s.length && s.codeUnitAt(lineEnd) == 0x0D) lineEnd++;
    return lineEnd < s.length ? lineEnd + 1 : lineEnd;
  }
}
