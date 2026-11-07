// YRD9 — editor "strict" mode: headline/id editing restricted to list-entry
// sections.
//
// These tests drive the value-backed `SpecDocumentTree` over a synthetic model
// + in-memory review store, asserting the header controls:
//   * strict mode → a fixed section's headline is read-only (no edit field);
//   * non-strict mode → a fixed section's headline is an editable, prefilled
//     field whose commit lands on the controller;
//   * a *list-entry* section's headline AND section id are editable in BOTH
//     modes (the list-entry exception), prefilled from the element's @Headline
//     default and the @SectionIdPattern generator;
//   * flipping the strict-mode notifier re-gates the fixed headers live.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';
import 'support/review_store_support.dart';

/// A model with a fixed content section carrying an `@Headline` default and a
/// complex list whose element type carries its own `@Headline` default and the
/// owning list a `@SectionIdPattern` (so added items get a generated id).
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
          'name': 'overview',
          'kind': 'content',
          'sectionId': 'D00-OVR',
          'headline': 'Overview Heading',
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

ReviewStore _tempReviewStore() {
  return memoryReviewStore();
}

Future<SpecDocumentController> _controller({required bool strict}) async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_json())),
    review: _tempReviewStore(),
    strictHeadlineEditing: strict,
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pump(WidgetTester tester, SpecDocumentController controller) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SpecDocumentTree(controller: controller, model: controller.model),
      ),
    ),
  );
}

/// The `TextField` nested inside a keyed `_HeaderEditField`.
Finder _fieldOf(Finder header) =>
    find.descendant(of: header, matching: find.byType(TextField));

/// Enters [text] into the field and commits it (the header fields commit on
/// submit / focus loss, not per keystroke).
Future<void> _commitText(
  WidgetTester tester,
  Finder header,
  String text,
) async {
  await tester.enterText(_fieldOf(header), text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  group('YRD9 strict headline editing', () {
    testWidgets('strict mode: a fixed section header is read-only', (t) async {
      final controller = await _controller(strict: true);
      // Give `overview` a value so it renders expanded with its header.
      controller.setContent('D00/D00-OVR', 'body');
      await _pump(t, controller);

      // No editable headline field for the fixed root or fixed content section.
      expect(find.byKey(const ValueKey('headline:D00')), findsNothing);
      expect(find.byKey(const ValueKey('headline:D00/D00-OVR')), findsNothing);
    });

    testWidgets('non-strict mode: a fixed section header is editable and '
        'prefilled with its default headline', (t) async {
      final controller = await _controller(strict: false);
      controller.setContent('D00/D00-OVR', 'body');
      await _pump(t, controller);

      final header = find.byKey(const ValueKey('headline:D00/D00-OVR'));
      expect(header, findsOneWidget);
      // Prefilled from the @Headline default (YRD9 item 4 / YRD4).
      expect(
        t.widget<TextField>(_fieldOf(header)).controller?.text,
        'Overview Heading',
      );

      // Editing it lands on the controller (values go to the YRD3 store).
      await _commitText(t, header, 'My Custom Heading');
      expect(controller.headline('D00/D00-OVR'), 'My Custom Heading');
    });

    testWidgets('non-strict mode: a headline equal to the default clears the '
        'stored value (byte-stability)', (t) async {
      final controller = await _controller(strict: false);
      controller.setContent('D00/D00-OVR', 'body');
      await _pump(t, controller);

      final header = find.byKey(const ValueKey('headline:D00/D00-OVR'));
      await _commitText(t, header, 'Changed');
      expect(controller.headline('D00/D00-OVR'), 'Changed');
      // Re-typing the effective default clears the stored headline.
      await _commitText(t, header, 'Overview Heading');
      expect(controller.headline('D00/D00-OVR'), isNull);
    });

    testWidgets('list-entry headline and id are editable in strict mode', (
      t,
    ) async {
      final controller = await _controller(strict: true);
      await _pump(t, controller);

      // Open the list and add an item.
      await t.tap(find.widgetWithText(ActionChip, 'items'));
      await t.pump();
      await t.tap(find.widgetWithText(TextButton, 'Add item'));
      await t.pump();

      final itemPath = controller.listItems('D00/D00-ITM').single;
      // The @SectionIdPattern generated an id on add (AA1).
      expect(controller.itemSectionId(itemPath), isNotNull);

      // Both the item headline and id fields are present even in strict mode.
      final headline = find.byKey(ValueKey('item-headline:$itemPath'));
      final id = find.byKey(ValueKey('item-id:$itemPath'));
      expect(headline, findsOneWidget);
      expect(id, findsOneWidget);
      // The headline prefills from the element class's @Headline default.
      expect(
        t.widget<TextField>(_fieldOf(headline)).controller?.text,
        'Item Entry',
      );

      // Editing both lands on the controller.
      await _commitText(t, headline, 'Renamed Item');
      expect(controller.headline(itemPath), 'Renamed Item');
      await _commitText(t, id, 'D01.9');
      expect(controller.itemSectionId(itemPath), 'D01.9');
    });

    testWidgets('toggling strict mode re-gates fixed headers live', (t) async {
      final controller = await _controller(strict: true);
      controller.setContent('D00/D00-OVR', 'body');
      await _pump(t, controller);

      final header = find.byKey(const ValueKey('headline:D00/D00-OVR'));
      expect(header, findsNothing);

      // Flip to non-strict: the fixed header becomes editable without a rebuild.
      controller.strictHeadlineEditing.value = false;
      await t.pump();
      expect(header, findsOneWidget);
    });
  });
}
