import 'package:flutter_test/flutter_test.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

void main() {
  group('YamlEditorController path normalization', () {
    const initialYaml = '''
workflow:
  steps:
    - id: step-1
      script-dart: |
        void main() {
          print('hello');
        }
    - id: step-2
      script-dart: |
        void main() {
          print('world');
        }
''';

    test('setValue supports list-index path segments as strings', () {
      final controller = YamlEditorController(initialYaml: initialYaml);

      expect(
        () => controller.setValue(
          ['workflow', 'steps', '0', 'script-dart'],
          'void main() { print("updated"); }',
        ),
        returnsNormally,
      );

      final updated = controller.document.valueOf(
        ['workflow', 'steps', 0, 'script-dart'],
      );

      expect(updated, 'void main() { print("updated"); }');
    });

    test('removeKey supports list-index path segments as strings', () {
      final controller = YamlEditorController(initialYaml: initialYaml);

      expect(
        () => controller.removeKey(['workflow', 'steps', '0', 'script-dart']),
        returnsNormally,
      );

      final removed = controller.document.valueOf(
        ['workflow', 'steps', 0, 'script-dart'],
      );

      expect(removed, isNull);
    });

    test('moveListItem supports list parent path from string segments', () {
      final controller = YamlEditorController(initialYaml: initialYaml);

      expect(
        () => controller.moveListItem(['workflow', 'steps'], 1, 0),
        returnsNormally,
      );

      final firstId =
          controller.document.valueOf(['workflow', 'steps', 0, 'id']);
      final secondId =
          controller.document.valueOf(['workflow', 'steps', 1, 'id']);

      expect(firstId, 'step-2');
      expect(secondId, 'step-1');
    });
  });
}
