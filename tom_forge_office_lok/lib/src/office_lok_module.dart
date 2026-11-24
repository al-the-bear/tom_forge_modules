import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:tom_file_session/tom_file_session.dart' show TomBinaryFiles;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_office_editor/io.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

import 'forge_office_editor.dart';
import 'forge_office_host.dart';
import 'forge_office_kind.dart';
import 'forge_office_trail.dart';
import 'libreoffice_tool.dart';

/// Another office route the LibreOfficeKit module defers to, as the
/// application wires it (Forge: the ZetaOffice adapter's module): the
/// missing-LibreOffice panel offers it, [ForgeOfficeLokModule.openUri]
/// leaves a file to it when the file-type default names [choiceId], and an
/// editor of it already open on a file is shown instead of a new one.
///
/// Every member is a kit or Flutter type, so neither adapter depends on the
/// other: an application that takes the LibreOfficeKit adapter alone gives
/// none, and its office files always open in LibreOfficeKit.
class ForgeOfficeAlternativeRoute {
  /// The route. [open] opens a file in it; [editors] answers its open
  /// editors; [available] says whether the panel offers it (null: always);
  /// [check] finds that out, run when no usable LibreOffice is found.
  const ForgeOfficeAlternativeRoute({
    required this.choiceId,
    required this.label,
    required this.open,
    this.icon = Icons.public,
    this.editors,
    this.available,
    this.check,
  });

  /// The route's choice id (`office.zetaoffice`).
  final String choiceId;

  /// The panel's button label (`Open with ZetaOffice`).
  final String label;

  /// The panel's button icon.
  final IconData icon;

  /// Opens a file in the route's editor.
  final void Function(Uri uri) open;

  /// The route's open editors (one already open on a file is shown).
  final List<ForgeEditor> Function()? editors;

  /// Whether the panel offers the route; null: always.
  final ValueListenable<bool>? available;

  /// Finds out whether the route is available.
  final Future<void> Function()? check;
}

/// The LibreOfficeKit office editor as a kit module (`part-forge-
/// integration`): it opens the office files itself, before the application
/// reads them as text — `.docx .xlsx .pptx .odt .ods .odp` and the older
/// `.doc .xls .ppt .rtf` (DPOE-2); `.csv` only under *Open With*, it stays
/// text by default — in [ForgeOfficeEditor] (choice `office.lok`, the
/// default), shows an editor already open on the file instead of opening a
/// second, and offers its editor under *Open With*.
///
/// It detects LibreOffice at activation with the user's path setting
/// (`forge.tools.libreoffice.path`) and starts `tom_office_host` from the
/// binaries layer for it. Without a usable LibreOffice an office file still
/// opens a tab, showing detection's state panel and the [alternative] route
/// when one is wired; `office.lok` then leaves *Open With*. LibreOffice's
/// row in *External Tools* is the module's extra
/// ([ForgeExternalToolsExtra] with [libreOfficeTool]). When the window
/// regains focus each editor checks its file for outside changes; a closed
/// editor ends its helper.
///
/// Written against the kit (R9): it runs in the panel shell and in any other
/// application of the kit. What the kit has no port for, the application
/// gives: [openExternal], [filePickers], [preferences], [windowFocus].
class ForgeOfficeLokModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  /// The module. Every parameter defaults to the desktop's: local files
  /// through `TomBinaryFileAccess`, `TomLibreOfficeDetector` with the path
  /// setting from [preferences] (else the application's state store),
  /// `TomOfficeProcessLauncher` with `tom_office_host` from
  /// `$TOM_BINARY_PATH`, [filePickers]' folder picker for *Choose
  /// LibreOffice…*, the application's lifecycle for [windowFocus]. Tests give
  /// fakes.
  ForgeOfficeLokModule({
    TomBinaryFiles? files,
    Future<LibreOfficeInstallation> Function(String userPath)? detect,
    FutureOr<String?> Function()? libreOfficePath,
    Future<void> Function(String path)? setLibreOfficePath,
    TomOfficeHelperLauncher Function(LibreOfficeInstallation installation)?
    launcherFor,
    Future<String?> Function()? pickLibreOffice,
    this.pickImage,
    Future<void> Function()? cleanUpHelpers,
    this.preferences,
    this.openExternal,
    this.filePickers,
    this.windowFocus,
    this.alternative,
    ForgeLibreOfficeTool? libreOfficeTool,
    this.tileDecoder,
  }) : files = files ?? const TomBinaryFileAccess(),
       detect =
           detect ??
           ((userPath) => TomLibreOfficeDetector(userPath: userPath).detect()),
       _libreOfficePath = libreOfficePath,
       _setLibreOfficePath = setLibreOfficePath,
       launcherFor = launcherFor ?? _processLauncher,
       _pickLibreOffice = pickLibreOffice,
       cleanUpHelpers = cleanUpHelpers ?? _cleanUpHelpers,
       libreOfficeTool = libreOfficeTool ?? ForgeLibreOfficeTool();

  /// The LibreOfficeKit editor's choice id (the default).
  static const lokChoiceId = 'office.lok';

  /// The file access for local files.
  final TomBinaryFiles files;

  /// Detects LibreOffice for a user path (empty: search).
  final Future<LibreOfficeInstallation> Function(String userPath) detect;

  final FutureOr<String?> Function()? _libreOfficePath;
  final Future<void> Function(String path)? _setLibreOfficePath;

  /// The helper launcher for a detection result.
  final TomOfficeHelperLauncher Function(LibreOfficeInstallation installation)
  launcherFor;

  final Future<String?> Function()? _pickLibreOffice;

  /// *Insert image*'s picker (default: [filePickers]' file picker).
  final Future<String?> Function()? pickImage;

  /// Removes what dead helpers left (profiles, lock and temporary files),
  /// once at activation.
  final Future<void> Function() cleanUpHelpers;

  /// The preferences the path setting `forge.tools.libreoffice.path` is
  /// read from and written to (the panel shell: `ForgePreferencesService.
  /// instance`, which its External Tools section edits). Null: the key in the
  /// application's state store (`ForgeKitApi.stateStore`).
  final ForgeKitPreferences? preferences;

  /// Opens a link or a quarantined LibreOffice outside the application (the
  /// panel shell: `shell.environment.openExternal`); null: nothing opens.
  final Future<void> Function(Uri uri)? openExternal;

  /// The application's file pickers, for *Choose LibreOffice…* and *Insert
  /// image* (the panel shell: `ForgeShellComponents.of(shell).pickers`);
  /// null: nothing is picked.
  final ForgeFilePickers Function()? filePickers;

  /// The window's focus (true: regained); null: the application's
  /// lifecycle (`AppLifecycleListener`, resumed).
  final Stream<bool>? windowFocus;

  /// The route the missing-LibreOffice panel offers and [openUri] defers to
  /// when the file-type default names it; null: none.
  final ForgeOfficeAlternativeRoute? alternative;

  /// LibreOffice's row in *External Tools*.
  final ForgeLibreOfficeTool libreOfficeTool;

  /// Decodes the LibreOfficeKit editor's tiles (default:
  /// `decodeImageFromPixels`; tests give one that needs no real time).
  final TomOfficeImageDecoder? tileDecoder;

  ForgeKitApi? _api;
  final _editors = <Uri, ForgeOfficeEditor>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  AppLifecycleListener? _lifecycle;
  LibreOfficeInstallation? _installation;
  TomOfficeHelperLauncher? _launcher;
  Future<void> _detection = Future<void>.value();

  /// The last detection result (null before the first one ended).
  LibreOfficeInstallation? get installation => _installation;

  /// Completes when the running detection has ended.
  Future<void> get detection => _detection;

  @override
  String get displayName => 'Office editor (LibreOfficeKit)';

  /// LibreOffice's row in *External Tools*.
  @override
  List<ForgeModuleExtra> get ownExtras => [
    ForgeExternalToolsExtra([libreOfficeTool]),
  ];

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
    unawaited(
      cleanUpHelpers().catchError(
        (Object e, StackTrace s) =>
            forgeOfficeReport(e, s, 'cleaning up after dead helpers'),
      ),
    );
    _detection = _detect();
    forgeOfficeTrail('activated');
  }

  /// The application's lifecycle (resumed: the window regained the focus),
  /// or null without a widgets binding (a plain unit test).
  AppLifecycleListener? _lifecycleListener() {
    try {
      return AppLifecycleListener(onResume: _checkExternal);
    } on FlutterError catch (e) {
      forgeOfficeTrail('no lifecycle to follow: $e');
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

  // ---------------------------------------------------------- path setting

  /// The user's LibreOffice path setting (null: search); answered at once
  /// unless it is read from the state store.
  FutureOr<String?> libreOfficePath() {
    final given = _libreOfficePath;
    if (given != null) return given();
    final prefs = preferences;
    if (prefs != null) {
      return prefs.externalToolPath(ForgeLibreOfficeTool.toolId);
    }
    return _storedPath();
  }

  Future<String?> _storedPath() async {
    final stored = await _api?.stateStore.read(_pathKey);
    return stored is String && stored.isNotEmpty ? stored : null;
  }

  /// Stores the path setting (*Choose LibreOffice…*).
  Future<void> setLibreOfficePath(String path) async {
    final given = _setLibreOfficePath;
    if (given != null) return given(path);
    final prefs = preferences;
    if (prefs != null) {
      return prefs.setExternalToolPath(ForgeLibreOfficeTool.toolId, path);
    }
    await _api?.stateStore.write(_pathKey, path);
  }

  static final _pathKey = ForgeKitPreferences.externalToolPathKey(
    ForgeLibreOfficeTool.toolId,
  );

  // ------------------------------------------------------------ detection

  Future<void> _detect() async {
    var path = '';
    try {
      // Detection starts at once when the setting is known at once.
      final setting = libreOfficePath();
      path =
          (setting is Future<String?> ? await setting : setting)?.trim() ?? '';
      final found = await detect(path);
      _installation = found;
      _launcher = launcherFor(found);
      forgeOfficeTrail(
        'detection: ${found.state.name} ${found.version ?? ''} '
        '(${path.isEmpty ? 'search' : 'path setting'})',
      );
    } catch (e, s) {
      forgeOfficeReport(e, s, 'detecting LibreOffice');
      final failed = LibreOfficeInstallation(
        state: LibreOfficeState.damaged,
        bundlePath: path.isEmpty ? null : path,
        reason: 'detection failed: $e',
      );
      _installation = failed;
      _launcher = launcherFor(failed);
    }
  }

  TomOfficeHelperLauncher _currentLauncher() =>
      _launcher ??
      _UnavailableLauncher(
        _installation ??
            const LibreOfficeInstallation(state: LibreOfficeState.missing),
      );

  /// *Check again*: detection runs again with the path setting; every tab
  /// showing the state panel opens its document once it reports `found`.
  Future<void> checkAgain() async {
    forgeOfficeTrail('check again');
    _detection = _detect();
    await _detection;
    for (final editor in _editors.values.toList()) {
      await editor.reopenIfUnavailable();
    }
    if (!(_installation?.isUsable ?? false)) await _checkAlternative();
  }

  /// *Choose LibreOffice…*: the picked app becomes the path setting, then
  /// detection runs again.
  Future<void> chooseLibreOffice() async {
    try {
      final path = await _pick();
      if (path == null || path.trim().isEmpty) return;
      forgeOfficeTrail('LibreOffice chosen');
      await setLibreOfficePath(path);
      await checkAgain();
    } catch (e, s) {
      forgeOfficeReport(e, s, 'choosing LibreOffice');
    }
  }

  Future<String?> _pick() async {
    final given = _pickLibreOffice;
    if (given != null) return given();
    final pickers = filePickers?.call();
    if (pickers == null || !pickers.available) return null;
    return pickers.pickFolder(
      title: 'Choose LibreOffice',
      initialDirectory: '/Applications',
    );
  }

  void _openLibreOffice(String path) {
    forgeOfficeTrail('open LibreOffice (quarantined)');
    final open = openExternal;
    if (open == null) return;
    unawaited(
      open(Uri.file(path)).catchError(
        (Object e, StackTrace s) =>
            forgeOfficeReport(e, s, 'opening LibreOffice'),
      ),
    );
  }

  Future<void> _checkAlternative() async {
    try {
      await alternative?.check?.call();
    } catch (e, s) {
      forgeOfficeReport(e, s, 'checking the alternative route');
    }
  }

  // -------------------------------------------------------------- opening

  /// Whether [uri] is an office file this module opens itself (any case):
  /// not `.csv`, which stays text and is only offered under *Open With*.
  bool handles(Uri uri) {
    final ext = ForgeOfficeKind.extensionOf(uri);
    return ForgeOfficeKind.extensions.containsKey(ext) &&
        !ForgeOfficeKind.openWithOnly.contains(ext);
  }

  /// Whether this module offers its editor for [uri] under *Open With*.
  bool offers(Uri uri) => ForgeOfficeKind.of(uri) != null;

  /// The local path of [uri]: the helper needs one, so a file of a file
  /// system without local paths is not opened here.
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
      if (api == null || !handles(uri)) return false;
      if (_localPath(uri) == null) {
        forgeOfficeTrail('openUri declined: no local path');
        return false;
      }
      final route = alternative;
      final theirs = route?.editors?.call() ?? const <ForgeEditor>[];
      for (final open in api.state.openEditors) {
        if (open.uri == uri &&
            (_editors.containsValue(open) || theirs.contains(open))) {
          forgeOfficeTrail('openUri: existing editor shown');
          unawaited(api.editorHost.showEditor(open));
          return true;
        }
      }
      final preferred = api.editorPicker.defaultIdFor(ForgeContentItem(uri)).$1;
      if (route != null && preferred == route.choiceId) {
        forgeOfficeTrail('openUri: left to ${route.choiceId} (the default)');
        return false;
      }
      forgeOfficeTrail(
        'openUri: $lokChoiceId (default ${preferred ?? 'none'})',
      );
      _open(uri);
      return true;
    } catch (e, s) {
      forgeOfficeReport(e, s, 'opening an office file');
      return false;
    }
  }

  @override
  List<ForgeKitEditorChoice> editorChoicesFor(Uri uri) {
    final kind = ForgeOfficeKind.of(uri);
    if (_api == null || kind == null || _localPath(uri) == null) {
      return const [];
    }
    // Without a usable LibreOffice the choice is left out (unknown before
    // the first detection ends: offered).
    if (!(_installation?.isUsable ?? true)) return const [];
    return [
      ForgeKitEditorChoice(
        id: lokChoiceId,
        label: kind.nativeLabel,
        description: 'The installed LibreOffice through LibreOfficeKit',
        icon: kind.icon,
        open: _open,
      ),
    ];
  }

  /// Opens [uri] in its LibreOfficeKit editor: the one already open for it,
  /// or a new one.
  void _open(Uri uri) {
    try {
      final api = _api;
      final path = _localPath(uri);
      final kind = ForgeOfficeKind.of(uri);
      if (api == null || path == null || kind == null) return;
      final existing = _editors[uri];
      if (existing != null && api.state.openEditors.contains(existing)) {
        forgeOfficeTrail('$lokChoiceId: existing editor shown');
        unawaited(api.editorHost.showEditor(existing));
        return;
      }
      final host = ForgeOfficeHost(
        filePath: path,
        api: api,
        files: files,
        launcher: _currentLauncher,
        openExternal: openExternal,
        filePickers: filePickers,
        pickImage: pickImage,
      );
      final route = alternative;
      final editor = ForgeOfficeEditor(
        uri: uri,
        host: host,
        kind: kind,
        detected: _detection,
        decoder: tileDecoder,
        panelActions: ForgeOfficePanelActions(
          checkAgain: checkAgain,
          chooseLibreOffice: chooseLibreOffice,
          openLibreOffice: _openLibreOffice,
          openAlternative: route == null ? null : () => route.open(uri),
          alternativeLabel: route?.label ?? 'Open with another editor',
          alternativeIcon: route?.icon ?? Icons.open_in_new,
          alternativeAvailable: route?.available,
        ),
      );
      if (route != null) {
        unawaited(
          _detection.then((_) {
            if (!(_installation?.isUsable ?? false)) {
              return _checkAlternative();
            }
            return null;
          }),
        );
      }
      _editors[uri] = editor;
      forgeOfficeTrail('$lokChoiceId: opened');
      unawaited(api.editorHost.showEditor(editor));
    } catch (e, s) {
      forgeOfficeReport(e, s, 'opening $lokChoiceId');
    }
  }

  void _checkExternal() {
    for (final editor in _editors.values.toList()) {
      try {
        forgeOfficeTrail('checkExternal on focus');
        unawaited(editor.checkExternal());
      } catch (e, s) {
        forgeOfficeReport(e, s, 'checking an office file for outside changes');
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
      forgeOfficeReport(e, s, 'closing an office editor');
    }
  }
}

/// The desktop's launcher: `tom_office_host` from the binaries layer for
/// [installation], or one that says it is missing.
TomOfficeHelperLauncher _processLauncher(LibreOfficeInstallation installation) {
  final helper = TomOfficeProcessLauncher.findHelper();
  if (helper == null) return _NoHelperLauncher(installation);
  return TomOfficeProcessLauncher(
    installation: installation,
    helperExecutable: helper,
  );
}

Future<void> _cleanUpHelpers() async {
  final removed = await TomOfficeProcessLauncher.cleanUp();
  if (removed.isNotEmpty) {
    forgeOfficeTrail('cleaned up ${removed.length} dead helper leftovers');
  }
}

/// The launcher before detection ended or after it failed: it starts
/// nothing (the editor shows detection's state).
class _UnavailableLauncher implements TomOfficeHelperLauncher {
  _UnavailableLauncher(this.installation);

  @override
  final LibreOfficeInstallation installation;

  @override
  Future<TomOfficeHelperChannel> start({required String documentPath}) =>
      Future.error(StateError('LibreOffice is not available'));
}

/// The launcher when the binaries layer has no `tom_office_host`.
class _NoHelperLauncher implements TomOfficeHelperLauncher {
  _NoHelperLauncher(this.installation);

  @override
  final LibreOfficeInstallation installation;

  @override
  Future<TomOfficeHelperChannel> start({required String documentPath}) =>
      Future.error(
        StateError(
          'tom_office_host is not in the binaries layer '
          '(\$TOM_BINARY_PATH/<platform>)',
        ),
      );
}
