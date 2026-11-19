/// The five file editors under Forge's undo conformance harness, with no
/// check skipped: the Markdown and YAML editors (their controllers keep the
/// history), the plain-text, `.env` and todo-file editors (the file session
/// keeps it).
/// Save saves through the session. The subjects are the package's
/// (`testing.dart`), so an app composing the editors runs the same checks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_file_editors_testing/tom_forge_file_editors_testing.dart';
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show kYamlEditorDebug;

TomForgeShellModule _module() => TomForgeShellModule()
  ..activate(
    DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'File editors',
      navigatorKey: GlobalKey<NavigatorState>(),
    ),
  );

/// A session over [name] holding [text], ready at once.
ForgeFileSession _session(String name, String text) {
  final fs = TomMemoryFileSystem(seed: {name: text});
  return ForgeFileSession(fileSystem: fs, path: name)..adoptText(text);
}

void main() {
  setUp(() => kYamlEditorDebug = false);

  runForgeUndoConformance(
    'Markdown file editor',
    (saved) => ForgeMarkdownFileSubject(
      ForgeMarkdownFileEditor(
        session: _session('notes.md', saved),
        module: _module(),
      ),
    ),
  );
  runForgeUndoConformance(
    'YAML file editor',
    (saved) => ForgeYamlFileSubject(
      ForgeYamlFileEditor(
        session: _session('config.yaml', saved),
        module: _module(),
      ),
    ),
  );
  runForgeUndoConformance(
    'text file editor',
    (saved) => ForgeTextFileSubject(
      ForgePlainTextEditor(
        session: _session('notes.txt', saved),
        module: _module(),
      ),
    ),
  );
  runForgeUndoConformance(
    '.env file editor',
    (saved) => ForgeEnvFileSubject(
      ForgeEnvFileEditor(session: _session('.env', saved), notifications: null),
    ),
  );
  runForgeUndoConformance(
    'todo-file editor',
    (saved) => ForgeTodoFileSubject(
      ForgeTodoFileEditor(
        session: _session('todos.garden.todo.yaml', saved),
        notifications: null,
        openTodo: (_, _) {},
      ),
    ),
  );
}
