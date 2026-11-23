# Changelog

## 0.1.0

- `ForgePlainTextEditor`, the plain-text editor the panel shell falls back
  to, as an adapter of its own over the kit: `tom_file_editors`'
  `TomTextFileEditor` in a `ForgeSessionFileFrame`, replacing the shell's own
  `ForgePlainTextEditor` with every feature kept (the session's one history
  and typing pause, dirty state, the save that checks the disk, the external
  change choice, read-only files, the text editor API, find through the
  application's find bar, the keys through the application's binding table,
  the undo depth setting) and the encoding and line endings now named in the
  header. It takes a `ForgeKitModule` (and optionally the `ForgeKitApi`,
  `api:`) where it took the shell's `ForgeModule`.
- `ForgePlainTextHighlighter`: the JSON, XML, CSS and SQL highlighting the
  shell's editor had, through the `SyntaxHighlighter` interface.
