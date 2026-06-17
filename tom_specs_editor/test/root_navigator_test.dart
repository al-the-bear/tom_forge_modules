// Tests for the §14 root navigator (step 20): Project Definition first, a
// separator, then the other roots alphabetically; selecting a root re-renders
// the document editor as that projection over the *same* shared document.
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

/// Three roots in deliberately non-alphabetical, non-PD-first order so the
/// ordering policy (PD first, then alphabetical by title) is actually exercised.
/// Each root's class carries one distinctively-named content field so the
/// rendered projection is identifiable by its chip/editor.
Map<String, dynamic> _multiRootJson() => {
      'roots': [
        {
          'type': 'CurrentSituation',
          'title': 'Current Situation',
          'sectionId': 'CS',
        },
        {
          'type': 'ProjectDefinition',
          'title': 'Project Definition',
          'sectionId': 'PD',
        },
        {
          'type': 'AuthorizationConcept',
          'title': 'Authorization Concept',
          'sectionId': 'AC',
        },
      ],
      'classes': {
        'ProjectDefinition': {
          'name': 'ProjectDefinition',
          'sectionId': 'PD',
          'fields': [
            {'name': 'pdOverview', 'kind': 'content', 'sectionId': 'PD-OVR'},
          ],
        },
        'CurrentSituation': {
          'name': 'CurrentSituation',
          'sectionId': 'CS',
          'fields': [
            {'name': 'csOverview', 'kind': 'content', 'sectionId': 'CS-OVR'},
          ],
        },
        'AuthorizationConcept': {
          'name': 'AuthorizationConcept',
          'sectionId': 'AC',
          'fields': [
            {'name': 'acOverview', 'kind': 'content', 'sectionId': 'AC-OVR'},
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
  group('navigator ordering (§14)', () {
    test('Project Definition is first, then the rest alphabetically by title',
        () {
      final model = SpecModel.fromJson(_multiRootJson());
      final ordered = navigatorRootOrder(model.roots).map((r) => r.type);
      expect(
        ordered,
        ['ProjectDefinition', 'AuthorizationConcept', 'CurrentSituation'],
      );
    });

    test('defaultNavigatorRoot is Project Definition when present', () {
      final model = SpecModel.fromJson(_multiRootJson());
      expect(defaultNavigatorRoot(model.roots)!.type, 'ProjectDefinition');
    });

    test('defaultNavigatorRoot falls back to the first root without a PD', () {
      final roots = [
        SpecRoot(type: 'CurrentSituation', title: 'Current Situation',
            sectionId: 'CS'),
        SpecRoot(type: 'UseCases', title: 'Use Cases', sectionId: 'UC'),
      ];
      expect(defaultNavigatorRoot(roots)!.type, 'CurrentSituation');
      expect(defaultNavigatorRoot(const [])?.type, isNull);
    });
  });

  group('RootNavigator widget (§14)', () {
    testWidgets('lists every root with Project Definition first + a separator',
        (tester) async {
      final controller = await _controller();
      await _pumpNavigator(tester, controller);

      expect(find.text('Project Definition'), findsOneWidget);
      expect(find.text('Current Situation'), findsOneWidget);
      expect(find.text('Authorization Concept'), findsOneWidget);
      // The separator after Project Definition.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('tapping a root sets the controller active root', (tester) async {
      final controller = await _controller();
      await _pumpNavigator(tester, controller);

      // Defaults to Project Definition with nothing explicitly selected.
      expect(controller.activeRootType, isNull);

      await tester.tap(find.text('Current Situation'));
      await tester.pump();
      expect(controller.activeRootType, 'CS');
    });
  });

  group('document tree follows the active root (Done condition)', () {
    testWidgets('renders Project Definition by default, not the first root',
        (tester) async {
      final controller = await _controller();
      await _pumpTree(tester, controller);

      // PD is the default projection even though CurrentSituation is roots.first.
      expect(find.widgetWithText(ActionChip, 'pdOverview'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'csOverview'), findsNothing);
    });

    testWidgets('selecting another root re-renders that projection',
        (tester) async {
      final controller = await _controller();
      await _pumpTree(tester, controller);

      controller.setActiveRoot('CS');
      await tester.pump();

      expect(find.widgetWithText(ActionChip, 'csOverview'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'pdOverview'), findsNothing);
    });

    testWidgets('edits persist across root switches (same underlying data)',
        (tester) async {
      final controller = await _controller();
      await _pumpTree(tester, controller);

      // Author content under Project Definition's overview.
      controller.setContent('PD/PD-OVR', 'shared body');
      await tester.pump();
      expect(find.widgetWithText(TextField, 'shared body'), findsOneWidget);

      // Switch away to Authorization Concept, then back to Project Definition.
      controller.setActiveRoot('AC');
      await tester.pump();
      expect(find.widgetWithText(TextField, 'shared body'), findsNothing);

      controller.setActiveRoot('PD');
      await tester.pump();

      // The PD value is intact — switching projections never forks the store.
      expect(controller.content('PD/PD-OVR'), 'shared body');
      expect(find.widgetWithText(TextField, 'shared body'), findsOneWidget);
    });
  });
}
