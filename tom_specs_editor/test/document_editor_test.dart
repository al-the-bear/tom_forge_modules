// Tests for the model-driven document editor + compact tree (step 19, §13).
//
// The step's Done condition: the bundled model renders; empty nodes collapse to
// clickable chips; lists add/remove. These tests drive the value-backed
// `SpecDocumentTree` over a synthetic model + temp-file review store (asset
// loading is not available under flutter_test), asserting the compact-tree
// behaviour and the live edits routed through the shared controller.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/document/spec_document.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A class graph covering every render kind: a content paragraph, an enum, a
/// `@Form` section, an empty complex sub-section, and a list of complex items.
Map<String, dynamic> _sampleJson() => {
      'roots': [
        {
          'type': 'DemoDoc',
          'title': 'Demo Document',
          'sectionId': 'D00',
          'description': 'A demo document for the editor.',
        },
      ],
      'classes': {
        'DemoDoc': {
          'name': 'DemoDoc',
          'sectionId': 'D00',
          'fields': [
            {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
            {
              'name': 'status',
              'kind': 'enum',
              'sectionId': 'D00-ST',
              'enumValues': ['draft', 'final'],
            },
            {
              'name': 'header',
              'kind': 'form',
              'sectionId': 'D00-HDR',
              'formFields': [
                {'name': 'author', 'label': 'Author', 'type': 'String'},
              ],
            },
            {
              'name': 'meta',
              'kind': 'complex',
              'type': 'DemoMeta',
              'sectionId': 'D00-MET',
            },
            {
              'name': 'items',
              'kind': 'list',
              'elementType': 'DemoItem',
              'elementIsComplex': true,
              'sectionId': 'D00-ITM',
            },
          ],
        },
        'DemoMeta': {
          'name': 'DemoMeta',
          'sectionId': 'D00-MET',
          'fields': [
            {'name': 'note', 'kind': 'content', 'sectionId': 'D00-MET-NOTE'},
          ],
        },
        'DemoItem': {
          'name': 'DemoItem',
          'fields': [
            {'name': 'label', 'kind': 'content', 'sectionId': 'D01-LBL'},
          ],
        },
      },
    };

/// A flat class with three content fields in document order, used to assert
/// empty-chip placement relative to an expanded sibling (D5).
Map<String, dynamic> _orderedJson() => {
      'roots': [
        {'type': 'OrderDoc', 'title': 'Ordered', 'sectionId': 'O00'},
      ],
      'classes': {
        'OrderDoc': {
          'name': 'OrderDoc',
          'sectionId': 'O00',
          'fields': [
            {'name': 'alpha', 'kind': 'content', 'sectionId': 'O00-A'},
            {'name': 'beta', 'kind': 'content', 'sectionId': 'O00-B'},
            {'name': 'gamma', 'kind': 'content', 'sectionId': 'O00-G'},
          ],
        },
      },
    };

ReviewStore _tempReviewStore() {
  final dir = Directory.systemTemp.createTempSync('doc_editor_review');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return ReviewStore(File('${dir.path}/review.yaml'));
}

Future<SpecDocumentController> _controller() => _controllerFor(_sampleJson());

Future<SpecDocumentController> _controllerFor(Map<String, dynamic> json) async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(json)),
    review: _tempReviewStore(),
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pump(WidgetTester tester, SpecDocumentController controller) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SpecDocumentTree(controller: controller, model: controller.model),
    ),
  ));
}

void main() {
  group('SpecDocument.hasValuesUnder (§13.1 D4 emptiness)', () {
    test('a path is empty until a value is set at or beneath it', () {
      final doc = SpecDocument();
      expect(doc.hasValuesUnder('D00/D00-OVR'), isFalse);
      doc.setContent('D00/D00-OVR', 'hello');
      expect(doc.hasValuesUnder('D00/D00-OVR'), isTrue);
      // The parent sees the descendant value too.
      expect(doc.hasValuesUnder('D00'), isTrue);
    });

    test('a list path is empty with zero items, non-empty once an item lands',
        () {
      final doc = SpecDocument();
      expect(doc.hasValuesUnder('D00/D00-ITM'), isFalse);
      final item = doc.addListItem('D00/D00-ITM');
      expect(doc.hasValuesUnder('D00/D00-ITM'), isTrue);
      doc.removeListItem(item);
      expect(doc.hasValuesUnder('D00/D00-ITM'), isFalse);
    });
  });

  group('compact tree (§13.1)', () {
    testWidgets('an empty document renders every field as a chip, no editors',
        (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);

      // Every top-level field collapses to a clickable chip…
      expect(find.byType(ActionChip), findsNWidgets(5));
      // …and no value editor is materialised yet.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DropdownButton<String>), findsNothing);
    });

    testWidgets('an all-empty complex subtree is a single chip (no descent)',
        (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);

      // The `meta` complex field is one chip; its child `note` is not rendered.
      expect(find.widgetWithText(ActionChip, 'meta'), findsOneWidget);
      expect(find.text('note'), findsNothing);
    });

    testWidgets('clicking a content chip inline-expands an editor (D2)',
        (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);

      await tester.tap(find.widgetWithText(ActionChip, 'overview'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'the overview body');
      expect(controller.content('D00/D00-OVR'), 'the overview body');
    });

    testWidgets('a non-empty node renders expanded, not as a chip',
        (tester) async {
      final controller = await _controller();
      controller.setContent('D00/D00-OVR', 'already written');
      await _pump(tester, controller);

      // `overview` shows its editor with the value; it is not a chip.
      expect(find.widgetWithText(ActionChip, 'overview'), findsNothing);
      expect(find.widgetWithText(TextField, 'already written'), findsOneWidget);
    });

    testWidgets('a list adds and removes items (D3)', (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);

      // Open the empty list, then add an item.
      await tester.tap(find.widgetWithText(ActionChip, 'items'));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Add item'));
      await tester.pump();
      expect(controller.listItems('D00/D00-ITM'), hasLength(1));

      // Remove it via the item's delete affordance.
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      expect(controller.listItems('D00/D00-ITM'), isEmpty);
    });

    testWidgets('an enum chip expands to a value dropdown', (tester) async {
      final controller = await _controller();
      await _pump(tester, controller);

      await tester.tap(find.widgetWithText(ActionChip, 'status'));
      await tester.pump();
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('empty-field chips sit in document order around an expanded '
        'sibling (D5)', (tester) async {
      final controller = await _controllerFor(_orderedJson());
      // Expand the *middle* field by giving it a value, leaving `alpha` (before)
      // and `gamma` (after) as empty chips.
      controller.setContent('O00/O00-B', 'beta body');
      await _pump(tester, controller);

      final alphaDy =
          tester.getTopLeft(find.widgetWithText(ActionChip, 'alpha')).dy;
      final betaDy =
          tester.getTopLeft(find.widgetWithText(TextField, 'beta body')).dy;
      final gammaDy =
          tester.getTopLeft(find.widgetWithText(ActionChip, 'gamma')).dy;

      // `alpha` precedes the expanded `beta`; `gamma` follows it. The chips are
      // placed at their field position — not bunched into one trailing run.
      expect(alphaDy, lessThan(betaDy),
          reason: 'the chip for the field before the expanded one renders above');
      expect(gammaDy, greaterThan(betaDy),
          reason: 'the chip for the field after the expanded one renders below');
    });
  });

  group('code content routing (§13 l / OE-1)', () {
    // The widget choice (summary-backed editor vs plain-text fallback) is
    // exercised by the production path: `flutter build linux` embeds the .sum
    // bundles and `_CodeField` renders the real editor when they are present.
    // Here we pin the deterministic routing decision — which content types are
    // treated as Dart/d4rt code — independent of asset availability.
    test('isDartCodeContentType matches only Dart/d4rt code flavours', () {
      expect(isDartCodeContentType('code'), isTrue);
      expect(isDartCodeContentType('code-dart'), isTrue);
      // d4rt code flavours route to the summary-backed editor too (step 11).
      expect(isDartCodeContentType('code-d4rt-flutter'), isTrue);
      expect(isDartCodeContentType('code-d4rt-doc'), isTrue);
      // Non-Dart code and prose stay plain text.
      expect(isDartCodeContentType('code-sql'), isFalse);
      expect(isDartCodeContentType('code-ddl'), isFalse);
      expect(isDartCodeContentType('text'), isFalse);
      expect(isDartCodeContentType(null), isFalse);
    });

    test('scopeForContentType maps each code flavour to its summary scope', () {
      // Names match the bundles declared in tom_specs_editor/buildkit.yaml.
      expect(scopeForContentType('code'), 'dart-plain');
      expect(scopeForContentType('code-dart'), 'dart-plain');
      expect(scopeForContentType('code-d4rt-flutter'), 'd4rt-flutter');
      // Maps to a scope that is not declared yet → unregistered at runtime, so
      // the field degrades to plain text via the absent-scope fallback.
      expect(scopeForContentType('code-d4rt-doc'), 'd4rt-document');
      // Non-code content has no scope.
      expect(scopeForContentType('code-sql'), isNull);
      expect(scopeForContentType('d4rt-flutter'), isNull);
      expect(scopeForContentType('text'), isNull);
      expect(scopeForContentType(null), isNull);
    });
  });

  group('layout content routing (§13 k / OE-3)', () {
    // The live d4rt-flutter render is deferred (OE-3a: analyzer ^8/^10
    // conflict); here we pin which content types route to the layout seam so
    // the convention and a future model-side layout section line up.
    test('isFlutterLayoutContentType matches layout flavours only', () {
      expect(isFlutterLayoutContentType('layout'), isTrue);
      expect(isFlutterLayoutContentType('flutter'), isTrue);
      expect(isFlutterLayoutContentType('flutter-layout'), isTrue);
      expect(isFlutterLayoutContentType('d4rt-flutter'), isTrue);
      // Code/prose/Dart stay on their own paths.
      expect(isFlutterLayoutContentType('code'), isFalse);
      expect(isFlutterLayoutContentType('code-dart'), isFalse);
      expect(isFlutterLayoutContentType('text'), isFalse);
      expect(isFlutterLayoutContentType(null), isFalse);
    });
  });
}
