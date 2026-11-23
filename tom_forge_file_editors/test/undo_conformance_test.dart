/// The three light file editors under Forge's undo conformance harness,
/// with no check skipped: the plain-text, `.env` and todo-file editors (the
/// file session keeps the history). The Markdown and YAML file kinds run the
/// harness in their adapters (`tom_forge_md_editor`, `tom_forge_yaml_editor`).
/// Save saves through the session. The subjects are the package's
/// (`testing.dart`), so an app composing the editors runs the same checks.
library;

import 'package:flutter/material.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_file_editors_testing/tom_forge_file_editors_testing.dart';
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultShellApi, ForgePlainTextEditor, TomForgeShellModule;

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
