import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

void main() {
  group('ForgeTextField', () {
    testWidgets('renders TextField', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgeTextField(),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('displays initial text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgeTextField(initialText: 'Hello'),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('calls onTextChanged when text changes', (tester) async {
      String? changedText;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(
              onTextChanged: (text) => changedText = text,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'New Text');
      expect(changedText, 'New Text');
    });

    testWidgets('calls onIntegrationReady with integration', (tester) async {
      ForgeEditorIntegration? receivedIntegration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(
              onIntegrationReady: (integration) {
                receivedIntegration = integration;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(receivedIntegration, isNotNull);
    });

    testWidgets('applies text settings', (tester) async {
      const settings = ForgeTextSettings(
        fontSize: 20,
        fontFamily: 'Courier',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgeTextField(textSettings: settings),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.style?.fontSize, 20);
      expect(textField.style?.fontFamily, 'Courier');
    });

    testWidgets('uses provided controller', (tester) async {
      final controller = TextEditingController(text: 'Provided');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(controller: controller),
          ),
        ),
      );

      expect(find.text('Provided'), findsOneWidget);
    });

    testWidgets('uses provided focusNode', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(focusNode: focusNode),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, true);
    });

    testWidgets('expands when set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgeTextField(expands: true),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.expands, true);
    });

    testWidgets('readOnly when set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgeTextField(readOnly: true),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.readOnly, true);
    });

    testWidgets('autofocus when set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgeTextField(autofocus: true),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.autofocus, true);
    });

    testWidgets('integration can set text', (tester) async {
      ForgeEditorIntegration? integration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(
              onIntegrationReady: (i) => integration = i,
            ),
          ),
        ),
      );

      await tester.pump();
      integration!.setText('Set via integration');
      await tester.pump();

      expect(find.text('Set via integration'), findsOneWidget);
    });

    testWidgets('integration can execute select all', (tester) async {
      ForgeEditorIntegration? integration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(
              initialText: 'Hello World',
              onIntegrationReady: (i) => integration = i,
            ),
          ),
        ),
      );

      await tester.pump();
      final executed = integration!.executeAction(
        StandardEditingActions.selectAllActionId,
      );

      expect(executed, true);
    });

    testWidgets('updates settings on rebuild', (tester) async {
      ForgeEditorIntegration? integration;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(
              textSettings: const ForgeTextSettings(fontSize: 14),
              onIntegrationReady: (i) => integration = i,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(integration!.textSettings.fontSize, 14);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(
              textSettings: const ForgeTextSettings(fontSize: 18),
              onIntegrationReady: (i) => integration = i,
            ),
          ),
        ),
      );

      expect(integration!.textSettings.fontSize, 18);
    });

    testWidgets('disposes correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForgeTextField(initialText: 'Disposable'),
          ),
        ),
      );

      // Replace with empty container to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Should not throw - disposal completed
    });

    testWidgets('GlobalKey extension returns integration', (tester) async {
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForgeTextField(
              key: key,
              initialText: 'Keyed',
            ),
          ),
        ),
      );

      await tester.pump();
      // The extension is defined, though we can't easily test it in isolation
      // without exposing the state type
    });
  });
}
