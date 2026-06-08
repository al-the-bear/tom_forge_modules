import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

/// A no-op editor factory — the registry stores factories but never invokes
/// them during resolution, so a [SizedBox] placeholder is sufficient.
Widget _noopFactory({
  required String key,
  required Object? value,
  required ValueChanged<Object?> onChanged,
  required YamlEditorTheme theme,
  required bool readOnly,
}) => const SizedBox.shrink();

EditorSuffix _editor(String suffix) =>
    EditorSuffix(suffix: suffix, label: suffix, factory: _noopFactory);

void main() {
  group('EditorRegistry suffix resolution', () {
    // EREG-01: a registered exact suffix resolves directly.
    test('EREG-01: exact suffix resolves to its editor', () {
      var registry = const EditorRegistry().register(_editor('markdown'));
      var resolved = registry.resolve('description-markdown', const []);
      expect(resolved?.suffix, 'markdown');
    });

    // EREG-02: the `-md` shorthand routes to the `markdown` editor via the
    // built-in alias (web_todo_list.md #9: typed-suffix inline editors).
    test('EREG-02: -md alias routes to the markdown editor', () {
      var registry = const EditorRegistry().register(_editor('markdown'));
      expect(registry.resolve('summary-md', const [])?.suffix, 'markdown');
      expect(registry.resolve('overview-md', const [])?.suffix, 'markdown');
    });

    // EREG-03: `-json` resolves directly to the json editor (no alias needed).
    test('EREG-03: -json resolves to the json editor', () {
      var registry = const EditorRegistry().register(_editor('json'));
      expect(registry.resolve('links-json', const [])?.suffix, 'json');
    });

    // EREG-04: a plain key with no suffix stays a plain field (null).
    test('EREG-04: plain key resolves to null', () {
      var registry = const EditorRegistry().register(_editor('markdown'));
      expect(registry.resolve('title', const []), isNull);
    });

    // EREG-05: an alias that has no canonical editor registered resolves to
    // null rather than throwing.
    test('EREG-05: -md with no markdown editor registered resolves to null', () {
      var registry = const EditorRegistry();
      expect(registry.resolve('summary-md', const []), isNull);
    });

    // EREG-06: an exact suffix match wins over the alias path — if a literal
    // `md` editor is registered, `-md` uses it (not the markdown alias target).
    test('EREG-06: exact suffix wins over alias', () {
      var registry = const EditorRegistry()
          .register(_editor('markdown'))
          .register(_editor('md'));
      expect(registry.resolve('summary-md', const [])?.suffix, 'md');
    });

    // EREG-07: custom aliases can be registered and resolve to their target.
    test('EREG-07: custom alias resolves to its canonical editor', () {
      var registry = const EditorRegistry()
          .register(_editor('yaml'))
          .registerAlias('yml', 'yaml');
      expect(registry.resolve('config-yml', const [])?.suffix, 'yaml');
    });

    // EREG-08: aliases survive register/withResolver (immutable preservation).
    test('EREG-08: aliases are preserved across register/withResolver', () {
      var registry = const EditorRegistry()
          .register(_editor('markdown'))
          .register(_editor('json'))
          .withResolver((key, path, type) => null);
      expect(registry.resolve('summary-md', const [])?.suffix, 'markdown');
    });
  });
}
