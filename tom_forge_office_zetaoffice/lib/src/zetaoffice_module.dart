import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:tom_file_session/io.dart' show TomBinaryFileAccess;
import 'package:tom_file_session/tom_file_session.dart' show TomBinaryFiles;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_office_zetaoffice/tom_office_zetaoffice.dart';

import 'forge_zetaoffice_editor.dart';
import 'forge_zetaoffice_host.dart';
import 'forge_zetaoffice_kind.dart';
import 'forge_zetaoffice_trail.dart';

/// The ZetaOffice office editor as a kit module (`part-office-webview`): it
/// offers [ForgeZetaOfficeEditor] (choice `office.zetaoffice`, ZetaOffice in
/// a webview, the comparison route) under *Open With* for the office files
/// with a local path — `.docx .xlsx .pptx .odt .ods .odp .doc .xls .ppt .rtf
/// .csv` — one editor per file, and opens an office file itself only when
/// the file-type default names it (or, with [opensByDefault], when no default
/// is set). In Forge the LibreOfficeKit adapter is the default and leaves a
/// file to this module when its default is `office.zetaoffice`; its
/// missing-LibreOffice panel offers this module's [open], with [available]
/// and [checkAvailable] (the application wires the two modules together, so
/// neither depends on the other).
///
/// When the window regains focus each editor checks its file for outside
/// changes; a closed editor closes its page and content site and frees the
/// ZetaOffice slot. Written against the kit (R9): no shell.
class ForgeZetaOfficeModule extends ForgeKitModule {
  /// The module. Every parameter defaults to the desktop's: local files
  /// through `TomBinaryFileAccess`, ZetaOffice's cache and local server, the
  /// application's lifecycle for [windowFocus]. Tests give fakes.
  ForgeZetaOfficeModule({
    TomBinaryFiles? files,
    TomZetaOfficeFiles? zetaFiles,
    TomZetaOfficeServing Function(TomBinaryFiles files)? zetaServing,
    this.zetaChannelForTesting,
    this.openExternal,
    this.windowFocus,
    this.opensByDefault = false,
  }) : files = files ?? const TomBinaryFileAccess(),
       zetaFiles = zetaFiles ?? TomZetaOfficeCache(),
       zetaServing =
           zetaServing ?? ((files) => TomZetaOfficeServer(files: files));

  /// ZetaOffice's choice id.
  static const choiceId = 'office.zetaoffice';

  /// The label of the button another route's panel offers this one with.
  static const openLabel = 'Open with ZetaOffice';

  /// The file access for local files.
  final TomBinaryFiles files;

  /// ZetaOffice's cached files.
  final TomZetaOfficeFiles zetaFiles;

  /// A ZetaOffice tab's local server, over the file's access.
  final TomZetaOfficeServing Function(TomBinaryFiles files) zetaServing;

  /// Makes an editor's channel instead of a webview (tests).
  final TomZetaOfficeChannel Function()? zetaChannelForTesting;

  /// Opens a link outside the application (the panel shell:
  /// `shell.environment.openExternal`); null: links are not opened.
  final Future<void> Function(Uri uri)? openExternal;

  /// The window's focus (true: regained); null: the application's
  /// lifecycle (`AppLifecycleListener`, resumed).
  final Stream<bool>? windowFocus;

  /// Whether [openUri] opens an office file when no file-type default names
  /// an editor for it (an application with ZetaOffice as its only office
  /// route). Default false: only when the default names `office.zetaoffice`.
  final bool opensByDefault;

  ForgeKitApi? _api;
  final _editors = <Uri, ForgeZetaOfficeEditor>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  AppLifecycleListener? _lifecycle;
  final _available = ValueNotifier(false);
  Future<void>? _availabilityCheck;

  /// Whether ZetaOffice can open without LibreOffice: its files are cached,
  /// or the CDN answers (the download prompt can then fetch them). False
  /// until [checkAvailable] found out.
  ValueListenable<bool> get available => _available;

  @override
  String get displayName => 'Office editor (ZetaOffice)';

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
    final focus = windowFocus;
    if (focus != null) {
      _subscriptions.add(
        focus.listen((focused) {
          if (focused) _checkExternal();
        }),
      );
    } else {
      _lifecycle = _lifecycleListener();
    }
    forgeZetaOfficeTrail('activated');
  }

  /// The application's lifecycle (resumed: the window regained the focus),
  /// or null without a widgets binding (a plain unit test).
  AppLifecycleListener? _lifecycleListener() {
    try {
      return AppLifecycleListener(onResume: _checkExternal);
    } on FlutterError catch (e) {
      forgeZetaOfficeTrail('no lifecycle to follow: $e');
      return null;
    }
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

  /// Finds out whether ZetaOffice is [available]: its files are cached, or
  /// the CDN answers within ten seconds.
  Future<void> checkAvailable() => _availabilityCheck ??= () async {
    try {
      final status = await zetaFiles.status();
      if (status.state == TomZetaOfficeCacheState.ready) {
        _available.value = true;
        return;
      }
      await zetaFiles.downloadSize().timeout(const Duration(seconds: 10));
      _available.value = true;
    } catch (e) {
      forgeZetaOfficeTrail('ZetaOffice not available offline: $e');
      _available.value = false;
    } finally {
      _availabilityCheck = null;
    }
  }();

  // -------------------------------------------------------------- opening

  /// Whether [uri] is an office file (any case) this module may open itself:
  /// not `.csv`, which stays text and is only offered under *Open With*.
  bool handles(Uri uri) {
    final ext = ForgeZetaOfficeKind.extensionOf(uri);
    return ForgeZetaOfficeKind.extensions.containsKey(ext) &&
        !ForgeZetaOfficeKind.openWithOnly.contains(ext);
  }

  /// Whether this module offers its editor for [uri] under *Open With*.
  bool offers(Uri uri) => ForgeZetaOfficeKind.of(uri) != null;

  /// The local path of [uri]: the content server reads the file there.
  String? _localPath(Uri uri) {
    final api = _api;
    if (api == null || !uri.isScheme('file')) return null;
    if (api.fileSystem.pathOf(uri) == null) return null;
    return uri.toFilePath();
  }

  @override
  bool openUri(Uri uri) {
    try {
      final api = _api;
      if (api == null || !handles(uri) || _localPath(uri) == null) {
        return false;
      }
      final existing = _editors[uri];
      if (existing != null && api.state.openEditors.contains(existing)) {
        forgeZetaOfficeTrail('openUri: existing editor shown');
        unawaited(api.editorHost.showEditor(existing));
        return true;
      }
      final preferred = api.editorPicker.defaultIdFor(ForgeContentItem(uri)).$1;
      if (preferred != choiceId && !(opensByDefault && preferred == null)) {
        return false;
      }
      forgeZetaOfficeTrail(
        'openUri: $choiceId (default ${preferred ?? 'none'})',
      );
      open(uri);
      return true;
    } catch (e, s) {
      forgeZetaOfficeReport(e, s, 'opening an office file');
      return false;
    }
  }

  @override
  List<ForgeKitEditorChoice> editorChoicesFor(Uri uri) {
    if (_api == null || !offers(uri) || _localPath(uri) == null) {
      return const [];
    }
    return [
      ForgeKitEditorChoice(
        id: choiceId,
        label: 'ZetaOffice (web, comparison)',
        description: 'LibreOffice compiled to WebAssembly, in a webview',
        icon: Icons.public,
        open: open,
      ),
    ];
  }

  /// Opens [uri] in its ZetaOffice editor: the one already open for it, or a
  /// new one.
  void open(Uri uri) {
    try {
      final api = _api;
      final path = _localPath(uri);
      final kind = ForgeZetaOfficeKind.of(uri);
      if (api == null || path == null || kind == null) return;
      final existing = _editors[uri];
      if (existing != null && api.state.openEditors.contains(existing)) {
        forgeZetaOfficeTrail('$choiceId: existing editor shown');
        unawaited(api.editorHost.showEditor(existing));
        return;
      }
      final host = ForgeZetaOfficeHost(
        filePath: path,
        api: api,
        files: files,
        openExternal: openExternal,
      );
      late final ForgeZetaOfficeEditor editor;
      editor = ForgeZetaOfficeEditor(
        uri: uri,
        host: host,
        kind: kind,
        files: zetaFiles,
        serving: zetaServing(files),
        channelForTesting: zetaChannelForTesting?.call(),
        onShowMain: () => unawaited(api.editorHost.showEditor(editor)),
      );
      _editors[uri] = editor;
      forgeZetaOfficeTrail('$choiceId: opened');
      unawaited(api.editorHost.showEditor(editor));
    } catch (e, s) {
      forgeZetaOfficeReport(e, s, 'opening $choiceId');
    }
  }

  void _checkExternal() {
    for (final editor in _editors.values.toList()) {
      try {
        forgeZetaOfficeTrail('checkExternal on focus');
        unawaited(editor.checkExternal());
      } catch (e, s) {
        forgeZetaOfficeReport(
          e,
          s,
          'checking an office file for outside changes',
        );
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
      forgeZetaOfficeReport(e, s, 'closing an office editor');
    }
  }
}
