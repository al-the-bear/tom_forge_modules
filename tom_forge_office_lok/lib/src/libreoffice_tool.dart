import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show ForgeExternalTool, ForgeToolCopy, ForgeToolState;
import 'package:tom_office_editor/io.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

import 'forge_office_trail.dart';

/// LibreOffice's row in the Configuration panel's *External Tools* section (a
/// kit [ForgeExternalTool], contributed by the module as a
/// `ForgeExternalToolsExtra`):
/// the path setting `forge.tools.libreoffice.path` (an app bundle), the
/// detected version and state through `TomLibreOfficeDetector`, the wider
/// search of *Auto-detect*, the download page, and — while LibreOffice is
/// missing, too old or unusable — the install help ([buildHelp]).
class ForgeLibreOfficeTool extends ForgeExternalTool {
  /// The descriptor. [detectorFor] makes the detector for a user path
  /// (empty: search); tests give a fake.
  ForgeLibreOfficeTool({
    TomLibreOfficeDetector Function(String userPath)? detectorFor,
  }) : _detectorFor =
           detectorFor ??
           ((userPath) => TomLibreOfficeDetector(userPath: userPath));

  /// The tool's id, and so its setting `forge.tools.libreoffice.path`.
  static const toolId = 'libreoffice';

  final TomLibreOfficeDetector Function(String userPath) _detectorFor;

  LibreOfficeInstallation? _installation;

  /// The last [check]'s detection result (null before the first).
  LibreOfficeInstallation? get lastInstallation => _installation;

  /// Builds the install help for a detection result; [checkAgain] runs the
  /// row's check again. The module sets it (its install runner, its
  /// `openExternal`, detection again); null: the help shows the routes
  /// with their commands and *Check again* only.
  ForgeLibreOfficeHelpBuilder? helpBuilder;

  @override
  String get id => toolId;

  @override
  String get name => 'LibreOffice';

  /// The first row.
  @override
  int get order => 0;

  @override
  String get pathHint => 'LibreOffice.app';

  @override
  bool get pathIsDirectory => true;

  @override
  String? get downloadUrl => kLibreOfficeDownloadUrl;

  @override
  Future<ForgeToolCopy> check(String? path) async {
    forgeOfficeTrail('tool check (${path == null ? 'search' : 'path'})');
    return remember(await _detectorFor(path ?? '').detect());
  }

  /// Keeps [installation] as the last check's result (the help shows it) and
  /// answers it as the section shows it.
  @protected
  ForgeToolCopy remember(LibreOfficeInstallation installation) {
    _installation = installation;
    return copyOf(installation);
  }

  /// `TomLibreOfficeInstallHelp` while the copy is missing, too old or
  /// unusable (a quarantined copy has the row's own advice); null else.
  @override
  Widget? buildHelp(
    BuildContext context,
    ForgeToolCopy copy, {
    required Future<void> Function() checkAgain,
  }) {
    if (copy.usable) return null;
    final installation =
        _installation ??
        LibreOfficeInstallation(
          state: switch (copy.state) {
            ForgeToolState.found => LibreOfficeState.found,
            ForgeToolState.missing => LibreOfficeState.missing,
            ForgeToolState.tooOld => LibreOfficeState.tooOld,
            ForgeToolState.damaged => LibreOfficeState.damaged,
            ForgeToolState.quarantined => LibreOfficeState.quarantined,
          },
          bundlePath: copy.path.isEmpty ? null : copy.path,
          version: copy.version,
          reason: copy.reason,
        );
    if (!TomLibreOfficeProblem.of(installation).offersInstall) return null;
    forgeOfficeTrail('tool help: ${installation.state.name}');
    final build = helpBuilder;
    if (build != null) return build(context, installation, checkAgain);
    return TomLibreOfficeInstallHelp(
      installation: installation,
      onCheckAgain: () => unawaited(checkAgain()),
    );
  }

  @override
  Future<List<ForgeToolCopy>> autoDetect() async {
    forgeOfficeTrail('tool auto-detect');
    final found = await _detectorFor('').autoDetect();
    return [for (final i in found) copyOf(i)];
  }

  /// Detection's answer as the section shows it.
  static ForgeToolCopy copyOf(LibreOfficeInstallation installation) =>
      ForgeToolCopy(
        path: installation.bundlePath ?? '',
        state: switch (installation.state) {
          LibreOfficeState.found => ForgeToolState.found,
          LibreOfficeState.missing => ForgeToolState.missing,
          LibreOfficeState.tooOld => ForgeToolState.tooOld,
          LibreOfficeState.damaged => ForgeToolState.damaged,
          LibreOfficeState.quarantined => ForgeToolState.quarantined,
        },
        version: installation.version,
        reason: installation.reason,
      );
}

/// Builds the install help for [installation] in the External Tools row;
/// [checkAgain] runs the row's check again.
typedef ForgeLibreOfficeHelpBuilder =
    Widget Function(
      BuildContext context,
      LibreOfficeInstallation installation,
      Future<void> Function() checkAgain,
    );
