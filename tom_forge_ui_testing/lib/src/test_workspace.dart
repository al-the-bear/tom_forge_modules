import 'dart:io';

/// Generates a temporary file structure for integration testing.
///
/// Creates a workspace directory with common file types (markdown, dart,
/// yaml, json) to test editor resolution and file handling.
class ForgeTestWorkspace {
  final Directory root;

  ForgeTestWorkspace(this.root);

  /// Create a temporary workspace with sample files.
  static Future<ForgeTestWorkspace> create() async {
    final dir = await Directory.systemTemp.createTemp('forge_test_');
    final workspace = ForgeTestWorkspace(dir);
    await workspace._populate();
    return workspace;
  }

  Future<void> _populate() async {
    await _createFile('readme.md', '# Test Workspace\n\nThis is a test.');
    await _createFile(
      'config.yaml',
      'name: test\nversion: 1\ndescription: Test config',
    );
    await _createFile('main.dart', 'void main() {\n  print("Hello");\n}');
    await _createFile('data.json', '{"key": "value"}');
    await _createFile('sample.test', 'Test file content');

    // Nested structure.
    await _createFile('src/lib.dart', 'library test;');
    await _createFile('src/utils.dart', '// Utilities');
    await _createFile('docs/guide.md', '# Guide\n\nGetting started.');

    // Schema files.
    await _createFile(
      'schema/form.yaml',
      '# schema: form-v2\nfields:\n  - name: title',
    );
    await _createFile(
      'schema/workflow.yaml',
      '# schema: workflow\nsteps:\n  - id: start',
    );
  }

  Future<void> _createFile(String path, String content) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// The workspace root URI.
  Uri get rootUri => root.uri;

  /// Clean up the temporary directory.
  Future<void> dispose() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}
