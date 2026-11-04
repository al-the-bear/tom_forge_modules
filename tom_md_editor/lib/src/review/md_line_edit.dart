/// An in-place edit of a Markdown file's lines, guarded by the text the
/// reader was shown: lines `startLine..endLine` (0-based, end exclusive) are
/// replaced only while they still hold [MdLineEdit.expected]. A file changed
/// since — in an editor, by another session, by an agent — is refused rather
/// than overwritten.
///
/// A CRLF file keeps its line endings; the comparison ignores them. The same
/// rule as the VS Code extension's Markdown Browser (`markdownBrowserEdits.ts`),
/// so the two produce the same file.
library;

/// One guarded line edit.
class MdLineEdit {
  const MdLineEdit({
    required this.startLine,
    required this.endLine,
    required this.expected,
    required this.replacement,
  });

  /// The first line replaced (0-based).
  final int startLine;

  /// The line after the last one replaced (exclusive).
  final int endLine;

  /// What lines `startLine..endLine` held when shown, joined by `\n`.
  final String expected;

  /// What they become.
  final String replacement;
}

/// How a guarded edit ended.
sealed class MdLineEditResult {
  const MdLineEditResult();
}

/// The edit applied: [text] is the whole file after it.
final class MdLineEditApplied extends MdLineEditResult {
  const MdLineEditApplied(this.text);

  final String text;
}

/// The edit was refused, and nothing changed: [reason] says why, in a sentence
/// a reader can act on.
final class MdLineEditRefused extends MdLineEditResult {
  const MdLineEditRefused(this.reason);

  final String reason;
}

final _lineBreak = RegExp(r'\r?\n');

/// [fileText] with [edit] applied, or the reason it was refused.
MdLineEditResult mdApplyLineEdit(String fileText, MdLineEdit edit) {
  final eol = fileText.contains('\r\n') ? '\r\n' : '\n';
  final lines = fileText.split(_lineBreak);
  final start = edit.startLine;
  final end = edit.endLine;
  if (start < 0 || end < start || end > lines.length) {
    return MdLineEditRefused(
      'Lines ${start + 1}–$end are not in the file (${lines.length} lines). '
      'Reload the document.',
    );
  }
  final current = lines.sublist(start, end).join('\n');
  if (current != edit.expected.replaceAll('\r\n', '\n')) {
    return const MdLineEditRefused(
      'The file changed since it was shown here. Reload the document and try '
      'again.',
    );
  }
  final replacement = edit.replacement
      .replaceAll(RegExp(r'\r\n|\r'), '\n')
      .split('\n');
  final next = [
    ...lines.sublist(0, start),
    ...replacement,
    ...lines.sublist(end),
  ];
  return MdLineEditApplied(next.join(eol));
}
