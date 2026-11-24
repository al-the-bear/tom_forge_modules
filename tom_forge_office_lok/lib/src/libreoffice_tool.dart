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
/// search of *Auto-detect*, the download page.
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
    return copyOf(await _detectorFor(path ?? '').detect());
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
