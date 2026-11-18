/// The shell's find bar on a non-text editor ([ForgeFindTarget]): Find is
/// enabled for it, the query goes to the editor, next and previous move its
/// matches, the counter shows its status, Replace is not offered, closing
/// the bar clears the editor's search.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

/// A document without a text buffer that searches itself.
class _FindableEditor extends ForgeEditor implements ForgeFindTarget {
  _FindableEditor(this.text);

  final String text;
  final calls = <String>[];
  final _status = ValueNotifier(ForgeFindStatus.none);
  List<int> _matches = const [];

  @override
  Uri get uri => Uri.parse('file:///workspace/doc.pdf');

  @override
  ValueListenable<String> get title => ValueNotifier('doc.pdf');

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.picture_as_pdf;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.accept;

  @override
  ValueListenable<bool> get isDirty => ValueNotifier(false);

  @override
  void markClean() {}

  @override
  Widget buildMain(BuildContext context) =>
      const Center(child: Text('rendered pages'));

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  @override
  void find(
    String query, {
    bool caseSensitive = false,
    bool wholeWord = false,
  }) {
    calls.add('find $query');
    _matches = [
      if (query.isNotEmpty)
        for (
          var i = text.indexOf(query);
          i >= 0;
          i = text.indexOf(query, i + 1)
        )
          i,
    ];
    _status.value = ForgeFindStatus(
      current: _matches.isEmpty ? 0 : 1,
      total: _matches.length,
    );
  }

  @override
  void findNext() {
    calls.add('next');
    final s = _status.value;
    if (s.total == 0) return;
    _status.value = ForgeFindStatus(
      current: s.current % s.total + 1,
      total: s.total,
    );
  }

  @override
  void findPrevious() {
    calls.add('previous');
    final s = _status.value;
    if (s.total == 0) return;
    _status.value = ForgeFindStatus(
      current: s.current == 1 ? s.total : s.current - 1,
      total: s.total,
    );
  }

  @override
  void clearFind() {
    calls.add('clear');
    _status.value = ForgeFindStatus.none;
  }

  @override
  ValueListenable<ForgeFindStatus> get findStatus => _status;
}

void main() {
  testWidgets('FIND-TARGET-1: the shell\'s find bar searches a non-text '
      'editor through ForgeFindTarget', (tester) async {
    suppressOverflowErrorsForTest();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Find target',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    shell.applications.add(
      ForgeApplication(
        id: 'find-target',
        title: 'Find target',
        layout: const PanelLayout(
          leftPanel: PanelConfig(initialSize: 250, tabs: []),
          rightPanel: PanelConfig(initialSize: 220, tabs: []),
          bottomPanel: PanelConfig(initialSize: 180, tabs: []),
          middlePanels: [MiddlePanelConfig()],
        ),
      ),
    );
    final editor = _FindableEditor(
      'reasoning chain, reasoning steps, reasoning',
    );
    final layout = shell.layout as DefaultLayoutController;
    layout.openEditor(editor, editor.uri);
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeShellScaffold(
          shell: shell,
          layoutController: layout,
          systemState: shell.systemState as DefaultSystemState,
          statusBarController: shell.statusBar,
          notificationManager:
              shell.notifications as DefaultNotificationManager,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(shell.actionRegistry.getAction('editor.find')!.isEnabled(), isTrue);
    expect(shell.executeAction('editor.find'), isTrue);
    await tester.pumpAndSettle();
    final query = find.byKey(const Key('find-bar-query-field'));
    expect(query, findsOneWidget);
    // Nothing to replace in a non-text editor.
    expect(find.byKey(const Key('find-toggle-replace-button')), findsNothing);

    await tester.enterText(query, 'reasoning');
    await tester.pumpAndSettle();
    expect(editor.calls.last, 'find reasoning');
    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('find-next-button')));
    await tester.pumpAndSettle();
    expect(editor.calls.last, 'next');
    expect(find.text('2/3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('find-prev-button')));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('find-close-button')));
    await tester.pumpAndSettle();
    expect(editor.calls.last, 'clear');
    expect(query, findsNothing);
    // Replace stays for text editors only.
    expect(
      shell.actionRegistry.getAction('edit.replace')!.isEnabled(),
      isFalse,
    );
  });
}
