// Tests for §14 cross-projection blueprint identity (N12 binding, OE-18).
//
// A spec is ONE document with thirteen roots: SolutionBlueprint (the master /
// source of truth) plus twelve Phase-3 projection roots that aggregate the
// SAME SBP00 classes. When an aggregated class is annotated (`@MapsTo` /
// `@DetailedIn`), its unique class section id names the one shared underlying
// section regardless of which root the editor reached it through. These tests
// pin `SpecDocumentController.canonicalPathFor` / `isProjectionRoot` over a
// synthetic SBP + RequirementsSpecification model that mirrors the real asset's
// shape (FunctionalRequirements is reachable via both SBP and RSP).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tom_specs_editor/src/document/spec_document_controller.dart';
import 'package:tom_specs_editor/src/structure/review_store.dart';
import 'package:tom_specs_editor/src/structure/spec_model.dart';

/// A two-root model: `SolutionBlueprint` (SBP, the master) and
/// `RequirementsSpecification` (RSP, a projection). `FunctionalRequirements` is
/// annotated (`detailedIn`) and reachable through *both* roots; its list of
/// requirements carries its own section id; `DocumentHeader` is an *unannotated*
/// shared class reached only through RSP (route-local — must not be conflated).
Map<String, dynamic> _sbpRspJson() => {
      'roots': [
        {
          'type': 'SolutionBlueprint',
          'title': 'Solution Blueprint',
          'sectionId': 'SBP',
        },
        {
          'type': 'RequirementsSpecification',
          'title': 'Requirements Specification',
          'sectionId': 'RSP',
        },
      ],
      'classes': {
        'SolutionBlueprint': {
          'name': 'SolutionBlueprint',
          'sectionId': 'SBP',
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
          'sectionId': 'SBP-SO',
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
          'sectionId': 'SBP-SO-REQ',
          'fields': [
            {
              'name': 'functionalRequirements',
              'kind': 'complex',
              'type': 'FunctionalRequirements',
            },
          ],
        },
        'RequirementsSpecification': {
          'name': 'RequirementsSpecification',
          'sectionId': 'RSP',
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
          'detailedIn': 'RequirementsSpecification',
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
    modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_sbpRspJson())),
    review: _tempReviewStore(),
  );
  await controller.ensureLoaded();
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('isProjectionRoot (§14 / N12)', () {
    test('SBP is the master, the others are projections', () async {
      final c = await _controller();
      expect(c.isProjectionRoot('SBP'), isFalse,
          reason: 'the Solution Blueprint root is the source of truth');
      expect(c.isProjectionRoot('SolutionBlueprint'), isFalse,
          reason: 'matched by type name, still the master');
      expect(c.isProjectionRoot('RSP'), isTrue);
      expect(c.isProjectionRoot('RequirementsSpecification'), isTrue);
    });

    test('an unknown root is not a projection', () async {
      final c = await _controller();
      expect(c.isProjectionRoot('ZZZ'), isFalse);
    });
  });

  group('canonicalPathFor (§14 / N12)', () {
    test('an annotated class canonicalizes identically via SBP and RSP routes',
        () async {
      final c = await _controller();
      const sbpRoute =
          'SBP/systemOverview/requirements/functionalRequirements';
      const rspRoute = 'RSP/functionalRequirements';
      expect(c.canonicalPathFor(sbpRoute), 'FR');
      expect(c.canonicalPathFor(rspRoute), 'FR');
      expect(c.canonicalPathFor(sbpRoute), c.canonicalPathFor(rspRoute),
          reason: 'both routes name the one shared FunctionalRequirements');
    });

    test('segments below the anchor are preserved verbatim', () async {
      final c = await _controller();
      const sbpRoute =
          'SBP/systemOverview/requirements/functionalRequirements/FRE-REQU-LST';
      const rspRoute = 'RSP/functionalRequirements/FRE-REQU-LST';
      expect(c.canonicalPathFor(sbpRoute), 'FR/FRE-REQU-LST');
      expect(c.canonicalPathFor(rspRoute), 'FR/FRE-REQU-LST');
    });

    test('an unannotated shared class stays route-local (no conflation)',
        () async {
      final c = await _controller();
      // DocumentHeader has a section id but no @MapsTo/@DetailedIn — each
      // document keeps its own header instance, so the route prefix is kept.
      expect(c.canonicalPathFor('RSP/header'), 'RSP/header');
    });

    test('the SBP master root and its unannotated nodes are unchanged',
        () async {
      final c = await _controller();
      expect(c.canonicalPathFor('SBP'), 'SBP');
      expect(c.canonicalPathFor('SBP/systemOverview'), 'SBP/systemOverview');
      expect(c.canonicalPathFor('SBP/systemOverview/requirements'),
          'SBP/systemOverview/requirements');
    });
  });
}
