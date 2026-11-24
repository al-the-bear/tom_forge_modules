import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show kShellEditorIntegrationDebug;
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show kYamlEditorDebug;

import 'sample_file.dart';

/// What the example's command line asks for: the YAML file to edit and the
/// debug trails to switch on.
///
/// ```bash
/// flutter run -d macos --dart-entrypoint-args $HOME/notes/config.yaml
/// tom_forge_single_window_example.app/Contents/MacOS/tom_forge_single_window_example \
///   --trail=yaml,kit ~/notes/config.yaml
/// ```
@immutable
class KitLaunch {
  const KitLaunch({this.file, this.trails = const {}});

  /// The file named on the command line; null when none was.
  final String? file;

  /// The trails to switch on: `yaml` (the YAML editor's `[YE]` trail,
  /// `kYamlEditorDebug`), `kit` (the editor integration's, the action and
  /// key routing between the editor and the kit,
  /// `kShellEditorIntegrationDebug`), `all` (both).
  final Set<String> trails;

  /// The trail names [trails] may hold.
  static const knownTrails = {'yaml', 'kit', 'all'};

  /// Reads [arguments]: `--file=<path>` (or `--file <path>`, or the first
  /// argument not starting with `-`) names the file; `--trail=<name>[,<name>]`
  /// switches trails on, `--trail` alone all of them.
  factory KitLaunch.parse(List<String> arguments) {
    String? file;
    final trails = <String>{};
    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument.startsWith('--file=')) {
        file = argument.substring('--file='.length);
      } else if (argument == '--file' && i + 1 < arguments.length) {
        file = arguments[++i];
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
        file ??= argument;
      }
    }
    return KitLaunch(file: file, trails: trails);
  }

  /// Switches the trails of [trails] on.
  void applyTrails() {
    final all = trails.contains('all');
    if (all || trails.contains('yaml')) kYamlEditorDebug = true;
    if (all || trails.contains('kit')) kShellEditorIntegrationDebug = true;
    for (final unknown in trails.difference(knownTrails)) {
      debugPrint('[kit] unknown trail "$unknown" (known: $knownTrails)');
    }
  }

  /// The file to open: the one named, else the sample file ([sampleFile]).
  File resolveFile() {
    if (file case final named?) return File(named).absolute;
    return sampleFile();
  }
}
