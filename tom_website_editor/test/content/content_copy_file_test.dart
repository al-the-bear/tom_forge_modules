// ContentCopyFile (website §16 / editor §6a–§6b): an external editorial copy
// file `content/copy/<…>.md` is YAML front-matter + a Markdown body. The model
// parses the two halves, round-trips them byte-for-byte, edits a front-matter
// field or a body override region in place, and leaves §6.2 managed/override
// markers (and the managed regions they protect) untouched — so a hand edit
// survives the next `generateContent`.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

/// A copy file shaped like the live website §16 files: unsuffixed front-matter
/// keys (`tagline` / `summary` / `enables` — the canonical `editableFields`),
/// an editable overview **body**, and a managed region the generator owns.
const _copy = '''
---
tagline: A clickable thing
summary: A button users press.
enables: [forms, dialogs]
---
<!-- @tom:override -->
# Overview

Hand-written overview body.

<!-- @tom:managed -->
Generated: do not edit.
''';

void main() {
  group('TWE-COPY-01: parse front-matter + body', () {
    test('splits the front-matter map from the Markdown body', () {
      final file = ContentCopyFile.parse(_copy);
      expect(file.hasFrontMatter, isTrue);
      expect(file.frontMatterValue('tagline'), 'A clickable thing');
      expect(file.frontMatterValue('summary'), 'A button users press.');
      expect(file.frontMatterValue('enables'), 'forms, dialogs');
      expect(file.frontMatterValue('missing'), isNull);
      expect(file.body.serialize(), contains('# Overview'));
      expect(file.body.serialize(), contains('Generated: do not edit.'));
    });

    test('exposes front-matter fields with editor-kind routing', () {
      final file = ContentCopyFile.parse(_copy);
      final names = file.frontMatter.map((f) => f.name).toList();
      expect(names, ['tagline', 'summary', 'enables']);
      // The live §16 keys are unsuffixed scalars → plain-string routing; the
      // Markdown surface (the overview) is the body, not a front-matter field.
      final summary = file.frontMatter.firstWhere((f) => f.name == 'summary');
      expect(summary.editorKind, ContentEditorKind.string);
      final tagline = file.frontMatter.firstWhere((f) => f.name == 'tagline');
      expect(tagline.editorKind, ContentEditorKind.string);
    });
  });

  group('TWE-COPY-02: round-trip', () {
    test('serialize() reproduces the source exactly', () {
      final file = ContentCopyFile.parse(_copy);
      expect(file.serialize(), _copy);
    });

    test('a file without front-matter is all body and round-trips', () {
      const noFm = '# Just a body\n\nNo front-matter here.\n';
      final file = ContentCopyFile.parse(noFm);
      expect(file.hasFrontMatter, isFalse);
      expect(file.frontMatter, isEmpty);
      expect(file.serialize(), noFm);
    });
  });

  group('TWE-COPY-03: edit a front-matter field', () {
    test('replaces one value and preserves the rest + the body', () {
      final file = ContentCopyFile.parse(_copy);
      final edited = file.withFrontMatterValue('tagline', 'A pressable thing');

      expect(edited.frontMatterValue('tagline'), 'A pressable thing');
      // The other front-matter fields and the whole body are intact.
      expect(edited.frontMatterValue('summary'), 'A button users press.');
      expect(edited.frontMatterValue('enables'), 'forms, dialogs');
      expect(edited.serialize(), contains('# Overview'));
      expect(edited.serialize(), contains('Generated: do not edit.'));

      // Re-parsing the serialized form confirms the persisted edit.
      final reparsed = ContentCopyFile.parse(edited.serialize());
      expect(reparsed.frontMatterValue('tagline'), 'A pressable thing');
    });

    test('editing an unknown field is a no-op (source unchanged)', () {
      final file = ContentCopyFile.parse(_copy);
      expect(file.withFrontMatterValue('nope', 'x').serialize(), _copy);
    });
  });

  group('TWE-COPY-04: edit the body, survive generate', () {
    test('editing the override region preserves the managed region + markers',
        () {
      final file = ContentCopyFile.parse(_copy);
      final overrideIndex = file.body.regions
          .indexWhere((r) => r.kind == ContentRegionKind.editable);
      expect(overrideIndex, greaterThanOrEqualTo(0));

      final editedBody = file.body
          .withRegionBody(overrideIndex, '# Overview\n\nNew hand text.');
      final edited = file.withBody(editedBody);
      final out = edited.serialize();

      // The override edit landed…
      expect(out, contains('New hand text.'));
      expect(out, isNot(contains('Hand-written overview body.')));
      // …the managed region and both markers are byte-identical (untouched by
      // a future generateContent that only rewrites managed content).
      expect(out, contains('<!-- @tom:managed -->'));
      expect(out, contains('Generated: do not edit.'));
      expect(out, contains('<!-- @tom:override -->'));
      // The front-matter is also preserved.
      expect(out, contains('tagline: A clickable thing'));
    });
  });
}
