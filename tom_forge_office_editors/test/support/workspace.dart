import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_office_editors/tom_forge_office_editors.dart';
import 'package:tom_forge_office_editors_testing/tom_forge_office_editors_testing.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultModuleRegistry, DefaultShellApi;
import 'package:tom_office_editor/testing.dart';
import 'package:tom_office_editor/tom_office_editor.dart';
import 'package:tom_office_editor/zetaoffice.dart';

/// LibreOffice as detection finds it on mbp.
const foundLibreOffice = LibreOfficeInstallation(
  state: LibreOfficeState.found,
  bundlePath: '/Applications/LibreOffice.app',
  version: kLibreOfficeMinimumVersion,
);

/// A shell with the module over a memory file system: detection answers
/// [installation], helpers are [ScriptedOfficeHelper]s, ZetaOffice pages
/// [ScriptedZetaOfficePage]s over fake servers.
class Workspace {
  Workspace({
    this.installation = foundLibreOffice,
    TomZetaOfficeFiles? zetaFiles,
    this.userPath,
  }) : fs = TomMemoryFileSystem(),
       zetaFiles =
           zetaFiles ??
           FakeZetaOfficeFiles(state: TomZetaOfficeCacheState.ready) {
    shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fs,
      appName: 'Office editors',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    files = TomFileSystemBinaryFiles(fs);
    module = ForgeOfficeEditorsModule(
      files: files,
      detect: (path) async {
        detections.add(path);
        return installation;
      },
      libreOfficePath: () => userPath,
      setLibreOfficePath: (path) async => userPath = path,
      launcherFor: (found) => launcher = FakeOfficeHelperLauncher(
        installation: found,
        channelFor: () {
          final helper = ScriptedOfficeHelper('doc', fileSystem: fs);
          helpers.add(helper);
          return helper;
        },
      ),
      pickLibreOffice: () async => picked,
      pickImage: () async => null,
      cleanUpHelpers: () async {},
      zetaFiles: this.zetaFiles,
      zetaServing: (_) {
        final serving = FakeZetaOfficeServing();
        servings.add(serving);
        return serving;
      },
      zetaChannelForTesting: () {
        final page = ScriptedZetaOfficePage('doc', servings.last);
        pages.add(page);
        return page;
      },
      tileDecoder: forgeOfficeTestDecoder,
    )..activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
  }

  final TomMemoryFileSystem fs;
  late final TomBinaryFiles files;
  late final DefaultShellApi shell;
  late final ForgeOfficeEditorsModule module;
  final TomZetaOfficeFiles zetaFiles;

  /// What detection answers.
  LibreOfficeInstallation installation;

  /// The user's path setting.
  String? userPath;

  /// What *Choose LibreOffice…* picks.
  String? picked;

  /// The paths detection ran with, in order.
  final detections = <String>[];

  /// The launcher of the last detection.
  FakeOfficeHelperLauncher? launcher;

  /// Every scripted helper started, newest last.
  final helpers = <ScriptedOfficeHelper>[];

  /// Every ZetaOffice server and page, newest last.
  final servings = <FakeZetaOfficeServing>[];
  final pages = <ScriptedZetaOfficePage>[];

  /// Adds a file holding [text] at [path].
  Future<Uri> add(String path, [String text = 'doc']) async {
    final uri = fs.uriOf(path);
    await fs.writeText(uri, text);
    return uri;
  }

  /// The file's text on disk.
  Future<String> text(String path) => fs.readText(fs.uriOf(path));

  ForgeEditor? editorOf(Uri uri) =>
      shell.systemState.openEditors.where((e) => e.uri == uri).lastOrNull;

  /// Shows [editor]'s main view and lets the fakes answer.
  Future<void> show(WidgetTester tester, ForgeEditor editor) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: editor.buildMain)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drops the tree and closes every editor of the module, so no timer is
  /// left.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    module.deactivate();
    await tester.pump(const Duration(seconds: 1));
  }
}
