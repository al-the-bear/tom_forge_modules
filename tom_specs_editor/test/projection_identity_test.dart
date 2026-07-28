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
            // An annotated class *below* a list item. Identity down here is
            // positional (which requirement), so the anchor scan must stop at
            // the item rather than collapsing every item onto REQ-DET.
            {'name': 'detail', 'kind': 'complex', 'type': 'RequirementDetail'},
          ],
        },
        'RequirementDetail': {
          'name': 'RequirementDetail',
          'sectionId': 'REQ-DET',
          'detailedIn': 'RequirementsSpecification',
          'fields': [
            {'name': 'rationale', 'kind': 'content', 'sectionId': 'REQ-DET-RAT'},
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

/// The two routes to the one shared `FunctionalRequirements` section: through
/// the Solution Blueprint master, and through the RSP projection.
const _sbpFr = 'SBP/systemOverview/requirements/functionalRequirements';
const _rspFr = 'RSP/functionalRequirements';

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

  group('storagePathFor (§14 storage identity)', () {
    test('both routes key on the master structural path', () async {
      final c = await _controller();
      expect(c.storagePathFor(_rspFr), _sbpFr);
      expect(c.storagePathFor(_sbpFr), _sbpFr,
          reason: 'the identity on the master route');
    });

    test('segments below the anchor are carried verbatim', () async {
      final c = await _controller();
      expect(c.storagePathFor('$_rspFr/FRE-REQU-LST'), '$_sbpFr/FRE-REQU-LST');
    });

    test('an unannotated shared class stays route-local', () async {
      final c = await _controller();
      expect(c.storagePathFor('RSP/header'), 'RSP/header');
      expect(c.storagePathFor('RSP/header/DOCHD-AUT'), 'RSP/header/DOCHD-AUT');
    });

    test('is idempotent and prefix-preserving, as the store requires',
        () async {
      final c = await _controller();
      for (final path in [
        _sbpFr,
        _rspFr,
        '$_rspFr/FRE-REQU-LST',
        '$_rspFr/FRE-REQU-LST-1/detail',
        'RSP/header',
        'SBP/systemOverview',
      ]) {
        final once = c.storagePathFor(path);
        expect(c.storagePathFor(once), once, reason: 'f(f($path)) == f($path)');
      }
      // A subtree maps onto a subtree: prefix scans over storage keys must keep
      // seeing everything beneath the prefix they were given.
      expect(c.storagePathFor('$_rspFr/FRE-REQU-LST-1/detail'),
          startsWith('${c.storagePathFor(_rspFr)}/'));
      expect(c.storagePathFor(_rspFr),
          startsWith('${c.storagePathFor('SBP/systemOverview')}/'));
    });

    test('the anchor scan stops at a list item, so items stay distinct',
        () async {
      final c = await _controller();
      // RequirementDetail is annotated, but it sits below a list item: anchoring
      // on it would give every requirement's detail the same key.
      final first = c.storagePathFor('$_rspFr/FRE-REQU-LST-1/detail');
      final second = c.storagePathFor('$_rspFr/FRE-REQU-LST-2/detail');
      expect(first, '$_sbpFr/FRE-REQU-LST-1/detail');
      expect(second, '$_sbpFr/FRE-REQU-LST-2/detail');
      expect(first, isNot(second));
    });
  });

  group('one section, one store entry (§14 value + review folding)', () {
    test('an edit through RSP is the same value as an edit through SBP',
        () async {
      final c = await _controller();
      c.setContent('$_rspFr/FRE-REQU-LST', 'authored via the projection');

      expect(c.content('$_sbpFr/FRE-REQU-LST'), 'authored via the projection',
          reason: 'the master route reads the projection edit');
      expect(c.document.toJson()['content'], hasLength(1),
          reason: 'one section is one entry, not one per route');

      c.setContent('$_sbpFr/FRE-REQU-LST', 'rewritten via the master');
      expect(c.content('$_rspFr/FRE-REQU-LST'), 'rewritten via the master');
      expect(c.document.toJson()['content'], hasLength(1));
    });

    test('a form field folds across routes too', () async {
      final c = await _controller();
      c.setFormField(_rspFr, 'owner', 'ops');
      expect(c.formField(_sbpFr, 'owner'), 'ops');
      expect(c.document.toJson()['forms'], hasLength(1));
    });

    test('hasValuesUnder holds in storage space from either route', () async {
      final c = await _controller();
      c.setContent('$_rspFr/FRE-REQU-LST', 'v');

      // The scan is a prefix match over storage keys, so an ancestor of the
      // *master* route sees a value written through the projection route.
      expect(c.document.hasValuesUnder('SBP/systemOverview'), isTrue);
      expect(c.document.hasValuesUnder('SBP/systemOverview/requirements'),
          isTrue);
      expect(c.document.hasValuesUnder(_rspFr), isTrue);
      expect(c.document.hasValuesUnder(_sbpFr), isTrue);
      expect(c.document.hasValuesUnder('RSP/header'), isFalse);
    });

    test('a purge through one route clears the value seen by the other',
        () async {
      final c = await _controller();
      c.setContent('$_rspFr/FRE-REQU-LST', 'v');
      c.document.removeValuesUnder('SBP/systemOverview');
      expect(c.content('$_rspFr/FRE-REQU-LST'), isNull);
      expect(c.document.hasValuesUnder(_sbpFr), isFalse);
    });

    test('a review decision folds onto one entry', () async {
      final c = await _controller();
      c.setReview(_rspFr, (e) => e.scope = ReviewScope.global);
      expect(c.review.entryFor(_sbpFr)?.scope, ReviewScope.global);
      expect(c.review.count, 1);
    });

    test('values written before the model resolves are re-keyed on load',
        () async {
      // The mapping is derived from the model, so it cannot be installed at
      // construction. Edits made in that gap key raw and must be folded in
      // rather than stranded.
      final c = SpecDocumentController(
        modelFuture: Future<SpecModel>.value(SpecModel.fromJson(_sbpRspJson())),
        review: _tempReviewStore(),
      );
      addTearDown(c.dispose);
      c.setContent('$_rspFr/FRE-REQU-LST', 'early');
      c.setReview('$_rspFr/FRE-REQU-LST', (e) => e.stopHere = true);

      await c.ensureLoaded();

      expect(c.content('$_sbpFr/FRE-REQU-LST'), 'early');
      expect(c.document.toJson()['content'], hasLength(1));
      expect(c.review.entryFor('$_sbpFr/FRE-REQU-LST')?.stopHere, isTrue);
      expect(c.review.count, 1);
    });
  });
}
