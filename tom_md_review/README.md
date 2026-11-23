# Tom Markdown Review

Document reviews for the Markdown editor (`tom_md_editor`): CriticMarkup marks
(SOM §11.9.3) accepted or rejected, and review comments
(`> ⬆️ **C-12** (author): text`) added and edited with ids and author, through
the TomSpecs Dart runtime (`tom_som_dart_runtime`). The file is the same the
VS Code extension's Markdown Browser writes.

```dart
import 'package:tom_md_review/tom_md_review.dart';

controller.addReviewComment(
  blockStart: 2,
  blockEnd: 3,
  text: 'Is this still true?',
  author: mdLocalCommentAuthor(),
);
controller.decideAllReviewChanges(MdMarkDecision.accept);
```

The entry point is the `MdReviewEditing` extension on `MdEditorController`;
each edit is one history entry guarded by the text the reader was shown
(the core's `applyLineEdit`). The text functions (`mdDecideMark`,
`mdAddCommentEdit`, `mdNextCommentId`, ...) work without a controller.

## License

BSD-3-Clause — see [LICENSE](LICENSE).
