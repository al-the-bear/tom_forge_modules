import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_terminal_view/tom_terminal_view.dart';
import 'package:xterm/xterm.dart' as xterm;

import 'support/fake_terminal_process.dart';

void main() {
  late FakeTerminalProcess process;

  TomTerminalSession start({
    TomTerminalOptions options = const TomTerminalOptions(),
    void Function(int)? onExit,
    void Function(String)? onTitleChange,
  }) => TomTerminalSession(
    options: options,
    start: (o) => process = FakeTerminalProcess(o),
    onExit: onExit,
    onTitleChange: onTitleChange,
  );

  group('TomTerminalOptions', () {
    test('defaults: the user\'s shell, 80x25, 10000 lines, exit message', () {
      const options = TomTerminalOptions();
      expect(options.columns, 80);
      expect(options.rows, 25);
      expect(options.scrollback, 10000);
      expect(options.exitMessage, isTrue);
      expect(options.arguments, isEmpty);
      expect(options.effectiveShell, TomTerminalOptions.defaultShell());
      if (!Platform.isWindows) {
        expect(
          TomTerminalOptions.defaultShell(),
          Platform.environment['SHELL'] ?? '/bin/bash',
        );
      }
    });

    test('a given shell is the one that runs', () {
      expect(
        const TomTerminalOptions(shell: '/bin/sh').effectiveShell,
        '/bin/sh',
      );
    });
  });

  group('TomTerminalSession', () {
    test('starts the process with the options and sizes the terminal', () {
      const options = TomTerminalOptions(
        shell: '/bin/sh',
        arguments: ['-i'],
        workingDirectory: '/work',
        environment: {'A': '1'},
        columns: 100,
        rows: 30,
        scrollback: 500,
      );
      final session = start(options: options);
      expect(process.options, same(options));
      expect(session.shell, '/bin/sh');
      expect(session.terminal.viewWidth, 100);
      expect(session.terminal.viewHeight, 30);
      expect(session.terminal.maxLines, 500);
      expect(session.pid, 4242);
      session.close();
    });

    test(
      'what the process writes goes into the terminal and to output',
      () async {
        final session = start();
        final out = <String>[];
        session.output.listen(out.add);
        process.emit('hello\r\nworld');
        await pumpEventQueue();
        expect(out, ['hello\r\nworld']);
        expect(session.text, 'hello\nworld');
        session.close();
      },
    );

    test('sendText adds a newline, write sends as it is', () {
      final session = start();
      session.sendText('ls');
      session.sendText('x', addNewLine: false);
      session.write('\x03');
      expect(process.written, ['ls\n', 'x', '\x03']);
      session.close();
    });

    test('what is typed into the terminal goes to the process', () {
      final session = start();
      session.terminal.textInput('a');
      session.terminal.keyInput(xterm.TerminalKey.enter);
      expect(process.written.join(), 'a\r');
      session.close();
    });

    test('a resize of the terminal resizes the pseudo-terminal', () {
      final session = start();
      session.terminal.resize(120, 40);
      expect(process.resizes, [(40, 120)]);
      session.close();
    });

    test('the title the shell sets reaches title and onTitleChange', () async {
      final titles = <String>[];
      final session = start(onTitleChange: titles.add);
      process.emit('\x1b]0;build\x07');
      await pumpEventQueue();
      expect(titles, ['build']);
      expect(session.title.value, 'build');
      session.close();
    });

    test('the end of the shell: exit message, onExit, exitCode', () async {
      final exits = <int>[];
      final session = start(onExit: exits.add);
      expect(session.hasExited, isFalse);
      process.exit(3);
      expect(await session.exitCode, 3);
      expect(exits, [3]);
      expect(session.hasExited, isTrue);
      expect(session.exitCodeOrNull, 3);
      expect(session.text, contains('[Process exited with code 3]'));
      session.close();
    });

    test('no exit message when exitMessage is false', () async {
      final session = start(
        options: const TomTerminalOptions(exitMessage: false),
      );
      process.exit(0);
      await session.exitCode;
      expect(session.text, isEmpty);
      session.close();
    });

    test('clear empties the terminal', () async {
      final session = start();
      process.emit('some text');
      await pumpEventQueue();
      session.clear();
      expect(session.text, isEmpty);
      expect(session.terminal.buffer.cursorX, 0);
      expect(session.terminal.buffer.cursorY, 0);
      session.close();
    });

    test('close kills the process once and stops sending', () async {
      final session = start();
      final out = <String>[];
      session.output.listen(out.add);
      session.close();
      session.close();
      expect(process.kills, 1);
      expect(session.isClosed, isTrue);
      session.sendText('ignored');
      expect(process.written, isEmpty);
      await pumpEventQueue();
      expect(out, isEmpty);
    });
  });

  group('TomTerminalStyle and TomTerminalColors', () {
    test('the standard colours are xterm\'s default theme', () {
      const base = xterm.TerminalThemes.defaultTheme;
      final theme = const TomTerminalStyle().toXtermTheme();
      expect(theme.foreground, base.foreground);
      expect(theme.background, base.background);
      expect(theme.cursor, base.cursor);
      expect(theme.selection, base.selection);
      expect(theme.red, base.red);
      expect(theme.brightWhite, base.brightWhite);
    });

    test('copyWith replaces what is given', () {
      const black = Color(0xFF000000);
      final colors = TomTerminalColors.standard.copyWith(background: black);
      expect(colors.background, black);
      expect(colors.foreground, TomTerminalColors.standard.foreground);
      expect(TomTerminalStyle(colors: colors).toXtermTheme().background, black);
    });

    test('the font goes into the xterm text style', () {
      final style = const TomTerminalStyle(
        fontFamily: 'Menlo',
        fontSize: 15,
      ).toXtermTextStyle();
      expect(style.fontFamily, 'Menlo');
      expect(style.fontSize, 15);
    });
  });

  group('TomTerminalView', () {
    testWidgets('shows the session and sends typed keys to the process', (
      tester,
    ) async {
      final session = start();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TomTerminalView(session: session),
        ),
      );
      await tester.pump();
      expect(find.byType(xterm.TerminalView), findsOneWidget);
      // The view resized the pseudo-terminal to its size.
      expect(process.resizes, isNotEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(process.written.join(), 'a\r');

      await tester.pumpWidget(const SizedBox());
      session.close();
    });
  });
}
