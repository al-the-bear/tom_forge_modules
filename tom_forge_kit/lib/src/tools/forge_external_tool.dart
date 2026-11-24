import 'package:flutter/widgets.dart';

import '../module/forge_kit_module.dart';

/// The state of an external tool's copy, as its detector reports it.
enum ForgeToolState {
  /// Usable.
  found,

  /// No copy anywhere (or none at the path set).
  missing,

  /// A copy below the minimum version.
  tooOld,

  /// A copy that cannot be used (incomplete, failing its checks).
  damaged,

  /// A copy the system has not let run yet (macOS: never opened, still
  /// quarantined).
  quarantined,
}

/// One copy of an external tool: where it is, its version and state.
@immutable
final class ForgeToolCopy {
  /// A copy from its parts.
  const ForgeToolCopy({
    required this.path,
    required this.state,
    this.version,
    this.reason,
  });

  /// No copy found.
  const ForgeToolCopy.missing({this.reason})
    : path = '',
      state = ForgeToolState.missing,
      version = null;

  /// The path the user's setting takes for it (an app bundle, a folder or an
  /// executable, as the tool's descriptor says).
  final String path;

  /// Its state.
  final ForgeToolState state;

  /// Its version, when it could be read.
  final String? version;

  /// Why it is not [ForgeToolState.found] (the output of the failing check).
  final String? reason;

  /// Whether it can be used.
  bool get usable => state == ForgeToolState.found;

  @override
  bool operator ==(Object other) =>
      other is ForgeToolCopy &&
      other.path == path &&
      other.state == state &&
      other.version == version &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(path, state, version, reason);

  @override
  String toString() => 'ForgeToolCopy(${state.name} $path $version)';
}

/// An external tool Forge uses (LibreOffice, later pandoc, Graphviz,
/// MarkText, ...): one row of the Configuration panel's *External Tools*
/// section, with its path setting `forge.tools.<id>.path`.
///
/// A descriptor, no widget: the panel shell draws the rows, another
/// application shows them as it decides or not at all. No application knows a
/// tool itself: the module that owns a tool contributes its descriptor — a
/// kit module as a [ForgeExternalToolsExtra], the panel shell's
/// `ForgeModule` from `externalTools` — so a new tool adds a row without
/// changing the section. A module reads the user's path for its own
/// detection from the preferences (`ForgeKitPreferences.externalToolPath`).
abstract class ForgeExternalTool {
  /// A const constructor for subclasses.
  const ForgeExternalTool();

  /// The id in the setting's key (`forge.tools.<id>.path`): lower case,
  /// letters, digits and `_`, e.g. `libreoffice`.
  String get id;

  /// The name shown, e.g. `LibreOffice`.
  String get name;

  /// Where its row goes: lower first (LibreOffice is 0).
  int get order => 100;

  /// What the path names, shown as the field's hint (e.g.
  /// `LibreOffice.app`).
  String get pathHint => 'path';

  /// Whether the path is a folder (an app bundle is one on macOS); the
  /// section's *Choose…* picks a folder then, else a file.
  bool get pathIsDirectory => false;

  /// Where to get it (shown when it is missing or too old, unless
  /// [buildHelp] gives help).
  String? get downloadUrl => null;

  /// Help shown in the tool's row while [copy] is not usable — how to get
  /// or repair it (LibreOffice: its install help, which can run an install);
  /// null: none (the row shows [downloadUrl]). [checkAgain] runs the row's
  /// check again (after an install, or on the help's *Check again*).
  Widget? buildHelp(
    BuildContext context,
    ForgeToolCopy copy, {
    required Future<void> Function() checkAgain,
  }) => null;

  /// Detects the tool: at [path] when the user set one (an unusable copy
  /// there is reported as it is, never replaced by another), else by its
  /// usual search.
  Future<ForgeToolCopy> check(String? path);

  /// The wider search of *Auto-detect*: every copy found, with its version
  /// and state, for the user to pick one.
  Future<List<ForgeToolCopy>> autoDetect();
}

/// A module's external tools as a [ForgeModuleExtra]: a kit module
/// contributes its tools' rows with it (the panel shell's `ForgeModule`
/// declares them as `externalTools`, which the shell wraps the same way). An
/// application with an *External Tools* section shows them; one without
/// ignores the kind.
class ForgeExternalToolsExtra extends ForgeModuleExtra {
  const ForgeExternalToolsExtra(List<ForgeExternalTool> tools)
    : super(kind: kindId, value: tools);

  /// The kind of this extra.
  static const kindId = 'forge.kit.externalTools';

  /// The tools.
  List<ForgeExternalTool> get tools => value as List<ForgeExternalTool>;
}
