import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

void main() {
  group('YamlStandaloneIntegration', () {
    late YamlEditorController controller;
    late YamlStandaloneIntegration integration;

    setUp(() {
      controller = YamlEditorController(initialYaml: 'name: test\nvalue: 42');
      integration = YamlStandaloneIntegration(controller: controller);
    });

    group('creation', () {
      test('creates with default text settings', () {
        final settings = integration.textSettings;
        expect(settings.fontFamily, YamlEditorDefaults.defaultFontFamily);
        expect(settings.fontSize, YamlEditorDefaults.defaultFontSize);
        expect(settings.tabSize, YamlEditorDefaults.defaultTabSize);
      });

      test('creates with custom text settings', () {
        const custom = ForgeTextSettings(
          fontFamily: 'Courier',
          fontSize: 16.0,
          tabSize: 4,
        );
        final customIntegration = YamlStandaloneIntegration(
          controller: controller,
          textSettings: custom,
        );
        expect(customIntegration.textSettings.fontFamily, 'Courier');
        expect(customIntegration.textSettings.fontSize, 16.0);
        expect(customIntegration.textSettings.tabSize, 4);
        customIntegration.dispose();
      });
    });

    group('undo/redo bridge', () {
      test('canUndo is false on clean controller', () {
        expect(integration.canUndo, isFalse);
      });

      test('canUndo is true after edit', () {
        controller.setValue(['name'], 'changed');
        expect(integration.canUndo, isTrue);
      });

      test('undo delegates to controller', () {
        controller.setValue(['name'], 'changed');
        expect(controller.yamlText, contains('changed'));
        integration.undo();
        expect(controller.yamlText, contains('test'));
      });

      test('redo delegates to controller', () {
        controller.setValue(['name'], 'changed');
        integration.undo();
        expect(controller.yamlText, contains('test'));
        integration.redo();
        expect(controller.yamlText, contains('changed'));
      });

      test('canRedo is false initially', () {
        expect(integration.canRedo, isFalse);
      });

      test('canRedo is true after undo', () {
        controller.setValue(['name'], 'changed');
        integration.undo();
        expect(integration.canRedo, isTrue);
      });
    });

    group('text context', () {
      test('provides text from controller', () {
        final ctx = integration.textContext;
        expect(ctx.text, controller.yamlText);
      });

      test('reflects isDirty state', () {
        expect(integration.textContext.isDirty, isFalse);
        controller.setValue(['name'], 'changed');
        expect(integration.textContext.isDirty, isTrue);
      });

      test('reflects canUndo state', () {
        expect(integration.textContext.canUndo, isFalse);
        controller.setValue(['name'], 'changed');
        expect(integration.textContext.canUndo, isTrue);
      });

      test('reflects canRedo state', () {
        expect(integration.textContext.canRedo, isFalse);
        controller.setValue(['name'], 'changed');
        integration.undo();
        expect(integration.textContext.canRedo, isTrue);
      });
    });

    group('supported actions', () {
      test('includes undo and redo actions', () {
        final actionIds = integration.supportedActions.map((a) => a.id).toList();
        expect(actionIds, contains(StandardEditingActions.undoActionId));
        expect(actionIds, contains(StandardEditingActions.redoActionId));
      });
    });

    group('action execution', () {
      test('undo action works via executeAction', () {
        controller.setValue(['name'], 'changed');
        expect(controller.yamlText, contains('changed'));
        integration.executeAction(StandardEditingActions.undoActionId);
        expect(controller.yamlText, contains('test'));
      });

      test('redo action works via executeAction', () {
        controller.setValue(['name'], 'changed');
        integration.executeAction(StandardEditingActions.undoActionId);
        integration.executeAction(StandardEditingActions.redoActionId);
        expect(controller.yamlText, contains('changed'));
      });
    });

    group('defaults', () {
      test('default font family is monospace', () {
        expect(YamlEditorDefaults.defaultFontFamily, 'monospace');
      });

      test('default font size is 13.0', () {
        expect(YamlEditorDefaults.defaultFontSize, 13.0);
      });

      test('default tab size is 2', () {
        expect(YamlEditorDefaults.defaultTabSize, 2);
      });
    });

    group('theme mapping', () {
      test('toForgeTextSettings maps default theme', () {
        const theme = YamlEditorTheme();
        final settings = YamlEditorDefaults.forgeTextSettingsFrom(theme);
        expect(settings.fontFamily, theme.fonts.valueFontFamily);
        expect(settings.fontSize, theme.fonts.valueFontSize);
      });

      test('toForgeTextSettings maps custom theme', () {
        const theme = YamlEditorTheme(
          fonts: YamlEditorFontSettings(
            valueFontFamily: 'CustomMono',
            valueFontSize: 16.0,
            lineHeight: 1.8,
          ),
        );
        final settings = YamlEditorDefaults.forgeTextSettingsFrom(theme);
        expect(settings.fontFamily, 'CustomMono');
        expect(settings.fontSize, 16.0);
        expect(settings.lineHeight, 1.8);
      });
    });
  });
}
