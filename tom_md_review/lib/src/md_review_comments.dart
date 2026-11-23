/// Reviewer comment blocks (tom_specs annot1, SOM §11.9): a blockquote whose
/// first line starts with the upward arrow, `> ⬆️ **C-12** (Alexis): text`.
/// Id and author are optional when read; written comments carry both. The
/// block ends at the first line without `>` and holds only the comment.
///
/// Ids come from the TomSpecs Dart runtime: the next comment id is the one
/// `SpecReviewAnnotations.nextCommentId` gives the text (annot2) — or the
/// document's highest `C-<n>` after an arrow plus one, or the number a
/// caller read from the loaded SOM document, whichever is highest — so a
/// browser and the agents' tools never hand out the same id twice. The
/// writing rules are the VS Code extension's Markdown Browser's
/// (`blocks.js`), so both write the same file.
library;

import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart';

/// The upward arrow and its emoji variation selector, as written.
const mdCommentArrow = '⬆️';

final _commentStart = RegExp('^ {0,3}> ?⬆️?');
final _quoteLine = RegExp(r'^ {0,3}> ?');
final _commentArrow = RegExp('^\\s*⬆️?');
final _commentIdAfterArrow = RegExp('⬆️?\\s*\\*\\*C-(\\d+)\\*\\*');
final _leadingId = RegExp(r'^\s*\*\*C-\d+\*\*');
final _header = RegExp('^(\\s*⬆️?\\s*\\*\\*C-\\d+\\*\\*)\\s*([\\s\\S]*)\$');

/// Whether [line] starts a comment block.
bool mdIsCommentLine(String line) => _commentStart.hasMatch(line);

/// A comment block in a file: its line range (end exclusive) and its text
/// with the `> ` prefixes removed.
class MdCommentBlock {
  const MdCommentBlock({
    required this.startLine,
    required this.endLine,
    required this.text,
  });

  final int startLine;
  final int endLine;
  final String text;
}

/// The comment block starting at [line] of [lines], or null.
MdCommentBlock? mdCommentAt(List<String> lines, int line) {
  if (line < 0 || line >= lines.length || !mdIsCommentLine(lines[line])) {
    return null;
  }
  var end = line;
  final text = <String>[];
  while (end < lines.length && _quoteLine.hasMatch(lines[end])) {
    text.add(lines[end].replaceFirst(_quoteLine, ''));
    end++;
  }
  return MdCommentBlock(startLine: line, endLine: end, text: text.join('\n'));
}

/// The next free comment id of [text]: the highest of the runtime's
/// `nextCommentId`, the highest `C-<n>` after an arrow plus one, and
/// [runtimeNext] — the number of the next id a caller read from the loaded
/// SOM document.
String mdNextCommentId(String text, {int? runtimeNext}) {
  final doc = SpecDocument()..setContent('text', text);
  final fromRuntime = int.parse(
    SpecReviewAnnotations(doc).nextCommentId().substring(2),
  );
  var highest = 0;
  for (final m in _commentIdAfterArrow.allMatches(text)) {
    final n = int.parse(m.group(1)!);
    if (n > highest) highest = n;
  }
  var next = highest + 1;
  if (fromRuntime > next) next = fromRuntime;
  if (runtimeNext != null && runtimeNext > next) next = runtimeNext;
  return 'C-$next';
}

final _trailingSpace = RegExp(r'\s+$');
final _leadingSpace = RegExp(r'^\s+');

/// A comment's text as it is written into the document: the arrow and an id
/// at the start ([nextId] when it has none), the author after the id when it
/// names none and [author] is given (a named author is kept), every line
/// under `> ` (a blank one as `>`), surrounding blank lines dropped. `''` when
/// the text holds nothing but the arrow, the id and the author — no comment.
String mdWriteComment(String text, String nextId, {String? author}) {
  final lines = text
      .replaceAll(RegExp(r'\r\n|\r'), '\n')
      .split('\n')
      .map((l) => l.replaceFirst(_trailingSpace, ''))
      .toList();
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  if (lines.isEmpty) return '';
  var first = lines.first.replaceFirst(_leadingSpace, '');
  final arrow = _commentArrow.firstMatch(first);
  if (arrow == null) {
    first = '$mdCommentArrow **$nextId** $first';
  } else if (!_leadingId.hasMatch(first.substring(arrow.end))) {
    final rest = first.substring(arrow.end).replaceFirst(RegExp(r'^\s*'), '');
    first =
        '${arrow.group(0)!.replaceFirst(RegExp(r'^\s*'), '')} **$nextId**'
        '${rest.isNotEmpty ? ' $rest' : ''}';
  }
  if (author != null && author.isNotEmpty) {
    final head = _header.firstMatch(first);
    if (head != null && !head.group(2)!.startsWith('(')) {
      final tail = head.group(2)!.replaceFirst(RegExp(r'^:\s*'), '');
      first = '${head.group(1)} ($author):${tail.isNotEmpty ? ' $tail' : ''}';
    }
  }
  lines[0] = first;
  final body = first
      .replaceFirst(_commentArrow, '')
      .replaceFirst(_leadingId, '')
      .replaceFirst(RegExp(r'^\s*\([^)]*\)'), '')
      .replaceFirst(RegExp(r'^\s*:'), '')
      .trim();
  if (body.isEmpty && lines.skip(1).every((l) => l.trim().isEmpty)) return '';
  return lines.map((l) => l.isEmpty ? '>' : '> $l').join('\n');
}

/// The edit that adds a comment after the block on lines
/// `blockStart..blockEnd` of [lines]: a blank line before the comment, and one
/// after it when the next block starts right away (else that block would
/// continue the quote). Null when [text] holds no comment.
MdLineEdit? mdAddCommentEdit(
  List<String> lines, {
  required int blockStart,
  required int blockEnd,
  required String text,
  required String nextId,
  String? author,
}) {
  final written = mdWriteComment(text, nextId, author: author);
  if (written.isEmpty) return null;
  final source = lines.sublist(blockStart, blockEnd).join('\n');
  final next = blockEnd < lines.length ? lines[blockEnd] : null;
  final after = next != null && next.trim().isNotEmpty ? '\n' : '';
  return MdLineEdit(
    startLine: blockStart,
    endLine: blockEnd,
    expected: source,
    replacement: '$source\n\n$written$after',
  );
}

/// The edit that rewrites [comment] with [text]; an empty comment removes it
/// with the blank lines around it, leaving one. Null when nothing changes.
MdLineEdit? mdEditCommentEdit(
  List<String> lines,
  MdCommentBlock comment, {
  required String text,
  required String nextId,
  String? author,
}) {
  if (text == comment.text) return null;
  final written = mdWriteComment(text, nextId, author: author);
  if (written.isNotEmpty) {
    return MdLineEdit(
      startLine: comment.startLine,
      endLine: comment.endLine,
      expected: lines.sublist(comment.startLine, comment.endLine).join('\n'),
      replacement: written,
    );
  }
  final start =
      comment.startLine > 0 && lines[comment.startLine - 1].trim().isEmpty
      ? comment.startLine - 1
      : comment.startLine;
  final end =
      comment.endLine < lines.length && lines[comment.endLine].trim().isEmpty
      ? comment.endLine + 1
      : comment.endLine;
  return MdLineEdit(
    startLine: start,
    endLine: end,
    expected: lines.sublist(start, end).join('\n'),
    replacement: '',
  );
}

/// How the author is written in a comment.
enum MdCommentAuthorForm {
  /// The account's first name.
  first,

  /// The account's full name.
  full,

  /// The login name.
  login,
}

/// The author as written in a comment: the full name's first word, the full
/// name or the login, by [form]; the login when there is no full name.
/// Parentheses are dropped, as they would end the author.
String mdCommentAuthorName(
  MdCommentAuthorForm form, {
  required String fullName,
  required String login,
}) {
  final full = fullName
      .replaceAll(RegExp(r'[()]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final name = form == MdCommentAuthorForm.login || full.isEmpty
      ? login
      : form == MdCommentAuthorForm.first
      ? full.split(' ').first
      : full;
  return name.replaceAll(RegExp(r'[()]'), '').trim();
}

/// The account's full name from what the platform offers: `id -F`'s output on
/// macOS, the GECOS field of the login's `/etc/passwd` line on Linux; `''`
/// elsewhere or when nothing is found.
String mdOsUserFullName({
  required String platform,
  required String login,
  String Function()? runIdF,
  String Function()? readPasswd,
}) {
  try {
    if (platform == 'macos' && runIdF != null) return runIdF().trim();
    if (platform == 'linux' && readPasswd != null) {
      for (final line in readPasswd().split('\n')) {
        final parts = line.split(':');
        if (parts.first == login) {
          return parts.length > 4 ? parts[4].split(',').first.trim() : '';
        }
      }
    }
  } on Object {
    // No full name to be had: the caller falls back to the login.
  }
  return '';
}
