/// Document reviews for the Markdown editor (`tom_md_editor`): CriticMarkup
/// marks accepted or rejected and review comments added with ids and author,
/// through the TomSpecs Dart runtime (`tom_som_dart_runtime`), giving the
/// same file as the VS Code extension's Markdown Browser.
///
/// The entry point is the [MdReviewEditing] extension on the editor's
/// controller (`controller.addReviewComment(...)`,
/// `controller.decideReviewMark(...)`); the functions below it work on text.
/// Importing the package registers nothing.
library;

export 'src/md_local_author.dart';
export 'src/md_review_comments.dart';
export 'src/md_review_editing.dart';
export 'src/md_review_marks.dart';
