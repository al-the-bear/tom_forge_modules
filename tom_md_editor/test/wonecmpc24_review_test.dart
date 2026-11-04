/// Document reviews in tom_md_editor (wonecmpc24): guarded in-place line
/// edits, CriticMarkup marks decided through the TomSpecs Dart runtime,
/// review comments with ids and author — and a review round on a SOM
/// Markdown spec gives the same file as the VS Code extension's Markdown
/// Browser (`test/fixtures/review_round/expected.json`, written by the
/// extension's own code).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

String _applied(MdLineEditResult r) => switch (r) {
  MdLineEditApplied(:final text) => text,
  MdLineEditRefused(:final reason) => fail('refused: $reason'),
};

MdMarkDecision _decision(String d) => MdMarkDecision.values.byName(d);

void main() {
  group('RV guarded line edits', () {
    const file = 'one\ntwo\nthree';

    test('RV-1: lines that still hold what was shown are replaced', () {
      final r = mdApplyLineEdit(
        file,
        const MdLineEdit(startLine: 1, endLine: 2, expected: 'two', replacement: 'TWO\n2'),
      );
      expect(_applied(r), 'one\nTWO\n2\nthree');
    });

    test('RV-2: a changed file or a range outside it is refused', () {
      expect(
        mdApplyLineEdit(
          file,
          const MdLineEdit(startLine: 1, endLine: 2, expected: 'zwei', replacement: 'x'),
        ),
        isA<MdLineEditRefused>(),
      );
      expect(
        mdApplyLineEdit(
          file,
          const MdLineEdit(startLine: 2, endLine: 9, expected: 'three', replacement: 'x'),
        ),
        isA<MdLineEditRefused>(),
      );
    });

    test('RV-3: a CRLF file keeps its line endings', () {
      final r = mdApplyLineEdit(
        'a\r\nb\r\nc',
        const MdLineEdit(startLine: 1, endLine: 2, expected: 'b', replacement: 'B\nB2'),
      );
      expect(_applied(r), 'a\r\nB\r\nB2\r\nc');
    });
  });

  group('RV marks', () {
    test('RV-4: accept, reject and remove, decided by the runtime', () {
      const t = 'x {++add++} y {--del--} z {~~a~>b~~} {==hi==}{>>note<<}';
      expect(mdListMarks(t), hasLength(4));
      expect(
        _applied(mdDecideMark(t, markup: '{~~a~>b~~}', occurrence: 0, decision: MdMarkDecision.accept)),
        contains(' b '),
      );
      expect(
        _applied(mdDecideMark(t, markup: '{++add++}', occurrence: 0, decision: MdMarkDecision.reject)),
        isNot(contains('add')),
      );
      final removed = _applied(
        mdDecideMark(t, markup: '{==hi==}{>>note<<}', occurrence: 0, decision: MdMarkDecision.remove),
      );
      expect(removed, endsWith('hi'));
      expect(removed, isNot(contains('note')));
      expect(
        mdDecideMark(t, markup: '{++gone++}', occurrence: 0, decision: MdMarkDecision.accept),
        isA<MdLineEditRefused>(),
      );
    });

    test('RV-5: every change decided at once; highlights and comments stay', () {
      const t = 'x {++add++} y {--del--} {==hi==}{>>note<<}';
      final r = mdDecideAllChanges(t, MdMarkDecision.accept);
      expect(r.decided, 2);
      expect(r.text, contains('{==hi==}{>>note<<}'));
      expect(mdDecideAllChanges('plain', MdMarkDecision.accept).decided, 0);
    });
  });

  group('RV comments', () {
    test('RV-6: the next id is the runtime\'s, or a higher one the caller '
        'read from the SOM document', () {
      expect(mdNextCommentId('no comments'), 'C-1');
      const t = 'p\n\n> ⬆️ **C-4** (A): x\n\n> ⬆️ **C-2**: y';
      expect(mdNextCommentId(t), 'C-5');
      expect(mdNextCommentId(t, runtimeNext: 9), 'C-9');
    });

    test('RV-7: a comment is written with the arrow, an id and the author', () {
      expect(
        mdWriteComment('Start with the EU.', 'C-3', author: 'Alexis'),
        '> ⬆️ **C-3** (Alexis): Start with the EU.',
      );
      expect(
        mdWriteComment('⬆️ **C-1** (Bob): kept\n\nsecond', 'C-3', author: 'Alexis'),
        '> ⬆️ **C-1** (Bob): kept\n>\n> second',
      );
      expect(mdWriteComment('⬆️ **C-3** (Alexis):', 'C-3', author: 'Alexis'), '');
      expect(mdWriteComment('  \n ', 'C-3'), '');
    });

    test('RV-8: an emptied comment is removed with its blank lines', () {
      final lines = 'a\n\n> ⬆️ **C-1**: x\n\nb'.split('\n');
      final comment = mdCommentAt(lines, 2)!;
      final edit = mdEditCommentEdit(lines, comment, text: '', nextId: 'C-2')!;
      expect(_applied(mdApplyLineEdit(lines.join('\n'), edit)), 'a\n\nb');
    });

    test('RV-9: the author as written in a comment', () {
      expect(
        mdCommentAuthorName(MdCommentAuthorForm.first, fullName: 'Alexis (Al) Kyaw', login: 'ak'),
        'Alexis',
      );
      expect(
        mdCommentAuthorName(MdCommentAuthorForm.full, fullName: 'Alexis  Kyaw', login: 'ak'),
        'Alexis Kyaw',
      );
      expect(mdCommentAuthorName(MdCommentAuthorForm.first, fullName: '', login: 'ak'), 'ak');
      expect(
        mdOsUserFullName(
          platform: 'linux',
          login: 'ak',
          readPasswd: () => 'root:x:0:0:root:/root:/bin/sh\nak:x:1:1:Alexis Kyaw,,,:/home/ak:/bin/bash',
        ),
        'Alexis Kyaw',
      );
      expect(mdOsUserFullName(platform: 'macos', login: 'ak', runIdF: () => 'Alexis\n'), 'Alexis');
      expect(mdOsUserFullName(platform: 'windows', login: 'ak'), '');
    });
  });

  group('RV the review round', () {
    final dir = Directory('test/fixtures/review_round');
    final source = File('${dir.path}/source.md').readAsStringSync();
    final steps = (jsonDecode(File('${dir.path}/expected.json').readAsStringSync())
            as Map<String, dynamic>)['steps'] as List<dynamic>;

    test('RV-10: each step gives the file the extension gives, as one undo '
        'entry each', () {
      final c = MdEditorController(initialMarkdown: source);
      addTearDown(c.dispose);
      for (final raw in steps) {
        final s = raw as Map<String, dynamic>;
        switch (s['op']) {
          case 'addComment':
            expect(c.nextReviewCommentId(), s['nextId']);
            _applied(c.addReviewComment(
              blockStart: s['startLine'] as int,
              blockEnd: s['endLine'] as int,
              text: s['text'] as String,
              author: s['author'] as String,
            )!);
          case 'decideMark':
            _applied(c.decideReviewMark(
              startLine: s['startLine'] as int,
              endLine: s['endLine'] as int,
              expected: s['blockText'] as String,
              markup: s['markup'] as String,
              occurrence: s['occurrence'] as int,
              decision: _decision(s['decision'] as String),
            ));
          case 'lineEdit':
            _applied(c.applyLineEdit(MdLineEdit(
              startLine: s['startLine'] as int,
              endLine: s['endLine'] as int,
              expected: s['expectedLines'] as String,
              replacement: s['replacement'] as String,
            )));
          case 'editComment':
            _applied(c.editReviewComment(
              line: s['line'] as int,
              text: s['text'] as String,
              author: s['author'] as String,
            )!);
          case 'decideAll':
            expect(c.decideAllReviewChanges(_decision(s['decision'] as String)), s['decided']);
        }
        expect(c.markdown, s['expected'], reason: 'after ${s['op']}');
      }
      expect(c.isDirty.value, isTrue);
      for (var i = 0; i < steps.length; i++) {
        c.undo();
      }
      expect(c.markdown, source, reason: 'every step was one entry');
      expect(c.canUndo, isFalse);
    });

    test('RV-11: a review of text that changed since it was shown changes '
        'nothing', () {
      final c = MdEditorController(initialMarkdown: source);
      addTearDown(c.dispose);
      final r = c.decideReviewMark(
        startLine: 3,
        endLine: 4,
        expected: 'not what is there',
        markup: '{~~one~>a single~~}',
        occurrence: 0,
        decision: MdMarkDecision.accept,
      );
      expect(r, isA<MdLineEditRefused>());
      expect(c.markdown, source);
      expect(c.canUndo, isFalse);
    });
  });
}
