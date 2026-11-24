import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_office_zetaoffice/tom_forge_office_zetaoffice.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart' show DefaultShellApi;
import 'package:tom_office_zetaoffice/testing.dart';
import 'package:tom_office_zetaoffice/tom_office_zetaoffice.dart';

import '../tom_forge_office_zetaoffice_testing.dart';

/// A panel shell with the ZetaOffice module over a memory file system,
/// registered as an application registers a kit module
/// (`DefaultShellApi.registerModule`): ZetaOffice's files are [zetaFiles]
/// (cached by default), each editor's page is a [ScriptedZetaOfficePage]
/// over a [FakeZetaOfficeServing], the window's focus is [focusWindow].
/// [registerFirst] registers modules before this one (the LibreOfficeKit
/// module, as Forge composes them).
class ForgeZetaOfficeWorkspace {
  ForgeZetaOfficeWorkspace({
    TomZetaOfficeFiles? zetaFiles,
    bool opensByDefault = false,
    void Function(ForgeZetaOfficeWorkspace w)? registerFirst,
  }) : fs = TomMemoryFileSystem(),
       zetaFiles =
           zetaFiles ??
           FakeZetaOfficeFiles(state: TomZetaOfficeCacheState.ready) {
    shell = DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: fs,
      appName: 'Office editor',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    files = TomFileSystemBinaryFiles(fs);
    module = ForgeZetaOfficeModule(
      files: files,
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
      openExternal: (uri) async => opened.add(uri),
      windowFocus: focus.stream,
      opensByDefault: opensByDefault,
    );
    registerFirst?.call(this);
    shell.registerModule(module);
  }

  final TomMemoryFileSystem fs;
  late final TomBinaryFiles files;

  /// The shell (a `ForgeKitApi`).
  late final DefaultShellApi shell;
  late final ForgeZetaOfficeModule module;
  final TomZetaOfficeFiles zetaFiles;

  /// The window's focus (true: regained); also for modules registered
  /// first.
  final focus = StreamController<bool>.broadcast();

  /// What the module opened outside the application, in order.
  final opened = <Uri>[];

  /// Every ZetaOffice server and page, newest last.
  final servings = <FakeZetaOfficeServing>[];
  final pages = <ScriptedZetaOfficePage>[];

  /// The window regains the focus.
  void focusWindow() => focus.add(true);

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
    await focus.close();
    await tester.pump(const Duration(seconds: 1));
  }
}
