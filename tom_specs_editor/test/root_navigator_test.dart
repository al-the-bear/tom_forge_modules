// Tests for the `tom_specs_editor_specification.md` §14 root navigator (step
// 20): Solution Blueprint first, a separator, then the other roots
// alphabetically; selecting a root re-renders the document editor as that
// projection over the *same* shared document.
//
// The Done condition — "switching roots re-renders the same underlying data
// consistently" — is driven here over a synthetic multi-root model and a
// in-memory review store (asset loading is unavailable under flutter_test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/document/root_navigator.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';
import 'support/review_store_support.dart';

/// Three roots in deliberately non-alphabetical, non-blueprint-first order so
/// the ordering policy (Solution Blueprint first, then alphabetical by title) is
/// actually exercised. Each root's class carries one distinctively-named content
/// field so the rendered projection is identifiable by its chip/editor.
///
/// [withGenerationInput] appends a fourth root marked `@CodeSpecsProjection` —
/// the shape of `D13CodeSpecsProjection`. Its title sorts *first*
/// alphabetically, so a test that finds it last is seeing the band, not the
/// alphabet.
Map<String, dynamic> _multiRootJson({bool withGenerationInput = false}) => {
  'roots': [
    {
      'type': 'CurrentLandscapeAssessment',
      'title': 'Current Landscape Assessment',
      'sectionId': 'CLA',
    },
    {
      'type': 'SolutionBlueprint',
      'title': 'Solution Blueprint',
      'sectionId': 'SBP',
    },
    {
      'type': 'SecurityAccessSpecification',
      'title': 'Security Access Specification',
      'sectionId': 'SAS',
    },
    if (withGenerationInput)
      {
        'type': 'CodeSpecsProjectionRoot',
        'title': 'A CodeSpecs Generation Projection',
        'sectionId': 'CGP',
      },
  ],
  'classes': {
    'SolutionBlueprint': {
      'name': 'SolutionBlueprint',
      'sectionId': 'SBP',
      'fields': [
        {'name': 'sbpOverview', 'kind': 'content', 'sectionId': 'SBP-OVR'},
      ],
    },
    'CurrentLandscapeAssessment': {
      'name': 'CurrentLandscapeAssessment',
      'sectionId': 'CLA',
      'fields': [
        {'name': 'claOverview', 'kind': 'content', 'sectionId': 'CLA-OVR'},
      ],
    },
    'SecurityAccessSpecification': {
      'name': 'SecurityAccessSpecification',
      'sectionId': 'SAS',
      'fields': [
        {'name': 'sasOverview', 'kind': 'content', 'sectionId': 'SAS-OVR'},
      ],
    },
    if (withGenerationInput)
      'CodeSpecsProjectionRoot': {
        'name': 'CodeSpecsProjectionRoot',
        'sectionId': 'CGP',
        'annotations': [
          {'name': 'CodeSpecsProjection', 'arguments': <String, dynamic>{}},
        ],
        'fields': [
          {'name': 'cgpOverview', 'kind': 'content', 'sectionId': 'CGP-OVR'},
        ],
      },
  },
};

ReviewStore _tempReviewStore() {
  return memoryReviewStore();
}

Future<SpecDocumentController> _controller({
  bool withGenerationInput = false,
}) async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(
      SpecModel.fromJson(
        _multiRootJson(withGenerationInput: withGenerationInput),
      ),
    ),
    review: _tempReviewStore(),
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pumpNavigator(
  WidgetTester tester,
  SpecDocumentController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: RootNavigatorList(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTree(
  WidgetTester tester,
  SpecDocumentController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SpecDocumentTree(controller: controller, model: controller.model),
      ),
    ),
  );
}

void main() {
  group('navigator ordering (tom_specs_editor_specification.md §14)', () {
    test(
      'Solution Blueprint is first, then the rest alphabetically by title',
      () {
        final model = SpecModel.fromJson(_multiRootJson());
        final ordered = navigatorRootOrder(model).map((r) => r.type);
        expect(ordered, [
          'SolutionBlueprint',
          'CurrentLandscapeAssessment',
          'SecurityAccessSpecification',
        ]);
      },
    );

    test('defaultNavigatorRoot is Solution Blueprint when present', () {
      final model = SpecModel.fromJson(_multiRootJson());
      expect(defaultNavigatorRoot(model)!.type, 'SolutionBlueprint');
    });

    test(
      'defaultNavigatorRoot falls back to the first root without a blueprint',
      () {
        final model = SpecModel.fromJson({
          'roots': [
            {
              'type': 'CurrentLandscapeAssessment',
              'title': 'Current Landscape Assessment',
              'sectionId': 'CLA',
            },
            {
              'type': 'InteractionScenarios',
              'title': 'Interaction Scenarios',
              'sectionId': 'ISC',
            },
          ],
          'classes': <String, dynamic>{},
        });
        expect(defaultNavigatorRoot(model)!.type, 'CurrentLandscapeAssessment');
        expect(
          defaultNavigatorRoot(
            SpecModel.fromJson({
              'roots': <dynamic>[],
              'classes': <String, dynamic>{},
            }),
          )?.type,
          isNull,
        );
      },
    );
  });

  group('generation-input band (tom_specs_editor_specification.md §14)', () {
    test('generation inputs sort into a band below the authored documents', () {
      final model = SpecModel.fromJson(
        _multiRootJson(withGenerationInput: true),
      );
      final ordered = navigatorRootOrder(model).map((r) => r.type);
      // 'A CodeSpecs Generation Projection' would sort *first* alphabetically;
      // it lands last because the band, not the alphabet, places it.
      expect(ordered, [
        'SolutionBlueprint',
        'CurrentLandscapeAssessment',
        'SecurityAccessSpecification',
        'CodeSpecsProjectionRoot',
      ]);
    });

    test('a generation input is never the default landing root', () {
      // No blueprint, and the only alternative to the projection sorts after
      // it — the default must still be the authored root.
      final model = SpecModel.fromJson({
        'roots': [
          {
            'type': 'CodeSpecsProjectionRoot',
            'title': 'A CodeSpecs Generation Projection',
            'sectionId': 'CGP',
          },
          {
            'type': 'CurrentLandscapeAssessment',
            'title': 'Current Landscape Assessment',
            'sectionId': 'CLA',
          },
        ],
        'classes': {
          'CodeSpecsProjectionRoot': {
            'name': 'CodeSpecsProjectionRoot',
            'annotations': [
              {'name': 'CodeSpecsProjection', 'arguments': <String, dynamic>{}},
            ],
            'fields': <dynamic>[],
          },
          'CurrentLandscapeAssessment': {
            'name': 'CurrentLandscapeAssessment',
            'fields': <dynamic>[],
          },
        },
      });
      expect(defaultNavigatorRoot(model)!.type, 'CurrentLandscapeAssessment');
    });

    testWidgets('the navigator draws a labelled heading above the band', (
      tester,
    ) async {
      final controller = await _controller(withGenerationInput: true);
      await _pumpNavigator(tester, controller);

      expect(
        find.text(kGenerationInputsBandLabel.toUpperCase()),
        findsOneWidget,
      );
      // The band's root is listed, not hidden.
      expect(find.text('A CodeSpecs Generation Projection'), findsOneWidget);
      // Two dividers now: after the Solution Blueprint, and opening the band.
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('a model with no generation input draws no band heading', (
      tester,
    ) async {
      final controller = await _controller();
      await _pumpNavigator(tester, controller);

      expect(find.text(kGenerationInputsBandLabel.toUpperCase()), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets(
      'a banded root stays selectable — the split is presentational',
      (tester) async {
        // The band says "this is not a document you author", not "you may not
        // touch it": an edit through any projection folds onto the same
        // Solution Blueprint storage path, so selection stays live.
        final controller = await _controller(withGenerationInput: true);
        await _pumpNavigator(tester, controller);

        await tester.tap(find.text('A CodeSpecs Generation Projection'));
        await tester.pump();
        expect(controller.activeRootType, 'CGP');
      },
    );
  });

  group('RootNavigator widget (tom_specs_editor_specification.md §14)', () {
    testWidgets(
      'lists every root with Solution Blueprint first + a separator',
      (tester) async {
        final controller = await _controller();
        await _pumpNavigator(tester, controller);

        expect(find.text('Solution Blueprint'), findsOneWidget);
        expect(find.text('Current Landscape Assessment'), findsOneWidget);
        expect(find.text('Security Access Specification'), findsOneWidget);
        // The separator after the Solution Blueprint.
        expect(find.byType(Divider), findsOneWidget);
      },
    );

    testWidgets('tapping a root sets the controller active root', (
      tester,
    ) async {
      final controller = await _controller();
      await _pumpNavigator(tester, controller);

      // Defaults to the Solution Blueprint with nothing explicitly selected.
      expect(controller.activeRootType, isNull);

      await tester.tap(find.text('Current Landscape Assessment'));
      await tester.pump();
      expect(controller.activeRootType, 'CLA');
    });
  });

  group('document tree follows the active root (Done condition)', () {
    testWidgets(
      'renders the Solution Blueprint by default, not the first root',
      (tester) async {
        final controller = await _controller();
        await _pumpTree(tester, controller);

        // SBP is the default projection even though CLA is roots.first.
        expect(find.widgetWithText(ActionChip, 'sbpOverview'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, 'claOverview'), findsNothing);
      },
    );

    testWidgets('selecting another root re-renders that projection', (
      tester,
    ) async {
      final controller = await _controller();
      await _pumpTree(tester, controller);

      controller.setActiveRoot('CLA');
      await tester.pump();

      expect(find.widgetWithText(ActionChip, 'claOverview'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'sbpOverview'), findsNothing);
    });

    testWidgets('edits persist across root switches (same underlying data)', (
      tester,
    ) async {
      final controller = await _controller();
      await _pumpTree(tester, controller);

      // Author content under the Solution Blueprint's overview.
      controller.setContent('SBP/SBP-OVR', 'shared body');
      await tester.pump();
      expect(find.widgetWithText(TextField, 'shared body'), findsOneWidget);

      // Switch away to Security Access Specification, then back to the blueprint.
      controller.setActiveRoot('SAS');
      await tester.pump();
      expect(find.widgetWithText(TextField, 'shared body'), findsNothing);

      controller.setActiveRoot('SBP');
      await tester.pump();

      // The SBP value is intact — switching projections never forks the store.
      expect(controller.content('SBP/SBP-OVR'), 'shared body');
      expect(find.widgetWithText(TextField, 'shared body'), findsOneWidget);
    });
  });

  group('model version stamp (tom_specs_editor_specification.md §17, B2)', () {
    test('SpecModel.fromJson parses modelVersion + label when stamped', () {
      final json = _multiRootJson()
        ..['modelVersion'] = 3
        ..['modelVersionLabel'] = '1.0.0+3.abc1234';
      final model = SpecModel.fromJson(json);
      expect(model.modelVersion, 3);
      expect(model.modelVersionLabel, '1.0.0+3.abc1234');
    });

    test('an unstamped model defaults to version 0 with no label', () {
      final model = SpecModel.fromJson(_multiRootJson());
      expect(model.modelVersion, 0);
      expect(model.modelVersionLabel, isNull);
    });

    testWidgets('the navigator footer reports the stamped model version', (
      tester,
    ) async {
      final controller = SpecDocumentController(
        modelFuture: Future<SpecModel>.value(
          SpecModel.fromJson(
            _multiRootJson()
              ..['modelVersion'] = 5
              ..['modelVersionLabel'] = '1.0.0+5.deadbee',
          ),
        ),
        review: _tempReviewStore(),
      );
      await controller.ensureLoaded();
      addTearDown(controller.dispose);
      await _pumpNavigator(tester, controller);

      expect(find.text('model v5 · 1.0.0+5.deadbee'), findsOneWidget);
    });

    testWidgets('an unstamped asset shows "model: unstamped"', (tester) async {
      final controller = await _controller();
      await _pumpNavigator(tester, controller);
      expect(find.text('model: unstamped'), findsOneWidget);
    });
  });
}
