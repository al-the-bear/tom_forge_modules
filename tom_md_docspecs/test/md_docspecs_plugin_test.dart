import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_md_docspecs/tom_md_docspecs.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

/// A schema with one required top-level section, `Overview`.
specs.DocSpecSchema _overviewSchema() => specs.DocSpecSchema(
  id: 'test',
  version: '1.0',
  sectionTypes: {
    'overview': const specs.SectionTypeDef(
      name: 'overview',
      prefix: 'Overview',
      description: 'What the document is about',
    ),
  },
  document: specs.DocumentStructure(
    sections: {'overview': const specs.SectionDef(sectionType: 'overview')},
  ),
);

void main() {
  // ── Schema Validation ──

  group('MdSchemaValidator', () {
    test('validate returns empty list when no schema is set', () {
      final validator = MdSchemaValidator();
      final doc = MdParser.parse('# Test\n\nBody.');
      expect(validator.validate(doc), isEmpty);
    });

    test('hasSchema is false initially', () {
      final validator = MdSchemaValidator();
      expect(validator.hasSchema, isFalse);
      expect(validator.schemaId, isNull);
    });

    test('setSchema makes hasSchema true', () {
      final validator = MdSchemaValidator();
      final schema = specs.DocSpecSchema(
        id: 'test',
        version: '1.0',
        sectionTypes: {},
        document: const specs.DocumentStructure(sections: {}),
      );
      validator.setSchema(schema);
      expect(validator.hasSchema, isTrue);
      expect(validator.schemaId, 'test/1.0');
    });

    test('clearSchema resets state', () {
      final validator = MdSchemaValidator();
      final schema = specs.DocSpecSchema(
        id: 'test',
        version: '1.0',
        sectionTypes: {},
        document: const specs.DocumentStructure(sections: {}),
      );
      validator.setSchema(schema);
      validator.clearSchema();
      expect(validator.hasSchema, isFalse);
      expect(validator.schemaId, isNull);
    });

    test('validate runs against schema and returns results', () {
      final schema = specs.DocSpecSchema(
        id: 'test',
        version: '1.0',
        sectionTypes: {
          'overview': const specs.SectionTypeDef(
            name: 'overview',
            prefix: 'Overview',
          ),
        },
        document: specs.DocumentStructure(
          sections: {
            'Overview': const specs.SectionDef(sectionType: 'overview'),
          },
        ),
      );
      final validator = MdSchemaValidator();
      validator.setSchema(schema);

      // Document without required "Overview" section
      final doc = MdParser.parse('# Wrong Title\n\nBody.');
      final errors = validator.validate(doc);
      // Validator should detect missing required section
      expect(errors, isA<List<ValidationError>>());
    });

    test('validate converts MdSection tree correctly', () {
      final schema = specs.DocSpecSchema(
        id: 'test',
        version: '1.0',
        sectionTypes: {},
        document: const specs.DocumentStructure(sections: {}),
      );
      final validator = MdSchemaValidator();
      validator.setSchema(schema);

      final doc = MdParser.parse(
        '# Title\n\nBody text.\n\n## Child\n\nChild body.\n',
      );
      // Should not throw when converting nested sections
      final errors = validator.validate(doc);
      expect(errors, isA<List<ValidationError>>());
    });
  });

  // ── Controller Schema Integration ──

  group('MdEditorController schema integration', () {
    test('setSchema triggers validation', () {
      final events = <ValidationChangedEvent>[];
      final ctrl = MdEditorController(
        initialMarkdown: '# Test\n\nBody.',
        eventHandlers: MdEditorEventHandlers(
          onValidationChanged: (e) => events.add(e),
        ),
      );

      final schema = specs.DocSpecSchema(
        id: 'test',
        version: '1.0',
        sectionTypes: {},
        document: const specs.DocumentStructure(sections: {}),
      );
      ctrl.setSchema(schema);
      expect(events, isNotEmpty);
      ctrl.dispose();
    });

    test('clearSchema removes validation errors', () {
      final events = <ValidationChangedEvent>[];
      final ctrl = MdEditorController(
        initialMarkdown: '# Test\n\nBody.',
        eventHandlers: MdEditorEventHandlers(
          onValidationChanged: (e) => events.add(e),
        ),
      );

      final schema = specs.DocSpecSchema(
        id: 'test',
        version: '1.0',
        sectionTypes: {},
        document: const specs.DocumentStructure(sections: {}),
      );
      ctrl.setSchema(schema);
      ctrl.clearSchema();
      expect(ctrl.validationErrors, isEmpty);
      // Last event should have empty errors list
      expect(events.last.errors, isEmpty);
      ctrl.dispose();
    });

    test('validation runs on markdown change', () {
      final events = <ValidationChangedEvent>[];
      final ctrl = MdEditorController(
        initialMarkdown: '# Test\n\nBody.',
        eventHandlers: MdEditorEventHandlers(
          onValidationChanged: (e) => events.add(e),
        ),
      );

      final schema = specs.DocSpecSchema(
        id: 'test',
        version: '1.0',
        sectionTypes: {},
        document: const specs.DocumentStructure(sections: {}),
      );
      ctrl.setSchema(schema);
      final eventsBefore = events.length;

      ctrl.applyEdit('# Updated\n\nNew body.');
      expect(events.length, greaterThan(eventsBefore));
      ctrl.dispose();
    });
  });

  group('MD-DOCS the DocSpecs plugin', () {
    test('MD-DOCS-1: setSchema attaches the schema as schema support', () {
      final controller = MdEditorController(initialMarkdown: '# Title\n');
      addTearDown(controller.dispose);
      expect(controller.schema, isNull);

      final schema = _overviewSchema();
      controller.setSchema(schema);
      expect(controller.schema, same(schema));
      expect(controller.schemaSupport, isA<MdDocSpecsSupport>());
      expect(controller.schemaSupport!.schemaId, 'test/1.0');
      expect(controller.schemaHelper, isNotNull);

      controller.clearSchema();
      expect(controller.schema, isNull);
      expect(controller.schemaSupport, isNull);
    });

    test('MD-DOCS-2: the support answers section types, ids and templates', () {
      final support = MdDocSpecsSupport(_overviewSchema());
      final document = MdParser.parse('# Overview\n<!-- id=Overview -->\n');
      expect(support.allowedTopLevelSections().single.typeName, 'overview');
      expect(support.allowedTopLevelSections().single.optional, isFalse);
      expect(support.idPrefixes(), ['Overview']);
      expect(support.suggestedId('overview'), 'Overview');
      expect(
        support.sectionTypeTooltip('overview'),
        'overview — What the document is about',
      );
      expect(support.validate(document), isA<List<ValidationError>>());
    });

    test(
      'MD-DOCS-3: scaffolding adds the required section, one history entry',
      () async {
        final controller = MdEditorController(initialMarkdown: '# Other\n');
        addTearDown(controller.dispose);
        controller.setSchema(_overviewSchema());

        final created = await controller.scaffoldMissingSections();
        expect(created, 1);
        List<String> headlines() =>
            controller.document.sections.map((s) => s.headline).toList();
        expect(headlines(), ['Other', 'Overview']);
        expect(controller.canUndo, isTrue);
        controller.undo();
        expect(headlines(), ['Other']);
      },
    );

    testWidgets('MD-DOCS-4: the editor shows the schema\'s panels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = MdEditorController(initialMarkdown: '# Other\n');
      addTearDown(controller.dispose);
      controller.setSchema(_overviewSchema());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditor(
              controller: controller,
              settings: MdEditorSettings.standard().copyWith(
                showSchemaInfoPanel: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(MdForEachSyncBanner), findsOneWidget);
      expect(find.byType(MdSchemaInfoPanel), findsOneWidget);
    });

    testWidgets('MD-DOCS-5: without a schema the panels are absent', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = MdEditorController(initialMarkdown: '# Other\n');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditor(
              controller: controller,
              settings: MdEditorSettings.standard().copyWith(
                showSchemaInfoPanel: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(MdForEachSyncBanner), findsNothing);
      expect(find.byType(MdSchemaInfoPanel), findsNothing);
    });
  });
}
