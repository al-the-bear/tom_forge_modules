import 'package:tom_md_editor/tom_md_editor.dart';

import 'md_review_comments.dart';
import 'md_review_marks.dart';

/// Reviewing the document of an [MdEditorController] in place: CriticMarkup
/// marks decided through the TomSpecs runtime and review comments added or
/// edited with ids and author.
///
/// Each edit is guarded by the text the reader was shown
/// ([MdEditorController.applyLineEdit]) and is one history entry; a refusal
/// changes nothing.
extension MdReviewEditing on MdEditorController {
  /// Decides the [occurrence]-th mark written [markup] in the block on lines
  /// `startLine..endLine` (which must still hold [expected]), through the
  /// TomSpecs runtime; one history entry.
  MdLineEditResult decideReviewMark({
    required int startLine,
    required int endLine,
    required String expected,
    required String markup,
    required int occurrence,
    required MdMarkDecision decision,
  }) {
    flush();
    final result = mdReviewMarkEdit(
      markdown,
      startLine: startLine,
      endLine: endLine,
      expected: expected,
      markup: markup,
      occurrence: occurrence,
      decision: decision,
    );
    if (result case MdLineEditApplied(:final text)) applyEdit(text);
    return result;
  }

  /// Accepts or rejects every change mark of the document (highlights and
  /// comments stay) as one history entry; answers how many were decided.
  int decideAllReviewChanges(MdMarkDecision decision) {
    flush();
    final result = mdDecideAllChanges(markdown, decision);
    if (result.decided > 0) applyEdit(result.text);
    return result.decided;
  }

  /// The id the next review comment gets ([mdNextCommentId]); [runtimeNext]
  /// is the number a caller read from the loaded SOM document.
  String nextReviewCommentId({int? runtimeNext}) =>
      mdNextCommentId(markdown, runtimeNext: runtimeNext);

  /// Adds a review comment with [text] by [author] after the block on lines
  /// `blockStart..blockEnd`, with the next free id; one history entry. Null
  /// when [text] holds no comment.
  MdLineEditResult? addReviewComment({
    required int blockStart,
    required int blockEnd,
    required String text,
    String? author,
    int? runtimeNext,
  }) {
    flush();
    final edit = mdAddCommentEdit(
      markdown.split('\n'),
      blockStart: blockStart,
      blockEnd: blockEnd,
      text: text,
      nextId: nextReviewCommentId(runtimeNext: runtimeNext),
      author: author,
    );
    return edit == null ? null : applyLineEdit(edit);
  }

  /// Rewrites the comment block starting at [line] with [text]; an empty
  /// [text] removes it. Null when there is no comment there or nothing
  /// changes.
  MdLineEditResult? editReviewComment({
    required int line,
    required String text,
    String? author,
    int? runtimeNext,
  }) {
    flush();
    final lines = markdown.split('\n');
    final comment = mdCommentAt(lines, line);
    if (comment == null) return null;
    final edit = mdEditCommentEdit(
      lines,
      comment,
      text: text,
      nextId: nextReviewCommentId(runtimeNext: runtimeNext),
      author: author,
    );
    return edit == null ? null : applyLineEdit(edit);
  }
}
