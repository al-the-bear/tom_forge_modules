import 'dart:io';

/// The sample folder the example opens when its command line names none and
/// the current directory is no folder to edit (an app started from the
/// Finder runs in `/`): its files by path relative to the folder.
const Map<String, String> sampleWorkspaceFiles = {
  'config.yaml': '''
# The example's configuration: edit it in the structure view or as text.
name: tom_forge_lite_example
version: 1
features:
  explorer: true
  yaml_editor: true
''',
  'pipelines/build.yml': '''
steps:
  - name: analyze
    run: dart analyze
  - name: test
    run: flutter test
''',
  'README.txt': '''
A sample workspace of the light panel shell example. YAML files open in the
YAML editor; every other file in the shell's plain-text editor.
''',
};

/// The sample folder under the user's Application Support folder, written
/// with [sampleWorkspaceFiles] the first time (files already there are kept,
/// so edits survive a restart).
Directory sampleWorkspaceFolder({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final home = env['HOME'] ?? Directory.current.path;
  final folder = Directory(
    '$home/Library/Application Support/tom_forge_lite_example/sample_workspace',
  );
  for (final MapEntry(key: path, value: content)
      in sampleWorkspaceFiles.entries) {
    final file = File('${folder.path}/$path');
    if (file.existsSync()) continue;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }
  return folder;
}
