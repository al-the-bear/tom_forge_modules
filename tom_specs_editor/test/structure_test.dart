// Tests for the ported structure browser + structural review (step 10).
//
// Covers three things the step's Done condition needs: the structure view
// renders a class-graph model, the review store persists/round-trips state to
// YAML, and the structure module wires its view into the DocSpecs left panel.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'package:tom_specs_editor/src/spec_structure_module.dart';
import 'package:tom_specs_editor/src/specs_shell_module.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';
import 'package:tom_specs_editor/src/structure/spec_structure_view.dart';
import 'package:tom_specs_editor/src/structure/spec_tree.dart';

/// A minimal class graph covering the field kinds the tree renders: a content
/// paragraph, a scalar, a complex sub-section, and a list of complex items.
Map<String, dynamic> _sampleJson() => {
  'roots': [
    {
      'type': 'DemoDoc',
      'title': 'Demo Document',
      'sectionId': 'D00',
      'description': 'A demo document for tests.',
    },
  ],
  'classes': {
    'DemoDoc': {
      'name': 'DemoDoc',
      'sectionId': 'D00',
      'fields': [
        {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
        {'name': 'name', 'kind': 'scalar', 'type': 'String'},
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
          'sectionIdPattern': 'D01.N',
        },
      ],
    },
    'DemoMeta': {
      'name': 'DemoMeta',
      'sectionId': 'D00-MET',
      'fields': [
        {'name': 'note', 'kind': 'scalar', 'type': 'String'},
      ],
    },
    'DemoItem': {
      'name': 'DemoItem',
      'fields': [
        {'name': 'label', 'kind': 'scalar', 'type': 'String'},
      ],
    },
  },
};

void main() {
  testWidgets('SpecStructureView renders the tree for a class-graph model', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final model = SpecModel.fromJson(_sampleJson());
    final dir = Directory.systemTemp.createTempSync('specs_review_view_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = ReviewStore(File('${dir.path}/review.yaml'));

    final view = SpecStructureView(
      modelFuture: Future<SpecModel>.value(model),
      store: store,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) => view.buildMain(context)),
        ),
      ),
    );
    // Let the model future resolve and the tree build.
    await tester.pumpAndSettle();

    // The tree mounted for the (default-selected) first root, with no errors.
    expect(find.byType(SpecTree), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The document selector shows the root's section + title.
    expect(find.textContaining('Demo Document'), findsWidgets);
  });

  test('ReviewStore persists and round-trips review state to YAML', () {
    final dir = Directory.systemTemp.createTempSync('specs_review_store_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/review.yaml');

    const path = 'DemoDoc/items/§item/content';
    final store = ReviewStore(file)
      ..update(path, (e) {
        e.scope = ReviewScope.global;
        e.addDetails = true;
        e.comment = 'needs its own section';
      });

    expect(store.count, 1);
    expect(file.existsSync(), isTrue);

    // A fresh store loading the same file recovers the entry verbatim.
    final reloaded = ReviewStore(file)..load();
    final entry = reloaded.entryFor(path);
    expect(entry, isNotNull);
    expect(entry!.scope, ReviewScope.global);
    expect(entry.addDetails, isTrue);
    expect(entry.comment, 'needs its own section');

    // Clearing an entry back to empty removes it from the file.
    reloaded.update(path, (e) {
      e.scope = ReviewScope.none;
      e.addDetails = false;
      e.comment = '';
    });
    expect(reloaded.count, 0);
    final reloadedAgain = ReviewStore(file)..load();
    expect(reloadedAgain.count, 0);
  });

  test('ReviewScope.parse maps the legacy only_pd token to onlyThisDocument', () {
    // Pre-`Dxx`-redesign review files persisted the scope as `only_pd` (when the
    // master was the "Project Definition"). Loading them must still resolve to
    // the renamed scope so existing reviews are not silently downgraded.
    expect(ReviewScope.parse('only_pd'), ReviewScope.onlyThisDocument);
    expect(
      ReviewScope.parse('only_this_document'),
      ReviewScope.onlyThisDocument,
    );
    // The canonical token written back out is the new one.
    expect(ReviewScope.onlyThisDocument.token, 'only_this_document');
  });

  test('a structure_review.yaml carrying legacy only_pd still loads', () {
    final dir = Directory.systemTemp.createTempSync('specs_review_legacy_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/structure_review.yaml')
      ..writeAsStringSync(
        'version: 1\n'
        'entries:\n'
        '  "DemoDoc/items/§item/content":\n'
        '    scope: only_pd\n'
        '    comment: "from a pre-rename review"\n',
      );

    final store = ReviewStore(file)..load();
    final entry = store.entryFor('DemoDoc/items/§item/content');
    expect(entry, isNotNull);
    expect(entry!.scope, ReviewScope.onlyThisDocument);
    expect(entry.comment, 'from a pre-rename review');
  });

  test('SpecStructureModule hosts its view as the DocSpecs Structure tab', () {
    final model = SpecModel.fromJson(_sampleJson());
    final dir = Directory.systemTemp.createTempSync('specs_review_module_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final structureModule = SpecStructureModule(
      modelFuture: Future<SpecModel>.value(model),
      store: ReviewStore(File('${dir.path}/review.yaml')),
    );
    expect(structureModule.views, contains(structureModule.structureView));

    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'TomSpecs Editor',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final shellModule = SpecsShellModule(
      structureView: structureModule.structureView,
    )..activate(shell);

    final leftTabs = shellModule.docSpecs.panelLayout.leftPanel.tabs;
    expect(leftTabs.map((t) => t.title), contains('Structure'));
    final structureTab = leftTabs.firstWhere((t) => t.title == 'Structure');
    expect(structureTab.sections, contains(structureModule.structureView));
  });
}
