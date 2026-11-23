# Tom Markdown Editor

A Flutter Markdown editor and reader: a rendered view with section navigation,
a raw editor, search and replace, code blocks and tables, guarded in-place
edits and workspace browsing. Diagrams, math, DocSpecs schemas, reviews and
documents on a web server come as plugin packages, which the editor does not
depend on.

## Features

- **Editing** — a rendered view and a raw editor over one controller
  (`MdEditorController`) with one history: typing is one undo entry per
  gesture, every other operation one entry, dirty measured against the saved
  text.
- **Guarded line edits** — `applyLineEdit` replaces lines only while they
  still hold what the reader was shown, so a file changed since is refused,
  never overwritten.
- **Browsing** — links resolved into the workspace (`MdLinkResolver`), back
  and forward with the reading position (`MdBrowserNavigator`), and following
  the end of a growing file such as a live trail (`followTail`,
  `MdFileFollower`).
- **Extension points** — content plugins (`MdContentPlugin`: a fenced or
  preprocessed block, inline syntax), document providers
  (`MdDocumentProvider`) and a document schema (`MdSchemaSupport`).

## Plugins

Each heavy feature is its own package; add the ones you want:

| Package | What it brings | How to add it |
| ------- | -------------- | ------------- |
| `tom_md_mermaid` | Mermaid diagrams drawn by mermaid.js in a webview | `MdEditor(plugins: [mdMermaidPlugin()])` |
| `tom_md_math` | LaTeX math, `$$…$$` and `$…$` | `MdEditor(plugins: [mdMathPlugin()])` |
| `tom_md_docspecs` | DocSpecs schemas: validation, typed sections, forms, scaffolding | `controller.setSchema(schema)` |
| `tom_md_review` | CriticMarkup marks and review comments, as the VS Code Markdown Browser writes them | `controller.addReviewComment(...)` (import the package) |
| `tom_md_http` | A document on a web server (GET to open, PUT to save) | `MdEditor(documentProvider: HttpDocumentProvider(url: ...))` |

Without them the editor shows the document as Markdown: a Mermaid fence is a
code block, math its LaTeX source, review markup its text.

## Usage

```dart
final controller = MdEditorController(initialMarkdown: '# Notes\n');

MdEditor(
  controller: controller,
  plugins: [mdMermaidPlugin(), mdMathPlugin()],
);
```

`doc/how_to_embed.md` shows each plugin in an application;
`doc/md_editor_specification.md` describes every feature.

## License

BSD-3-Clause — see [LICENSE](LICENSE).
