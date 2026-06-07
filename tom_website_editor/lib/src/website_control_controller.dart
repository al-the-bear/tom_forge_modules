import 'package:flutter/foundation.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import 'website_control_log.dart';
import 'website_editor_controller.dart';
import 'website_process_runner.dart';

/// One action button in the control view (§5).
class WebsiteCommandButton {
  const WebsiteCommandButton({
    required this.name,
    required this.label,
    required this.isAvailable,
    required this.isRunning,
  });

  /// The §7 command name (e.g. `generateAll`).
  final String name;

  /// Human-readable button label.
  final String label;

  /// `true` when the active website configures this command (else disabled).
  final bool isAvailable;

  /// `true` while the command's process is in flight.
  final bool isRunning;
}

/// The canonical §7 commands, in the order the control view renders them.
/// Every website may configure any subset; missing ones render disabled.
const List<(String, String)> _canonicalCommands = [
  ('generateContent', 'Generate content'),
  ('extractDesign', 'Extract design'),
  ('generateAll', 'Generate all'),
  ('statusReport', 'Status report'),
  ('smoke', 'Smoke test'),
  ('serveStart', 'Start dev server'),
  ('build', 'Build'),
  ('openBrowser', 'Open in browser'),
];

/// Drives the control panel (§5): renders one button per configured command,
/// spawns the matching external process for the active website, streams its
/// stdout/stderr into a levelled log, and maps the exit code via the §7
/// taxonomy (`0` info, `1` error, `2` error tagged usage/config).
///
/// It wraps the shared [WebsiteEditorController] (website selection lives there)
/// and delegates spawning to an injected [WebsiteProcessRunner], so it never
/// imports the website's Dart code — every action is a process (§1). Placeholder
/// expansion reuses [PlaceholderResolver]; a resolution failure is logged as a
/// pinned error and the process is not started (never a silent blank run).
class WebsiteControlController extends ChangeNotifier {
  WebsiteControlController({
    required WebsiteEditorController editor,
    WebsiteProcessRunner runner = const DartIoWebsiteProcessRunner(),
    Map<String, String> builtins = const {},
    Map<String, String>? environment,
    String? homeDir,
    DateTime Function()? clock,
  })  : _editor = editor,
        _runner = runner,
        _builtins = builtins,
        _environment = environment,
        _homeDir = homeDir,
        _clock = clock ?? DateTime.now {
    _editor.addListener(_onEditorChanged);
  }

  final WebsiteEditorController _editor;
  final WebsiteProcessRunner _runner;
  final Map<String, String> _builtins;
  final Map<String, String>? _environment;
  final String? _homeDir;
  final DateTime Function() _clock;

  final List<WebsiteLogEntry> _log = [];
  final Map<String, WebsiteProcessHandle> _running = {};
  DateTime? _lastRunAt;

  /// The active website id, or `null` until the editor has loaded.
  String? get activeWebsiteId => _editor.activeWebsiteId;

  /// The registered websites (empty until the editor has loaded).
  List<WebsiteEntry> get websites => _editor.websites;

  /// The full message log, oldest first.
  List<WebsiteLogEntry> get log => List.unmodifiable(_log);

  /// Timestamp of the last completed run, or `null` if nothing has run.
  DateTime? get lastRunAt => _lastRunAt;

  /// Number of error-level entries in the log.
  int get errorCount =>
      _log.where((e) => e.level == WebsiteLogLevel.error).length;

  /// Number of warning-level entries in the log.
  int get warningCount =>
      _log.where((e) => e.level == WebsiteLogLevel.warning).length;

  /// `true` while [name]'s process is in flight.
  bool isRunning(String name) => _running.containsKey(name);

  /// The action buttons for the active website, in canonical order followed by
  /// any extra (non-canonical) configured commands.
  List<WebsiteCommandButton> get buttons {
    final commands = _editor.registry?.activeWebsite.commands ?? const {};
    final result = <WebsiteCommandButton>[];
    final seen = <String>{};
    for (final (name, label) in _canonicalCommands) {
      seen.add(name);
      result.add(WebsiteCommandButton(
        name: name,
        label: label,
        isAvailable: commands.containsKey(name),
        isRunning: isRunning(name),
      ));
    }
    for (final name in commands.keys) {
      if (seen.contains(name)) continue;
      result.add(WebsiteCommandButton(
        name: name,
        label: _titleCase(name),
        isAvailable: true,
        isRunning: isRunning(name),
      ));
    }
    return result;
  }

  /// Makes [id] the active website (delegates to the shared editor).
  void selectWebsite(String id) => _editor.selectWebsite(id);

  /// Spawns [name]'s configured command for the active website.
  ///
  /// Expands the command template and `cwd` via [PlaceholderResolver], logs the
  /// expanded line before running, streams stdout (info) / stderr (warning) into
  /// the log, and maps the exit code via the §7 taxonomy. Returns the exit code,
  /// or `null` when the command is unconfigured or a placeholder failed (in
  /// which case nothing is spawned and the reason is logged).
  Future<int?> runCommand(String name, {bool dryRun = false}) async {
    final registry = _editor.registry;
    if (registry == null) {
      _add(WebsiteLogLevel.error, 'No website configuration is loaded.',
          pinned: true);
      return null;
    }
    final website = registry.activeWebsite;
    final template = website.commands[name];
    if (template == null) {
      _add(WebsiteLogLevel.error,
          'Command "$name" is not configured for "${website.id}".',
          pinned: true);
      return null;
    }

    final resolver = PlaceholderResolver.forWebsite(
      registry.config,
      website,
      builtins: _builtins,
      environment: _environment,
      homeDir: _homeDir,
      clock: _clock,
    );

    final String command;
    final String cwd;
    try {
      final resolved = resolver.resolve(template,
          location: 'websites.${website.id}.commands.$name');
      command = dryRun ? '$resolved --dry-run' : resolved;
      cwd = resolver.resolve('{cwd}',
          location: 'websites.${website.id}.cwd');
    } on PlaceholderException catch (e) {
      _add(WebsiteLogLevel.error, 'Cannot run "$name": ${e.message}',
          pinned: true);
      return null;
    }

    final shell = registry.config.defaults.shell;
    final spec = WebsiteCommandSpec(
      executable: shell.isEmpty ? command : shell.first,
      arguments: shell.isEmpty ? const [] : [...shell.skip(1), command],
      workingDirectory: cwd,
      display: command,
    );

    _add(WebsiteLogLevel.info, '\$ $command  (cwd: $cwd)');

    final handle = _runner.start(spec);
    _running[name] = handle;
    notifyListeners();

    await for (final line in handle.output) {
      _add(
        line.stream == ProcessStream.stderr
            ? WebsiteLogLevel.warning
            : WebsiteLogLevel.info,
        line.text,
      );
    }
    final code = await handle.exitCode;
    _running.remove(name);
    _lastRunAt = _clock();
    _logExit(name, code);
    notifyListeners();
    return code;
  }

  /// Kills [name]'s running process, if any (e.g. stopping the dev server).
  Future<void> stop(String name) async {
    final handle = _running[name];
    if (handle == null) return;
    await handle.kill();
  }

  /// Clears the message log.
  void clearLog() {
    _log.clear();
    notifyListeners();
  }

  void _logExit(String name, int code) {
    switch (code) {
      case 0:
        _add(WebsiteLogLevel.info, '✓ $name completed (exit 0)');
      case 1:
        _add(WebsiteLogLevel.error, '✗ $name failed (exit 1)',
            pinned: true);
      case 2:
        _add(WebsiteLogLevel.error,
            '✗ $name usage/config error (exit 2)',
            pinned: true);
      default:
        _add(WebsiteLogLevel.error, '✗ $name exited with code $code',
            pinned: true);
    }
  }

  void _add(WebsiteLogLevel level, String message, {bool pinned = false}) {
    _log.add(WebsiteLogEntry(
      level: level,
      message: message,
      timestamp: _clock(),
      pinned: pinned,
    ));
    notifyListeners();
  }

  void _onEditorChanged() => notifyListeners();

  static String _titleCase(String name) =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

  @override
  void dispose() {
    _editor.removeListener(_onEditorChanged);
    super.dispose();
  }
}
