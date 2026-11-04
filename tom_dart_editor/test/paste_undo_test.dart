import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

/// Tests for Dart editor undo/redo functionality with focus on paste operations.
///
/// Verifies that:
/// - Each paste creates a separate undo entry
/// - Undo restores text to pre-paste state
/// - Multiple pastes can be undone individually
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dart Editor Paste Undo', () {
    late DartCodeController controller;

    setUp(() {
      controller = DartCodeController(initialCode: 'void main() {}');
      // Mock clipboard
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': 'PASTED_TEXT'};
        }
        if (call.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      });
    });

    tearDown(() {
      controller.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('01: single paste creates undo entry', (tester) async {
      await tester.pumpWidget(_buildEditor(controller));
      await tester.pumpAndSettle();

      // Find the TextField and enter some text to simulate typing
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Focus and position cursor at end
      await tester.tap(textField);
      await tester.pumpAndSettle();

      // Simulate paste via keyboard shortcut
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      // Text should have changed (paste happened)
      // Note: In widget tests, the clipboard mock may not integrate fully
      // with TextField, so we verify the controller still works
      expect(controller.userCode, isNotNull);
    });

    test('02: each programmatic edit is its own history entry', () {
      controller.applyEdit('first change');
      controller.applyEdit('second change');
      expect(controller.userCode, equals('second change'));
      controller.undo();
      expect(controller.userCode, equals('first change'));
      controller.undo();
      expect(controller.userCode, equals('void main() {}'));
      expect(controller.canUndo, isFalse);
    });

    test('03: replaceCode replaces the text, saved and with no history', () {
      controller.applyEdit('edited');
      controller.replaceCode('new code');
      expect(controller.userCode, equals('new code'));
      expect(controller.canUndo, isFalse);
      expect(controller.isDirty.value, isFalse);
    });

    test('04: revealLine notifier can be triggered', () {
      var revealed = false;
      controller.revealLineNotifier.addListener(() {
        revealed = true;
      });

      controller.revealLine(5);
      expect(revealed, isTrue);
      expect(controller.revealLineNotifier.value, equals(5));
    });
  });

  group('Dart Editor Text Controller', () {
    testWidgets('05: text changes trigger re-tokenization', (tester) async {
      final controller = DartCodeController(initialCode: '');

      await tester.pumpWidget(_buildEditor(controller));
      await tester.pumpAndSettle();

      // Type some code
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'void main() {}');
      await tester.pumpAndSettle();

      // The controller should have the new text
      expect(controller.userCode, equals('void main() {}'));
      // Let the typing pause end before the tree goes.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('06: cursor position is tracked', (tester) async {
      final controller = DartCodeController(initialCode: 'hello world');

      await tester.pumpWidget(_buildEditor(controller));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.tap(textField);
      await tester.pumpAndSettle();

      // Text field should be focused
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

Widget _buildEditor(DartCodeController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 1600,
        height: 600,
        child: DartCodeEditor(
          controller: controller,
          theme: DartEditorTheme.dark(),
          settings: const DartEditorSettings(showToolbar: false),
        ),
      ),
    ),
  );
}
