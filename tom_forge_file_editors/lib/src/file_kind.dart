/// Which of this package's own editors a file opens in, by its name.
library;

/// The kinds of file this package edits with its own editors. Every other
/// kind (Markdown, YAML) comes from the kinds the application registers with
/// the module (`ForgeFileKindRegistry`), asked after `.env` and todo files
/// and before plain text.
enum ForgeFileKind {
  /// A `*.todo.yaml` file: tom_todo_ui's todo-file editor.
  todoFile,

  /// A `.env` file: entries in a table, values hidden until shown.
  env,

  /// Any other text: the plain-text editor (unless a registered kind takes
  /// the file).
  text,
}

/// The kind of the file named [name] (its last path segment) among this
/// package's own: `.env`, a todo file, else [ForgeFileKind.text].
ForgeFileKind forgeFileKindOf(String name) {
  final lower = name.toLowerCase();
  if (lower == '.env' || lower.startsWith('.env.') || lower.endsWith('.env')) {
    return ForgeFileKind.env;
  }
  if (lower.endsWith('.todo.yaml')) return ForgeFileKind.todoFile;
  return ForgeFileKind.text;
}
