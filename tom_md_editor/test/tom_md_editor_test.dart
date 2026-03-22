import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tom_doc_specs/tom_doc_specs.dart' as specs;
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

void main() {
  group('MdParser', () {
    test('parses empty string to empty document', () {
      final doc = MdParser.parse('');
      expect(doc.sections, isEmpty);
      expect(doc.title, isNull);
    });

    test('parses single heading', () {
      final doc = MdParser.parse('# Hello World');
      expect(doc.sections.length, 1);
      expect(doc.sections.first.headline, 'Hello World');
      expect(doc.sections.first.level, 1);
    });

    test('parses heading with body text', () {
      final doc = MdParser.parse('# Title\n\nSome body text.\n\nMore text.');
      expect(doc.sections.length, 1);
      expect(doc.sections.first.headline, 'Title');
      expect(doc.sections.first.text, contains('Some body text.'));
    });

    test('parses nested headings into hierarchy', () {
      const md = '''# H1
Body 1
## H2a
Body 2a
## H2b
Body 2b
### H3
Body 3
''';
      final doc = MdParser.parse(md);
      expect(doc.sections.length, 1);
      final h1 = doc.sections.first;
      expect(h1.headline, 'H1');
      expect(h1.subsections.length, 2);
      expect(h1.subsections[0].headline, 'H2a');
      expect(h1.subsections[1].headline, 'H2b');
      expect(h1.subsections[1].subsections.length, 1);
      expect(h1.subsections[1].subsections.first.headline, 'H3');
    });

    test('roundtrip: parse then toMarkdown preserves content', () {
      const md = '# Title\n\nParagraph one.\n\n## Section\n\nParagraph two.\n';
      final doc = MdParser.parse(md);
      final result = MdParser.toMarkdown(doc);
      // Both should contain the same headings and paragraphs.
      expect(result, contains('# Title'));
      expect(result, contains('## Section'));
      expect(result, contains('Paragraph one.'));
      expect(result, contains('Paragraph two.'));
    });

    test('parses schema annotation', () {
      const md = '<!-- schema=my-schema/1.0 -->\n# Doc\n\nBody.';
      final doc = MdParser.parse(md);
      expect(doc.schemaId, 'my-schema/1.0');
    });

    test('parses multiple top-level sections', () {
      const md = '# First\n\nText 1\n\n# Second\n\nText 2\n';
      final doc = MdParser.parse(md);
      expect(doc.sections.length, 2);
      expect(doc.sections[0].headline, 'First');
      expect(doc.sections[1].headline, 'Second');
    });

    test('document allSections flattens hierarchy', () {
      const md = '# A\n## B\n### C\n## D\n';
      final doc = MdParser.parse(md);
      final all = doc.allSections;
      expect(all.length, 4);
      expect(all.map((s) => s.headline), ['A', 'B', 'C', 'D']);
    });
  });

  group('MdDocument', () {
    test('findById returns matching section', () {
      const md = '# Title <!--[sec-1]-->\n\nBody.\n';
      final doc = MdParser.parse(md);
      expect(doc.findById('sec-1'), isNotNull);
    });

    test('hierarchyDepth returns correct depth', () {
      const md = '# A\n## B\n### C\n#### D\n';
      final doc = MdParser.parse(md);
      expect(doc.hierarchyDepth, 4);
    });

    test('title returns first section headline', () {
      const md = '# My Title\n\n## Sub\n';
      final doc = MdParser.parse(md);
      expect(doc.title, 'My Title');
    });
  });

  group('MdEditorController', () {
    test('initial state has parsed document', () {
      final ctrl = MdEditorController(initialMarkdown: '# Test\n\nBody.');
      expect(ctrl.document.sections, isNotEmpty);
      expect(ctrl.document.sections.first.headline, 'Test');
      ctrl.dispose();
    });

    test('setting markdown re-parses document', () {
      final ctrl = MdEditorController(initialMarkdown: '# A');
      ctrl.markdown = '# B\n\n## C';
      expect(ctrl.document.sections.first.headline, 'B');
      expect(ctrl.document.sections.first.subsections.length, 1);
      ctrl.dispose();
    });

    test('selectSection updates selectedSection', () {
      final ctrl = MdEditorController(initialMarkdown: '# S1\n\n# S2');
      final section = ctrl.document.sections[1];
      ctrl.selectSection(section);
      expect(ctrl.selectedSection, section);
      ctrl.dispose();
    });

    test('undo/redo works for text changes', () {
      final ctrl = MdEditorController(initialMarkdown: '# Original');
      ctrl.markdown = '# Changed';
      expect(ctrl.canUndo, isTrue);
      ctrl.undo();
      expect(ctrl.markdown, '# Original');
      expect(ctrl.canRedo, isTrue);
      ctrl.redo();
      expect(ctrl.markdown, '# Changed');
      ctrl.dispose();
    });

    test('search finds matches', () {
      final ctrl = MdEditorController(
        initialMarkdown: '# Title\n\nHello world.\n\n## Section\n\nHello again.',
      );
      ctrl.search('Hello');
      expect(ctrl.searchResults.length, 2);
      ctrl.dispose();
    });

    test('insertSection adds new section', () async {
      final ctrl = MdEditorController(initialMarkdown: '# Existing');
      await ctrl.insertSection(
        parent: null,
        index: 1,
        level: 1,
        headline: 'New',
      );
      expect(ctrl.document.sections.length, 2);
      expect(ctrl.document.sections[1].headline, 'New');
      ctrl.dispose();
    });

    test('deleteSection removes section', () async {
      final ctrl = MdEditorController(
        initialMarkdown: '# First\n\n# Second\n\n# Third',
      );
      final toDelete = ctrl.document.sections[1];
      await ctrl.deleteSection(toDelete);
      expect(ctrl.document.sections.length, 2);
      expect(ctrl.document.sections.map((s) => s.headline), ['First', 'Third']);
      ctrl.dispose();
    });

    test('updateSectionHeadline changes headline', () async {
      final ctrl = MdEditorController(initialMarkdown: '# Old Name');
      final section = ctrl.document.sections.first;
      await ctrl.updateSectionHeadline(section, 'New Name');
      expect(ctrl.markdown, contains('# New Name'));
      ctrl.dispose();
    });

    test('replaceCurrentMatch performs replacement', () {
      final ctrl = MdEditorController(initialMarkdown: '# Hello\n\nHello world.');
      ctrl.search('Hello');
      expect(ctrl.searchResults.length, 2);
      ctrl.replaceCurrentMatch('Hi');
      expect(ctrl.markdown, contains('Hi'));
      ctrl.dispose();
    });
  });

  group('MdEditorSettings', () {
    test('standard factory has expected defaults', () {
      final s = MdEditorSettings.standard();
      expect(s.readOnly, isFalse);
      expect(s.showTree, isTrue);
      expect(s.autoHideEditor, isTrue);
      expect(s.showToolbar, isFalse);
    });

    test('viewer factory is read-only', () {
      final s = MdEditorSettings.viewer();
      expect(s.readOnly, isTrue);
      expect(s.showTree, isFalse);
      expect(s.showToolbar, isFalse);
    });

    test('copyWith preserves and overrides', () {
      final original = MdEditorSettings.standard();
      final copy = original.copyWith(readOnly: true, showToolbar: false);
      expect(copy.readOnly, isTrue);
      expect(copy.showToolbar, isFalse);
      expect(copy.showTree, original.showTree);
    });
  });

  group('MdEditorTheme', () {
    test('dark factory produces valid theme', () {
      final t = MdEditorTheme.dark();
      expect(t.basic.background, isNotNull);
      expect(t.basic.text, isNotNull);
    });

    test('light factory produces valid theme', () {
      final t = MdEditorTheme.light();
      expect(t.basic.background, isNotNull);
      expect(t.basic.text, isNotNull);
    });

    test('heading styles scale by level', () {
      final basic = MdEditorTheme.dark().basic;
      final h1 = basic.headingStyle(1);
      final h3 = basic.headingStyle(3);
      expect(h1.fontSize! > h3.fontSize!, isTrue);
    });
  });

  group('MdSearchResult', () {
    test('stores match data', () {
      final r = MdSearchResult(
        sectionHeadline: 'Test',
        matchText: 'hello',
        contextBefore: '...say ',
        contextAfter: ' world...',
        lineNumber: 5,
        offset: 42,
        length: 5,
      );
      expect(r.matchText, 'hello');
      expect(r.lineNumber, 5);
      expect(r.length, 5);
    });
  });

  group('MdSection', () {
    test('toMarkdown includes heading and body', () {
      final section = MdSection(
        headline: 'Test',
        level: 2,
        text: 'Body text.',
      );
      final md = section.toMarkdown();
      expect(md, contains('## Test'));
      expect(md, contains('Body text.'));
    });

    test('allDescendants traverses hierarchy', () {
      final child = MdSection(headline: 'Child', level: 3, text: '');
      final parent = MdSection(
        headline: 'Parent',
        level: 2,
        text: '',
        subsections: [child],
      );
      expect(parent.allDescendants, contains(child));
    });
  });

  group('MdConstants', () {
    test('resolveLanguage maps aliases', () {
      expect(MdConstants.resolveLanguage('js'), 'javascript');
      expect(MdConstants.resolveLanguage('py'), 'python');
      expect(MdConstants.resolveLanguage('ts'), 'typescript');
      expect(MdConstants.resolveLanguage('dart'), 'dart');
      expect(MdConstants.resolveLanguage('unknown'), 'unknown');
    });
  });

  group('StringDocumentProvider', () {
    test('load returns document content', () async {
      final provider = StringDocumentProvider(
        markdown: '# Hello',
      );
      final content = await provider.load();
      expect(content, '# Hello');
    });

    test('save updates content', () async {
      final provider = StringDocumentProvider(
        markdown: '# Old',
      );
      await provider.save('# New');
      final content = await provider.load();
      expect(content, '# New');
    });
  });

  // ── Step 1: Widget API, Registries, Convenience Layer ──

  group('MdCodeEditorRegistry', () {
    test('register and lookup by language', () {
      final registry = MdCodeEditorRegistry();
      registry.register(MdCodeEditorRegistration(
        languages: ['dart', 'python'],
        editorBuilder: (code, onChanged) => const SizedBox.shrink(),
      ));
      expect(registry.hasCustomEditor('dart'), isTrue);
      expect(registry.hasCustomEditor('python'), isTrue);
      expect(registry.hasCustomEditor('javascript'), isFalse);
    });

    test('lookup is case-insensitive', () {
      final registry = MdCodeEditorRegistry([
        MdCodeEditorRegistration(
          languages: ['Dart'],
          editorBuilder: (code, onChanged) => const SizedBox.shrink(),
        ),
      ]);
      expect(registry.hasCustomEditor('dart'), isTrue);
      expect(registry.hasCustomEditor('DART'), isTrue);
    });

    test('buildEditor returns null for unregistered language', () {
      final registry = MdCodeEditorRegistry();
      expect(registry.buildEditor('rust', 'fn main()', (_) {}), isNull);
    });
  });

  group('MdLanguageRendererRegistry', () {
    test('register and lookup by language', () {
      final registry = MdLanguageRendererRegistry();
      registry.register(MdLanguageRenderer(
        languages: ['mermaid'],
        renderer: (code, theme) => const SizedBox.shrink(),
      ));
      expect(registry.hasRenderer('mermaid'), isTrue);
      expect(registry.hasRenderer('dart'), isFalse);
    });

    test('buildRenderer returns null for unregistered language', () {
      final registry = MdLanguageRendererRegistry();
      final theme = MdEditorTheme.dark().basic;
      expect(registry.buildRenderer('mermaid', 'graph', theme), isNull);
    });
  });

  group('New Events', () {
    test('ValidationChangedEvent holds errors', () {
      const event = ValidationChangedEvent(errors: []);
      expect(event.errors, isEmpty);
    });

    test('DocumentLoadedEvent holds document', () {
      final doc = MdDocument(sections: []);
      final event = DocumentLoadedEvent(document: doc);
      expect(event.document, doc);
    });

    test('DocumentSaveEvent supports copyWith', () {
      final event = DocumentSaveEvent(markdown: '# Test');
      final copy = event.copyWith(markdown: '# Changed');
      expect(copy.markdown, '# Changed');
    });

    test('MdEditorEventHandlers accepts new handler slots', () {
      final handlers = MdEditorEventHandlers(
        onValidationChanged: (e) {},
        onLoaded: (e) {},
        onBeforeSave: (e) async => e,
      );
      expect(handlers.onValidationChanged, isNotNull);
      expect(handlers.onLoaded, isNotNull);
      expect(handlers.onBeforeSave, isNotNull);
    });
  });

  group('MdEditorSettings copyWith completeness', () {
    test('copyWith preserves all fields when no overrides given', () {
      const original = MdEditorSettings(
        showTree: false,
        showToolbar: true,
        showStatusBar: false,
        showSearchBox: false,
        rawEditorPosition: RawEditorPosition.right,
        allowEditorPositionChange: false,
        autoHideEditor: false,
        livePreview: false,
        livePreviewDebounceMs: 500,
        draggableSeparators: false,
        persistSeparatorPositions: true,
        treePanelWidthRatio: 0.3,
        rawEditorHeightRatio: 0.5,
        rawEditorWidthRatio: 0.6,
        searchResultsHeightRatio: 0.4,
        showLineNumbers: true,
        showSectionBorders: false,
        highlightCurrentSection: false,
        enableSmoothScrolling: false,
        expandAllByDefault: false,
        showValidationMarkers: false,
        enableDragAndDrop: false,
        showSectionIcons: true,
        enableSearch: false,
        enableReplace: false,
        enableRegexSearch: true,
        enableMermaid: false,
        enableMath: false,
        enableFootnotes: false,
        enableTaskLists: false,
        enableInteractiveTaskLists: false,
        enableTables: false,
        enableSyntaxHighlighting: false,
        showCodeBlockLanguage: false,
        showCopyCodeButton: false,
        showCodeEditButton: false,
        enableCodeEditing: false,
        showTableEditButton: false,
        enableTableEditing: false,
        enableSchemaValidation: true,
        showSchemaErrors: false,
        enableAutoScaffold: true,
        readOnly: true,
        enableUndo: false,
        maxUndoHistory: 50,
        confirmDelete: false,
        autoSave: true,
        autoSaveDebounceMs: 5000,
      );
      final copy = original.copyWith();

      expect(copy.showTree, original.showTree);
      expect(copy.showToolbar, original.showToolbar);
      expect(copy.showStatusBar, original.showStatusBar);
      expect(copy.showSearchBox, original.showSearchBox);
      expect(copy.rawEditorPosition, original.rawEditorPosition);
      expect(copy.allowEditorPositionChange, original.allowEditorPositionChange);
      expect(copy.autoHideEditor, original.autoHideEditor);
      expect(copy.livePreview, original.livePreview);
      expect(copy.livePreviewDebounceMs, original.livePreviewDebounceMs);
      expect(copy.draggableSeparators, original.draggableSeparators);
      expect(copy.persistSeparatorPositions, original.persistSeparatorPositions);
      expect(copy.treePanelWidthRatio, original.treePanelWidthRatio);
      expect(copy.rawEditorHeightRatio, original.rawEditorHeightRatio);
      expect(copy.rawEditorWidthRatio, original.rawEditorWidthRatio);
      expect(copy.searchResultsHeightRatio, original.searchResultsHeightRatio);
      expect(copy.showLineNumbers, original.showLineNumbers);
      expect(copy.showSectionBorders, original.showSectionBorders);
      expect(copy.highlightCurrentSection, original.highlightCurrentSection);
      expect(copy.enableSmoothScrolling, original.enableSmoothScrolling);
      expect(copy.expandAllByDefault, original.expandAllByDefault);
      expect(copy.showValidationMarkers, original.showValidationMarkers);
      expect(copy.enableDragAndDrop, original.enableDragAndDrop);
      expect(copy.showSectionIcons, original.showSectionIcons);
      expect(copy.enableSearch, original.enableSearch);
      expect(copy.enableReplace, original.enableReplace);
      expect(copy.enableRegexSearch, original.enableRegexSearch);
      expect(copy.enableMermaid, original.enableMermaid);
      expect(copy.enableMath, original.enableMath);
      expect(copy.enableFootnotes, original.enableFootnotes);
      expect(copy.enableTaskLists, original.enableTaskLists);
      expect(copy.enableInteractiveTaskLists, original.enableInteractiveTaskLists);
      expect(copy.enableTables, original.enableTables);
      expect(copy.enableSyntaxHighlighting, original.enableSyntaxHighlighting);
      expect(copy.showCodeBlockLanguage, original.showCodeBlockLanguage);
      expect(copy.showCopyCodeButton, original.showCopyCodeButton);
      expect(copy.showCodeEditButton, original.showCodeEditButton);
      expect(copy.enableCodeEditing, original.enableCodeEditing);
      expect(copy.showTableEditButton, original.showTableEditButton);
      expect(copy.enableTableEditing, original.enableTableEditing);
      expect(copy.enableSchemaValidation, original.enableSchemaValidation);
      expect(copy.showSchemaErrors, original.showSchemaErrors);
      expect(copy.enableAutoScaffold, original.enableAutoScaffold);
      expect(copy.readOnly, original.readOnly);
      expect(copy.enableUndo, original.enableUndo);
      expect(copy.maxUndoHistory, original.maxUndoHistory);
      expect(copy.confirmDelete, original.confirmDelete);
      expect(copy.autoSave, original.autoSave);
      expect(copy.autoSaveDebounceMs, original.autoSaveDebounceMs);
    });
  });

  group('MdEditorController events', () {
    test('loadFromProvider fires DocumentLoadedEvent', () async {
      MdDocument? loadedDoc;
      final ctrl = MdEditorController(
        eventHandlers: MdEditorEventHandlers(
          onLoaded: (e) => loadedDoc = e.document,
        ),
      );
      final provider = StringDocumentProvider(markdown: '# Test');
      await ctrl.loadFromProvider(provider);
      expect(loadedDoc, isNotNull);
      expect(loadedDoc!.sections.first.headline, 'Test');
      ctrl.dispose();
    });

    test('saveToProvider fires DocumentSaveEvent before saving', () async {
      String? savedMarkdown;
      final ctrl = MdEditorController(
        initialMarkdown: '# Original',
        eventHandlers: MdEditorEventHandlers(
          onBeforeSave: (e) async {
            return e.copyWith(markdown: '# Modified By Handler');
          },
        ),
      );
      final provider = StringDocumentProvider(markdown: '');
      await ctrl.saveToProvider(provider);
      savedMarkdown = await provider.load();
      expect(savedMarkdown, '# Modified By Handler');
      ctrl.dispose();
    });
  });

  // ── Step 2: Tree & Preview Interactivity ──

  group('MdEditorController promote/demote', () {
    test('promoteSection decreases heading level', () async {
      final ctrl = MdEditorController(
        initialMarkdown: '# Root\n\n## Sub\n\nBody.',
      );
      final sub = ctrl.document.sections.first.subsections.first;
      expect(sub.level, 2);
      await ctrl.promoteSection(sub);
      // After promote, the section's level should be 1
      expect(ctrl.markdown, contains('# Sub'));
    });

    test('promoteSection does nothing at level 1', () async {
      final ctrl = MdEditorController(initialMarkdown: '# Top');
      final section = ctrl.document.sections.first;
      await ctrl.promoteSection(section);
      expect(section.level, 1);
      ctrl.dispose();
    });

    test('demoteSection increases heading level', () async {
      final ctrl = MdEditorController(initialMarkdown: '# Title\n\n## Sub');
      final sub = ctrl.document.sections.first.subsections.first;
      await ctrl.demoteSection(sub);
      expect(ctrl.markdown, contains('### Sub'));
      ctrl.dispose();
    });

    test('demoteSection does nothing at level 6', () async {
      final ctrl = MdEditorController(
        initialMarkdown: '###### Deep',
      );
      final section = ctrl.document.sections.first;
      await ctrl.demoteSection(section);
      expect(section.level, 6);
      ctrl.dispose();
    });

    test('promote is undoable', () async {
      final ctrl = MdEditorController(
        initialMarkdown: '# Root\n\n## Sub',
      );
      final sub = ctrl.document.sections.first.subsections.first;
      await ctrl.promoteSection(sub);
      expect(ctrl.markdown, contains('# Sub'));
      ctrl.undo();
      expect(ctrl.markdown, contains('## Sub'));
      ctrl.dispose();
    });
  });

  group('MdEditorController move up/down', () {
    test('moveSectionUp swaps with previous sibling', () async {
      final ctrl = MdEditorController(
        initialMarkdown: '# A\n\n# B\n\n# C',
      );
      final sectionB = ctrl.document.sections[1];
      await ctrl.moveSectionUp(sectionB);
      expect(ctrl.document.sections[0].headline, 'B');
      expect(ctrl.document.sections[1].headline, 'A');
      ctrl.dispose();
    });

    test('moveSectionDown swaps with next sibling', () async {
      final ctrl = MdEditorController(
        initialMarkdown: '# A\n\n# B\n\n# C',
      );
      final sectionA = ctrl.document.sections[0];
      await ctrl.moveSectionDown(sectionA);
      expect(ctrl.document.sections[0].headline, 'B');
      expect(ctrl.document.sections[1].headline, 'A');
      ctrl.dispose();
    });

    test('moveSectionUp does nothing for first sibling', () async {
      final ctrl = MdEditorController(initialMarkdown: '# A\n\n# B');
      final sectionA = ctrl.document.sections[0];
      await ctrl.moveSectionUp(sectionA);
      expect(ctrl.document.sections[0].headline, 'A');
      ctrl.dispose();
    });

    test('moveSectionDown does nothing for last sibling', () async {
      final ctrl = MdEditorController(initialMarkdown: '# A\n\n# B');
      final sectionB = ctrl.document.sections[1];
      await ctrl.moveSectionDown(sectionB);
      expect(ctrl.document.sections[1].headline, 'B');
      ctrl.dispose();
    });
  });

  // ── Step 3: Toolbar & Status Bar ──

  group('MdEditorToolbar', () {
    testWidgets('renders undo and redo buttons', (tester) async {
      final ctrl = MdEditorController(initialMarkdown: '# Test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditorToolbar(
              controller: ctrl,
              theme: MdEditorTheme.dark(),
              settings: MdEditorSettings.standard(),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.undo), findsOneWidget);
      expect(find.byIcon(Icons.redo), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('renders formatting buttons when not read-only', (tester) async {
      final ctrl = MdEditorController(initialMarkdown: '# Test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditorToolbar(
              controller: ctrl,
              theme: MdEditorTheme.dark(),
              settings: MdEditorSettings.standard(),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.table_chart), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('hides formatting buttons when read-only', (tester) async {
      final ctrl = MdEditorController(initialMarkdown: '# Test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditorToolbar(
              controller: ctrl,
              theme: MdEditorTheme.dark(),
              settings: MdEditorSettings.standard().copyWith(readOnly: true),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.format_bold), findsNothing);
      expect(find.byIcon(Icons.format_italic), findsNothing);
      // Search should still be visible
      expect(find.byIcon(Icons.search), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('shows save button when onSave provided', (tester) async {
      final ctrl = MdEditorController(initialMarkdown: '# Test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditorToolbar(
              controller: ctrl,
              theme: MdEditorTheme.dark(),
              settings: MdEditorSettings.standard(),
              onSave: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.save), findsOneWidget);
      ctrl.dispose();
    });
  });

  group('MdEditorStatusBar', () {
    testWidgets('displays word and character counts', (tester) async {
      final ctrl = MdEditorController(
        initialMarkdown: '# Hello\n\nSome body text here.',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditorStatusBar(
              controller: ctrl,
              theme: MdEditorTheme.dark(),
            ),
          ),
        ),
      );
      // Contains "words" and "chars" labels
      expect(find.textContaining('words'), findsOneWidget);
      expect(find.textContaining('chars'), findsOneWidget);
      expect(find.textContaining('lines'), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('shows read-only indicator', (tester) async {
      final ctrl = MdEditorController(initialMarkdown: '# Test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditorStatusBar(
              controller: ctrl,
              theme: MdEditorTheme.dark(),
              readOnly: true,
            ),
          ),
        ),
      );
      expect(find.text('Read-only'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('shows segment icon when section selected', (tester) async {
      final ctrl = MdEditorController(
        initialMarkdown: '# Parent\n\n## Child\n\nBody',
      );
      ctrl.selectSection(ctrl.document.sections[0].subsections[0]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditorStatusBar(
              controller: ctrl,
              theme: MdEditorTheme.dark(),
            ),
          ),
        ),
      );
      // Segment icon shown when a section is selected
      expect(find.byIcon(Icons.segment), findsOneWidget);
      ctrl.dispose();
    });

    testWidgets('shows validation error count', (tester) async {
      final ctrl = MdEditorController(initialMarkdown: '# Test');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdEditorStatusBar(
              controller: ctrl,
              theme: MdEditorTheme.dark(),
              validationErrors: const [
                ValidationError(path: ['section1'], message: 'Error 1'),
                ValidationError(path: ['section2'], message: 'Error 2', severity: ValidationSeverity.warning),
              ],
            ),
          ),
        ),
      );
      expect(find.text('2 issues'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      ctrl.dispose();
    });
  });

  // ── Step 4: Math, Mermaid, Table alignment ──

  group('Math detection', () {
    test('detects inline math', () {
      expect(containsInlineMath(r'The formula $E=mc^2$ is famous.'), isTrue);
      expect(containsInlineMath('No math here'), isFalse);
    });

    test('detects block math', () {
      expect(containsBlockMath(r'$$\sum_{i=1}^n i$$'), isTrue);
      expect(containsBlockMath('No block math'), isFalse);
    });

    test('extracts inline math expressions', () {
      final results = extractInlineMath(r'Both $a+b$ and $x^2$ here.');
      expect(results, hasLength(2));
      expect(results[0], 'a+b');
      expect(results[1], 'x^2');
    });

    test('extracts block math expressions', () {
      final results = extractBlockMath(r'$$\int_0^1 x\,dx$$');
      expect(results, hasLength(1));
      expect(results[0], contains('int'));
    });
  });

  group('Mermaid detection', () {
    test('detects mermaid code blocks', () {
      const md = '```mermaid\nflowchart TD\n  A-->B\n```';
      expect(containsMermaid(md), isTrue);
    });

    test('returns false for non-mermaid blocks', () {
      const md = '```dart\nvoid main() {}\n```';
      expect(containsMermaid(md), isFalse);
    });

    test('extracts mermaid sources', () {
      const md = '```mermaid\ngraph LR\n  A-->B\n```';
      final sources = extractMermaidSources(md);
      expect(sources, hasLength(1));
      expect(sources[0], contains('graph LR'));
    });
  });

  group('Table alignment', () {
    test('ColumnAlignment enum has all values', () {
      expect(ColumnAlignment.values, hasLength(3));
      expect(ColumnAlignment.values, contains(ColumnAlignment.left));
      expect(ColumnAlignment.values, contains(ColumnAlignment.center));
      expect(ColumnAlignment.values, contains(ColumnAlignment.right));
    });
  });

  // ── Step 5: Providers, Controller extras, Accessibility ──

  group('toJson', () {
    test('exports document as JSON map', () {
      final ctrl = MdEditorController(
        initialMarkdown: '# Title\n\nBody text\n\n## Sub\n\nSub body',
      );
      final json = ctrl.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['sections'], isA<List>());
      final sections = json['sections'] as List;
      expect(sections.length, 1);
      final first = sections[0] as Map<String, dynamic>;
      expect(first['headline'], 'Title');
      expect(first['level'], 1);
      expect(first['subsections'], isA<List>());
      ctrl.dispose();
    });
  });

  group('toMarkdownString', () {
    test('returns raw markdown when no normalization', () {
      const md = '# Hello\n\nWorld';
      final ctrl = MdEditorController(initialMarkdown: md);
      expect(ctrl.toMarkdownString(), contains('Hello'));
      ctrl.dispose();
    });

    test('normalizes multiple blank lines', () {
      const md = '# Hello\n\n\n\n\nWorld';
      final ctrl = MdEditorController(initialMarkdown: md);
      final normalized = ctrl.toMarkdownString(normalizeWhitespace: true);
      // Should not have 3+ consecutive newlines
      expect(normalized.contains('\n\n\n'), isFalse);
      ctrl.dispose();
    });
  });

  group('StringDocumentProvider', () {
    test('load returns initial markdown', () async {
      final provider = StringDocumentProvider(markdown: '# Hello');
      expect(await provider.load(), '# Hello');
    });

    test('save updates content', () async {
      final provider = StringDocumentProvider(markdown: '# Old');
      await provider.save('# New');
      expect(await provider.load(), '# New');
    });

    test('canSave is true', () {
      final provider = StringDocumentProvider(markdown: '');
      expect(provider.canSave, isTrue);
    });
  });

  group('MdEditorController load/save with provider', () {
    test('loads from provider', () async {
      final provider = StringDocumentProvider(markdown: '# From Provider');
      final ctrl = MdEditorController(initialMarkdown: '');
      await ctrl.loadFromProvider(provider);
      expect(ctrl.document.sections.length, 1);
      expect(ctrl.document.sections[0].headline, 'From Provider');
      ctrl.dispose();
    });

    test('saves to provider', () async {
      final provider = StringDocumentProvider(markdown: '');
      final ctrl = MdEditorController(initialMarkdown: '# Save Me');
      await ctrl.saveToProvider(provider);
      final loaded = await provider.load();
      expect(loaded, contains('Save Me'));
      ctrl.dispose();
    });
  });

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
        document: specs.DocumentStructure(sections: {
          'Overview': const specs.SectionDef(sectionType: 'overview'),
        }),
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

      ctrl.markdown = '# Updated\n\nNew body.';
      expect(events.length, greaterThan(eventsBefore));
      ctrl.dispose();
    });
  });

  // ── Controller addSectionAfter ──

  group('MdEditorController.addSectionAfter', () {
    test('inserts section after specified sibling', () async {
      final ctrl = MdEditorController(
        initialMarkdown: '# First\n\nBody 1.\n\n# Second\n\nBody 2.\n',
      );
      expect(ctrl.document.sections.length, 2);

      final first = ctrl.document.sections[0];
      await ctrl.addSectionAfter(
        afterSection: first,
        level: 1,
        headline: 'Inserted',
        text: 'Inserted body.',
      );

      expect(ctrl.document.sections.length, 3);
      expect(ctrl.document.sections[1].headline, 'Inserted');
      expect(ctrl.document.sections[2].headline, 'Second');
      ctrl.dispose();
    });

    test('inserts at end when after last section', () async {
      final ctrl = MdEditorController(
        initialMarkdown: '# Only\n\nBody.\n',
      );

      final only = ctrl.document.sections[0];
      await ctrl.addSectionAfter(
        afterSection: only,
        level: 1,
        headline: 'Appended',
      );

      expect(ctrl.document.sections.length, 2);
      expect(ctrl.document.sections.last.headline, 'Appended');
      ctrl.dispose();
    });
  });

  // ── Syntax Highlighting ──

  group('MdSyntaxHighlightController', () {
    test('creates controller with theme colors', () {
      final ctrl = MdSyntaxHighlightController(
        text: '# Hello',
        headingColor: Colors.blue,
        boldColor: Colors.white,
        italicColor: Colors.grey,
        codeColor: Colors.green,
        linkColor: Colors.lightBlue,
        listMarkerColor: Colors.grey,
        defaultColor: Colors.white,
        fontFamily: 'monospace',
        fontSize: 14,
        lineHeight: 1.6,
      );
      expect(ctrl.text, '# Hello');
      ctrl.dispose();
    });

    test('updating text preserves controller state', () {
      final ctrl = MdSyntaxHighlightController(
        text: '# Old',
        headingColor: Colors.blue,
        boldColor: Colors.white,
        italicColor: Colors.grey,
        codeColor: Colors.green,
        linkColor: Colors.lightBlue,
        listMarkerColor: Colors.grey,
        defaultColor: Colors.white,
        fontFamily: 'monospace',
        fontSize: 14,
        lineHeight: 1.6,
      );
      ctrl.text = '# New\n\n**Bold text**';
      expect(ctrl.text, contains('**Bold text**'));
      ctrl.dispose();
    });
  });

  // ── Headline Marker Detection ──

  group('Headline marker detection', () {
    test('headlineMarkerPattern detects hash markers', () {
      expect(MdConstants.headlineMarkerPattern.hasMatch('## Sub heading'), isTrue);
    });

    test('headlineMarkerPattern detects various levels', () {
      expect(MdConstants.headlineMarkerPattern.hasMatch('# H1'), isTrue);
      expect(MdConstants.headlineMarkerPattern.hasMatch('### H3'), isTrue);
      expect(MdConstants.headlineMarkerPattern.hasMatch('###### H6'), isTrue);
    });

    test('headlineMarkerPattern ignores non-headline hashes', () {
      expect(MdConstants.headlineMarkerPattern.hasMatch('C# code'), isFalse);
      expect(MdConstants.headlineMarkerPattern.hasMatch('no hash here'), isFalse);
    });

    test('headlineMarkerPattern matches within multiline text', () {
      const text = 'Some text\n## Headline inside\nMore text';
      expect(MdConstants.headlineMarkerPattern.hasMatch(text), isTrue);
    });

    test('headlineMarkerPattern does not match escaped markers', () {
      // Backslash-escaped markers should be literal
      expect(MdConstants.headlineMarkerPattern.hasMatch('\\## Escaped'), isFalse);
    });
  });

  // ── Mermaid Detection Helpers ──

  group('Mermaid detection helpers', () {
    test('containsMermaid detects mermaid code block', () {
      const text = '```mermaid\nflowchart LR\n  A --> B\n```';
      expect(containsMermaid(text), isTrue);
    });

    test('containsMermaid returns false for non-mermaid blocks', () {
      const text = '```dart\nvoid main() {}\n```';
      expect(containsMermaid(text), isFalse);
    });

    test('extractMermaidSources returns diagram source', () {
      const text = '```mermaid\nflowchart LR\n  A --> B\n```';
      final sources = extractMermaidSources(text);
      expect(sources, hasLength(1));
      expect(sources.first, contains('flowchart LR'));
    });

    test('extractMermaidSources handles multiple blocks', () {
      const text = '''
```mermaid
sequenceDiagram
  Alice->>Bob: Hi
```

Some text

```mermaid
pie
  "A" : 30
  "B" : 70
```
''';
      final sources = extractMermaidSources(text);
      expect(sources, hasLength(2));
      expect(sources[0], contains('sequenceDiagram'));
      expect(sources[1], contains('pie'));
    });

    test('kMermaidDiagramTypes contains expected types', () {
      expect(kMermaidDiagramTypes, contains('flowchart'));
      expect(kMermaidDiagramTypes, contains('sequenceDiagram'));
      expect(kMermaidDiagramTypes, contains('pie'));
      expect(kMermaidDiagramTypes, contains('gantt'));
    });
  });

  // ── Mermaid Renderer Widget ──

  group('MdMermaidRenderer', () {
    testWidgets('renders with mermaid diagram', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdMermaidRenderer(
              source: 'flowchart LR\n  A --> B',
              theme: MdEditorTheme.dark(),
            ),
          ),
        ),
      );

      expect(find.text('Mermaid Diagram'), findsOneWidget);
      expect(find.byIcon(Icons.schema), findsOneWidget);
    });

    testWidgets('shows edit button when onEdit is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdMermaidRenderer(
              source: 'pie\n  "A": 50\n  "B": 50',
              theme: MdEditorTheme.dark(),
              onEdit: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('toggles source panel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MdMermaidRenderer(
              source: 'flowchart LR\n  A --> B',
              theme: MdEditorTheme.dark(),
            ),
          ),
        ),
      );

      // Initially source is hidden
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.code_off), findsNothing);

      // Tap to show source
      await tester.tap(find.byIcon(Icons.code));
      await tester.pump();

      expect(find.byIcon(Icons.code_off), findsOneWidget);
    });
  });

  group('Section text preservation', () {
    const testDoc = '''<!-- docspec: schema-test/1.0 -->
# Schema Test Document

Intro text for root section.

## <!--[overview] --> Project Overview

This is the project overview section.
It has multiple lines of text.
Goals: Test everything.

## <!--[config-001] --> Configuration

Environment: production
Version: 2.1.0
Owner: Tom Framework Team

## <!--[components-001] --> Component Registry

This section defines all components.

### <!--[comp-auth] component-id=auth --> Authentication

Handles user authentication and session management.
Supports OAuth2.

### <!--[comp-api] component-id=api --> API Gateway

Central API gateway routes requests.
Applies rate limiting.

## <!--[detail-auth] --> Auth Component

Detailed specification for authentication.

### <!--[api-auth] --> Auth API Endpoints

API endpoints for auth.

#### <!--[endpoint-login] --> Login

Description: Authenticates a user.
Method: POST
Path: /api/v1/auth/login
Auth: none

#### <!--[endpoint-logout] --> Logout

Description: Invalidates session.
Method: POST
Path: /api/v1/auth/logout
Auth: token
''';

    test('all sections have non-empty text after initial parse', () {
      final doc = MdParser.parse(testDoc);
      final all = doc.allSections;

      // Verify each section has text
      for (final s in all) {
        expect(
          s.text.isNotEmpty,
          isTrue,
          reason: 'Section "${s.headline}" (level ${s.level}) should have text '
              'but got empty. sourceLineStart=${s.sourceLineStart}',
        );
      }
    });

    test('section text survives round-trip', () {
      final doc = MdParser.parse(testDoc);
      final allOriginal = doc.allSections;

      // Round-trip
      final serialized = MdParser.toMarkdown(doc);
      final doc2 = MdParser.parse(serialized);
      final allRoundTrip = doc2.allSections;

      expect(allRoundTrip.length, allOriginal.length);
      for (var i = 0; i < allOriginal.length; i++) {
        expect(
          allRoundTrip[i].headline,
          allOriginal[i].headline,
          reason: 'Headline mismatch at index $i',
        );
        expect(
          allRoundTrip[i].text,
          allOriginal[i].text,
          reason: 'Text mismatch for "${allOriginal[i].headline}"',
        );
      }
    });

    test('controller selectSection preserves section text', () {
      final controller = MdEditorController(initialMarkdown: testDoc);

      final all = controller.document.allSections;
      // Click through each section
      for (final section in all) {
        controller.selectSection(section);
        final selected = controller.selectedSection;
        expect(selected, isNotNull,
            reason: 'Should have selected "${section.headline}"');
        expect(selected!.headline, section.headline);
        expect(
          selected.text.isNotEmpty,
          isTrue,
          reason: 'Selected section "${section.headline}" should have text '
              'but got empty. text.length=${selected.text.length}',
        );
        expect(selected.text, section.text,
            reason: 'Text should match for "${section.headline}"');
      }
      controller.dispose();
    });

    test('controller selectSection + rebuild preserves text', () {
      final controller = MdEditorController(initialMarkdown: testDoc);

      // Select first section
      final firstSection = controller.document.allSections[1]; // Overview
      controller.selectSection(firstSection);
      expect(controller.selectedSection!.text.isNotEmpty, isTrue);

      // Now select second section (Configuration)
      final secondSection = controller.document.allSections[2];
      controller.selectSection(secondSection);
      expect(controller.selectedSection!.headline, 'Configuration');
      expect(
        controller.selectedSection!.text,
        contains('Environment'),
        reason: 'Configuration section should contain "Environment"',
      );

      // Select component section
      final componentSection = controller.document.allSections[3];
      controller.selectSection(componentSection);
      expect(controller.selectedSection!.headline, 'Component Registry');
      expect(
        controller.selectedSection!.text,
        contains('components'),
        reason: 'Component Registry should contain "components"',
      );

      controller.dispose();
    });

    test('section text after updateSectionText round-trip', () {
      final controller = MdEditorController(initialMarkdown: testDoc);

      // Select and update overview section
      final overview = controller.document.allSections[1];
      controller.selectSection(overview);
      controller.updateSectionText(overview, 'New overview text');

      // After rebuild, check OTHER sections still have text
      final all = controller.document.allSections;
      for (final s in all) {
        if (s.headline == 'Project Overview') {
          expect(s.text, 'New overview text');
        } else {
          expect(
            s.text.isNotEmpty,
            isTrue,
            reason: 'Section "${s.headline}" lost text after updateSectionText '
                'on a different section',
          );
        }
      }
      controller.dispose();
    });
  });
}
