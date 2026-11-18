/// Browsing in tom_md_editor (wonecmpc24): links resolved into the
/// workspace, back/forward history with the reading position, a navigator
/// over a controller, following the end of a growing file (live trail), and
/// mermaid fences rendered as diagrams in the preview.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tom_mermaid_view/tom_mermaid_view.dart' show MermaidWebView;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

const _root = '/ws';
final _files = {
  '/ws/docs/a.md',
  '/ws/docs/b.md',
  '/ws/lib/x.dart',
  '/ws/README.md',
  '/ws/_ai/quests/web/overview.web.md',
};

MdLinkResolver _resolver() =>
    MdLinkResolver(exists: _files.contains, pathContext: p.posix);

const _from = MdLinkContext(currentFilePath: '/ws/docs/a.md', workspaceRoot: _root);

void main() {
  group('BR links', () {
    test('BR-1: anchors, documents, files, URLs and typed references', () {
      final r = _resolver();
      expect(r.resolve('#intro', _from).action, MdLinkAction.scrollToAnchor);
      final b = r.resolve('b.md#part-2', _from);
      expect((b.action, b.filePath, b.anchor), (MdLinkAction.navigateMdAnchor, '/ws/docs/b.md', 'part-2'));
      expect(r.resolve('../README.md', _from).filePath, '/ws/README.md');
      // Not beside the document: the workspace root is tried.
      final x = r.resolve('lib/x.dart#L20', _from);
      expect((x.action, x.filePath, x.lineNumber), (MdLinkAction.openInEditorLine, '/ws/lib/x.dart', 20));
      expect(r.resolve('lib/x.dart', _from).action, MdLinkAction.openInEditor);
      expect(r.resolve('https://example.org', _from).action, MdLinkAction.openExternal);
      expect(r.resolve('missing.md', _from).action, MdLinkAction.error);
      final q = r.resolve('quest:web', _from);
      expect((q.action, q.filePath), (MdLinkAction.navigateMd, '/ws/_ai/quests/web/overview.web.md'));
      final t = r.resolve('todo:web/abc', _from);
      expect((t.type, t.action, t.identifier), (MdLinkType.todo, MdLinkAction.runCommand, 'web/abc'));
      expect(mdAnchorId('Hello World!'), 'hello-world');
    });

    test('BR-2: a host adds its own reference type', () {
      final r = MdLinkResolver(
        exists: _files.contains,
        pathContext: p.posix,
        handlers: [
          MdLinkHandler('spec:', (id, _) => MdResolvedLink(type: MdLinkType.unknown, action: MdLinkAction.runCommand, identifier: 'spec/$id')),
        ],
      );
      expect(r.resolve('spec:SBP', _from).identifier, 'spec/SBP');
    });
  });

  group('BR history', () {
    test('BR-3: back and forward keep the reading position; a new document '
        'drops the forward entries', () {
      final h = MdNavigationHistory(maxEntries: 3);
      h.push(MdHistoryEntry(filePath: 'a'));
      h.recordPosition('a', const MdReadingPosition(line: 12));
      h.push(MdHistoryEntry(filePath: 'b'));
      h.recordPosition('a', const MdReadingPosition(line: 99)); // stale report
      expect(h.goBack()!.position!.line, 12);
      expect(h.canGoForward, isTrue);
      h.push(MdHistoryEntry(filePath: 'c'));
      expect(h.canGoForward, isFalse);
      h
        ..push(MdHistoryEntry(filePath: 'd'))
        ..push(MdHistoryEntry(filePath: 'e'));
      expect(h.goBack()!.filePath, 'd');
      expect(h.goBack()!.filePath, 'c');
      expect(h.canGoBack, isFalse, reason: 'three entries kept');
    });

    test('BR-4: the navigator opens, follows links and goes back to where '
        'the reader was', () async {
      final c = MdEditorController();
      addTearDown(c.dispose);
      final n = MdBrowserNavigator(
        controller: c,
        resolver: _resolver(),
        workspaceRoot: _root,
        read: (path) async => '# $path\n',
      );
      await n.open('/ws/docs/a.md');
      expect(c.markdown, '# /ws/docs/a.md\n');
      n.recordPosition(const MdReadingPosition(line: 7));
      final link = await n.follow('b.md#part-2');
      expect(link.action, MdLinkAction.navigateMdAnchor);
      expect(n.currentPath, '/ws/docs/b.md');
      expect(n.takeAnchor(), 'part-2');
      expect(n.takeAnchor(), isNull);
      expect((await n.follow('lib/x.dart')).action, MdLinkAction.openInEditor);
      expect(n.currentPath, '/ws/docs/b.md', reason: 'the host opens files');
      expect(await n.back(), isTrue);
      expect(c.markdown, '# /ws/docs/a.md\n');
      expect(n.takePosition()!.line, 7);
      expect(c.canUndo, isFalse, reason: 'a shown document is no edit');
      expect(await n.forward(), isTrue);
      expect(n.currentPath, '/ws/docs/b.md');
    });
  });

  group('BR follow-tail', () {
    test('BR-5: following stops away from the end and resumes', () {
      final f = MdFollowTail(threshold: 10);
      expect(f.following, isTrue);
      f.scrolled(pixels: 100, maxExtent: 500);
      expect(f.following, isFalse);
      f.scrolled(pixels: 495, maxExtent: 500);
      expect(f.following, isTrue);
      f.scrolled(pixels: 0, maxExtent: 500);
      f.resume();
      expect(f.following, isTrue);
    });

    test('BR-6: a growing file is shown as it grows, read through the '
        'file system', () async {
      final fs = TomMemoryFileSystem(
        root: Uri.directory('/ws'),
        seed: {'/ws/live-trail.md': '# Trail\n'},
      );
      final file = fs.uriOf('live-trail.md');
      final c = MdEditorController();
      addTearDown(c.dispose);
      final follower = MdFileFollower(
        controller: c,
        fileSystem: fs,
        uri: file,
        interval: const Duration(milliseconds: 20),
      );
      addTearDown(follower.stop);
      await follower.start();
      expect(c.markdown, '# Trail\n');
      await fs.writeText(file, '# Trail\n\nentry 1\n');
      for (var i = 0; i < 100 && !c.markdown.contains('entry 1'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(c.markdown, '# Trail\n\nentry 1\n');
      expect(c.isDirty.value, isFalse);
      await fs.delete(file);
      await follower.check();
      expect(c.markdown, contains('entry 1'), reason: 'the last content stays');
    });

    testWidgets('BR-7: the preview follows new content at the end; scrolling '
        'up shows Follow, which resumes', (tester) async {
      final c = MdEditorController(
        initialMarkdown: List.generate(80, (i) => 'line $i\n').join('\n'),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: MdPreviewPanel(
                controller: c,
                theme: MdEditorTheme.light(),
                settings: const MdEditorSettings(followTail: true, readOnly: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      ScrollPosition position() =>
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(position().maxScrollExtent, greaterThan(0));
      expect(position().pixels, position().maxScrollExtent, reason: 'opens at the end');

      c.replaceContent('${c.markdown}\nnew line\n');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(position().pixels, position().maxScrollExtent);
      expect(find.byKey(const ValueKey('md-follow-tail')), findsNothing);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('md-follow-tail')), findsOneWidget);
      final before = position().pixels;
      c.replaceContent('${c.markdown}\nanother\n');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(position().pixels, before, reason: 'not following now');

      await tester.tap(find.byKey(const ValueKey('md-follow-tail')));
      await tester.pumpAndSettle();
      expect(position().pixels, position().maxScrollExtent);
      expect(find.byKey(const ValueKey('md-follow-tail')), findsNothing);
    });
  });

  testWidgets('BR-8: a mermaid fence is drawn as a diagram', (tester) async {
    final c = MdEditorController(
      initialMarkdown: '# D\n\n```mermaid\nflowchart TD\n  A-->B\n```\n',
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MdPreviewPanel(
            controller: c,
            theme: MdEditorTheme.light(),
            settings: const MdEditorSettings(readOnly: true),
          ),
        ),
      ),
    );
    await tester.pump();
    final view = tester.widget<MermaidWebView>(find.byType(MermaidWebView));
    expect(view.source.trim(), 'flowchart TD\n  A-->B');
  });
}
