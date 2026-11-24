import 'dart:io';

/// The name of the sample file the example opens when its command line names
/// none.
const String sampleFileName = 'settings.yaml';

/// The sample file's first content.
const String sampleFileContent = '''
# The single-window example's sample file: edit it in the structure view or
# as text, undo with the Edit menu or the toolbar, save with File > Save.
name: tom_forge_single_window_example
version: 1
window:
  toolbar: true
  menus: [File, Edit]
''';

/// The sample file under the user's Application Support folder, written with
/// [sampleFileContent] the first time (a file already there is kept, so
/// edits survive a restart).
File sampleFile({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final home = env['HOME'] ?? Directory.current.path;
  final file = File(
    '$home/Library/Application Support/tom_forge_single_window_example/$sampleFileName',
  );
  if (!file.existsSync()) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(sampleFileContent);
  }
  return file;
}
