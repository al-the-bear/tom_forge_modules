// Content model (§6a): typed-suffix editor routing, span-precise record
// parsing + field classification (managed vs editable vs pinned), the
// `# @manual` pin read/write, and the override/managed page-region round-trip.
//
// These are the pure-Dart pieces the content browser builds on; they have no
// Flutter or file-system dependency, so they exercise the catalog logic
// directly against literal YAML / Markdown fixtures.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

const _editableFields = ['tagline', 'summary-md', 'overview-md', 'enables'];
const _manualPin = '# @manual';

const _component = '''
id: button
name: Button
tagline: A clickable thing
summary-md: |
  ## Button
  Click me.
status: stable
links-json: "[]"
extra: keep-me  # @manual
modules:
  - id: primary
    name: Primary
    overview-md: Primary variant
    color: blue
    submodules:
      - id: large
        name: Large
        size: lg
      - id: small
        size: sm
  - id: secondary
    name: Secondary
    color: gray
''';

void main() {
  group('TWE-MODEL-01: contentEditorKindForField', () {
    test('routes by typed suffix', () {
      expect(contentEditorKindForField('summary-md'),
          ContentEditorKind.markdown);
      expect(contentEditorKindForField('links-json'), ContentEditorKind.json);
      expect(contentEditorKindForField('tagline'), ContentEditorKind.string);
    });
  });

  group('TWE-MODEL-02: parseComponentRecord tree', () {
    test('builds component → module → submodule levels', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);

      expect(record.kind, ContentRecordKind.component);
      expect(record.id, 'button');
      expect(record.label, 'Button');
      expect(record.children, hasLength(2));

      final primary = record.children[0];
      expect(primary.kind, ContentRecordKind.module);
      expect(primary.id, 'primary');
      expect(primary.children, hasLength(2),
          reason: 'primary has two submodules');
      expect(primary.children.first.kind, ContentRecordKind.submodule);

      final secondary = record.children[1];
      expect(secondary.id, 'secondary');
      expect(secondary.children, isEmpty,
          reason: 'secondary has no submodules');
    });
  });

  group('TWE-MODEL-03: field classification', () {
    test('curated fields are editable, others managed, pins win', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);
      final byName = {for (final f in record.fields) f.name: f};

      expect(byName['tagline']!.isEditable, isTrue);
      expect(byName['summary-md']!.isEditable, isTrue);
      expect(byName['status']!.isEditable, isFalse);
      expect(byName['links-json']!.isEditable, isFalse,
          reason: 'a -json suffix does not make a field editable');
      expect(byName['extra']!.isEditable, isTrue,
          reason: 'a # @manual pin makes a managed field editable');
      expect(byName['extra']!.isPinned, isTrue);

      expect(record.editableFields.map((f) => f.name),
          containsAll(['tagline', 'summary-md', 'extra']));
      expect(record.managedFields.map((f) => f.name),
          containsAll(['status', 'links-json']));
    });

    test('block-scalar fields keep a correct source line', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);
      final summary =
          record.fields.firstWhere((f) => f.name == 'summary-md');
      final lines = _component.split('\n');
      expect(lines[summary.sourceLine], contains('summary-md:'));
    });
  });

  group('TWE-MODEL-04: pinFieldLine', () {
    test('appends the pin and survives a re-parse', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);
      final status = record.fields.firstWhere((f) => f.name == 'status');
      expect(status.isPinned, isFalse);

      final pinned =
          pinFieldLine(_component, status.sourceLine, _manualPin);
      expect(pinned, contains('status: stable  # @manual'));

      final reparsed = parseComponentRecord(pinned,
          editableFields: _editableFields, manualPin: _manualPin);
      final reStatus =
          reparsed.fields.firstWhere((f) => f.name == 'status');
      expect(reStatus.isPinned, isTrue);
      expect(reStatus.isEditable, isTrue);
    });

    test('is idempotent when the pin already exists', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);
      final extra = record.fields.firstWhere((f) => f.name == 'extra');
      final once = pinFieldLine(_component, extra.sourceLine, _manualPin);
      expect(once, _component, reason: 'already pinned → unchanged');
    });
  });

  group('TWE-MODEL-06: setFieldLineValue', () {
    test('replaces a scalar value and re-parses', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);
      final tagline = record.fields.firstWhere((f) => f.name == 'tagline');

      final edited =
          setFieldLineValue(_component, tagline.sourceLine, 'Pressable');
      expect(edited, contains('tagline: Pressable'));
      expect(edited, contains('id: button'),
          reason: 'other lines are untouched');

      final reparsed = parseComponentRecord(edited,
          editableFields: _editableFields, manualPin: _manualPin);
      expect(reparsed.fields.firstWhere((f) => f.name == 'tagline').value,
          'Pressable');
    });

    test('quotes a value with YAML-special characters', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);
      final tagline = record.fields.firstWhere((f) => f.name == 'tagline');

      final edited =
          setFieldLineValue(_component, tagline.sourceLine, 'a: b # c');
      expect(edited, contains('tagline: "a: b # c"'));

      final reparsed = parseComponentRecord(edited,
          editableFields: _editableFields, manualPin: _manualPin);
      expect(reparsed.fields.firstWhere((f) => f.name == 'tagline').value,
          'a: b # c');
    });

    test('preserves a pin comment when asked', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);
      final extra = record.fields.firstWhere((f) => f.name == 'extra');
      expect(extra.isPinned, isTrue);

      final edited = setFieldLineValue(_component, extra.sourceLine, 'changed',
          preserveComment: _manualPin);
      expect(edited, contains('extra: changed  # @manual'));
    });

    test('returns the source unchanged for an out-of-range line', () {
      expect(setFieldLineValue(_component, 9999, 'x'), _component);
    });
  });

  group('TWE-MODEL-05: ContentPage override regions', () {
    const raw = 'intro line\n'
        '<!-- @tom:managed -->\n'
        'generated body\n'
        '<!-- @tom:override -->\n'
        'hand written\n'
        'more hand';

    test('round-trips the source exactly', () {
      final page = ContentPage.parse(raw);
      expect(page.serialize(), raw);
    });

    test('classifies regions and exposes editable bodies', () {
      final page = ContentPage.parse(raw);
      expect(page.regions, hasLength(3));
      expect(page.regions[0].kind, ContentRegionKind.managed);
      expect(page.regions[0].hasMarker, isFalse);
      expect(page.regions[1].kind, ContentRegionKind.managed);
      expect(page.regions[2].kind, ContentRegionKind.editable);

      final editable = page.editableRegions.single;
      expect(editable.body, 'hand written\nmore hand');
    });

    test('withRegionBody preserves marker + other regions', () {
      final page = ContentPage.parse(raw);
      final updated = page.withRegionBody(2, 'edited\ntext');
      expect(updated.serialize(),
          'intro line\n'
          '<!-- @tom:managed -->\n'
          'generated body\n'
          '<!-- @tom:override -->\n'
          'edited\n'
          'text');
    });
  });

  group('TWE-MODEL-07: _generated provenance', () {
    const withGen = '''
id: button
name: Button
status: stable
_generated:
  by: tom-generate
  at: 2026-06-01T10:00:00Z
''';

    test('captures the _generated block as record provenance, not a field', () {
      final record = parseComponentRecord(withGen,
          editableFields: _editableFields, manualPin: _manualPin);

      expect(record.provenance, isNotNull);
      expect(record.provenance, contains('by: tom-generate'));
      expect(record.provenance, contains('at: 2026-06-01T10:00:00Z'));
      expect(record.fields.map((f) => f.name), isNot(contains('_generated')),
          reason: '_generated is provenance, never an inline field');
    });

    test('provenance is null when there is no _generated block', () {
      final record = parseComponentRecord(_component,
          editableFields: _editableFields, manualPin: _manualPin);
      expect(record.provenance, isNull);
    });
  });

  group('TWE-MODEL-08: valueHasPlaceholder', () {
    test('detects bare {placeholder} tokens', () {
      expect(valueHasPlaceholder('{websiteRoot}/docs'), isTrue);
      expect(valueHasPlaceholder('see {env:HOME}'), isTrue);
      expect(valueHasPlaceholder('{date}'), isTrue);
    });

    test('ignores literals and flow-map-like values', () {
      expect(valueHasPlaceholder('plain value'), isFalse);
      expect(valueHasPlaceholder('{ a: 1 }'), isFalse,
          reason: 'a YAML flow map (space after brace) is not a placeholder');
      expect(valueHasPlaceholder(r'price is $5'), isFalse);
    });
  });
}
