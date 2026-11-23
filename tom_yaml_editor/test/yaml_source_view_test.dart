/// The YAML editor's source views — the text mode of the schema editor and
/// the subtree inspector — are `tom_file_editors`' source editor
/// (TomTextSource) and keep what they offered: line numbers with the caret's
/// line brighter, the editor theme's look, the YAML highlighting, the parse
/// error and schema markers, typing through the document's history, the
/// undo keys reaching that history, text from outside with its selection,
/// the selection reported to the host, read-only, the clipboard and line
/// edits through the action integration (only while the source is shown),
/// and in the inspector the draft's own undo, Apply and Cancel.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeEditorIntegration, StandardEditingActions;
import 'package:tom_file_editors/tom_file_editors.dart'
    show
        TomTextMarker,
        TomTextMarkerSeverity,
        TomTextSource,
        tomTextMarkerColor;
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

const _theme = YamlEditorTheme();

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _editor(
  YamlEditorController controller, {
  bool readOnly = false,
  ForgeEditorIntegration? integration,
  ValueChanged<TextSelection>? onSelection,
}) =>
    _app(
      YamlSchemaEditor(
        controller: controller,
        readOnly: readOnly,
        integration: integration,
        onTextModeSelectionChanged: onSelection,
      ),
    );

TextEditingController _field(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller;

/// The leaf spans the source draws, with their merged styles.
List<TextSpan> _leaves(WidgetTester tester) {
  final span = _field(tester).buildTextSpan(
    context: tester.element(find.byType(EditableText)),
    withComposing: false,
  );
  final out = <TextSpan>[];
  void walk(InlineSpan s, TextStyle? inherited) {
    if (s is! TextSpan) return;
    final merged = inherited?.merge(s.style) ?? s.style;
    if (s.text != null) out.add(TextSpan(text: s.text, style: merged));
    for (final c in s.children ?? const <InlineSpan>[]) {
      walk(c, merged);
    }
  }

  walk(span, null);
  return out;
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

Future<YamlEditorController> _textMode(
  WidgetTester tester,
  String yaml, {
  bool readOnly = false,
  ForgeEditorIntegration? integration,
  ValueChanged<TextSelection>? onSelection,
}) async {
  final controller = YamlEditorController(initialYaml: yaml);
  addTearDown(controller.dispose);
  controller.textMode = true;
  await tester.pumpWidget(
    _editor(
      controller,
      readOnly: readOnly,
      integration: integration,
      onSelection: onSelection,
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  setUp(() => kYamlEditorDebug = false);

  group('YSV text mode', () {
    testWidgets(
        'YSV-1: the source is a TomTextSource with line numbers in '
        'the editor theme\'s look', (tester) async {
      await _textMode(tester, 'name: a\nport: 1\n');
      expect(find.byType(TomTextSource), findsOneWidget);
      final gutter = tester.widget<Container>(
        find.byKey(const Key('tom-text-gutter')),
      );
      expect(gutter.color, _theme.colors.surface);
      final border = tester.widget<Container>(
        find.byKey(const Key('tom-text-gutter-border')),
      );
      expect(border.color, _theme.colors.separatorColor.withAlpha(80));
      expect(
        find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == _theme.colors.background,
        ),
        findsWidgets,
      );
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.style.color, _theme.colors.valueColor);
      expect(field.style.fontSize, _theme.fonts.valueFontSize);
      expect(field.style.height, 1.4);
      expect(field.cursorColor, Colors.white);
      expect(field.contextMenuBuilder, isNotNull, reason: 'the menu');
      final numbers = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('tom-text-gutter')),
          matching: find.byType(Text),
        ),
      );
      final lines = (numbers.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(lines.map((l) => l.text), ['1', '\n2', '\n3']);
      expect(numbers.style!.color, _theme.colors.hintColor);
    });

    testWidgets('YSV-2: the caret\'s line number is drawn at full opacity', (
      tester,
    ) async {
      await _textMode(tester, 'a: 1\nb: 2\n');
      _field(tester).selection = const TextSelection.collapsed(offset: 6);
      await tester.pump();
      final numbers = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('tom-text-gutter')),
          matching: find.byType(Text),
        ),
      );
      final lines = (numbers.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(lines[1].style!.color!.a, 1.0);
      expect(lines[0].style, isNull);
    });

    testWidgets('YSV-3: the YAML is highlighted in the theme\'s colours', (
      tester,
    ) async {
      await _textMode(tester, 'name: a\n');
      final key = _leaves(tester).firstWhere((l) => l.text == 'name');
      expect(key.style!.color, _theme.colors.keyColor);
    });

    testWidgets(
        'YSV-4: source that does not parse is underlined where the '
        'parser stopped, in the error colour', (tester) async {
      final controller = await _textMode(tester, 'a: 1\n');
      controller.editSource(
        'a: b: c\n',
        const TextSelection.collapsed(offset: 7),
      );
      await tester.pumpAndSettle();
      final marked = _leaves(
        tester,
      ).where((l) => l.style?.decorationStyle == TextDecorationStyle.wavy);
      expect(marked, isNotEmpty);
      expect(
        marked.first.style!.decorationColor,
        tomTextMarkerColor(TomTextMarkerSeverity.error),
      );
      expect(find.textContaining('YAML parse error'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
        'YSV-5: typing edits the document through its history, the '
        'selection is reported, and the undo key undoes it', (tester) async {
      final selections = <TextSelection>[];
      final controller = await _textMode(
        tester,
        'a: 1\n',
        onSelection: selections.add,
      );
      await tester.tap(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'a: 2\n');
      await tester.pump(const Duration(seconds: 2));
      expect(controller.sourceText, 'a: 2\n');
      expect(controller.canUndo, isTrue);
      expect(selections, isNotEmpty);
      await _press(tester, LogicalKeyboardKey.keyZ);
      expect(controller.sourceText, 'a: 1\n');
      expect(_field(tester).text, 'a: 1\n', reason: 'shown from outside');
      await _press(tester, LogicalKeyboardKey.keyZ, shift: true);
      expect(controller.sourceText, 'a: 2\n');
    });

    testWidgets(
        'YSV-6: text from outside shows with the document\'s '
        'selection', (tester) async {
      final controller = await _textMode(tester, 'a: 1\n');
      controller.editSource(
        'a: 1\nb: 2\n',
        const TextSelection(baseOffset: 5, extentOffset: 6),
      );
      await tester.pumpAndSettle();
      expect(_field(tester).text, 'a: 1\nb: 2\n');
      expect(
        _field(tester).selection,
        const TextSelection(baseOffset: 5, extentOffset: 6),
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets(
        'YSV-7: read-only shows the source without letting it '
        'change', (tester) async {
      final integration = YamlStandaloneIntegration(
        controller: YamlEditorController(initialYaml: ''),
      );
      final controller = await _textMode(
        tester,
        'a: 1\n',
        readOnly: true,
        integration: integration,
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        isTrue,
      );
      expect(
        integration.isActionEnabled(StandardEditingActions.deleteLineActionId),
        isFalse,
      );
      integration.executeAction(StandardEditingActions.deleteLineActionId);
      await tester.pump();
      expect(controller.sourceText, 'a: 1\n');
    });

    testWidgets(
        'YSV-8: the line edits run on the source through the '
        'integration while it is shown, as an edit of the document', (
      tester,
    ) async {
      final controller = YamlEditorController(initialYaml: 'a: 1\nb: 2\n');
      addTearDown(controller.dispose);
      final integration = YamlStandaloneIntegration(controller: controller);
      controller.textMode = true;
      await tester.pumpWidget(_editor(controller, integration: integration));
      await tester.pumpAndSettle();
      _field(tester).selection = const TextSelection.collapsed(offset: 1);
      await tester.pump();
      expect(
        integration.executeAction(
          StandardEditingActions.duplicateLineActionId,
        ),
        isTrue,
      );
      await tester.pump();
      expect(controller.sourceText, 'a: 1\na: 1\nb: 2\n');
      integration.executeAction(StandardEditingActions.moveLineDownActionId);
      await tester.pump();
      expect(controller.sourceText, 'a: 1\nb: 2\na: 1\n');
      integration.executeAction(StandardEditingActions.moveLineUpActionId);
      await tester.pump();
      expect(controller.sourceText, 'a: 1\na: 1\nb: 2\n');
      integration.executeAction(StandardEditingActions.deleteLineActionId);
      await tester.pump();
      expect(controller.sourceText, 'a: 1\nb: 2\n');
      integration.executeAction(StandardEditingActions.toggleCommentActionId);
      await tester.pump();
      expect(controller.sourceText.split('\n'), contains('# b: 2'));
      await tester.pump(const Duration(seconds: 2));
      expect(controller.canUndo, isTrue, reason: 'the line edits are history');
      controller.undo();
      expect(controller.sourceText, isNot(contains('# b: 2')));

      controller.textMode = false;
      await tester.pumpAndSettle();
      expect(
        integration.isActionEnabled(
          StandardEditingActions.duplicateLineActionId,
        ),
        isFalse,
        reason: 'no source shown',
      );
      final before = controller.sourceText;
      integration.executeAction(StandardEditingActions.duplicateLineActionId);
      await tester.pump();
      expect(controller.sourceText, before);
    });

    testWidgets(
        'YSV-9: cut, copy, paste and select all through the '
        'integration', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          } else if (call.method == 'Clipboard.getData') {
            return {'text': clipboard};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final controller = YamlEditorController(initialYaml: 'a: 1\n');
      addTearDown(controller.dispose);
      final integration = YamlStandaloneIntegration(controller: controller);
      controller.textMode = true;
      await tester.pumpWidget(_editor(controller, integration: integration));
      await tester.pumpAndSettle();
      expect(
        integration.isActionEnabled(StandardEditingActions.copyActionId),
        isFalse,
        reason: 'nothing selected',
      );
      integration.executeAction(StandardEditingActions.selectAllActionId);
      await tester.pump();
      expect(
        _field(tester).selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      _field(tester).selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 4,
      );
      await tester.pump();
      integration.executeAction(StandardEditingActions.copyActionId);
      await tester.pumpAndSettle();
      expect(clipboard, '1');
      integration.executeAction(StandardEditingActions.cutActionId);
      await tester.pumpAndSettle();
      expect(controller.sourceText, 'a: \n');
      _field(tester).selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();
      integration.executeAction(StandardEditingActions.pasteActionId);
      await tester.pumpAndSettle();
      expect(controller.sourceText, 'a: 1\n');
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('YSV inspector', () {
    Future<(YamlEditorController, GlobalKey<SubtreeInspectorState>)> pump(
      WidgetTester tester,
      String yaml, {
      bool readOnly = false,
    }) async {
      final controller = YamlEditorController(initialYaml: yaml);
      addTearDown(controller.dispose);
      final key = GlobalKey<SubtreeInspectorState>();
      await tester.pumpWidget(
        _app(
          SubtreeInspector(
            key: key,
            controller: controller,
            path: const ['meta'],
            readOnly: readOnly,
            debounceDuration: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (controller, key);
    }

    testWidgets(
        'YSI-1: the subtree shows in a TomTextSource in the editor\'s '
        'look, highlighted, with line numbers', (tester) async {
      await pump(tester, 'meta:\n  a: 1\n  b: 2\n');
      expect(find.byType(TomTextSource), findsOneWidget);
      expect(_field(tester).text, contains('a: 1'));
      final gutter = tester.widget<Container>(
        find.byKey(const Key('tom-text-gutter')),
      );
      expect(gutter.color, _theme.colors.surface);
      expect(find.byKey(const Key('tom-text-gutter-border')), findsOneWidget);
      final key = _leaves(tester).firstWhere((l) => l.text == 'a');
      expect(key.style!.color, _theme.colors.keyColor);
    });

    testWidgets(
        'YSI-2: a draft that does not parse is marked and cannot be '
        'applied; Cancel restores the subtree', (tester) async {
      final (_, key) = await pump(tester, 'meta:\n  a: 1\n');
      await tester.enterText(find.byType(EditableText), 'a: [1');
      await tester.pumpAndSettle();
      expect(key.currentState!.canApply, isFalse);
      expect(find.textContaining('fix before applying'), findsOneWidget);
      key.currentState!.cancel();
      await tester.pumpAndSettle();
      expect(_field(tester).text, contains('a: 1'));
    });

    testWidgets('YSI-3: a valid draft is applied to the document', (
      tester,
    ) async {
      final (controller, key) = await pump(tester, 'meta:\n  a: 1\n');
      await tester.enterText(find.byType(EditableText), 'a: 2\n');
      await tester.pumpAndSettle();
      expect(key.currentState!.apply(), isTrue);
      expect(controller.sourceText, contains('a: 2'));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('YSI-4: the draft keeps the text field\'s own undo', (
      tester,
    ) async {
      final (controller, _) = await pump(tester, 'meta:\n  a: 1\n');
      final source = tester.widget<TomTextSource>(find.byType(TomTextSource));
      expect(source.hostOwnsUndo, isFalse);
      await tester.tap(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'a: 2\n');
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(EditableText), 'a: 3\n');
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(_field(tester).text, 'a: 2\n');
      expect(controller.canUndo, isFalse, reason: 'the document is untouched');
    });

    testWidgets('YSI-5: a read-only inspector shows the subtree unchanged', (
      tester,
    ) async {
      final (_, key) = await pump(tester, 'meta:\n  a: 1\n', readOnly: true);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        isTrue,
      );
      expect(key.currentState!.canApply, isFalse);
    });
  });

  test('YSM-1: schema findings map onto the neutral markers by severity', () {
    final markers = SchemaMarkerGenerator.generate(
      yamlText: 'name: a\nport: x\n',
      errors: const [
        ValidationError(
          path: ['port'],
          message: 'not an integer',
          severity: ValidationSeverity.warning,
        ),
      ],
    );
    expect(markers, hasLength(1));
    final TomTextMarker marker = markers.single;
    expect(marker.severity, TomTextMarkerSeverity.warning);
    expect(marker.line, 2);
    expect(marker.message, 'not an integer');
  });
}
