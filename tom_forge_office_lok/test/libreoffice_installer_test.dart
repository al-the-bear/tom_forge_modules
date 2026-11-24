/// LibreOffice's install help in Forge and its install runner
/// (`ForgeLibreOfficeInstaller`, DPLD-3): the missing-LibreOffice panel and
/// the External Tools row show `TomLibreOfficeInstallHelp`; a confirmed route
/// runs as processes, elevated its way, with `PATH` extended by Homebrew's
/// folders on macOS; its output streams into the help; Stop kills it; when it
/// ends detection runs again and the panel, the editor and the row follow. A
/// managed download is checked against its published SHA-256 before anything
/// runs. Every process is a fake (`FakeInstallStarter`): no test installs
/// anything.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_office_lok/tom_forge_office_lok.dart';
import 'package:tom_forge_office_lok_testing/tom_forge_office_lok_testing.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

const _missing = LibreOfficeInstallation(state: LibreOfficeState.missing);

/// The PATH the test installer starts from, and as the runner extends it on
/// macOS.
const _path = '/usr/bin:/bin';
const _macPath = '/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin';

TomInstallRoute _route(String id) => TomLibreOfficeTool.standard.route(id)!;

/// The output and end of [run].
Future<(String, TomLibreOfficeInstallResult)> _drain(
  TomLibreOfficeInstallRun run,
) async {
  final output = StringBuffer();
  await run.output.forEach(output.write);
  return (output.toString(), await run.result);
}

/// The LibreOffice row whose check answers [installation] (the module's
/// help builder is set on it), without a detector.
class _ScriptedTool extends ForgeLibreOfficeTool {
  _ScriptedTool(this.installation);

  LibreOfficeInstallation installation;
  var checks = 0;

  @override
  Future<ForgeToolCopy> check(String? path) async {
    checks++;
    return remember(installation);
  }

  @override
  Future<List<ForgeToolCopy>> autoDetect() async => const [];
}

/// Taps [key] after scrolling it into view.
Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

void main() {
  testWidgets('FOFF-INSTALL-1: the missing-LibreOffice panel runs the '
      'Homebrew route after the confirmation: brew install --cask '
      'libreoffice with Homebrew\'s folders on PATH, its output in the '
      'panel; when it exits detection runs again and the tab turns into the '
      'editor', (tester) async {
    final starter = FakeInstallStarter();
    final w = ForgeOfficeLokWorkspace(
      installation: _missing,
      installer: forgeOfficeTestInstaller(starter: starter),
    );
    final a = await w.add('/docs/a.docx');
    await w.module.detection;
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);
    expect(find.text('LibreOffice is not installed.'), findsOneWidget);
    expect(find.text('Install with Homebrew'), findsOneWidget);
    expect(find.text('Open with ZetaOffice'), findsNothing);

    await _tap(tester, 'office-install-run-macos-brew-cask');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('office-install-confirm-dialog')),
      findsOneWidget,
    );
    expect(starter.started, isEmpty, reason: 'nothing runs before the yes');
    await tester.tap(find.byKey(const ValueKey('office-install-confirm')));
    await tester.pump();
    await tester.pump();

    final brew = starter.started.single;
    expect(brew.executable, '/opt/homebrew/bin/brew');
    expect(brew.arguments, ['install', '--cask', 'libreoffice']);
    expect(brew.environment, {'PATH': _macPath});
    brew.out('==> Downloading https://download.documentfoundation.org/\n');
    brew.err('==> Installing Cask libreoffice\n');
    await tester.pump();
    await tester.pump();
    final output = tester
        .widget<SelectableText>(
          find.byKey(const ValueKey('office-install-output')),
        )
        .data!;
    expect(output, contains('\$ brew install --cask libreoffice'));
    expect(output, contains('==> Downloading'));
    expect(output, contains('==> Installing Cask libreoffice'));
    expect(w.detections, hasLength(1));

    w.installation = forgeOfficeFoundLibreOffice;
    brew.exit(0);
    await tester.pumpAndSettle();
    expect(w.detections, hasLength(2), reason: 'detection ran again');
    expect(editor.controller.state, TomOfficeEditorState.open);
    expect(
      find.byKey(const ValueKey('forge-office-missing-panel')),
      findsNothing,
    );
    expect(find.byType(TomOfficeEditor), findsOneWidget);
    await w.close(tester);
  });

  testWidgets('FOFF-INSTALL-2: a failed install stays in the panel with its '
      'exit code; Stop kills the running command', (tester) async {
    final starter = FakeInstallStarter();
    final w = ForgeOfficeLokWorkspace(
      installation: _missing,
      installer: forgeOfficeTestInstaller(starter: starter),
    );
    final a = await w.add('/docs/a.xlsx');
    await w.module.detection;
    w.module.openUri(a);
    final editor = w.editorOf(a)! as ForgeOfficeEditor;
    await w.show(tester, editor);

    await _tap(tester, 'office-install-run-macos-brew-cask');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('office-install-confirm')));
    await tester.pump();
    await tester.pump();
    final brew = starter.started.single;
    await _tap(tester, 'office-install-stop');
    await tester.pumpAndSettle();
    expect(brew.killed, isTrue);
    expect(find.textContaining('failed (exit -1): Stopped.'), findsOneWidget);
    expect(w.detections, hasLength(2), reason: 'detection ran again');
    expect(editor.controller.state, TomOfficeEditorState.unavailable);

    starter.onStart = (p) => p.exit(1);
    await _tap(tester, 'office-install-run-macos-brew-cask');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('office-install-confirm')));
    await tester.pumpAndSettle();
    expect(starter.started, hasLength(2));
    expect(
      find.textContaining(
        'failed (exit 1): brew install --cask libreoffice exited with 1',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-office-missing-panel')),
      findsOneWidget,
    );
    await w.close(tester);
  });

  test('FOFF-INSTALL-3: Stop during a run kills the process and ends the run '
      'as stopped; detection still runs after it', () async {
    final starter = FakeInstallStarter();
    final installer = forgeOfficeTestInstaller(starter: starter);
    var exits = 0;
    final run = installer.run(
      _route('macos-brew-cask'),
      onExit: () async => exits++,
    );
    await pumpEventQueue();
    final brew = starter.started.single;
    expect(brew.killed, isFalse);
    run.cancel!();
    final (_, result) = await _drain(run);
    expect(brew.killed, isTrue);
    expect(result.exitCode, -1);
    expect(result.message, 'Stopped.');
    await pumpEventQueue();
    expect(exits, 1);
  });

  group('FOFF-INSTALL-4: each route runs elevated its own way', () {
    test('Homebrew as the user, found on the extended PATH', () async {
      final starter = FakeInstallStarter(onStart: (p) => p.exit(0));
      final installer = forgeOfficeTestInstaller(starter: starter);
      final (_, result) = await _drain(
        installer.run(_route('macos-brew-cask')),
      );
      expect(result.ok, isTrue);
      expect(starter.started.single.executable, '/opt/homebrew/bin/brew');
      expect(starter.started.single.environment, {'PATH': _macPath});
    });

    test('winget as the user (its installer raises UAC)', () async {
      final starter = FakeInstallStarter(onStart: (p) => p.exit(0));
      final installer = forgeOfficeTestInstaller(
        starter: starter,
        platform: TomToolPlatform.windows,
        executables: const {},
      );
      final (_, result) = await _drain(installer.run(_route('windows-winget')));
      expect(result.ok, isTrue);
      final winget = starter.started.single;
      expect(winget.executable, 'winget');
      expect(winget.arguments, [
        'install',
        '--id',
        'TheDocumentFoundation.LibreOffice',
        '-e',
        '--accept-package-agreements',
        '--accept-source-agreements',
      ]);
      expect(winget.environment, {'PATH': _path});
      // Nothing is typed into it: a question reads end-of-input.
      expect(winget.stdinClosed, isTrue);
    });

    test('winget is found as its app execution alias; a PATH folder ending '
        'in a backslash gives no doubled one', () {
      const apps = r'C:\Users\a\AppData\Local\Microsoft\WindowsApps';
      const shell = r'C:\Windows\System32\WindowsPowerShell\v1.0\';
      final installer = ForgeLibreOfficeInstaller(
        environment: const {'Path': '$shell;$apps'},
        platform: TomToolPlatform.windows,
        executableExists: const {
          '$apps\\winget.exe',
          '${shell}powershell.exe',
        }.contains,
      );
      expect(installer.resolve('winget'), '$apps\\winget.exe');
      expect(installer.resolve('powershell'), '${shell}powershell.exe');
      expect(installer.routeAvailability['windows-winget'], isTrue);
      expect(installer.routeAvailability['windows-choco'], isFalse);
    });

    test('Chocolatey\'s log as Windows PowerShell writes it (UTF-16 LE with '
        'a byte-order mark) is read back; the exit code stays', () async {
      final starter = FakeInstallStarter(
        onStart: (p) {
          final encoded = RegExp(
            r'-EncodedCommand ([A-Za-z0-9+/=]+)',
          ).firstMatch(p.arguments.last)!.group(1)!;
          final bytes = base64Decode(encoded);
          final inner = String.fromCharCodes([
            for (var i = 0; i < bytes.length; i += 2)
              bytes[i] | (bytes[i + 1] << 8),
          ]);
          final log = RegExp(r"\*> '([^']+)'").firstMatch(inner)!.group(1)!;
          const text = 'The install of libreoffice-fresh was successful.\r\n';
          File(log).writeAsBytesSync([
            0xff,
            0xfe,
            for (final unit in text.codeUnits) ...[unit & 0xff, unit >> 8],
          ]);
          p.exit(0);
        },
      );
      final installer = forgeOfficeTestInstaller(
        starter: starter,
        platform: TomToolPlatform.windows,
        executables: const {},
      );
      final (output, result) = await _drain(
        installer.run(_route('windows-choco')),
      );
      expect(result.ok, isTrue, reason: '$result');
      expect(
        output,
        contains('The install of libreoffice-fresh was successful.'),
      );
    });

    test('Chocolatey in an elevated PowerShell (Start-Process -Verb RunAs), '
        'its output read back from the log it was redirected into', () async {
      String? inner;
      final starter = FakeInstallStarter(
        onStart: (p) {
          final encoded = RegExp(
            r'-EncodedCommand ([A-Za-z0-9+/=]+)',
          ).firstMatch(p.arguments.last)!.group(1)!;
          final bytes = base64Decode(encoded);
          inner = String.fromCharCodes([
            for (var i = 0; i < bytes.length; i += 2)
              bytes[i] | (bytes[i + 1] << 8),
          ]);
          final log = RegExp(r"\*> '([^']+)'").firstMatch(inner!)!.group(1)!;
          File(log).writeAsStringSync('Chocolatey installed 1/1 packages.\n');
          p.exit(0);
        },
      );
      final installer = forgeOfficeTestInstaller(
        starter: starter,
        platform: TomToolPlatform.windows,
        executables: const {},
      );
      final (output, result) = await _drain(
        installer.run(_route('windows-choco')),
      );
      expect(result.ok, isTrue);
      final shell = starter.started.single;
      expect(shell.executable, 'powershell');
      expect(shell.arguments.take(3), [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
      ]);
      expect(
        shell.arguments.last,
        allOf(
          startsWith('\$p = Start-Process -FilePath powershell.exe'),
          contains('-Verb RunAs -Wait -PassThru'),
          endsWith('exit \$p.ExitCode'),
        ),
      );
      expect(
        inner,
        matches(
          RegExp(
            r"^& 'choco' 'install' 'libreoffice-fresh' '-y' \*> '[^']+'; "
            r'exit \$LASTEXITCODE$',
          ),
        ),
      );
      expect(output, contains('Chocolatey installed 1/1 packages.'));
      final log = RegExp(r"\*> '([^']+)'").firstMatch(inner!)!.group(1)!;
      expect(File(log).existsSync(), isFalse, reason: 'the log is removed');
    });

    test('apt through pkexec, its commands in order; a failing command ends '
        'the run', () async {
      final starter = FakeInstallStarter(onStart: (p) => p.exit(0));
      final installer = forgeOfficeTestInstaller(
        starter: starter,
        platform: TomToolPlatform.linux,
        executables: const {},
      );
      final (_, result) = await _drain(installer.run(_route('linux-apt-ppa')));
      expect(result.ok, isTrue);
      expect(
        [for (final p in starter.started) '$p'],
        [
          'pkexec add-apt-repository -y ppa:libreoffice/ppa',
          'pkexec apt-get update',
          'pkexec apt-get install -y libreoffice',
        ],
      );
      expect(starter.started.first.environment, {'PATH': _path});

      starter
        ..started.clear()
        ..onStart = (p) => p.exit(100);
      final (_, failed) = await _drain(installer.run(_route('linux-apt-ppa')));
      expect(failed.exitCode, 100);
      expect(starter.started, hasLength(1));
    });
  });

  group('FOFF-INSTALL-5: the managed download (TDF\'s .deb archive)', () {
    final route = _route('linux-tdf-deb');
    final download = route.download!;
    final archive = utf8.encode('the archive');
    final digest = sha256.convert(archive).toString();

    /// A starter whose `tar` unpacks two packages and a stray file into the
    /// `-C` folder; every command exits 0.
    FakeInstallStarter unpacking() => FakeInstallStarter(
      onStart: (p) {
        if (p.executable == 'tar') {
          final into = p.arguments[p.arguments.indexOf('-C') + 1];
          final debs = Directory(
            '$into/LibreOffice_26.8.3.1_Linux_x86-64_deb/DEBS',
          )..createSync(recursive: true);
          File('${debs.path}/libreoffice26.8-writer.deb').writeAsStringSync('');
          File('${debs.path}/libreoffice26.8-core.deb').writeAsStringSync('');
          File('$into/readme.txt').writeAsStringSync('');
        }
        p.exit(0);
      },
    );

    test('a matching SHA-256: unpacked with tar, its packages installed with '
        'pkexec dpkg -i; the scratch folder is removed', () async {
      final starter = unpacking();
      final http = FakeInstallHttp(
        files: {download.url(): archive},
        texts: {download.hashUrl(): '$digest  ${download.fileName()}\n'},
      );
      final installer = forgeOfficeTestInstaller(
        starter: starter,
        http: http,
        platform: TomToolPlatform.linux,
        executables: const {},
      );
      final (output, result) = await _drain(installer.run(route));
      expect(result.ok, isTrue, reason: '${result.message}\n$output');
      expect(http.requests, [download.url(), download.hashUrl()]);
      expect(output, contains('SHA-256 matches: $digest'));
      final tar = starter.started.first;
      expect(tar.executable, 'tar');
      expect(tar.arguments.first, '-xzf');
      expect(tar.arguments[1], endsWith('/${download.fileName()}'));
      final dpkg = starter.started.last;
      expect(starter.started, hasLength(2));
      expect(dpkg.executable, 'pkexec');
      expect(dpkg.arguments.take(2), ['dpkg', '-i']);
      expect(dpkg.arguments.skip(2).map((f) => f.split('/').last), [
        'libreoffice26.8-core.deb',
        'libreoffice26.8-writer.deb',
      ]);
      final scratch = Directory(tar.arguments[1]).parent;
      expect(scratch.path, startsWith(Directory.systemTemp.path));
      expect(scratch.existsSync(), isFalse);
    });

    test('a SHA-256 that does not match stops it: nothing is unpacked or '
        'run', () async {
      final starter = unpacking();
      final http = FakeInstallHttp(
        files: {download.url(): archive},
        texts: {download.hashUrl(): '${'0' * 64}  ${download.fileName()}\n'},
      );
      final installer = forgeOfficeTestInstaller(
        starter: starter,
        http: http,
        platform: TomToolPlatform.linux,
        executables: const {},
      );
      final (_, result) = await _drain(installer.run(route));
      expect(result.exitCode, -1);
      expect(result.message, contains('The SHA-256 does not match'));
      expect(result.message, contains('nothing was installed'));
      expect(starter.started, isEmpty);
    });
  });

  test('FOFF-INSTALL-7: an install log is read in the encoding it was '
      'written in', () {
    List<int> utf16le(String s, {bool bom = true}) => [
      if (bom) ...[0xff, 0xfe],
      for (final u in s.codeUnits) ...[u & 0xff, u >> 8],
    ];
    expect(forgeDecodeInstallLog(utf16le('Größe ok')), 'Größe ok');
    expect(forgeDecodeInstallLog(utf16le('ok', bom: false)), 'ok');
    expect(
      forgeDecodeInstallLog([0xfe, 0xff, 0, 0x6f, 0, 0x6b]),
      'ok',
      reason: 'UTF-16 BE',
    );
    expect(
      forgeDecodeInstallLog([0xef, 0xbb, 0xbf, ...utf8.encode('Größe')]),
      'Größe',
    );
    expect(forgeDecodeInstallLog(utf8.encode('plain')), 'plain');
    // A byte that is no UTF-8 is replaced, not thrown.
    expect(forgeDecodeInstallLog([0x53, 0xfc, 0x21]), 'S\ufffd!');
    expect(forgeDecodeInstallLog(const []), '');
  });

  test('FOFF-INSTALL-6: PATH gets Homebrew\'s folders on macOS only; route '
      'availability looks on it', () {
    expect(
      forgeInstallSearchPath('/usr/bin:/bin', TomToolPlatform.macos),
      _macPath,
    );
    expect(
      forgeInstallSearchPath(
        '/opt/homebrew/bin:/usr/bin',
        TomToolPlatform.macos,
      ),
      '/opt/homebrew/bin:/usr/bin:/usr/local/bin',
    );
    expect(
      forgeInstallSearchPath('/usr/bin', TomToolPlatform.linux),
      '/usr/bin',
    );
    final withBrew = forgeOfficeTestInstaller();
    expect(withBrew.searchPath, _macPath);
    expect(withBrew.routeAvailability, {
      'macos-brew-cask': true,
      'macos-download': true,
    });
    expect(forgeOfficeTestInstaller(executables: const {}).routeAvailability, {
      'macos-brew-cask': false,
      'macos-download': true,
    });
    // The desktop's: installRouteAvailability on the extended PATH, so a GUI
    // app started without Homebrew on its PATH still finds brew.
    final desktop = ForgeLibreOfficeInstaller(
      environment: const {'PATH': '/usr/bin:/bin'},
      platform: TomToolPlatform.macos,
    );
    expect(
      desktop.routeAvailability['macos-brew-cask'],
      File('/opt/homebrew/bin/brew').existsSync() ||
          File('/usr/local/bin/brew').existsSync(),
    );
  });

  testWidgets('FOFF-TOOL-6: the External Tools row shows the install help '
      'while LibreOffice is missing and not once it is found; an install '
      'from the row checks the row again', (tester) async {
    final tool = _ScriptedTool(_missing);
    final starter = FakeInstallStarter();
    final module = ForgeOfficeLokModule(
      detect: (_) async => tool.installation,
      cleanUpHelpers: () async {},
      libreOfficeTool: tool,
      installer: forgeOfficeTestInstaller(starter: starter),
    );
    await pumpForgeExternalToolsSection(
      tester,
      forgeShellExternalToolsOf(module),
    );
    expect(
      find.byKey(const ValueKey('forge-tool-libreoffice-help')),
      findsOneWidget,
    );
    expect(find.text('LibreOffice is not installed.'), findsOneWidget);
    expect(find.text('Install with Homebrew'), findsOneWidget);
    expect(find.textContaining('Download: '), findsNothing);
    final checksBefore = tool.checks;

    await _tap(tester, 'office-install-run-macos-brew-cask');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('office-install-confirm')));
    await tester.pump();
    await tester.pump();
    final brew = starter.started.single;
    expect(brew.arguments, ['install', '--cask', 'libreoffice']);
    brew.out('==> Moving App \'LibreOffice.app\' to \'/Applications\'\n');
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Moving App'), findsOneWidget);

    tool.installation = forgeOfficeFoundLibreOffice;
    brew.exit(0);
    await tester.pumpAndSettle();
    expect(tool.checks, greaterThan(checksBefore), reason: 'checked again');
    expect(
      find.byKey(const ValueKey('forge-tool-libreoffice-help')),
      findsNothing,
    );
    expect(find.text('Found'), findsOneWidget);
    expect(module.installation, forgeOfficeFoundLibreOffice);
  });

  testWidgets('FOFF-TOOL-7: a found LibreOffice shows no help in the row; a '
      'too old one shows it with its version', (tester) async {
    final tool = _ScriptedTool(forgeOfficeFoundLibreOffice);
    final module = ForgeOfficeLokModule(
      detect: (_) async => tool.installation,
      cleanUpHelpers: () async {},
      libreOfficeTool: tool,
      installer: forgeOfficeTestInstaller(),
    );
    await pumpForgeExternalToolsSection(
      tester,
      forgeShellExternalToolsOf(module),
    );
    expect(
      find.byKey(const ValueKey('forge-tool-libreoffice-help')),
      findsNothing,
    );
    expect(find.byType(TomLibreOfficeInstallHelp), findsNothing);

    tool.installation = const LibreOfficeInstallation(
      state: LibreOfficeState.tooOld,
      bundlePath: '/Applications/LibreOffice.app',
      version: '24.2.7.2',
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-tool-libreoffice-check')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('forge-tool-libreoffice-help')),
      findsOneWidget,
    );
    expect(
      find.text('LibreOffice 24.2.7.2 is older than 26.8.3.1.'),
      findsOneWidget,
    );
  });
}
