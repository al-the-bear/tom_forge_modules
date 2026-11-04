import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('MdStandaloneIntegration', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    group('creation', () {
      test('creates with default MD editor settings', () {
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        final settings = integration.textSettings;
        expect(settings.fontFamily, MdEditorDefaults.defaultFontFamily);
        expect(settings.fontSize, MdEditorDefaults.defaultFontSize);
        expect(settings.lineHeight, MdEditorDefaults.defaultLineHeight);
        expect(settings.tabSize, MdEditorDefaults.defaultTabSize);
        expect(settings.insertSpaces, true);
        expect(settings.wordWrap, true);
        expect(settings.showLineNumbers, false);
      });

      test('creates with custom settings', () {
        const custom = ForgeTextSettings(
          fontFamily: 'Fira Code',
          fontSize: 16.0,
          tabSize: 4,
        );
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
          textSettings: custom,
        );
        addTeardownDispose(integration);

        expect(integration.textSettings.fontFamily, 'Fira Code');
        expect(integration.textSettings.fontSize, 16.0);
        expect(integration.textSettings.tabSize, 4);
      });

      test('has auto undo tracking disabled', () {
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        // Verify auto-tracking is off by checking undo not available
        // after a text change
        controller.text = 'hello';
        expect(integration.isActionEnabled(StandardEditingActions.undoActionId),
            false);
      });
    });

    group('default settings values', () {
      test('MdEditorDefaults has correct values', () {
        expect(MdEditorDefaults.defaultFontFamily, 'Segoe UI');
        expect(MdEditorDefaults.defaultMonoFontFamily, 'Cascadia Code');
        expect(MdEditorDefaults.defaultFontSize, 14.0);
        expect(MdEditorDefaults.defaultLineHeight, 1.6);
        expect(MdEditorDefaults.defaultTabSize, 2);
      });

      test('default settings instance matches individual values', () {
        const settings = MdEditorDefaults.defaultSettings;
        expect(settings.fontFamily, MdEditorDefaults.defaultFontFamily);
        expect(settings.fontSize, MdEditorDefaults.defaultFontSize);
        expect(settings.lineHeight, MdEditorDefaults.defaultLineHeight);
        expect(settings.tabSize, MdEditorDefaults.defaultTabSize);
      });
    });

    group('standard actions', () {
      test('registers standard editing actions', () {
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        final actionIds = integration.supportedActions.map((a) => a.id).toSet();
        expect(actionIds.contains(StandardEditingActions.cutActionId), true);
        expect(actionIds.contains(StandardEditingActions.copyActionId), true);
        expect(actionIds.contains(StandardEditingActions.pasteActionId), true);
        expect(
            actionIds.contains(StandardEditingActions.selectAllActionId), true);
        expect(actionIds.contains(StandardEditingActions.undoActionId), true);
        expect(actionIds.contains(StandardEditingActions.redoActionId), true);
      });
    });

    group('action registration', () {
      test('can register custom actions and execute them', () {
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        var invoked = false;
        integration.registerAction(
          MdEditorActions.toggleBoldActionId,
          () => invoked = true,
        );

        final result = integration.executeAction(
            MdEditorActions.toggleBoldActionId);
        expect(result, true);
        expect(invoked, true);
      });

      test('isActionEnabled returns true for registered actions', () {
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        integration.registerAction(
          MdEditorActions.saveActionId,
          () {},
          isEnabled: () => true,
        );

        expect(
          integration.isActionEnabled(MdEditorActions.saveActionId),
          true,
        );
      });

      test('can override standard undo/redo handlers', () {
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        var undoInvoked = false;
        var redoInvoked = false;
        integration.registerAction(
          StandardEditingActions.undoActionId,
          () => undoInvoked = true,
          isEnabled: () => true,
        );
        integration.registerAction(
          StandardEditingActions.redoActionId,
          () => redoInvoked = true,
          isEnabled: () => true,
        );

        integration.executeAction(StandardEditingActions.undoActionId);
        integration.executeAction(StandardEditingActions.redoActionId);

        expect(undoInvoked, true);
        expect(redoInvoked, true);
      });
    });

    group('buildEditorShortcutMap', () {
      test('builds map with standard action shortcuts', () {
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        final map = buildEditorShortcutMap(
          integration,
          alternates: MdEditorActions.alternativeShortcuts,
        );
        expect(map.isNotEmpty, true);

        // Standard actions should be present
        final actionIds = map.values.toSet();
        expect(
            actionIds.contains(StandardEditingActions.undoActionId), true);
        expect(
            actionIds.contains(StandardEditingActions.redoActionId), true);
        expect(
            actionIds.contains(StandardEditingActions.cutActionId), true);
        expect(
            actionIds.contains(StandardEditingActions.copyActionId), true);
        expect(
            actionIds.contains(StandardEditingActions.pasteActionId), true);
        expect(
            actionIds.contains(StandardEditingActions.selectAllActionId), true);
      });

      test('includes redo shortcut', () {
        final integration = MdStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        final map = buildEditorShortcutMap(
          integration,
          alternates: MdEditorActions.alternativeShortcuts,
        );
        // Redo is bound to Shift+Cmd/Ctrl+Z, and on Windows and Linux also to
        // Ctrl+Y (StandardEditingActions.alternateShortcuts).
        final redoCount = map.values
            .where((id) => id == StandardEditingActions.redoActionId)
            .length;
        expect(redoCount, greaterThanOrEqualTo(1));
      });
    });
  });
}

/// Helper to add teardown disposal.
void addTeardownDispose(ForgeEditorIntegration integration) {
  addTearDown(() => integration.dispose());
}
