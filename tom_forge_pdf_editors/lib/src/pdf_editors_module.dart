import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_file_session/io.dart'
    show TomBinaryFileAccess, TomLocalContentServer;
import 'package:tom_file_session/tom_file_session.dart'
    show TomBinaryFiles, TomFileSystemBinaryFiles;
import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show DefaultLayoutController, ForgeEditorChoice, ForgeModule, ForgeShellApi;
import 'package:tom_pdf_editor/io.dart';
import 'package:tom_pdf_editor/pdfium.dart';
import 'package:tom_pdf_editor/pdfjs.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';

import 'forge_pdf_editor.dart';
import 'forge_pdf_host.dart';
import 'forge_pdf_trail.dart';
import 'forge_pdfjs_editor.dart';

/// The PDF editors as one module: it opens `.pdf` files itself, before the
/// shell reads them as text, in the editor the file-type default names
/// (`pdf.pdfium`, the PDFium editor, when none does), shows an editor
/// already open on the file instead of opening a second, and offers both
/// editors under *Open With* — one editor per (choice, file), so a file may
/// be open in both routes in two tabs. When the window regains focus each
/// editor checks its file for outside changes; a closed editor gives its
/// document and engine up.
class ForgePdfEditorsModule extends ForgeModule {
  /// The module. [files], [locatePdfium], [startEngine], [decoder],
  /// [server] and [authorName] default to the desktop's (the binaries
  /// layer's PDFium, `TomBinaryFileAccess`, the shared content server);
  /// tests give fakes. [pdfJsChannelForTesting] and [pdfJsTestBaseUri] run
  /// the pdf.js editor without a webview or a server.
  ForgePdfEditorsModule({
    TomBinaryFiles? files,
    TomPdfiumLibrary Function()? locatePdfium,
    Future<TomPdfEngine> Function(TomPdfiumLibrary library)? startEngine,
    this.decoder = decodeBgra,
    TomBinaryFiles Function(TomFileSystem fileSystem)? fileSystemFiles,
    this.server,
    this.authorName,
    this.pdfJsChannelForTesting,
    this.pdfJsTestBaseUri,
  }) : files = files ?? const TomBinaryFileAccess(),
       fileSystemFiles =
           fileSystemFiles ?? ((fs) => TomFileSystemBinaryFiles(fs)),
       locatePdfium = locatePdfium ?? (() => const TomPdfiumLocator().locate()),
       startEngine =
           startEngine ?? ((library) => PdfiumEngine.acquire(library.path!));

  /// The PDFium editor's choice id (the default for `.pdf`).
  static const pdfiumChoiceId = 'pdf.pdfium';

  /// The pdf.js view's choice id.
  static const pdfJsChoiceId = 'pdf.pdfjs';

  /// The file access for local (`file:`) files.
  final TomBinaryFiles files;

  /// The file access for the files of a file system without local paths.
  final TomBinaryFiles Function(TomFileSystem fileSystem) fileSystemFiles;

  /// Where PDFium is.
  final TomPdfiumLibrary Function() locatePdfium;

  /// Starts (or shares) the PDFium engine.
  final Future<TomPdfEngine> Function(TomPdfiumLibrary library) startEngine;

  /// Decodes the PDFium editor's rendered pixels.
  final PdfImageDecoder decoder;

  /// The pdf.js view's content server.
  final TomLocalContentServer? server;

  /// `T` of new annotations (default: the user's login name).
  final String? authorName;

  /// Makes the pdf.js editor's channel instead of a webview (tests).
  final TomPdfJsChannel Function()? pdfJsChannelForTesting;

  /// Keeps the pdf.js editor's controller offline (tests).
  final Uri? pdfJsTestBaseUri;

  ForgeShellApi? _shell;
  final _editors = <(String, Uri), ForgeEditor>{};
  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  String get displayName => 'PDF editors';

  @override
  void activate(ForgeShellApi shell) {
    _shell = shell;
    final state = shell.systemState;
    _subscriptions
      ..add(
        state.onWindowFocusChanged.listen((e) {
          if (e.focused) _checkExternal();
        }),
      )
      ..add(
        state.onEditorsChanged.listen((e) {
          for (final closed in e.closed) {
            _closed(closed);
          }
        }),
      );
    forgePdfTrail('activated');
  }

  @override
  void deactivate() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    for (final editor in _editors.values.toList()) {
      _closed(editor);
    }
    _shell = null;
  }

  @override
  List<ForgeEditor> get editors => List.unmodifiable(_editors.values);

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  /// Whether [uri] is a PDF (`.pdf`, any case) this module opens.
  bool handles(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return name.toLowerCase().endsWith('.pdf');
  }

  /// Where the editors read and write [uri]: a `file:` URI by its local
  /// path through [files]; any other file of the shell's file system (a
  /// remote or virtual one) by its path in that file system through
  /// `TomFileSystemBinaryFiles` — its bytes go to PDFium and pdf.js, the
  /// saved bytes back through the file system. `null` for a URI outside the
  /// shell's file system.
  (String, TomBinaryFiles)? _accessOf(Uri uri) {
    final shell = _shell;
    if (shell == null) return null;
    final fsPath = shell.fileSystem.pathOf(uri);
    if (fsPath == null) return null;
    if (uri.isScheme('file')) return (uri.toFilePath(), files);
    final remote = _remoteFiles ??= fileSystemFiles(shell.fileSystem);
    return (fsPath, remote);
  }

  TomBinaryFiles? _remoteFiles;

  String? _pathOf(Uri uri) => _accessOf(uri)?.$1;

  @override
  bool openUri(Uri uri, {int? middlePanelIndex}) {
    try {
      final shell = _shell;
      if (shell == null || !handles(uri)) return false;
      if (_pathOf(uri) == null) {
        forgePdfTrail('openUri declined: not in the shell\'s file system');
        return false;
      }
      // An editor of this module already open on the file is shown.
      for (final open in shell.systemState.openEditors) {
        if (open.uri == uri && _editors.containsValue(open)) {
          forgePdfTrail('openUri: existing editor shown');
          shell.layout.openEditor(
            open,
            uri,
            middlePanelIndex: middlePanelIndex,
          );
          return true;
        }
      }
      final layout = shell.layout;
      final preferred = layout is DefaultLayoutController
          ? layout.getFileTypeDefaultEditor('pdf')
          : null;
      final id = preferred == pdfJsChoiceId ? pdfJsChoiceId : pdfiumChoiceId;
      forgePdfTrail('openUri: $id (default ${preferred ?? 'none'})');
      _open(id, uri, middlePanelIndex: middlePanelIndex);
      return true;
    } catch (e, s) {
      forgePdfReport(e, s, 'opening a PDF');
      return false;
    }
  }

  @override
  List<ForgeEditorChoice> editorChoicesFor(Uri uri) {
    if (_shell == null || !handles(uri) || _pathOf(uri) == null) {
      return const [];
    }
    return [
      ForgeEditorChoice(
        id: pdfiumChoiceId,
        label: 'PDF editor (PDFium)',
        description: 'Native rendering, annotations and forms',
        icon: Icons.picture_as_pdf_outlined,
        open: (uri, {middlePanelIndex}) =>
            _open(pdfiumChoiceId, uri, middlePanelIndex: middlePanelIndex),
      ),
      ForgeEditorChoice(
        id: pdfJsChoiceId,
        label: 'pdf.js (web, comparison)',
        description: "Mozilla's pdf.js in a webview",
        icon: Icons.picture_as_pdf,
        open: (uri, {middlePanelIndex}) =>
            _open(pdfJsChoiceId, uri, middlePanelIndex: middlePanelIndex),
      ),
    ];
  }

  /// Opens [uri] in the editor of choice [id]: the one already open for it,
  /// or a new one.
  void _open(String id, Uri uri, {int? middlePanelIndex}) {
    final shell = _shell;
    if (shell == null) return;
    final existing = _editors[(id, uri)];
    if (existing != null && shell.systemState.openEditors.contains(existing)) {
      forgePdfTrail('$id: existing editor shown');
      shell.layout.openEditor(
        existing,
        uri,
        middlePanelIndex: middlePanelIndex,
      );
      return;
    }
    final (path, access) = _accessOf(uri)!;
    if (!identical(access, files)) {
      forgePdfTrail('$id: no local path, the file system\'s bytes');
    }
    final host = ForgePdfHost(
      filePath: path,
      shell: shell,
      files: access,
      locatePdfium: locatePdfium,
      startEngine: startEngine,
      authorName: authorName,
    );
    late final ForgeEditor editor;
    if (id == pdfJsChoiceId) {
      editor = ForgePdfJsEditor(
        uri: uri,
        host: host,
        server: server,
        channelForTesting: pdfJsChannelForTesting?.call(),
        testBaseUri: pdfJsTestBaseUri,
        onShowMain: () => shell.layout.openEditor(editor, uri),
      );
    } else {
      editor = ForgePdfEditor(uri: uri, host: host, decoder: decoder);
    }
    _editors[(id, uri)] = editor;
    forgePdfTrail('$id: opened');
    shell.layout.openEditor(editor, uri, middlePanelIndex: middlePanelIndex);
  }

  void _checkExternal() {
    for (final editor in _editors.values) {
      try {
        forgePdfTrail('checkExternal on focus');
        switch (editor) {
          case ForgePdfEditor():
            unawaited(editor.checkExternal());
          case ForgePdfJsEditor():
            unawaited(editor.checkExternal());
        }
      } catch (e, s) {
        forgePdfReport(e, s, 'checking a PDF for outside changes');
      }
    }
  }

  void _closed(Object editor) {
    final key = _editors.entries
        .where((e) => identical(e.value, editor))
        .map((e) => e.key)
        .firstOrNull;
    if (key == null) return;
    _editors.remove(key);
    try {
      switch (editor) {
        case ForgePdfEditor():
          unawaited(editor.close());
        case ForgePdfJsEditor():
          unawaited(editor.close());
      }
    } catch (e, s) {
      forgePdfReport(e, s, 'closing a PDF editor');
    }
  }
}
