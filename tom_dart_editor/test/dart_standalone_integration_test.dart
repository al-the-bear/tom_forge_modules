import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('DartStandaloneIntegration', () {
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
      test('creates with default Dart editor settings', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        final settings = integration.textSettings;
        expect(settings.fontFamily, DartEditorDefaults.defaultFontFamily);
        expect(settings.fontSize, DartEditorDefaults.defaultFontSize);
        expect(settings.lineHeight, DartEditorDefaults.defaultLineHeight);
        expect(settings.tabSize, DartEditorDefaults.defaultTabSize);
        expect(settings.insertSpaces, true);
        expect(settings.wordWrap, false);
        expect(settings.showLineNumbers, true);
      });

      test('creates with custom settings', () {
        const custom = ForgeTextSettings(
          fontFamily: 'Fira Code',
          fontSize: 14.0,
          tabSize: 4,
        );
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
          textSettings: custom,
        );
        addTeardownDispose(integration);

        expect(integration.textSettings.fontFamily, 'Fira Code');
        expect(integration.textSettings.fontSize, 14.0);
        expect(integration.textSettings.tabSize, 4);
      });

      test('has standard editing actions registered', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        final actionIds =
            integration.supportedActions.map((a) => a.id).toList();
        expect(actionIds, contains(StandardEditingActions.cutActionId));
        expect(actionIds, contains(StandardEditingActions.copyActionId));
        expect(actionIds, contains(StandardEditingActions.pasteActionId));
        expect(actionIds, contains(StandardEditingActions.selectAllActionId));
        expect(actionIds, contains(StandardEditingActions.undoActionId));
        expect(actionIds, contains(StandardEditingActions.redoActionId));
      });
    });

    group('action registration', () {
      test('can register Dart-specific actions', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        var completionCalled = false;
        integration.registerAction(
          DartEditorActions.triggerCompletionActionId,
          () => completionCalled = true,
        );

        integration.executeAction(DartEditorActions.triggerCompletionActionId);
        expect(completionCalled, true);
      });

      test('can override undo/redo handlers', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        var customUndoCalled = false;
        integration.registerAction(
          StandardEditingActions.undoActionId,
          () => customUndoCalled = true,
        );

        integration.executeAction(StandardEditingActions.undoActionId);
        expect(customUndoCalled, true);
      });

      test('isEnabled works for custom actions', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        var enabled = false;
        integration.registerAction(
          DartEditorActions.triggerCompletionActionId,
          () {},
          isEnabled: () => enabled,
        );

        expect(
          integration
              .isActionEnabled(DartEditorActions.triggerCompletionActionId),
          false,
        );
        enabled = true;
        expect(
          integration
              .isActionEnabled(DartEditorActions.triggerCompletionActionId),
          true,
        );
      });
    });

    group('auto undo tracking', () {
      test('does not track undo on text change (auto tracking disabled)', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        controller.text = 'first change';
        controller.text = 'second change';

        // Undo should not work because auto tracking is disabled
        // and no custom undo handler has been registered to replace the default
        // The base class undo/redo still calls its internal stacks which are empty
        expect(
          integration.isActionEnabled(StandardEditingActions.undoActionId),
          false,
        );
      });
    });

    group('buildEditorShortcutMap', () {
      test('includes shortcuts from registered actions', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        // Register a Dart action to get its shortcut in the map
        integration.registerAction(
          DartEditorActions.triggerCompletionActionId,
          () {},
        );

        final map = buildEditorShortcutMap(
          integration,
          alternates: DartEditorActions.alternativeShortcuts,
        );

        // Should have standard actions + any we registered with shortcuts
        expect(map.isNotEmpty, true);

        // Standard actions should be in the map
        final actionIds = map.values.toSet();
        expect(actionIds, contains(StandardEditingActions.undoActionId));
        expect(actionIds, contains(StandardEditingActions.redoActionId));
      });

      test('includes alternative shortcuts', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        integration.registerAction(
          DartEditorActions.triggerCompletionActionId,
          () {},
        );

        final map = buildEditorShortcutMap(
          integration,
          alternates: DartEditorActions.alternativeShortcuts,
        );

        // Alternative shortcuts for triggerCompletion should be present
        final triggerCompletionEntries = map.entries
            .where(
                (e) => e.value == DartEditorActions.triggerCompletionActionId)
            .toList();

        // At least the alternatives should be present
        // (primary shortcut may not be there if action wasn't registered
        // via ForgeAction with shortcut, but alternatives always are)
        expect(triggerCompletionEntries.length,
            greaterThanOrEqualTo(2)); // 2 alt shortcuts
      });

      test(
          'takes a key once: an alternate on a bound key keeps the bound '
          'action', () {
        final integration = DartStandaloneIntegration(
          controller: controller,
          focusNode: focusNode,
        );
        addTeardownDispose(integration);

        final map = buildEditorShortcutMap(
          integration,
          alternates: {
            'some.other.action': [StandardEditingActions.undoShortcut],
          },
        );
        final undo = StandardEditingActions.undoShortcut.toActivator();
        final meanings = [
          for (final entry in map.entries)
            if (entry.key case final SingleActivator a
                when a.trigger == undo.trigger &&
                    a.meta == undo.meta &&
                    a.control == undo.control &&
                    a.shift == undo.shift)
              entry.value,
        ];
        expect(meanings, [StandardEditingActions.undoActionId]);
      });
    });

    group('DartEditorDefaults', () {
      test('has expected default values', () {
        expect(DartEditorDefaults.defaultFontFamily, 'JetBrains Mono');
        expect(DartEditorDefaults.defaultFontSize, 13.0);
        expect(DartEditorDefaults.defaultLineHeight, 1.5);
        expect(DartEditorDefaults.defaultTabSize, 2);
      });

      test('defaultSettings has all expected values', () {
        const settings = DartEditorDefaults.defaultSettings;
        expect(settings.fontFamily, 'JetBrains Mono');
        expect(settings.fontSize, 13.0);
        expect(settings.lineHeight, 1.5);
        expect(settings.tabSize, 2);
        expect(settings.insertSpaces, true);
        expect(settings.wordWrap, false);
        expect(settings.showLineNumbers, true);
      });
    });
  });
}

/// Helper to add teardown disposal.
void addTeardownDispose(ForgeEditorIntegration integration) {
  addTearDown(() => integration.dispose());
}
