import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_office_lok/tom_forge_office_lok.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart' show DefaultShellApi;
import 'package:tom_office_editor/testing.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

import '../tom_forge_office_lok_testing.dart';

/// LibreOffice as detection finds it on mbp.
const forgeOfficeFoundLibreOffice = LibreOfficeInstallation(
  state: LibreOfficeState.found,
  bundlePath: '/Applications/LibreOffice.app',
  version: kLibreOfficeMinimumVersion,
);

/// A panel shell with the LibreOfficeKit module over a memory file system,
/// registered as an application registers a kit module
/// (`DefaultShellApi.registerModule`): detection answers [installation],
/// helpers are [ScriptedOfficeHelper]s, the window's focus is [focusWindow],
/// the path setting is [userPath], *Choose LibreOffice…* picks [picked], and
/// [alternative] is the route the module defers to (none by default).
class ForgeOfficeLokWorkspace {
  ForgeOfficeLokWorkspace({
    this.installation = forgeOfficeFoundLibreOffice,
    this.userPath,
    ForgeOfficeAlternativeRoute? Function(ForgeOfficeLokWorkspace w)?
    alternative,
  }) : fs = TomMemoryFileSystem() {
    shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fs,
      appName: 'Office editor',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    files = TomFileSystemBinaryFiles(fs);
    module = ForgeOfficeLokModule(
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
      openExternal: (uri) async => opened.add(uri),
      windowFocus: _focus.stream,
      alternative: alternative?.call(this),
      tileDecoder: forgeOfficeTestDecoder,
    );
    shell.registerModule(module);
  }

  final TomMemoryFileSystem fs;
  late final TomBinaryFiles files;

  /// The shell (a `ForgeKitApi`).
  late final DefaultShellApi shell;
  late final ForgeOfficeLokModule module;

  final _focus = StreamController<bool>.broadcast();

  /// What detection answers.
  LibreOfficeInstallation installation;

  /// The user's path setting.
  String? userPath;

  /// What *Choose LibreOffice…* picks.
  String? picked;

  /// The paths detection ran with, in order.
  final detections = <String>[];

  /// What the module opened outside the application, in order.
  final opened = <Uri>[];

  /// The launcher of the last detection.
  FakeOfficeHelperLauncher? launcher;

  /// Every scripted helper started, newest last.
  final helpers = <ScriptedOfficeHelper>[];

  /// The window regains the focus.
  void focusWindow() => _focus.add(true);

  /// Adds a file holding [text] at [path].
  Future<Uri> add(String path, [String text = 'doc']) async {
    final uri = fs.uriOf(path);
    await fs.writeText(uri, text);
    return uri;
  }

  /// The file's text on disk.
  Future<String> text(String path) => fs.readText(fs.uriOf(path));

  /// The editor open last on [uri], or null.
  ForgeEditor? editorOf(Uri uri) =>
      shell.state.openEditors.where((e) => e.uri == uri).lastOrNull;

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
    await _focus.close();
    await tester.pump(const Duration(seconds: 1));
  }
}
