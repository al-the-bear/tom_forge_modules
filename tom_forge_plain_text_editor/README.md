# Tom Forge Plain Text Editor

Forge's plain-text editor adapter. `ForgePlainTextEditor` makes the text file
editor of `tom_file_editors` (`TomTextFileEditor`, in `tom_ai/modules`) a
Forge text editor (`ForgeTextEditor`) over the Forge kit: the editor of every
file Forge has no other editor for.

## What it does

- **The file's session.** The editor edits one `ForgeFileSession`: its text,
  its one history (typing merged per burst; a caret move, leaving the source
  or the typing pause ends the burst), dirty as the text against the saved
  text, and a save that checks the disk first and never writes over a file
  changed elsewhere. The editor saves its own file (`getContent()` is null);
  `ForgeSessionFileFrame` shows the file's state above the source: loading,
  missing, refused, read-only with the reason, deleted or changed on disk
  with **Keep mine** / **Take theirs**. A split copy edits the same session.
- **The format.** The header names the encoding (UTF-8, UTF-8 with BOM,
  UTF-16 LE / BE, Latin-1) and the line endings (LF, CRLF, mixed) the file is
  written back with; every untouched byte is kept.
- **Find.** In an application, the find key reaches the application's find
  bar, which searches the text through the editor's `findAll`, shows a match
  through `revealRange` and replaces through `replaceAll` (one undoable
  change); the header's find button opens the source's own find bar. On its
  own the source answers the find key itself.
- **Keys and settings.** With the application's `ForgeKitApi` the undo, redo
  and save actions and their keys go through the application's binding table
  (`ShellEditorIntegration`; a rebound key works at once), and the undo depth
  setting bounds the history. On its own the source answers the undo and
  redo keys itself.
- **The text editor API.** Cursor, selection and selections reported as the
  user leaves them; `setSelection`, `selectAll`, `revealPosition`;
  `insertText`, `replaceRange`, `deleteRange` (each one history entry);
  `saveState` / `restoreState` (caret and selection); text options and
  decorations; the `ForgeDocument` of the session's text.
- **Highlighting.** `ForgePlainTextHighlighter` gives JSON, XML (HTML, SVG,
  XHTML), CSS and SQL files light highlighting, through the one highlighter
  interface (`SyntaxHighlighter`); other files are plain.

## How Forge uses it

The panel shell (`tom_forge_shell`) opens every file no editor type takes in
it (`ForgePlainTextEditor.forFile` over the shell's file system, or
`fromContent` for text outside it), and the file editors module
(`tom_forge_file_editors`) uses it for its text kind. An application or module
makes one itself the same way:

```dart
final editor = ForgePlainTextEditor.forFile(
  fileSystem: fileSystem,
  uri: uri,
  module: module, // its kit API: `api:`, else forgeKitApiOf(module)
);
```

## Testing

`test/undo_conformance_test.dart` runs Forge's undo conformance harness with
no check skipped; `test/forge_plain_text_editor_test.dart` covers each feature
above, `test/plain_text_highlighter_test.dart` the highlighting. The suites run
the editor in the shell of `tom_forge_ui_testing`'s `ForgeFileKindTestBed`
(test support, a dev_dependency).

## Dependencies

`tom_file_editors` (its editor), `tom_forge_kit`, `tom_forge_shared_ui`,
`tom_forge_core`, `tom_editors_shared` and `tom_file_system` — never
`tom_forge_shell` (`tom_forge_app/test/platform_layering_test.dart` PL-8);
test support only as dev_dependencies. Layer 3 of
`tom_ai/forge_modules/_agent_guidelines/platform_architecture.md`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).
