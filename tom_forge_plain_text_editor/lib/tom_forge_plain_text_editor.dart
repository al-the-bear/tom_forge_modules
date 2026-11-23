/// Forge's plain-text editor adapter: [ForgePlainTextEditor] makes the text
/// file editor of `tom_file_editors` (`TomTextFileEditor`) a Forge text
/// editor over the kit (`tom_forge_kit`) — any file Forge has no other editor
/// for, read and saved through its file session — and
/// [ForgePlainTextHighlighter] is the light highlighting it gives JSON, XML,
/// CSS and SQL files.
library;

export 'src/forge_plain_text_editor.dart';
export 'src/plain_text_highlighter.dart';
