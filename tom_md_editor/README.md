# Tom Markdown Editor

A Flutter Markdown editor and reader: a rendered view with section navigation,
a raw editor, search and replace, code blocks, tables, math and mermaid
diagrams, DocSpecs schema validation — and in-place document reviews and
workspace browsing.

## Features

- **Editing** — a rendered view and a raw editor over one controller
  (`MdEditorController`) with one history: typing is one undo entry per
  gesture, every other operation one entry, dirty measured against the saved
  text.
- **Reviews** — guarded in-place line edits, CriticMarkup marks accepted or
  rejected and review comments added with ids and author, through the
  TomSpecs Dart runtime (`tom_som_dart_runtime`), giving the same file as the
  VS Code extension's Markdown Browser.
- **Browsing** — links resolved into the workspace (`MdLinkResolver`), back
  and forward with the reading position (`MdBrowserNavigator`), and following
  the end of a growing file such as a live trail (`followTail`,
  `MdFileFollower`).
- **Diagrams and math** — mermaid fences drawn by mermaid.js, LaTeX math.

## Usage

```dart
final controller = MdEditorController(initialMarkdown: '# Notes\n');

MdEditor(controller: controller);

// A review comment after the paragraph on line 2, by this machine's user.
controller.addReviewComment(
  blockStart: 2,
  blockEnd: 3,
  text: 'Is this still true?',
  author: mdLocalCommentAuthor(),
);
```

`doc/md_editor_specification.md` describes every feature; §11 is reviews,
§12 browsing.

## License

BSD-3-Clause — see [LICENSE](LICENSE).
