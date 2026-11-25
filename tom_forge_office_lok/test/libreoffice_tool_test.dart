/// LibreOffice's row in the Configuration panel's External Tools section:
/// the module contributes the descriptor as a kit extra
/// (`ForgeExternalToolsExtra`: `libreoffice`, the setting
/// `forge.tools.libreoffice.path`, the first row), which the panel shell
/// reads; its check runs detection with the user's path and maps its states.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_office_lok/tom_forge_office_lok.dart';
import 'package:tom_forge_office_lok_testing/tom_forge_office_lok_testing.dart';
import 'package:tom_office_editor/io.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

/// A detector that finds nothing and runs no process.
TomLibreOfficeDetector _emptyDetector(String userPath, Directory scratch) =>
    TomLibreOfficeDetector(
      userPath: userPath,
      applicationFolders: const [],
      caskFolders: const [],
      macPortsFolders: const [],
      run: (executable, arguments, {timeout = const Duration(seconds: 1)}) =>
          Future.error(StateError('no process in this test')),
      scratch: scratch.path,
      searchPath: '',
      useSpotlight: false,
    );

/// The descriptor with fixed answers (the section checks every row).
class _FixedLibreOffice extends ForgeLibreOfficeTool {
  @override
  Future<ForgeToolCopy> check(String? path) async => const ForgeToolCopy(
    path: '/Applications/LibreOffice.app',
    state: ForgeToolState.found,
    version: kLibreOfficeMinimumVersion,
  );

  @override
  Future<List<ForgeToolCopy>> autoDetect() async => const [];
}

class _OtherTool extends ForgeExternalTool {
  @override
  String get id => 'pandoc';

  @override
  String get name => 'Pandoc';

  @override
  Future<ForgeToolCopy> check(String? path) async =>
      const ForgeToolCopy.missing();

  @override
  Future<List<ForgeToolCopy>> autoDetect() async => const [];
}

void main() {
  test('FOFF-TOOL-1: the module contributes the LibreOffice descriptor as '
      'a kit extra, which the panel shell reads', () {
    final module = ForgeOfficeLokModule(cleanUpHelpers: () async {});
    final extras = module.extras.whereType<ForgeExternalToolsExtra>();
    expect(extras, hasLength(1));
    final tools = extras.single.tools;
    expect(tools, hasLength(1));
    expect(forgeShellExternalToolsOf(module), tools);
    final tool = tools.single;
    expect(tool, isA<ForgeLibreOfficeTool>());
    expect(tool.id, 'libreoffice');
    expect(
      ForgeKitPreferences.externalToolPathKey(tool.id),
      'forge.tools.libreoffice.path',
    );
    expect(tool.name, 'LibreOffice');
    expect(tool.order, 0);
    expect(tool.pathIsDirectory, isTrue);
    expect(tool.pathHint, 'LibreOffice.app');
    expect(tool.downloadUrl, kLibreOfficeDownloadUrl);
  });

  test('FOFF-TOOL-2: detection\'s states map to the section\'s', () {
    for (final (state, expected) in [
      (LibreOfficeState.found, ForgeToolState.found),
      (LibreOfficeState.missing, ForgeToolState.missing),
      (LibreOfficeState.tooOld, ForgeToolState.tooOld),
      (LibreOfficeState.damaged, ForgeToolState.damaged),
      (LibreOfficeState.quarantined, ForgeToolState.quarantined),
    ]) {
      final copy = ForgeLibreOfficeTool.copyOf(
        LibreOfficeInstallation(
          state: state,
          bundlePath: '/Applications/LibreOffice.app',
          version: '26.8.3.1',
          reason: 'why',
        ),
      );
      expect(copy.state, expected);
      expect(copy.path, '/Applications/LibreOffice.app');
      expect(copy.version, '26.8.3.1');
      expect(copy.reason, 'why');
    }
    expect(
      ForgeLibreOfficeTool.copyOf(
        const LibreOfficeInstallation(state: LibreOfficeState.missing),
      ).path,
      '',
    );
  });

  test('FOFF-TOOL-3: check runs detection with the user\'s path, or a '
      'search without one', () async {
    final scratch = Directory.systemTemp.createTempSync('foff-tool-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final paths = <String>[];
    final tool = ForgeLibreOfficeTool(
      detectorFor: (userPath) {
        paths.add(userPath);
        return _emptyDetector(userPath, scratch);
      },
    );
    final searched = await tool.check(null);
    expect(searched.state, ForgeToolState.missing);
    final atPath = await tool.check('/nowhere/LibreOffice.app');
    expect(atPath.usable, isFalse);
    expect(paths, ['', '/nowhere/LibreOffice.app']);
    expect(await tool.autoDetect(), isEmpty);
  });

  test('FOFF-TOOL-5: the module reads and writes the path setting through '
      'the preferences it is given (the panel shell: the ones its External '
      'Tools section edits)', () async {
    final prefs = ForgeKitPreferences(stateStore: ForgeMemoryStateStore());
    await prefs.load();
    final module = ForgeOfficeLokModule(
      preferences: prefs,
      cleanUpHelpers: () async {},
    );
    expect(module.libreOfficePath(), isNull);
    await module.setLibreOfficePath('/Applications/LibreOffice.app');
    expect(
      prefs.externalToolPath(ForgeLibreOfficeTool.toolId),
      '/Applications/LibreOffice.app',
    );
    expect(module.libreOfficePath(), '/Applications/LibreOffice.app');
  });

  testWidgets('FOFF-TOOL-4: the LibreOffice row is the first row of External '
      'Tools', (tester) async {
    // Registered after another tool: the section sorts by order.
    await pumpForgeExternalToolsTile(tester, [
      _OtherTool(),
      _FixedLibreOffice(),
    ]);
    final libreOffice = tester.getTopLeft(
      forgeExternalToolEntry('libreoffice'),
    );
    final other = tester.getTopLeft(forgeExternalToolEntry('pandoc'));
    expect(libreOffice.dy, lessThan(other.dy));
  });
  testWidgets('FOFF-TOOL-8: the real row over the real detector finding '
      'nothing shows the install help with this platform\'s routes and the '
      'desktop runner\'s availability (nothing is run)', (tester) async {
    final scratch = Directory.systemTemp.createTempSync('foff-tool-');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final module = ForgeOfficeLokModule(
      detect: (_) async =>
          const LibreOfficeInstallation(state: LibreOfficeState.missing),
      cleanUpHelpers: () async {},
      libreOfficeTool: ForgeLibreOfficeTool(
        detectorFor: (userPath) => _emptyDetector(userPath, scratch),
      ),
    );
    await tester.runAsync(
      () =>
          pumpForgeExternalToolsTile(tester, forgeShellExternalToolsOf(module)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Not found'), findsOneWidget);
    expect(forgeExternalToolHelp('libreoffice'), findsOneWidget);
    expect(find.text('LibreOffice is not installed.'), findsOneWidget);
    final platform = module.installer.platform;
    expect(
      platform,
      TomToolPlatform.fromName(Platform.operatingSystem) ??
          TomToolPlatform.macos,
    );
    for (final route in TomLibreOfficeTool.standard.routes(platform)) {
      expect(
        find.byKey(ValueKey('office-install-route-${route.id}')),
        findsOneWidget,
      );
    }
  });
}
