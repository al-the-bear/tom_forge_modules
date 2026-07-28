// Tests for the `tom_specs_editor_specification.md` §14 root navigator (step
// 20): Solution Blueprint first, a separator, then the other roots
// alphabetically; selecting a root re-renders the document editor as that
// projection over the *same* shared document.
//
// The Done condition — "switching roots re-renders the same underlying data
// consistently" — is driven here over a synthetic multi-root model and a
// temp-file review store (asset loading is unavailable under flutter_test).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/document/root_navigator.dart';
import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/document/spec_document_editor.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// Three roots in deliberately non-alphabetical, non-blueprint-first order so
/// the ordering policy (Solution Blueprint first, then alphabetical by title) is
/// actually exercised. Each root's class carries one distinctively-named content
/// field so the rendered projection is identifiable by its chip/editor.
Map<String, dynamic> _multiRootJson() => {
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
      },
    };

ReviewStore _tempReviewStore() {
  final dir = Directory.systemTemp.createTempSync('root_nav_review');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return ReviewStore(File('${dir.path}/review.yaml'));
}

Future<SpecDocumentController> _controller() async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_multiRootJson())),
    review: _tempReviewStore(),
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _pumpNavigator(
    WidgetTester tester, SpecDocumentController controller) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: RootNavigatorList(controller: controller)),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpTree(
    WidgetTester tester, SpecDocumentController controller) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SpecDocumentTree(controller: controller, model: controller.model),
    ),
  ));
}

void main() {
  group('navigator ordering (tom_specs_editor_specification.md §14)', () {
    test('Solution Blueprint is first, then the rest alphabetically by title',
        () {
      final model = SpecModel.fromJson(_multiRootJson());
      final ordered = navigatorRootOrder(model.roots).map((r) => r.type);
      expect(
        ordered,
        ['SolutionBlueprint', 'CurrentLandscapeAssessment',
            'SecurityAccessSpecification'],
      );
    });

    test('defaultNavigatorRoot is Solution Blueprint when present', () {
      final model = SpecModel.fromJson(_multiRootJson());
      expect(defaultNavigatorRoot(model.roots)!.type, 'SolutionBlueprint');
    });

    test('defaultNavigatorRoot falls back to the first root without a blueprint',
        () {
      final roots = [
        SpecRoot(type: 'CurrentLandscapeAssessment',
            title: 'Current Landscape Assessment', sectionId: 'CLA'),
        SpecRoot(type: 'InteractionScenarios', title: 'Interaction Scenarios',
            sectionId: 'ISC'),
      ];
      expect(defaultNavigatorRoot(roots)!.type, 'CurrentLandscapeAssessment');
      expect(defaultNavigatorRoot(const [])?.type, isNull);
    });
  });

  group('RootNavigator widget (tom_specs_editor_specification.md §14)', () {
    testWidgets('lists every root with Solution Blueprint first + a separator',
        (tester) async {
      final controller = await _controller();
      await _pumpNavigator(tester, controller);

      expect(find.text('Solution Blueprint'), findsOneWidget);
      expect(find.text('Current Landscape Assessment'), findsOneWidget);
      expect(find.text('Security Access Specification'), findsOneWidget);
      // The separator after the Solution Blueprint.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('tapping a root sets the controller active root', (tester) async {
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
    testWidgets('renders the Solution Blueprint by default, not the first root',
        (tester) async {
      final controller = await _controller();
      await _pumpTree(tester, controller);

      // SBP is the default projection even though CLA is roots.first.
      expect(find.widgetWithText(ActionChip, 'sbpOverview'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'claOverview'), findsNothing);
    });

    testWidgets('selecting another root re-renders that projection',
        (tester) async {
      final controller = await _controller();
      await _pumpTree(tester, controller);

      controller.setActiveRoot('CLA');
      await tester.pump();

      expect(find.widgetWithText(ActionChip, 'claOverview'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'sbpOverview'), findsNothing);
    });

    testWidgets('edits persist across root switches (same underlying data)',
        (tester) async {
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

    testWidgets('the navigator footer reports the stamped model version',
        (tester) async {
      final controller = SpecDocumentController(
        modelFuture: Future<SpecModel>.value(SpecModel.fromJson(
          _multiRootJson()
            ..['modelVersion'] = 5
            ..['modelVersionLabel'] = '1.0.0+5.deadbee',
        )),
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
