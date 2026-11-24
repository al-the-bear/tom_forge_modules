import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show kShellEditorIntegrationDebug;
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show kYamlEditorDebug;

import 'sample_workspace.dart';

/// What the example's command line asks for: the workspace folder and the
/// debug trails to switch on.
///
/// ```bash
/// flutter run -d macos --dart-entrypoint-args $HOME/notes
/// tom_forge_lite_example.app/Contents/MacOS/tom_forge_lite_example \
///   --trail=yaml,kit ~/notes
/// ```
@immutable
class LiteLaunch {
  const LiteLaunch({this.workspace, this.trails = const {}});

  /// The folder named on the command line; null when none was.
  final String? workspace;

  /// The trails to switch on: `yaml` (the YAML editor's `[YE]` trail,
  /// `kYamlEditorDebug`), `kit` (the editor integration's, the action and
  /// key routing between an editor and the shell,
  /// `kShellEditorIntegrationDebug`), `all` (both).
  final Set<String> trails;

  /// The trail names [trails] may hold.
  static const knownTrails = {'yaml', 'kit', 'all'};

  /// Reads [arguments]: `--workspace=<folder>` (or `--workspace <folder>`,
  /// or the first argument not starting with `-`) names the folder;
  /// `--trail=<name>[,<name>]` switches trails on, `--trail` alone all of
  /// them.
  factory LiteLaunch.parse(List<String> arguments) {
    String? workspace;
    final trails = <String>{};
    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument.startsWith('--workspace=')) {
        workspace = argument.substring('--workspace='.length);
      } else if (argument == '--workspace' && i + 1 < arguments.length) {
        workspace = arguments[++i];
      } else if (argument == '--trail') {
        trails.add('all');
      } else if (argument.startsWith('--trail=')) {
        trails.addAll(
          argument
              .substring('--trail='.length)
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty),
        );
      } else if (!argument.startsWith('-')) {
        workspace ??= argument;
      }
    }
    return LiteLaunch(workspace: workspace, trails: trails);
  }

  /// Switches the trails of [trails] on.
  void applyTrails() {
    final all = trails.contains('all');
    if (all || trails.contains('yaml')) kYamlEditorDebug = true;
    if (all || trails.contains('kit')) kShellEditorIntegrationDebug = true;
    for (final unknown in trails.difference(knownTrails)) {
      debugPrint('[lite] unknown trail "$unknown" (known: $knownTrails)');
    }
  }

  /// The folder to open: the one named, else the current directory when it
  /// is a folder to edit, else the sample folder ([sampleWorkspaceFolder]).
  String resolveWorkspace() {
    if (workspace case final named?) return Directory(named).absolute.path;
    final current = Directory.current.path;
    if (current != '/') return current;
    return sampleWorkspaceFolder().path;
  }
}
