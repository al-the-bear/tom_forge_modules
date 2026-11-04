/// Deciding inline review marks (CriticMarkup, SOM §11.9.3) in Markdown text
/// through the TomSpecs Dart runtime's annotation API — what a Markdown
/// browser's accept / reject / remove buttons do.
///
/// The text (a block, or a whole file) is held as one content value of a
/// scratch [SpecDocument], so the runtime's own rules decide what the text
/// becomes: accepted changes stay, rejected ones are undone, a removed comment
/// leaves the text it was on, and the whitespace rules hold. Any Markdown file
/// works this way, a TomSpecs document or not: only the marks' text changes.
/// The same rules as the VS Code extension's `review-marks.ts`, run by the
/// runtime in its other language, so both produce the same file.
library;

import 'package:tom_som_dart_runtime/tom_som_dart_runtime.dart';

import 'md_line_edit.dart';

const _scratchPath = 'text';

/// The mark kinds that are changes; highlights and comments are not.
const _changeKinds = {
  SpecMarkKind.insertion,
  SpecMarkKind.deletion,
  SpecMarkKind.substitution,
};

/// What is done with one mark.
enum MdMarkDecision {
  /// Take a change; remove a highlight or a comment, keeping its text.
  accept,

  /// Undo a change.
  reject,

  /// Take a comment (or a highlight's comment) out, keeping the text it was
  /// on — the same act as [accept] on a comment.
  remove,
}

(SpecDocument, SpecReviewAnnotations) _scratch(String text) {
  final doc = SpecDocument()..setContent(_scratchPath, text);
  return (doc, SpecReviewAnnotations(doc));
}

/// The inline marks of [text], in order, as the runtime reads them.
List<SpecMarkEntry> mdListMarks(String text) => _scratch(text).$2.listMarks();

/// [text] with one mark decided: the [occurrence]-th (0-based) mark whose
/// markup is [markup].
MdLineEditResult mdDecideMark(
  String text, {
  required String markup,
  required int occurrence,
  required MdMarkDecision decision,
}) {
  final (doc, notes) = _scratch(text);
  final same = notes.listMarks().where((m) => m.markup == markup).toList();
  if (occurrence < 0 || occurrence >= same.length) {
    return MdLineEditRefused(
      'The mark $markup is not in the text (any more). Reload the document.',
    );
  }
  notes.decideMarks({
    same[occurrence].id: decision == MdMarkDecision.reject
        ? SpecMarkDecision.reject
        : SpecMarkDecision.accept,
  }, revision: notes.revision());
  return MdLineEditApplied(doc.content(_scratchPath) ?? '');
}

/// [text] with every change mark accepted or rejected; highlights and
/// comments stay for their own decision. [decided] is how many changed.
({String text, int decided}) mdDecideAllChanges(
  String text,
  MdMarkDecision decision,
) {
  final (doc, notes) = _scratch(text);
  final changes = notes
      .listMarks()
      .where((m) => _changeKinds.contains(m.markKind))
      .toList();
  if (changes.isEmpty) return (text: text, decided: 0);
  final value = decision == MdMarkDecision.reject
      ? SpecMarkDecision.reject
      : SpecMarkDecision.accept;
  notes.decideMarks({
    for (final m in changes) m.id: value,
  }, revision: notes.revision());
  return (text: doc.content(_scratchPath) ?? '', decided: changes.length);
}

/// [fileText] with one mark of a block decided: lines `startLine..endLine`
/// must still hold [expected] (what the reader was shown); the decided block
/// replaces them.
MdLineEditResult mdReviewMarkEdit(
  String fileText, {
  required int startLine,
  required int endLine,
  required String expected,
  required String markup,
  required int occurrence,
  required MdMarkDecision decision,
}) {
  final guard = MdLineEdit(
    startLine: startLine,
    endLine: endLine,
    expected: expected,
    replacement: expected,
  );
  if (mdApplyLineEdit(fileText, guard) case final MdLineEditRefused refused) {
    return refused;
  }
  final decided = mdDecideMark(
    expected.replaceAll('\r\n', '\n'),
    markup: markup,
    occurrence: occurrence,
    decision: decision,
  );
  return switch (decided) {
    MdLineEditRefused() => decided,
    MdLineEditApplied(:final text) => mdApplyLineEdit(
      fileText,
      MdLineEdit(
        startLine: startLine,
        endLine: endLine,
        expected: expected,
        replacement: text,
      ),
    ),
  };
}
