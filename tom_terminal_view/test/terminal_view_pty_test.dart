// A real shell in a pseudo-terminal, shown in the view: the native library
// of flutter_pty is compiled for the test (support/pty_native_library.dart).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_terminal_view/tom_terminal_view.dart';
import 'package:xterm/xterm.dart' as xterm;

import 'support/pty_native_library.dart';

void main() {
  PtyNativeLibrary? library;
  String? skipReason;

  setUpAll(() async {
    (library, skipReason) = await PtyNativeLibrary.prepare();
  });

  tearDownAll(() => library?.restore());

  Future<void> waitFor(bool Function() done, String what) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('timed out waiting for $what');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  testWidgets('runs /bin/sh in the view: echo hello-tom, then exit', (
    tester,
  ) async {
    if (skipReason != null) {
      markTestSkipped(skipReason!);
      return;
    }
    final exits = <int>[];
    final session = (await tester.runAsync(
      () async => TomTerminalSession(
        options: const TomTerminalOptions(
          shell: '/bin/sh',
          environment: {'PS1': r'$ ', 'ENV': ''},
        ),
        onExit: exits.add,
      ),
    ))!;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TomTerminalView(session: session),
      ),
    );
    await tester.pump();
    expect(find.byType(xterm.TerminalView), findsOneWidget);

    session.sendText('echo hello-tom');
    await tester.runAsync(
      () => waitFor(
        () => session.text.split('\n').any((l) => l.trim() == 'hello-tom'),
        'hello-tom in the terminal',
      ),
    );
    // The command line itself and its output.
    expect(session.text, contains('echo hello-tom'));
    expect(
      session.text.split('\n').where((l) => l.trim() == 'hello-tom'),
      hasLength(1),
    );

    session.sendText('exit');
    final code = await tester.runAsync(
      () => session.exitCode.timeout(const Duration(seconds: 15)),
    );
    expect(code, 0);
    expect(exits, [0]);
    expect(session.hasExited, isTrue);

    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    session.close();
  });
}
