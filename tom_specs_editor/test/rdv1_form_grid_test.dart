/// A form is edited as one grid, and its values keep their line breaks
/// (tom_forge 02d_rdv1, reading_view part *The TomSpecs editor*;
/// `tom_specs_editor_specification.md` §13).
///
/// The label sits in a fixed-width left column and the value in the right
/// one, one row per declared field in model order. Every value cell is a
/// multi-line field that starts one line high and grows: a one-line field
/// (`maxLines: 1`) filtered the line breaks of a hard-wrapped value out on the
/// first keystroke.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show forgeTypingPause;

import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';
import 'support/review_store_support.dart';

const _header = 'D00/D00-HDR';
const _items = 'D00/D00-ITM';

Map<String, dynamic> _json() => {
  'roots': [
    {'type': 'DemoDoc', 'title': 'Demo Document', 'sectionId': 'D00'},
  ],
  'classes': {
    'DemoDoc': {
      'name': 'DemoDoc',
      'sectionId': 'D00',
      'fields': [
        {
          'name': 'header',
          'kind': 'form',
          'sectionId': 'D00-HDR',
          'formFields': [
            {'name': 'author', 'label': 'Author', 'type': 'String'},
            {'name': 'purpose', 'label': 'Purpose', 'type': 'String'},
            {'name': 'scope', 'label': 'Scope', 'type': 'String'},
          ],
        },
        {
          'name': 'items',
          'kind': 'list',
          'elementType': 'DemoItem',
          'elementIsComplex': true,
          'sectionId': 'D00-ITM',
          'sectionIdPattern': 'D01.N',
        },
      ],
    },
    'DemoItem': {
      'name': 'DemoItem',
      'headline': 'Item Entry',
      'fields': [
        {'name': 'label', 'kind': 'scalar', 'type': 'String'},
      ],
    },
  },
};

Future<SpecDocumentController> _controller() async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_json())),
    review: memoryReviewStore(),
    strictHeadlineEditing: false,
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  SpecDocumentController controller,
) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SpecDocumentTree(controller: controller, model: controller.model),
      ),
    ),
  );
  await tester.pump();
}

/// Opens the empty field [name] (shown as a chip until then).
Future<void> _open(WidgetTester tester, String name) async {
  final chip = find.widgetWithText(ActionChip, name);
  if (chip.evaluate().isEmpty) return;
  await tester.tap(chip);
  await tester.pump();
}

Finder _formField(String name) => find.descendant(
  of: find.byKey(ValueKey('form:$_header/$name')),
  matching: find.byType(TextField),
);

/// Types [text] into [field] as an input method does: the field's whole new
/// value with the caret at its end.
Future<void> _typeAll(WidgetTester tester, Finder field, String text) async {
  await tester.showKeyboard(field);
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );
  await tester.pump();
}

/// The typing pause passes, ending the gesture (and its timer).
Future<void> _pause(WidgetTester tester) async {
  await tester.pump(forgeTypingPause);
  await tester.pump();
}

void main() {
  testWidgets('RDV1-1: the form is one grid — labels in a fixed-width left '
      'column, values in the right one, one row per field in model order', (
    tester,
  ) async {
    final controller = await _controller();
    await _pump(tester, controller);
    await _open(tester, 'header');

    final grid = find.byKey(const ValueKey('form-grid:$_header'));
    expect(grid, findsOneWidget);
    final table = tester.widget<Table>(grid);
    expect(table.children.map((r) => r.key), [
      const ValueKey('form-row:$_header/author'),
      const ValueKey('form-row:$_header/purpose'),
      const ValueKey('form-row:$_header/scope'),
    ]);

    final gridLeft = tester.getTopLeft(grid).dx;
    for (final (label, name) in [
      ('Author', 'author'),
      ('Purpose', 'purpose'),
      ('Scope', 'scope'),
    ]) {
      final labelBox = tester.getRect(
        find.descendant(of: grid, matching: find.text(label)),
      );
      final fieldBox = tester.getRect(_formField(name));
      expect(labelBox.left, gridLeft, reason: '$label in the left column');
      expect(
        fieldBox.left,
        gridLeft + 160,
        reason: '$name in the right column, after the fixed label width',
      );
      expect(
        labelBox.top,
        greaterThanOrEqualTo(fieldBox.top),
        reason: '$label on its value row',
      );
    }
  });

  testWidgets('RDV1-2: a hard-wrapped value edited in its cell keeps its line '
      'breaks', (tester) async {
    final controller = await _controller();
    const wrapped =
        'The purpose of this document is to state what the\n'
        'system does, for whom, and within which limits.';
    controller.setFormField(_header, 'purpose', wrapped);
    await _pump(tester, controller);
    await _open(tester, 'header');

    final field = _formField('purpose');
    expect(tester.widget<TextField>(field).controller!.text, wrapped);
    // One keystroke at the end: the breaks must survive it.
    await _typeAll(tester, field, '$wrapped!');
    expect(controller.formField(_header, 'purpose'), '$wrapped!');
    expect(
      tester.widget<TextField>(field).controller!.text,
      '$wrapped!',
      reason: 'the field shows the break it stores',
    );
    await _pause(tester);
  });

  testWidgets('RDV1-3: a multi-paragraph value is edited in a cell, stored '
      'exactly as typed', (tester) async {
    final controller = await _controller();
    await _pump(tester, controller);
    await _open(tester, 'header');

    const paragraphs =
        'First paragraph, one line.\n'
        '\n'
        'Second paragraph,\n'
        'wrapped over two lines.\n'
        '\n'
        '- a list item\n'
        '- another';
    final field = _formField('scope');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('form-grid:$_header')),
        matching: field,
      ),
      findsOneWidget,
      reason: 'the value is edited in its grid cell',
    );
    await _typeAll(tester, field, paragraphs);
    expect(controller.formField(_header, 'scope'), paragraphs);
    final text = tester.widget<TextField>(field);
    expect(text.maxLines, isNull, reason: 'the cell grows, never one line');
    expect(text.minLines, 1);
    await _pause(tester);
  });

  testWidgets('RDV1-4: a cell starts one line high and grows with its value', (
    tester,
  ) async {
    final controller = await _controller();
    await _pump(tester, controller);
    await _open(tester, 'header');

    final field = _formField('author');
    final oneLine = tester.getSize(field).height;
    expect(
      oneLine,
      lessThan(tester.getSize(_formField('purpose')).height * 1.01),
      reason: 'empty cells are the same, one line, height',
    );

    await _typeAll(tester, field, 'one\ntwo\nthree\nfour\nfive');
    await tester.pumpAndSettle();
    final fiveLines = tester.getSize(field).height;
    expect(fiveLines, greaterThan(oneLine * 3));

    // And shrinks back with the value.
    await _typeAll(tester, field, 'one');
    await tester.pumpAndSettle();
    expect(tester.getSize(field).height, closeTo(oneLine, 0.5));
    await _pause(tester);
  });

  testWidgets('RDV1-5: a scalar value keeps its line breaks too', (
    tester,
  ) async {
    final controller = await _controller();
    controller.addListItem(_items);
    await _pump(tester, controller);
    await _open(tester, 'items');
    await _open(tester, 'label');

    final item = controller.listItems(_items).single;
    final path = '$item/label';
    final field = find.descendant(
      of: find.byKey(ValueKey('content:$path')),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);
    await _typeAll(tester, field, 'a label\nwrapped');
    expect(controller.content(path), 'a label\nwrapped');
    expect(tester.widget<TextField>(field).maxLines, isNull);
    await _pause(tester);
  });
}
