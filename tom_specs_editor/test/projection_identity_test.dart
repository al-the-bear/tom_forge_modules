// Tests for §14 cross-projection PD identity (N12 binding, OE-18).
//
// A spec is ONE document with thirteen roots: ProjectDefinition (the master /
// source of truth) plus twelve Phase-3 projection roots that aggregate the
// SAME PD00 classes. When an aggregated class is annotated (`@MapsTo` /
// `@DetailedIn`), its unique class section id names the one shared underlying
// section regardless of which root the editor reached it through. These tests
// pin `SpecDocumentController.canonicalPathFor` / `isProjectionRoot` over a
// synthetic PD + RequirementsCatalog model that mirrors the real asset's shape
// (FunctionalRequirements is reachable via both PD and RC).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A two-root model: `ProjectDefinition` (PD, the master) and
/// `RequirementsCatalog` (RC, a projection). `FunctionalRequirements` is
/// annotated (`detailedIn`) and reachable through *both* roots; its list of
/// requirements carries its own section id; `DocumentHeader` is an *unannotated*
/// shared class reached only through RC (route-local — must not be conflated).
Map<String, dynamic> _pdRcJson() => {
      'roots': [
        {
          'type': 'ProjectDefinition',
          'title': 'Project Definition',
          'sectionId': 'PD',
        },
        {
          'type': 'RequirementsCatalog',
          'title': 'Requirements Catalog',
          'sectionId': 'RC',
        },
      ],
      'classes': {
        'ProjectDefinition': {
          'name': 'ProjectDefinition',
          'sectionId': 'PD',
          'fields': [
            {
              'name': 'systemOverview',
              'kind': 'complex',
              'type': 'SystemOverview',
            },
          ],
        },
        'SystemOverview': {
          'name': 'SystemOverview',
          'sectionId': 'PD-SO',
          'fields': [
            {
              'name': 'requirements',
              'kind': 'complex',
              'type': 'Requirements',
            },
          ],
        },
        'Requirements': {
          'name': 'Requirements',
          'sectionId': 'PD-SO-REQ',
          'fields': [
            {
              'name': 'functionalRequirements',
              'kind': 'complex',
              'type': 'FunctionalRequirements',
            },
          ],
        },
        'RequirementsCatalog': {
          'name': 'RequirementsCatalog',
          'sectionId': 'RC',
          'fields': [
            {'name': 'header', 'kind': 'complex', 'type': 'DocumentHeader'},
            {
              'name': 'functionalRequirements',
              'kind': 'complex',
              'type': 'FunctionalRequirements',
            },
          ],
        },
        // The annotated projection target: its class section id (FR) is the
        // canonical anchor; `detailedIn` makes it a projection node.
        'FunctionalRequirements': {
          'name': 'FunctionalRequirements',
          'sectionId': 'FR',
          'detailedIn': 'RequirementsCatalog',
          'fields': [
            {
              'name': 'requirementsList',
              'kind': 'list',
              'sectionId': 'FRE-REQU-LST',
              'elementType': 'Requirement',
              'elementIsComplex': true,
            },
          ],
        },
        'Requirement': {
          'name': 'Requirement',
          'fields': [
            {'name': 'label', 'kind': 'content', 'sectionId': 'FRE-LBL'},
          ],
        },
        // An UNannotated shared class: reached via RC only, stays route-local.
        'DocumentHeader': {
          'name': 'DocumentHeader',
          'sectionId': 'DOCHD',
          'fields': [
            {'name': 'author', 'kind': 'content', 'sectionId': 'DOCHD-AUT'},
          ],
        },
      },
    };

ReviewStore _tempReviewStore() {
  final dir = Directory.systemTemp.createTempSync('projection_identity');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return ReviewStore(File('${dir.path}/review.yaml'));
}

Future<SpecDocumentController> _controller() async {
  final controller = SpecDocumentController(
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_pdRcJson())),
    review: _tempReviewStore(),
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('isProjectionRoot (§14 / N12)', () {
    test('PD is the master, the others are projections', () async {
      final c = await _controller();
      expect(c.isProjectionRoot('PD'), isFalse,
          reason: 'the Project Definition root is the source of truth');
      expect(c.isProjectionRoot('ProjectDefinition'), isFalse,
          reason: 'matched by type name, still the master');
      expect(c.isProjectionRoot('RC'), isTrue);
      expect(c.isProjectionRoot('RequirementsCatalog'), isTrue);
    });

    test('an unknown root is not a projection', () async {
      final c = await _controller();
      expect(c.isProjectionRoot('ZZZ'), isFalse);
    });
  });

  group('canonicalPathFor (§14 / N12)', () {
    test('an annotated class canonicalizes identically via PD and RC routes',
        () async {
      final c = await _controller();
      const pdRoute =
          'PD/systemOverview/requirements/functionalRequirements';
      const rcRoute = 'RC/functionalRequirements';
      expect(c.canonicalPathFor(pdRoute), 'FR');
      expect(c.canonicalPathFor(rcRoute), 'FR');
      expect(c.canonicalPathFor(pdRoute), c.canonicalPathFor(rcRoute),
          reason: 'both routes name the one shared FunctionalRequirements');
    });

    test('segments below the anchor are preserved verbatim', () async {
      final c = await _controller();
      const pdRoute =
          'PD/systemOverview/requirements/functionalRequirements/FRE-REQU-LST';
      const rcRoute = 'RC/functionalRequirements/FRE-REQU-LST';
      expect(c.canonicalPathFor(pdRoute), 'FR/FRE-REQU-LST');
      expect(c.canonicalPathFor(rcRoute), 'FR/FRE-REQU-LST');
    });

    test('an unannotated shared class stays route-local (no conflation)',
        () async {
      final c = await _controller();
      // DocumentHeader has a section id but no @MapsTo/@DetailedIn — each
      // document keeps its own header instance, so the route prefix is kept.
      expect(c.canonicalPathFor('RC/header'), 'RC/header');
    });

    test('the PD master root and its unannotated nodes are unchanged',
        () async {
      final c = await _controller();
      expect(c.canonicalPathFor('PD'), 'PD');
      expect(c.canonicalPathFor('PD/systemOverview'), 'PD/systemOverview');
      expect(c.canonicalPathFor('PD/systemOverview/requirements'),
          'PD/systemOverview/requirements');
    });
  });
}
