/// The raw-file module opens a config editor's backing file through the
/// shell's file system (`tom_specs_editor_specification.md` §12, E2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultShellApi, ForgePlainTextEditor;
import 'package:tom_specs_editor/src/config/raw_file_module.dart';

void main() {
  test('RAW-1: a missing backing file is made (with its folder) in the '
      'shell\'s file system and opened in a plain-text editor over it; an '
      'existing one is opened as it is', () async {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {'.tom/agent_settings.yaml': 'version: 1\n'},
      appName: 'TomSpecs Editor',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final fs = shell.fileSystem;
    final module = RawFileModule()..activate(shell);

    final missing = fs.uriOf('.tom/queue/queue.yaml');
    await module.openRawFile(missing);
    expect(await fs.readText(missing), '');
    final editor = module.editors.single;
    expect(editor, isA<ForgePlainTextEditor>());
    expect(editor.uri, missing);
    expect(shell.systemState.activeEditor, same(editor));

    final existing = fs.uriOf('.tom/agent_settings.yaml');
    await module.openRawFile(existing);
    expect(await fs.readText(existing), 'version: 1\n');
    expect(module.editors.last.uri, existing);
  });
}
