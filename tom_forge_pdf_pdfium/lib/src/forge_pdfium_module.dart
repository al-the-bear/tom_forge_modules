import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_file_session/io.dart' show TomBinaryFileAccess;
import 'package:tom_file_session/tom_file_session.dart'
    show TomBinaryFiles, TomFileSystemBinaryFiles;
import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_pdf_editor/tom_pdf_editor.dart';
import 'package:tom_pdf_pdfium/tom_pdf_pdfium.dart';

import 'forge_pdf_editor.dart';
import 'forge_pdf_host.dart';
import 'forge_pdf_trail.dart';

/// The PDFium editor as a kit module: it opens `.pdf` files itself, before
/// the application reads them as text, in the PDFium editor ([ForgePdfEditor],
/// choice `pdf.pdfium`, the default for `.pdf`), and offers it under *Open
/// With*, one editor per file.
///
/// It is written against the kit alone ([ForgeKitApi], no shell, no
/// webview): an application that takes only this module gets PDFs without
/// pdf.js. Other PDF engines are modules of their own (the pdf.js view:
/// `tom_forge_pdf_pdfjs`); with one of them registered:
///
/// - when the file-type default for `.pdf` names another module's choice,
///   [openUri] opens the file in that choice (so the default works whatever
///   order the modules are registered in);
/// - an editor of a PDF engine module (one that offers a `pdf.*` choice for
///   the file) already open on the file is shown instead of opening a
///   second one.
///
/// When the window regains focus (by default the application's lifecycle
/// returning to *resumed*; [windowFocusRegained] gives another source) each
/// editor checks its file for outside changes; a closed editor gives its
/// document and its share of the engine up.
class ForgePdfiumModule extends ForgeKitModule implements ForgeKitApiProvider {
  /// The module. [files], [locatePdfium], [startEngine], [decoder] and
  /// [authorName] default to the desktop's (the binaries layer's PDFium,
  /// `TomBinaryFileAccess`); tests give fakes. [openExternal] opens a link
  /// of the document outside the application (the panel shell's
  /// `shell.environment.openExternal`); without it links are not opened.
  /// [windowFocusRegained] fires each time the window regains focus (the
  /// panel shell's `systemState.onWindowFocusChanged` where focused); by
  /// default the app lifecycle's resume.
  ForgePdfiumModule({
    TomBinaryFiles? files,
    TomPdfiumLibrary Function()? locatePdfium,
    Future<TomPdfEngine> Function(TomPdfiumLibrary library)? startEngine,
    this.decoder = decodeBgra,
    TomBinaryFiles Function(TomFileSystem fileSystem)? fileSystemFiles,
    this.authorName,
    this.openExternal,
    this.windowFocusRegained,
  }) : files = files ?? const TomBinaryFileAccess(),
       fileSystemFiles =
           fileSystemFiles ?? ((fs) => TomFileSystemBinaryFiles(fs)),
       locatePdfium = locatePdfium ?? (() => const TomPdfiumLocator().locate()),
       startEngine =
           startEngine ?? ((library) => PdfiumEngine.acquire(library.path!));

  /// The PDFium editor's choice id (the default for `.pdf`).
  static const pdfiumChoiceId = 'pdf.pdfium';

  /// The prefix every PDF engine module's choice id has (`pdf.pdfium`,
  /// `pdf.pdfjs`): an editor of a module offering one for a file is a PDF
  /// editor of that file.
  static const pdfChoicePrefix = 'pdf.';

  /// The file access for local (`file:`) files.
  final TomBinaryFiles files;

  /// The file access for the files of a file system without local paths.
  final TomBinaryFiles Function(TomFileSystem fileSystem) fileSystemFiles;

  /// Where PDFium is.
  final TomPdfiumLibrary Function() locatePdfium;

  /// Starts (or shares) the PDFium engine.
  final Future<TomPdfEngine> Function(TomPdfiumLibrary library) startEngine;

  /// Decodes the editor's rendered pixels.
  final PdfImageDecoder decoder;

  /// `T` of new annotations (default: the user's login name).
  final String? authorName;

  /// Opens a link outside the application; null: links are not opened.
  final Future<void> Function(Uri uri)? openExternal;

  /// Fires each time the window regains focus; null: the app lifecycle's
  /// resume ([AppLifecycleListener.onResume]).
  final Stream<Object?>? windowFocusRegained;

  ForgeKitApi? _api;
  final _editors = <Uri, ForgePdfEditor>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  AppLifecycleListener? _lifecycle;

  @override
  ForgeKitApi? get activeKitApi => _api;

  @override
  String get displayName => 'PDF editor (PDFium)';

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
      _lifecycle = forgePdfiumLifecycleListener(checkExternalChanges);
    }
    forgePdfiumTrail('activated');
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
  /// (a remote or virtual one) by its path in that file system through
  /// `TomFileSystemBinaryFiles` — its bytes go to PDFium, the saved bytes
  /// back through the file system. `null` for a URI outside the
  /// application's file system.
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

  /// The other modules registered with the application, when it tells them.
  Iterable<ForgeKitModule> _otherModules(ForgeKitApi api) => [
    for (final module
        in forgeKitModulesOf(api)?.allKitModules ?? const <ForgeKitModule>[])
      if (!identical(module, this)) module,
  ];

  /// Whether [module] is a PDF engine module for [uri] (it offers a
  /// [pdfChoicePrefix] choice for it).
  bool _isPdfModule(ForgeKitModule module, Uri uri) =>
      module.editorChoicesFor(uri).any((c) => c.id.startsWith(pdfChoicePrefix));

  @override
  bool openUri(Uri uri) {
    try {
      final api = _api;
      if (api == null || !handles(uri)) return false;
      if (_accessOf(uri) == null) {
        forgePdfiumTrail('openUri declined: not in the file system');
        return false;
      }
      final others = _otherModules(api).toList();
      // A PDF editor already open on the file is shown.
      for (final open in api.state.openEditors) {
        if (open.uri != uri) continue;
        final ours = _editors.containsValue(open);
        if (ours ||
            others.any(
              (m) => m.editors.contains(open) && _isPdfModule(m, uri),
            )) {
          forgePdfiumTrail('openUri: existing editor shown (ours: $ours)');
          unawaited(api.editorHost.showEditor(open));
          return true;
        }
      }
      // The file-type default naming another module's choice opens there.
      final preferred = api.getFileTypeDefaults()['.pdf'];
      if (preferred != null && preferred != pdfiumChoiceId) {
        for (final module in others) {
          for (final choice in module.editorChoicesFor(uri)) {
            if (choice.id != preferred) continue;
            forgePdfiumTrail('openUri: the default $preferred');
            choice.open(uri);
            return true;
          }
        }
      }
      forgePdfiumTrail(
        'openUri: $pdfiumChoiceId (default '
        '${preferred ?? 'none'})',
      );
      _open(uri);
      return true;
    } catch (e, s) {
      forgePdfiumReport(e, s, 'opening a PDF');
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
        id: pdfiumChoiceId,
        label: 'PDF editor (PDFium)',
        description: 'Native rendering, annotations and forms',
        icon: Icons.picture_as_pdf_outlined,
        open: _open,
      ),
    ];
  }

  /// Opens [uri] in the PDFium editor: the one already open for it, or a
  /// new one, where the application places it.
  void _open(Uri uri) {
    final api = _api;
    if (api == null) return;
    final existing = _editors[uri];
    if (existing != null && api.state.openEditors.contains(existing)) {
      forgePdfiumTrail('$pdfiumChoiceId: existing editor shown');
      unawaited(api.editorHost.showEditor(existing));
      return;
    }
    final access = _accessOf(uri);
    if (access == null) return;
    final (path, binaryFiles) = access;
    if (!identical(binaryFiles, files)) {
      forgePdfiumTrail(
        '$pdfiumChoiceId: no local path, the file system\'s bytes',
      );
    }
    final editor = ForgePdfEditor(
      uri: uri,
      host: ForgePdfHost(
        filePath: path,
        api: api,
        files: binaryFiles,
        locatePdfium: locatePdfium,
        startEngine: startEngine,
        openExternal: openExternal,
        authorName: authorName,
      ),
      decoder: decoder,
    );
    _editors[uri] = editor;
    forgePdfiumTrail('$pdfiumChoiceId: opened');
    unawaited(api.editorHost.showEditor(editor));
  }

  /// Every editor checks its file for outside changes: a clean document
  /// reopens, a dirty one shows the conflict banner. Runs when the window
  /// regains focus.
  void checkExternalChanges() {
    for (final editor in _editors.values) {
      try {
        forgePdfiumTrail('checkExternal on focus');
        unawaited(editor.checkExternal());
      } catch (e, s) {
        forgePdfiumReport(e, s, 'checking a PDF for outside changes');
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
      forgePdfiumReport(e, s, 'closing a PDF editor');
    }
  }
}
