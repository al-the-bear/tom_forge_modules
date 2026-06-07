// The per-website `content:` block (§6a): loader parsing + schema/validator
// agreement (single source of truth). A website omits `content:` to disable
// the content browser; when present, `dir` is the only required key.
import 'package:tom_website_editor_core/tom_website_editor_core.dart';
import 'package:test/test.dart';

/// A minimal valid config with a [content] block injected verbatim.
String _withContent(String contentBlock) => '''
version: 1
websites:
  - id: ef
    paths:
      websiteRoot: "/code/ef/website"
$contentBlock
''';

void main() {
  group('content block — loader', () {
    test('TWEC-CONT-01: parses every key', () {
      final result = loadWebsiteEditorConfig(_withContent('''
    content:
      dir: "{websiteRoot}/content"
      components: "components/*.yaml"
      site: "site.yaml"
      pages: "pages/*.md"
      editableFields: [tagline, summary-md, overview-md, enables]
      manualPin: "# @manual"
'''));
      expect(result.isValid, isTrue, reason: result.issues.toString());
      final content = result.config!.websites.single.content!;
      expect(content.dir, '{websiteRoot}/content');
      expect(content.components, 'components/*.yaml');
      expect(content.site, 'site.yaml');
      expect(content.pages, 'pages/*.md');
      expect(content.editableFields,
          ['tagline', 'summary-md', 'overview-md', 'enables']);
      expect(content.manualPin, '# @manual');
    });

    test('TWEC-CONT-02: omitted keys fall back to the conventional defaults',
        () {
      final result = loadWebsiteEditorConfig(_withContent('''
    content:
      dir: "{websiteRoot}/content"
'''));
      expect(result.isValid, isTrue, reason: result.issues.toString());
      final content = result.config!.websites.single.content!;
      expect(content.dir, '{websiteRoot}/content');
      expect(content.components, kDefaultContentComponents);
      expect(content.site, kDefaultContentSite);
      expect(content.pages, kDefaultContentPages);
      expect(content.editableFields, kDefaultEditableFields);
      expect(content.manualPin, kDefaultManualPin);
    });

    test('TWEC-CONT-03: a website without a content block opts out (null)', () {
      final result = loadWebsiteEditorConfig(_withContent(''));
      expect(result.isValid, isTrue, reason: result.issues.toString());
      expect(result.config!.websites.single.content, isNull);
    });
  });

  group('content block — validator/schema agreement', () {
    test('TWEC-CONT-04: missing required dir — validator + schema agree', () {
      const yaml = '''
version: 1
websites:
  - id: ef
    paths:
      websiteRoot: "/code/ef/website"
    content:
      site: "site.yaml"
''';
      final result = loadWebsiteEditorConfig(yaml);
      expect(result.isValid, isFalse);
      expect(
          result.issues.any((i) =>
              i.path.contains('content') && i.message.contains('dir')),
          isTrue,
          reason: result.issues.toString());

      // The JSON Schema requires `dir` on the content object too.
      final contentSchema = (((websiteEditorJsonSchema()['properties']
              as Map)['websites'] as Map)['items'] as Map)['properties']
          as Map;
      final content = contentSchema['content'] as Map;
      expect(content['required'], contains('dir'));
    });

    test('TWEC-CONT-05: wrong type for editableFields — rejected', () {
      final result = loadWebsiteEditorConfig(_withContent('''
    content:
      dir: "{websiteRoot}/content"
      editableFields: "tagline"
'''));
      expect(result.isValid, isFalse);
      expect(
          result.issues.any((i) => i.path.contains('editableFields')), isTrue,
          reason: result.issues.toString());
    });

    test('TWEC-CONT-06: unknown key inside content is rejected (typo guard)',
        () {
      final result = loadWebsiteEditorConfig(_withContent('''
    content:
      dir: "{websiteRoot}/content"
      componnts: "components/*.yaml"
'''));
      expect(result.isValid, isFalse);
      expect(result.issues.any((i) => i.message.contains('componnts')), isTrue,
          reason: result.issues.toString());
    });
  });
}
