/// The file editors of a Forge shell: Forge's Markdown and YAML editors, the
/// plain-text editor, the `.env` editor and the todo-file editor, each editing one file through a
/// `ForgeFileSession` that keeps its bytes and saves it, and the module that
/// opens files in them.
library;

export 'src/env_file_editor.dart';
export 'src/file_editors_module.dart';
export 'src/file_kind.dart';
export 'src/markdown_file_editor.dart';
export 'src/protected_clipboard.dart';
export 'src/session_file.dart';
export 'src/todo_file_editor.dart';
export 'src/yaml_file_editor.dart';
