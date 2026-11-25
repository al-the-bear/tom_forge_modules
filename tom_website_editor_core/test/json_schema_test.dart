// JSON Schema for tom.website-editor.yaml — §6 of the specification.
//
// The Dart field-spec model is the single source of truth: the runtime
// validator and this JSON Schema are both derived from it. These tests prove
// (a) the schema is generated correctly, (b) it agrees with the runtime
// validator on the same rules, and (c) the committed schema file is in sync.
import 'dart:convert';

import 'package:tom_website_editor_core/tom_website_editor_core.dart';
import 'package:test/test.dart';

import '../tool/schema_location.dart';

void main() {
  group('websiteEditorJsonSchema — structure', () {
    final schema = websiteEditorJsonSchema();

    test('TWEC-SCH-01: draft-07 object schema with the expected envelope', () {
      expect(schema[r'$schema'], 'http://json-schema.org/draft-07/schema#');
      expect(schema[r'$id'], 'tom.website-editor.schema.json');
      expect(schema['type'], 'object');
    });

    test('TWEC-SCH-02: top-level required mirrors the validator rules', () {
      final required = (schema['required'] as List).cast<String>();
      expect(required, containsAll(<String>['version', 'websites']));
    });

    test(
        'TWEC-SCH-03: version is a const integer; websites is a non-empty array',
        () {
      final props = schema['properties'] as Map<String, dynamic>;
      final version = props['version'] as Map<String, dynamic>;
      expect(version['type'], 'integer');
      expect(version['const'], 1);
      final websites = props['websites'] as Map<String, dynamic>;
      expect(websites['type'], 'array');
      expect(websites['minItems'], 1);
    });

    test('TWEC-SCH-04: a website requires id and paths.websiteRoot', () {
      final props = schema['properties'] as Map<String, dynamic>;
      final websites = props['websites'] as Map<String, dynamic>;
      final item = websites['items'] as Map<String, dynamic>;
      expect((item['required'] as List).cast<String>(),
          containsAll(['id', 'paths']));
      final paths = (item['properties'] as Map<String, dynamic>)['paths']
          as Map<String, dynamic>;
      expect(
          (paths['required'] as List).cast<String>(), contains('websiteRoot'));
    });

    test('TWEC-SCH-05: commands is a map of string command templates', () {
      final props = schema['properties'] as Map<String, dynamic>;
      final item = (props['websites'] as Map<String, dynamic>)['items']
          as Map<String, dynamic>;
      final commands = (item['properties'] as Map<String, dynamic>)['commands']
          as Map<String, dynamic>;
      expect(commands['type'], 'object');
      expect((commands['additionalProperties'] as Map)['type'], 'string');
    });
  });

  group('schema ⇄ validator agreement (single source of truth)', () {
    // Each malformed fixture is rejected by the runtime validator AND the
    // schema declares the matching constraint — both derive from the field-spec.
    test('TWEC-SCH-06: missing version — validator rejects, schema requires it',
        () {
      final result = loadWebsiteEditorConfig('''
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
''');
      expect(result.isValid, isFalse);
      final required =
          (websiteEditorJsonSchema()['required'] as List).cast<String>();
      expect(required, contains('version'));
    });

    test('TWEC-SCH-07: wrong version type — validator rejects, schema types it',
        () {
      final result = loadWebsiteEditorConfig('''
version: "1"
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
''');
      expect(result.isValid, isFalse);
      final props =
          websiteEditorJsonSchema()['properties'] as Map<String, dynamic>;
      expect((props['version'] as Map)['type'], 'integer');
    });

    test('TWEC-SCH-09: malformed commands — validator rejects, schema types it',
        () {
      final result = loadWebsiteEditorConfig('''
version: 1
websites:
  - id: ef
    paths: { websiteRoot: "/a" }
    commands: "jaspr build"
''');
      expect(result.isValid, isFalse);
      final item = ((websiteEditorJsonSchema()['properties']
              as Map<String, dynamic>)['websites']
          as Map<String, dynamic>)['items'] as Map<String, dynamic>;
      final commands =
          (item['properties'] as Map<String, dynamic>)['commands'] as Map;
      expect(commands['type'], 'object');
    });

    test(
        'TWEC-SCH-10: malformed paths — validator rejects, schema requires '
        'websiteRoot', () {
      final result = loadWebsiteEditorConfig('''
version: 1
websites:
  - id: ef
    paths: { designDir: "/a/design" }
''');
      expect(result.isValid, isFalse);
      final item = ((websiteEditorJsonSchema()['properties']
              as Map<String, dynamic>)['websites']
          as Map<String, dynamic>)['items'] as Map<String, dynamic>;
      final paths =
          (item['properties'] as Map<String, dynamic>)['paths'] as Map;
      expect(
          (paths['required'] as List).cast<String>(), contains('websiteRoot'));
    });
  });

  group('committed schema file is in sync', () {
    test(
        'TWEC-SCH-08: the Tom root\'s .tom/json-schema file equals the '
        'generated schema', () {
      final file = committedWebsiteEditorSchema();
      expect(file.existsSync(), isTrue,
          reason: 'committed schema missing at ${file.path} — '
              'run tool/write_schema.dart');
      final onDisk = jsonDecode(file.readAsStringSync());
      expect(onDisk, equals(websiteEditorJsonSchema()),
          reason: 'committed schema drifted from the field-spec model');
    });
  });
}
