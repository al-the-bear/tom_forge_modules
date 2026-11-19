/// LibreOffice's row in the Configuration panel's External Tools section:
/// the module registers the descriptor (`libreoffice`, the setting
/// `forge.tools.libreoffice.path`, the first row), whose check runs
/// detection with the user's path and maps its states.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_office_editors/tom_forge_office_editors.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
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
  test('FOFF-TOOL-1: the module registers the LibreOffice descriptor', () {
    final module = ForgeOfficeEditorsModule(cleanUpHelpers: () async {});
    final tools = module.externalTools;
    expect(tools, hasLength(1));
    final tool = tools.single;
    expect(tool, isA<ForgeLibreOfficeTool>());
    expect(tool.id, 'libreoffice');
    expect(
      ForgePreferencesService.externalToolPathKey(tool.id),
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

  testWidgets('FOFF-TOOL-4: the LibreOffice row is the first row of External '
      'Tools', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = ForgePreferencesService();
    await prefs.load();
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeExternalToolsSection(
            // Registered after another tool: the section sorts by order.
            tools: [_OtherTool(), _FixedLibreOffice()],
            preferencesService: prefs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final libreOffice = tester.getTopLeft(
      find.byKey(const ValueKey('forge-tool-libreoffice')),
    );
    final other = tester.getTopLeft(
      find.byKey(const ValueKey('forge-tool-pandoc')),
    );
    expect(libreOffice.dy, lessThan(other.dy));
  });
}
