// csmc9 — editor strict-mode validation surface.
//
// The editor wires the canonical runtime document validator
// (`tom_som_dart_runtime`'s `validateDocument`) into the document controller and
// renders each `SpecValidationError` as a per-section diagnostics badge, behind
// a strict-mode toggle. These tests prove:
//   * the controller runs the runtime validator and groups errors by section
//     path (every `SpecValidationCode`, incl. `oneOfCaseMismatch`);
//   * the toggle gates the overlay (off → no diagnostics; on → validation runs);
//   * the offending `@OneOf` subsection carries the mismatch badge in the tree.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/document/spec_document.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A model with a `@Form` (author), a `@Min(2)` list, and an `@OneOf` container
/// (`element`, discriminated on `kind`) carrying `action`/`input` case-bound
/// subsections plus a common one. Enough to trigger every `SpecValidationCode`.
Map<String, dynamic> _oneOfJson() => {
      'modelVersion': 1,
      'roots': [
        {'type': 'Widget', 'title': 'Widget', 'sectionId': 'WD00'},
      ],
      'classes': {
        'Widget': {
          'name': 'Widget',
          'sectionId': 'WD00',
          'annotations': [
            {'name': 'Document', 'arguments': {'title': 'Widget'}},
            {'name': 'SectionId', 'arguments': {'id': 'WD00'}},
          ],
          'fields': [
            {
              'name': 'owner',
              'kind': 'form',
              'sectionId': 'OWN',
              'formFields': [
                {'name': 'author', 'label': 'Author', 'type': 'String'},
              ],
            },
            {
              'name': 'risks',
              'kind': 'list',
              'sectionId': 'RSK',
              'elementType': 'Risk',
              'elementIsComplex': true,
              'min': 2,
            },
            {
              'name': 'element',
              'kind': 'complex',
              'sectionId': 'ELM',
              'type': 'Element',
            },
          ],
        },
        'Risk': {
          'name': 'Risk',
          'sectionId': 'RSK',
          'fields': [
            {'name': 'title', 'kind': 'content', 'sectionId': 'title'},
          ],
        },
        'Element': {
          'name': 'Element',
          'sectionId': 'ELM',
          'annotations': [
            {'name': 'SectionId', 'arguments': {'id': 'ELM'}},
            {'name': 'OneOf', 'arguments': {'discriminator': 'kind'}},
          ],
          'fields': [
            {
              'name': 'content',
              'kind': 'form',
              'formFields': [
                {
                  'name': 'kind',
                  'label': 'Kind',
                  'type': 'ElementKind',
                  'enumValues': ['action', 'input', 'display'],
                },
              ],
            },
            {
              'name': 'action',
              'kind': 'complex',
              'sectionId': 'ACT',
              'type': 'ActionSub',
              'annotations': [
                {'name': 'Case', 'arguments': {'value': 'ElementKind.action'}},
              ],
            },
            {
              'name': 'input',
              'kind': 'complex',
              'sectionId': 'INP',
              'type': 'InputSub',
              'annotations': [
                {'name': 'Case', 'arguments': {'value': 'ElementKind.input'}},
              ],
            },
            {
              'name': 'common',
              'kind': 'complex',
              'sectionId': 'CMN',
              'type': 'CommonSub',
            },
          ],
        },
        'ActionSub': {
          'name': 'ActionSub',
          'sectionId': 'ACT',
          'fields': [
            {'name': 'detail', 'kind': 'content', 'sectionId': 'detail'},
          ],
        },
        'InputSub': {
          'name': 'InputSub',
          'sectionId': 'INP',
          'fields': [
            {'name': 'detail', 'kind': 'content', 'sectionId': 'detail'},
          ],
        },
        'CommonSub': {
          'name': 'CommonSub',
          'sectionId': 'CMN',
          'fields': [
            {'name': 'detail', 'kind': 'content', 'sectionId': 'detail'},
          ],
        },
      },
    };

ReviewStore _tempReviewStore() {
  final dir = Directory.systemTemp.createTempSync('strict_validation_review');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return ReviewStore(File('${dir.path}/review.yaml'));
}

Future<SpecDocumentController> _controller({SpecDocument? document}) async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_oneOfJson())),
    review: _tempReviewStore(),
    document: document,
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

/// A document where the chosen case is `action` but the `input` subsection is
/// populated — one `oneOfCaseMismatch` anchored on `WD00/ELM/INP`.
SpecDocument _caseMismatchDoc() => SpecDocument()
  ..setFormField('WD00/ELM/content', 'kind', 'action')
  ..setContent('WD00/ELM/INP/detail', 'typed');

final Finder _diagnosticsBadge = find.byWidgetPredicate(
  (w) => w is Tooltip && (w.message ?? '').contains('oneOfCaseMismatch'),
);

void main() {
  group('SpecDocumentController.validate (csmc9)', () {
    test('a well-formed document validates clean', () async {
      final doc = SpecDocument()
        ..setFormField('WD00/ELM/content', 'kind', 'action')
        ..setContent('WD00/ELM/ACT/detail', 'go');
      final controller = await _controller(document: doc);
      expect(controller.validate(), isEmpty);
      expect(controller.validationByPath(), isEmpty);
    });

    test('validate returns empty before the model resolves', () {
      final controller = SpecDocumentController(
        modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_oneOfJson())),
        review: _tempReviewStore(),
      );
      addTearDown(controller.dispose);
      // No ensureLoaded() yet → schema-dependent validation is a safe no-op.
      expect(controller.validate(), isEmpty);
    });

    test('a dangling content path is reported', () async {
      final doc = SpecDocument()..setContent('WD00/ghost', 'x');
      final controller = await _controller(document: doc);
      final errors = controller.validate();
      expect(errors, hasLength(1));
      expect(errors.single.code, SpecValidationCode.danglingPath);
      expect(controller.validationByPath().keys, contains('WD00/ghost'));
    });

    test('an unknown form field is reported', () async {
      final doc = SpecDocument()..setFormField('WD00/OWN', 'phone', '123');
      final controller = await _controller(document: doc);
      expect(
        controller.validate().where(
            (e) => e.code == SpecValidationCode.unknownFormField),
        hasLength(1),
      );
    });

    test('a populated list below its @Min is reported', () async {
      final doc = SpecDocument()..addListItem('WD00/RSK'); // 1 item, min 2
      final controller = await _controller(document: doc);
      expect(
        controller.validate().where(
            (e) => e.code == SpecValidationCode.minItems),
        hasLength(1),
      );
    });

    test('a one-of case mismatch is grouped on the offending subsection path',
        () async {
      final controller = await _controller(document: _caseMismatchDoc());
      final byPath = controller.validationByPath();
      expect(byPath.keys, contains('WD00/ELM/INP'));
      final onSubsection = byPath['WD00/ELM/INP']!;
      expect(onSubsection, hasLength(1));
      expect(onSubsection.single.code, SpecValidationCode.oneOfCaseMismatch);
      expect(onSubsection.single.message, contains('input'));
    });
  });

  group('SpecDocumentController.setStrictValidation (csmc9)', () {
    test('toggling flips the notifier and notifies listeners', () async {
      final controller = await _controller();
      var notified = 0;
      controller.addListener(() => notified++);
      expect(controller.strictValidation.value, isFalse);
      controller.setStrictValidation(true);
      expect(controller.strictValidation.value, isTrue);
      expect(notified, 1);
      // A no-op toggle neither flips nor notifies again.
      controller.setStrictValidation(true);
      expect(notified, 1);
    });
  });

  group('strict-mode diagnostics overlay in the document tree (csmc9)', () {
    Future<void> pump(WidgetTester tester, SpecDocumentController c) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SpecDocumentTree(controller: c, model: c.model),
        ),
      ));
    }

    testWidgets('no diagnostics render while strict mode is off',
        (tester) async {
      final controller = await _controller(document: _caseMismatchDoc());
      await pump(tester, controller);
      // The mismatch exists in the document, but the overlay is off.
      expect(controller.strictValidation.value, isFalse);
      expect(_diagnosticsBadge, findsNothing);
    });

    testWidgets(
        'turning strict mode on surfaces the one-of mismatch on the offending '
        'subsection', (tester) async {
      final controller = await _controller(document: _caseMismatchDoc());
      controller.setStrictValidation(true);
      await pump(tester, controller);

      // The mismatch badge renders, and its tooltip names the one-of code and
      // the offending `input` subsection.
      expect(_diagnosticsBadge, findsOneWidget);
      final tooltip = tester.widget<Tooltip>(_diagnosticsBadge);
      expect(tooltip.message, contains('oneOfCaseMismatch'));
      expect(tooltip.message, contains('input'));
    });

    testWidgets('turning strict mode back off clears the overlay',
        (tester) async {
      final controller = await _controller(document: _caseMismatchDoc());
      controller.setStrictValidation(true);
      await pump(tester, controller);
      expect(_diagnosticsBadge, findsOneWidget);

      controller.setStrictValidation(false);
      await tester.pump();
      expect(_diagnosticsBadge, findsNothing);
    });
  });
}
