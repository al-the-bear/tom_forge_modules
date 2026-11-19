import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_file_session/tom_file_session.dart' show TomBinaryFiles;
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_office_editor/io.dart';
import 'package:tom_office_editor/tom_office_editor.dart';
import 'package:tom_office_editor/zetaoffice.dart';

import 'forge_office_editor.dart';
import 'forge_office_host.dart';
import 'forge_office_kind.dart';
import 'forge_office_trail.dart';
import 'forge_zetaoffice_editor.dart';
import 'libreoffice_tool.dart';

/// The office editors as one module (`part-forge-integration`): it opens
/// the office files itself, before the shell reads them as text — `.docx
/// .xlsx .pptx .odt .ods .odp` and the older `.doc .xls .ppt .rtf` (DPOE-2);
/// `.csv` only under *Open With*, it stays text by default — in the editor
/// the file-type default names (`office.lok`, the LibreOfficeKit editor,
/// when none does), shows an editor already open on the file instead of
/// opening a second, and offers both editors under *Open With*: one editor
/// per (choice, file), so a file may be open in both routes.
///
/// It detects LibreOffice at activation with the user's path setting
/// (`forge.tools.libreoffice.path`) and starts `tom_office_host` from the
/// binaries layer for it. Without a usable LibreOffice an office file still
/// opens a tab, showing detection's state panel; `office.lok` then leaves
/// *Open With*, `office.zetaoffice` stays. LibreOffice's row in *External
/// Tools* is the module's ([externalTools]). When the window regains focus
/// each editor checks its file for outside changes; a closed editor ends its
/// helper or page.
class ForgeOfficeEditorsModule extends ForgeModule {
  /// The module. Every parameter defaults to the desktop's: local files
  /// through `TomBinaryFileAccess`, `TomLibreOfficeDetector` with the path
  /// setting from `ForgePreferencesService`, `TomOfficeProcessLauncher` with
  /// `tom_office_host` from `$TOM_BINARY_PATH`, the shell's folder picker for
  /// *Choose LibreOffice…*, ZetaOffice's cache and local server. Tests give
  /// fakes.
  ForgeOfficeEditorsModule({
    TomBinaryFiles? files,
    Future<LibreOfficeInstallation> Function(String userPath)? detect,
    String? Function()? libreOfficePath,
    Future<void> Function(String path)? setLibreOfficePath,
    TomOfficeHelperLauncher Function(LibreOfficeInstallation installation)?
    launcherFor,
    Future<String?> Function()? pickLibreOffice,
    this.pickImage,
    Future<void> Function()? cleanUpHelpers,
    TomZetaOfficeFiles? zetaFiles,
    TomZetaOfficeServing Function(TomBinaryFiles files)? zetaServing,
    this.zetaChannelForTesting,
    ForgeLibreOfficeTool? libreOfficeTool,
    this.tileDecoder,
  }) : files = files ?? const TomBinaryFileAccess(),
       detect =
           detect ??
           ((userPath) => TomLibreOfficeDetector(userPath: userPath).detect()),
       libreOfficePath =
           libreOfficePath ??
           (() => ForgePreferencesService.instance.externalToolPath(
             ForgeLibreOfficeTool.toolId,
           )),
       setLibreOfficePath =
           setLibreOfficePath ??
           ((path) => ForgePreferencesService.instance.setExternalToolPath(
             ForgeLibreOfficeTool.toolId,
             path,
           )),
       launcherFor = launcherFor ?? _processLauncher,
       pickLibreOffice = pickLibreOffice ?? _pickLibreOfficeFolder,
       cleanUpHelpers = cleanUpHelpers ?? _cleanUpHelpers,
       zetaFiles = zetaFiles ?? TomZetaOfficeCache(),
       zetaServing =
           zetaServing ?? ((files) => TomZetaOfficeServer(files: files)),
       libreOfficeTool = libreOfficeTool ?? ForgeLibreOfficeTool();

  /// The LibreOfficeKit editor's choice id (the default).
  static const lokChoiceId = 'office.lok';

  /// ZetaOffice's choice id.
  static const zetaOfficeChoiceId = 'office.zetaoffice';

  /// The file access for local files.
  final TomBinaryFiles files;

  /// Detects LibreOffice for a user path (empty: search).
  final Future<LibreOfficeInstallation> Function(String userPath) detect;

  /// The user's LibreOffice path setting (null: search).
  final String? Function() libreOfficePath;

  /// Stores the path setting (*Choose LibreOffice…*).
  final Future<void> Function(String path) setLibreOfficePath;

  /// The helper launcher for a detection result.
  final TomOfficeHelperLauncher Function(LibreOfficeInstallation installation)
  launcherFor;

  /// *Choose LibreOffice…*: the app the user picks, or null.
  final Future<String?> Function() pickLibreOffice;

  /// *Insert image*'s picker (default: the shell's file picker).
  final Future<String?> Function()? pickImage;

  /// Removes what dead helpers left (profiles, lock and temporary files),
  /// once at activation.
  final Future<void> Function() cleanUpHelpers;

  /// ZetaOffice's cached files.
  final TomZetaOfficeFiles zetaFiles;

  /// A ZetaOffice tab's local server, over the file's access.
  final TomZetaOfficeServing Function(TomBinaryFiles files) zetaServing;

  /// Makes a ZetaOffice editor's channel instead of a webview (tests).
  final TomZetaOfficeChannel Function()? zetaChannelForTesting;

  /// LibreOffice's row in *External Tools*.
  final ForgeLibreOfficeTool libreOfficeTool;

  /// Decodes the LibreOfficeKit editor's tiles (default:
  /// `decodeImageFromPixels`; tests give one that needs no real time).
  final TomOfficeImageDecoder? tileDecoder;

  ForgeShellApi? _shell;
  final _editors = <(String, Uri), ForgeEditor>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  LibreOfficeInstallation? _installation;
  TomOfficeHelperLauncher? _launcher;
  Future<void> _detection = Future<void>.value();
  final _zetaAvailable = ValueNotifier(false);
  Future<void>? _zetaCheck;

  /// The last detection result (null before the first one ended).
  LibreOfficeInstallation? get installation => _installation;

  /// Completes when the running detection has ended.
  Future<void> get detection => _detection;

  /// Whether the missing-LibreOffice panel offers *Open with ZetaOffice*.
  ValueNotifier<bool> get zetaOfficeAvailable => _zetaAvailable;

  @override
  String get displayName => 'Office editors';

  @override
  List<ForgeExternalTool> get externalTools => [libreOfficeTool];

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
    unawaited(
      cleanUpHelpers().catchError(
        (Object e, StackTrace s) =>
            forgeOfficeReport(e, s, 'cleaning up after dead helpers'),
      ),
    );
    _detection = _detect();
    forgeOfficeTrail('activated');
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

  // ------------------------------------------------------------ detection

  Future<void> _detect() async {
    final path = libreOfficePath()?.trim() ?? '';
    try {
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

  /// *Check again*: detection runs again with the path setting; every
  /// LibreOfficeKit tab showing the state panel opens its document once it
  /// reports `found`.
  Future<void> checkAgain() async {
    forgeOfficeTrail('check again');
    _detection = _detect();
    await _detection;
    for (final editor in _editors.values.whereType<ForgeOfficeEditor>()) {
      await editor.reopenIfUnavailable();
    }
    if (!(_installation?.isUsable ?? false)) await _checkZetaOffice();
  }

  /// *Choose LibreOffice…*: the picked app becomes the path setting, then
  /// detection runs again.
  Future<void> chooseLibreOffice() async {
    try {
      final path = await pickLibreOffice();
      if (path == null || path.trim().isEmpty) return;
      forgeOfficeTrail('LibreOffice chosen');
      await setLibreOfficePath(path);
      await checkAgain();
    } catch (e, s) {
      forgeOfficeReport(e, s, 'choosing LibreOffice');
    }
  }

  void _openLibreOffice(String path) {
    forgeOfficeTrail('open LibreOffice (quarantined)');
    unawaited(_shell?.environment.openExternal(Uri.file(path)));
  }

  /// Whether ZetaOffice can open without LibreOffice: its files are cached,
  /// or the CDN answers (the download prompt can then fetch them).
  Future<void> _checkZetaOffice() => _zetaCheck ??= () async {
    try {
      final status = await zetaFiles.status();
      if (status.state == TomZetaOfficeCacheState.ready) {
        _zetaAvailable.value = true;
        return;
      }
      await zetaFiles.downloadSize().timeout(const Duration(seconds: 10));
      _zetaAvailable.value = true;
    } catch (e) {
      forgeOfficeTrail('ZetaOffice not available offline: $e');
      _zetaAvailable.value = false;
    } finally {
      _zetaCheck = null;
    }
  }();

  // -------------------------------------------------------------- opening

  /// Whether [uri] is an office file this module opens itself (any case):
  /// not `.csv`, which stays text and is only offered under *Open With*.
  bool handles(Uri uri) {
    final ext = ForgeOfficeKind.extensionOf(uri);
    return ForgeOfficeKind.extensions.containsKey(ext) &&
        !ForgeOfficeKind.openWithOnly.contains(ext);
  }

  /// Whether this module offers its editors for [uri] under *Open With*.
  bool offers(Uri uri) => ForgeOfficeKind.of(uri) != null;

  /// The local path of [uri]: the helper needs one, so a file of a file
  /// system without local paths is not opened here.
  String? _localPath(Uri uri) {
    final shell = _shell;
    if (shell == null || !uri.isScheme('file')) return null;
    if (shell.fileSystem.pathOf(uri) == null) return null;
    return uri.toFilePath();
  }

  @override
  bool openUri(Uri uri, {int? middlePanelIndex}) {
    try {
      final shell = _shell;
      if (shell == null || !handles(uri)) return false;
      if (_localPath(uri) == null) {
        forgeOfficeTrail('openUri declined: no local path');
        return false;
      }
      for (final open in shell.systemState.openEditors) {
        if (open.uri == uri && _editors.containsValue(open)) {
          forgeOfficeTrail('openUri: existing editor shown');
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
          ? layout.getFileTypeDefaultEditor(ForgeOfficeKind.extensionOf(uri))
          : null;
      final id = preferred == zetaOfficeChoiceId
          ? zetaOfficeChoiceId
          : lokChoiceId;
      forgeOfficeTrail('openUri: $id (default ${preferred ?? 'none'})');
      _open(id, uri, middlePanelIndex: middlePanelIndex);
      return true;
    } catch (e, s) {
      forgeOfficeReport(e, s, 'opening an office file');
      return false;
    }
  }

  @override
  List<ForgeEditorChoice> editorChoicesFor(Uri uri) {
    final kind = ForgeOfficeKind.of(uri);
    if (_shell == null || kind == null || _localPath(uri) == null) {
      return const [];
    }
    // Without a usable LibreOffice the native choice is left out (unknown
    // before the first detection ends: offered).
    final lokUsable = _installation?.isUsable ?? true;
    return [
      if (lokUsable)
        ForgeEditorChoice(
          id: lokChoiceId,
          label: kind.nativeLabel,
          description: 'The installed LibreOffice through LibreOfficeKit',
          icon: kind.icon,
          open: (uri, {middlePanelIndex}) =>
              _open(lokChoiceId, uri, middlePanelIndex: middlePanelIndex),
        ),
      ForgeEditorChoice(
        id: zetaOfficeChoiceId,
        label: 'ZetaOffice (web, comparison)',
        description: 'LibreOffice compiled to WebAssembly, in a webview',
        icon: Icons.public,
        open: (uri, {middlePanelIndex}) =>
            _open(zetaOfficeChoiceId, uri, middlePanelIndex: middlePanelIndex),
      ),
    ];
  }

  /// Opens [uri] in the editor of choice [id]: the one already open for it,
  /// or a new one.
  void _open(String id, Uri uri, {int? middlePanelIndex}) {
    try {
      final shell = _shell;
      final path = _localPath(uri);
      final kind = ForgeOfficeKind.of(uri);
      if (shell == null || path == null || kind == null) return;
      final existing = _editors[(id, uri)];
      if (existing != null &&
          shell.systemState.openEditors.contains(existing)) {
        forgeOfficeTrail('$id: existing editor shown');
        shell.layout.openEditor(
          existing,
          uri,
          middlePanelIndex: middlePanelIndex,
        );
        return;
      }
      final host = ForgeOfficeHost(
        filePath: path,
        shell: shell,
        files: files,
        launcher: _currentLauncher,
        pickImage: pickImage,
      );
      late final ForgeEditor editor;
      if (id == zetaOfficeChoiceId) {
        editor = ForgeZetaOfficeEditor(
          uri: uri,
          host: host,
          kind: kind,
          files: zetaFiles,
          serving: zetaServing(files),
          channelForTesting: zetaChannelForTesting?.call(),
          onShowMain: () => shell.layout.openEditor(editor, uri),
        );
      } else {
        editor = ForgeOfficeEditor(
          uri: uri,
          host: host,
          kind: kind,
          detected: _detection,
          decoder: tileDecoder,
          panelActions: ForgeOfficePanelActions(
            checkAgain: checkAgain,
            chooseLibreOffice: chooseLibreOffice,
            openLibreOffice: _openLibreOffice,
            openWithZetaOffice: () => _open(zetaOfficeChoiceId, uri),
            zetaOfficeAvailable: _zetaAvailable,
          ),
        );
        unawaited(
          _detection.then((_) {
            if (!(_installation?.isUsable ?? false)) {
              return _checkZetaOffice();
            }
            return null;
          }),
        );
      }
      _editors[(id, uri)] = editor;
      forgeOfficeTrail('$id: opened');
      shell.layout.openEditor(editor, uri, middlePanelIndex: middlePanelIndex);
    } catch (e, s) {
      forgeOfficeReport(e, s, 'opening $id');
    }
  }

  void _checkExternal() {
    for (final editor in _editors.values) {
      try {
        forgeOfficeTrail('checkExternal on focus');
        switch (editor) {
          case ForgeOfficeEditor():
            unawaited(editor.checkExternal());
          case ForgeZetaOfficeEditor():
            unawaited(editor.checkExternal());
        }
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
    _editors.remove(key);
    try {
      switch (editor) {
        case ForgeOfficeEditor():
          unawaited(editor.close());
        case ForgeZetaOfficeEditor():
          unawaited(editor.close());
      }
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

Future<String?> _pickLibreOfficeFolder() async {
  final pickers = ForgeShellComponents.registered.pickers;
  if (!pickers.available) return null;
  return pickers.pickFolder(
    title: 'Choose LibreOffice',
    initialDirectory: '/Applications',
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
