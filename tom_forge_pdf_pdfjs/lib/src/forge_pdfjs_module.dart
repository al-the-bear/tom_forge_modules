import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_file_session/io.dart'
    show TomBinaryFileAccess, TomLocalContentServer;
import 'package:tom_file_session/tom_file_session.dart'
    show TomBinaryFiles, TomFileSystemBinaryFiles;
import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_pdf_pdfjs/tom_pdf_pdfjs.dart';

import 'forge_pdfjs_editor.dart';
import 'forge_pdfjs_host.dart';
import 'forge_pdfjs_trail.dart';

/// The pdf.js view as a kit module: it offers [ForgePdfJsEditor] (choice
/// `pdf.pdfjs`, Mozilla's pdf.js in a webview) under *Open With* for `.pdf`
/// files, one editor per file. It is an editor choice, not the default: the
/// PDFium module (`tom_forge_pdf_pdfium`) opens `.pdf` files by default, and
/// this module opens one itself ([openUri]) only when the file-type default
/// for `.pdf` names `pdf.pdfjs`.
///
/// It is written against the kit alone ([ForgeKitApi], no shell, no
/// PDFium). When the window regains focus (by default the application's
/// lifecycle returning to *resumed*; [windowFocusRegained] gives another
/// source) each editor checks its file for outside changes; a closed
/// editor closes its page and content site.
class ForgePdfJsModule extends ForgeKitModule implements ForgeKitApiProvider {
  /// The module. [files], [server] and [authorName] default to the
  /// desktop's (`TomBinaryFileAccess`, the shared content server); tests
  /// give fakes. [openExternal] opens a link of the document outside the
  /// application (the panel shell's `shell.environment.openExternal`);
  /// without it links are not opened. [windowFocusRegained] fires each time
  /// the window regains focus; by default the app lifecycle's resume.
  /// [channelForTesting] and [testBaseUri] run the editor without a webview
  /// or a server.
  ForgePdfJsModule({
    TomBinaryFiles? files,
    TomBinaryFiles Function(TomFileSystem fileSystem)? fileSystemFiles,
    this.server,
    this.authorName,
    this.openExternal,
    this.windowFocusRegained,
    this.channelForTesting,
    this.testBaseUri,
  }) : files = files ?? const TomBinaryFileAccess(),
       fileSystemFiles =
           fileSystemFiles ?? ((fs) => TomFileSystemBinaryFiles(fs));

  /// The pdf.js view's choice id.
  static const pdfJsChoiceId = 'pdf.pdfjs';

  /// The file access for local (`file:`) files.
  final TomBinaryFiles files;

  /// The file access for the files of a file system without local paths.
  final TomBinaryFiles Function(TomFileSystem fileSystem) fileSystemFiles;

  /// The view's content server (default: the process's shared one).
  final TomLocalContentServer? server;

  /// `T` of new annotations (default: the user's login name).
  final String? authorName;

  /// Opens a link outside the application; null: links are not opened.
  final Future<void> Function(Uri uri)? openExternal;

  /// Fires each time the window regains focus; null: the app lifecycle's
  /// resume ([AppLifecycleListener.onResume]).
  final Stream<Object?>? windowFocusRegained;

  /// Makes the editor's channel instead of a webview (tests).
  final TomPdfJsChannel Function()? channelForTesting;

  /// Keeps the editor's controller offline (tests).
  final Uri? testBaseUri;

  ForgeKitApi? _api;
  final _editors = <Uri, ForgePdfJsEditor>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  AppLifecycleListener? _lifecycle;

  @override
  ForgeKitApi? get activeKitApi => _api;

  @override
  String get displayName => 'PDF view (pdf.js)';

  @override
  void activate(ForgeKitApi api) {
    _api = api;
    _subscriptions.add(
      api.state.onEditorsChanged.listen((e) {
        for (final closed in e.closed) {
          _closed(closed);
        }
      }),
    );
    final focus = windowFocusRegained;
    if (focus != null) {
      _subscriptions.add(focus.listen((_) => checkExternalChanges()));
    } else {
      _lifecycle = forgePdfJsLifecycleListener(checkExternalChanges);
    }
    forgePdfJsTrail('activated');
  }

  @override
  void deactivate() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
    _lifecycle?.dispose();
    _lifecycle = null;
    for (final editor in _editors.values.toList()) {
      _closed(editor);
    }
    _api = null;
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
  bool handles(Uri uri) => forgeExtensionOf(uri) == '.pdf';

  /// Where the editor reads and writes [uri]: a `file:` URI by its local
  /// path through [files]; any other file of the application's file system
  /// by its path in that file system through `TomFileSystemBinaryFiles` (its
  /// bytes go to pdf.js through the content site). `null` for a URI outside
  /// the application's file system.
  (String, TomBinaryFiles)? _accessOf(Uri uri) {
    final api = _api;
    if (api == null) return null;
    final fsPath = api.fileSystem.pathOf(uri);
    if (fsPath == null) return null;
    if (uri.isScheme('file')) return (uri.toFilePath(), files);
    final remote = _remoteFiles ??= fileSystemFiles(api.fileSystem);
    return (fsPath, remote);
  }

  TomBinaryFiles? _remoteFiles;

  /// Opens [uri] itself only when the file-type default for `.pdf` names
  /// this module's choice (`pdf.pdfjs`); every other `.pdf` is left to the
  /// default PDF editor.
  @override
  bool openUri(Uri uri) {
    try {
      final api = _api;
      if (api == null || !handles(uri) || _accessOf(uri) == null) {
        return false;
      }
      if (api.getFileTypeDefaults()['.pdf'] != pdfJsChoiceId) return false;
      forgePdfJsTrail('openUri: $pdfJsChoiceId (the file-type default)');
      _open(uri);
      return true;
    } catch (e, s) {
      forgePdfJsReport(e, s, 'opening a PDF');
      return false;
    }
  }

  @override
  List<ForgeKitEditorChoice> editorChoicesFor(Uri uri) {
    if (_api == null || !handles(uri) || _accessOf(uri) == null) {
      return const [];
    }
    return [
      ForgeKitEditorChoice(
        id: pdfJsChoiceId,
        label: 'pdf.js (web, comparison)',
        description: "Mozilla's pdf.js in a webview",
        icon: Icons.picture_as_pdf,
        open: _open,
      ),
    ];
  }

  /// Opens [uri] in the pdf.js editor: the one already open for it, or a
  /// new one, where the application places it.
  void _open(Uri uri) {
    final api = _api;
    if (api == null) return;
    final existing = _editors[uri];
    if (existing != null && api.state.openEditors.contains(existing)) {
      forgePdfJsTrail('$pdfJsChoiceId: existing editor shown');
      unawaited(api.editorHost.showEditor(existing));
      return;
    }
    final access = _accessOf(uri);
    if (access == null) return;
    final (path, binaryFiles) = access;
    if (!identical(binaryFiles, files)) {
      forgePdfJsTrail(
        '$pdfJsChoiceId: no local path, the file system\'s bytes',
      );
    }
    late final ForgePdfJsEditor editor;
    editor = ForgePdfJsEditor(
      uri: uri,
      host: ForgePdfJsHost(
        filePath: path,
        api: api,
        files: binaryFiles,
        openExternal: openExternal,
        authorName: authorName,
      ),
      server: server,
      channelForTesting: channelForTesting?.call(),
      testBaseUri: testBaseUri,
      onShowMain: () => unawaited(api.editorHost.showEditor(editor)),
    );
    _editors[uri] = editor;
    forgePdfJsTrail('$pdfJsChoiceId: opened');
    unawaited(api.editorHost.showEditor(editor));
  }

  /// Every editor checks its file for outside changes: a clean document
  /// reopens, a dirty one shows the conflict banner. Runs when the window
  /// regains focus.
  void checkExternalChanges() {
    for (final editor in _editors.values) {
      try {
        forgePdfJsTrail('checkExternal on focus');
        unawaited(editor.checkExternal());
      } catch (e, s) {
        forgePdfJsReport(e, s, 'checking a PDF for outside changes');
      }
    }
  }

  void _closed(Object editor) {
    final key = _editors.entries
        .where((e) => identical(e.value, editor))
        .map((e) => e.key)
        .firstOrNull;
    if (key == null) return;
    final closed = _editors.remove(key)!;
    try {
      unawaited(closed.close());
    } catch (e, s) {
      forgePdfJsReport(e, s, 'closing a PDF editor');
    }
  }
}
