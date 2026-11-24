/// The pdf.js editor as the application's find target and its kept view
/// state.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_pdf_pdfjs/tom_pdf_pdfjs.dart';

import 'support/workspace.dart';

/// Records the application's Find action instead of a find bar.
List<String> _recordFind(Workspace w) {
  final log = <String>[];
  w.api.actionRegistry.registerAction(
    ForgeAction(
      id: 'editor.find',
      label: 'Find',
      execute: (_) async {
        log.add('editor.find');
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    ),
  );
  return log;
}

void main() {
  group('the application\'s find', () {
    testWidgets('FPDFJS-FIND-1: the pdf.js editor is a find target; the '
        'page\'s Cmd+F opens the application\'s find bar', (tester) async {
      final w = Workspace();
      final log = _recordFind(w);
      final a = w.add('/docs/a.pdf');
      final js = w.openJs(a);
      await w.show(tester, js);
      final page = w.pages.single;
      page.send({'type': 'shortcut', 'key': 'find'});
      await tester.pumpAndSettle();
      expect(log, ['editor.find']);
      expect(find.byKey(const ValueKey('pdfjs-find-field')), findsNothing);

      js.find('reasoning', wholeWord: true);
      await tester.pumpAndSettle();
      final (fn, args) = page.calls.last;
      expect(fn, 'find');
      expect(args.first, 'reasoning');
      expect((args[1]! as Map)['entireWord'], isTrue);
      page.send({'type': 'findCount', 'current': 1, 'total': 4});
      await tester.pumpAndSettle();
      expect(js.findStatus.value, const ForgeFindStatus(current: 1, total: 4));
      js.findNext();
      await tester.pumpAndSettle();
      expect((page.calls.last.$2[1]! as Map)['again'], isTrue);
      js.findPrevious();
      await tester.pumpAndSettle();
      expect((page.calls.last.$2[1]! as Map)['previous'], isTrue);
      js.clearFind();
      await tester.pumpAndSettle();
      expect(page.calls.last.$2.first, '');
      expect(js.findStatus.value, ForgeFindStatus.none);
    });
  });

  group('kept view state', () {
    testWidgets('FPDFJS-STATE-1: the pdf.js editor keeps page and scale; a '
        'restored state is applied when the page has loaded and survives a '
        'mode switch', (tester) async {
      final w = Workspace();
      final a = w.add('/docs/a.pdf');
      final js = w.openJs(a);
      js.restoreState({'page': 3, 'scale': '1.25'});
      await w.show(tester, js);
      final page = w.pages.single;
      final names = page.callNames;
      expect(names.sublist(names.indexOf('open')), [
        'open',
        'zoom',
        'scrollTo',
      ]);
      expect(page.calls.last.$2, [4]);
      page.send({'type': 'view', 'page': 6, 'scale': 'page-width'});
      await tester.pumpAndSettle();
      expect(js.saveState(), {
        'route': 'pdfjs',
        'mode': 'full',
        'page': 5,
        'scale': 'page-width',
      });

      expect(js.setMode(TomPdfJsMode.components), isTrue);
      await tester.pumpAndSettle();
      expect(
        page.loads.last.path,
        endsWith('/pdfjs/web/forge/components.html'),
      );
      final calls = page.callNames;
      expect(calls.sublist(calls.lastIndexOf('open')), [
        'open',
        'zoom',
        'scrollTo',
      ]);
      expect(page.calls.last.$2, [6]);
    });

    testWidgets('FPDFJS-STATE-2: a kept state reopens the tab in its mode, '
        'at its page and scale', (tester) async {
      final w = Workspace();
      final a = w.add('/docs/a.pdf');
      final js = w.openJs(a);
      js.restoreState({
        'route': 'pdfjs',
        'mode': 'integrated',
        'page': 2,
        'scale': '1.5',
      });
      expect(js.mode, TomPdfJsMode.integrated);
      await w.show(tester, js);
      final page = w.pages.last;
      expect(
        page.loads.last.path,
        endsWith('/pdfjs/web/forge-integrated.html'),
      );
      final names = page.callNames;
      expect(names.sublist(names.lastIndexOf('open')), [
        'open',
        'zoom',
        'scrollTo',
      ]);
      expect(js.saveState()!['mode'], 'integrated');
      // An unknown mode leaves the mode as it is.
      js.restoreState(const {'mode': 'nonsense'});
      expect(js.mode, TomPdfJsMode.integrated);
    });
  });
}
