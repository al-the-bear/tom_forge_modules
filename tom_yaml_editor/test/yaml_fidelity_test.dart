/// A tree edit changes what it targets and nothing else: comments, blank
/// lines, flow collections, key order and quoting of the rest of a workspace
/// YAML file stay as they were written
/// (`tom_ai/forge_modules/_agent_guidelines/configuration_compatibility.md` §3).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';
import 'package:yaml/yaml.dart';

const _source = '''# Workspace build configuration.
# Keep this header.

name: demo   # the project name
version: "1.2"

paths:
  - lib       # sources
  - test

dart-editor-bundler:
  scopes:
    dart-plain: {sdk: true}
    d4rt-flutter:
      bridges: [tom_d4rt_flutter]

# trailing comment
''';

String _edit(void Function(YamlEditorController c) edit) {
  final controller = YamlEditorController(initialYaml: _source);
  edit(controller);
  controller.flush();
  return controller.yamlText;
}

void main() {
  test('YF-1: loading changes nothing', () {
    expect(YamlEditorController(initialYaml: _source).yamlText, _source);
  });

  test(
      'YF-2: setting a value changes that value only; flow collections '
      'elsewhere stay flow', () {
    expect(
      _edit((c) => c.setValue(['name'], 'other')),
      _source.replaceFirst('name: demo', 'name: other'),
    );
  });

  test('YF-3: a quoted string stays quoted, so it stays a string', () {
    final text = _edit((c) => c.setValue(['version'], '1.3'));
    expect(text, _source.replaceFirst('version: "1.2"', 'version: "1.3"'));
    expect((loadYaml(text) as Map)['version'], '1.3');
  });

  test('YF-4: a value inside a flow collection is set in place', () {
    expect(
      _edit(
        (c) => c.setValue(
          ['dart-editor-bundler', 'scopes', 'dart-plain', 'sdk'],
          false,
        ),
      ),
      _source.replaceFirst('{sdk: true}', '{sdk: false}'),
    );
  });

  test('YF-5: appending to a list keeps the comments of its other items', () {
    expect(
      _edit((c) => c.appendListItem(['paths'], 'tool')),
      _source.replaceFirst('  - test\n', '  - test\n  - tool\n'),
    );
  });

  test(
      'YF-6: inserting a key adds its line (in key order when the map\'s '
      'keys are sorted) and keeps the rest', () {
    expect(
      _edit((c) => c.insertKey(['dart-editor-bundler'], 'output', 'out')),
      _source.replaceFirst(
        'dart-editor-bundler:\n  scopes:',
        'dart-editor-bundler:\n  output: out\n  scopes:',
      ),
    );
  });

  test(
      'YF-7: removing a key removes its line and keeps the blank line '
      'after it', () {
    expect(
      _edit((c) => c.removeKey(['version'])),
      _source.replaceFirst('version: "1.2"\n', ''),
    );
  });

  test(
      'YF-8: removing a key whose value is a block list removes the list '
      'with it and keeps the lines around it', () {
    expect(
      _edit((c) => c.removeKey(['paths'])),
      _source.replaceFirst('paths:\n  - lib       # sources\n  - test\n', ''),
    );
    expect(
      _edit((c) =>
          c.removeKey(['dart-editor-bundler', 'scopes', 'd4rt-flutter'])),
      _source.replaceFirst(
          '    d4rt-flutter:\n      bridges: [tom_d4rt_flutter]\n', ''),
    );
  });
}
