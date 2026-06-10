import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import 'website_control_log.dart';
import 'website_editor_controller.dart';
import 'website_process_runner.dart';

/// Predicate over a dev-server stdout line that returns `true` when the line
/// signals a completed (re)build — the cue to auto-refresh the preview (§5).
///
/// Injected so the exact marker can be tuned per dev server; the default
/// [WebsiteControlController.isRebuildCompleteLine] matches common reload cues.
typedef ServerOutputMatcher = bool Function(String line);

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

/// The §7 commands that (re)generate on-disk content. A successful or failed
/// run of any of these means the website's content/structure on disk may have
/// changed, so the content tree and structure explorer must refresh (§5).
/// Dry-runs are excluded — they never touch disk.
const Set<String> _contentRegeneratingCommands = {
  'generateContent',
  'generateAll',
};

/// Commands that drive `build_runner` and therefore contend for the single
/// `.dart_tool` build lock the dev server already holds while it is running.
/// Running one of these concurrently with the dev server fails with "another
/// process is using build_runner" (§5), so the controller refuses to start it
/// and tells the user to stop the dev server first.
const Set<String> _buildLockCommands = {
  'build',
};

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
    VoidCallback? onRebuildComplete,
    VoidCallback? onContentRegenerated,
    ServerOutputMatcher? rebuildMatcher,
  })  : _editor = editor,
        _runner = runner,
        _builtins = builtins,
        _environment = environment,
        _homeDir = homeDir,
        _clock = clock ?? DateTime.now,
        _onRebuildComplete = onRebuildComplete,
        _onContentRegenerated = onContentRegenerated,
        _rebuildMatcher = rebuildMatcher ?? isRebuildCompleteLine {
    _editor.addListener(_onEditorChanged);
  }

  /// The §7 command that runs the long-lived dev server.
  static const String serveCommand = 'serveStart';

  final WebsiteEditorController _editor;
  final WebsiteProcessRunner _runner;
  final Map<String, String> _builtins;
  final Map<String, String>? _environment;
  final String? _homeDir;
  final DateTime Function() _clock;
  final VoidCallback? _onRebuildComplete;
  final VoidCallback? _onContentRegenerated;
  final ServerOutputMatcher _rebuildMatcher;

  final List<WebsiteLogEntry> _log = [];
  final Map<String, WebsiteProcessHandle> _running = {};
  DateTime? _lastRunAt;

  WebsiteProcessHandle? _serverHandle;
  String? _serverWebsiteId;
  Future<void>? _serverDone;

  /// Matches common dev-server "(re)build complete / reloading" stdout cues.
  /// Best-effort default; the precise `jaspr serve` marker is confirmed against
  /// the live website in §9.7. Injectable via `rebuildMatcher`.
  static final RegExp _defaultRebuildPattern = RegExp(
    r'reload|rebuilt|recompiled|compiled|serving at|served',
    caseSensitive: false,
  );

  /// The default [ServerOutputMatcher] used when none is injected.
  static bool isRebuildCompleteLine(String line) =>
      _defaultRebuildPattern.hasMatch(line);

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

  /// `true` while the dev server child process is running.
  bool get isServerRunning => _serverHandle != null;

  /// The id of the website the dev server is running for, or `null`.
  String? get serverWebsiteId => _serverWebsiteId;

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
    // A build_runner command can't share the build lock with the dev server.
    // Refuse early with an actionable message instead of letting build_runner
    // fail deep inside the process with the opaque "another process is using
    // build_runner" error (§5).
    if (_buildLockCommands.contains(name) && isServerRunning) {
      _add(
        WebsiteLogLevel.error,
        'Cannot run "$name" while the dev server is running — both use '
        'build_runner and share one build lock. Stop the dev server first.',
        pinned: true,
      );
      return null;
    }

    final spec = _buildSpec(name, dryRun: dryRun);
    if (spec == null) return null;

    _add(WebsiteLogLevel.info, '\$ ${spec.display}  (cwd: ${spec.workingDirectory})');

    final handle = _runner.start(spec);
    _running[name] = handle;
    notifyListeners();

    await for (final line in handle.output) {
      _add(_levelFor(line.stream), line.text);
    }
    final code = await handle.exitCode;
    _running.remove(name);
    _lastRunAt = _clock();
    _logExit(name, code);
    notifyListeners();
    // §5: a real (non dry-run) generate run may have changed content on disk —
    // signal the host so it can refresh the content tree + structure explorer.
    // Fire regardless of exit code: a partial/failed run still mutates disk, and
    // the trees should reflect reality, not the last clean state.
    if (!dryRun && _contentRegeneratingCommands.contains(name)) {
      _onContentRegenerated?.call();
    }
    return code;
  }

  /// Kills [name]'s running one-shot process, if any.
  Future<void> stop(String name) async {
    final handle = _running[name];
    if (handle == null) return;
    await handle.kill();
  }

  /// Starts the long-lived dev server (`serveStart`) for the active website.
  ///
  /// Unlike [runCommand] this does **not** block on the process exit: the
  /// handle is tracked, its output streamed into the log, and each stdout line
  /// matching the rebuild marker triggers the injected `onRebuildComplete`
  /// (auto-refresh, §5). Returns `false` (and logs) when a server is already
  /// running or `serveStart` is unconfigured / unresolvable.
  Future<bool> startServer() async {
    if (_serverHandle != null) return false;
    final spec = _buildSpec(serveCommand);
    if (spec == null) return false;

    _add(WebsiteLogLevel.info,
        '\$ ${spec.display}  (cwd: ${spec.workingDirectory})');
    final handle = _runner.start(spec);
    _serverHandle = handle;
    _serverWebsiteId = _editor.activeWebsiteId;
    notifyListeners();
    _serverDone = _superviseServer(handle);
    return true;
  }

  /// Stops the running dev server (if any) and waits for it to exit.
  Future<void> stopServer() async {
    final handle = _serverHandle;
    if (handle == null) return;
    await handle.kill();
    await _serverDone;
  }

  /// Restarts the dev server: stops the current child (if any), then starts a
  /// fresh one for the active website.
  Future<bool> restartServer() async {
    await stopServer();
    return startServer();
  }

  /// Watches the server's output (streaming into the log + firing the rebuild
  /// callback) and clears the server state when it exits.
  Future<void> _superviseServer(WebsiteProcessHandle handle) async {
    final outputDone = handle.output.forEach((line) {
      _add(_levelFor(line.stream), line.text);
      if (line.stream == ProcessStream.stdout && _rebuildMatcher(line.text)) {
        _onRebuildComplete?.call();
      }
    });
    final code = await handle.exitCode;
    await outputDone;
    _serverHandle = null;
    _serverWebsiteId = null;
    _serverDone = null;
    _add(code == 0 ? WebsiteLogLevel.info : WebsiteLogLevel.warning,
        'dev server stopped (exit $code)');
    notifyListeners();
  }

  /// Resolves [name]'s command template + `cwd` for the active website into a
  /// spawnable [WebsiteCommandSpec], logging (and returning `null`) when no
  /// config is loaded, the command is unconfigured, or a placeholder fails.
  WebsiteCommandSpec? _buildSpec(String name, {bool dryRun = false}) {
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

    try {
      final resolved = resolver.resolve(template,
          location: 'websites.${website.id}.commands.$name');
      final command = dryRun ? '$resolved --dry-run' : resolved;
      final cwd =
          resolver.resolve('{cwd}', location: 'websites.${website.id}.cwd');
      final shell = registry.config.defaults.shell;
      return WebsiteCommandSpec(
        executable: shell.isEmpty ? command : shell.first,
        arguments: shell.isEmpty ? const [] : [...shell.skip(1), command],
        workingDirectory: cwd,
        display: command,
      );
    } on PlaceholderException catch (e) {
      _add(WebsiteLogLevel.error, 'Cannot run "$name": ${e.message}',
          pinned: true);
      return null;
    }
  }

  static WebsiteLogLevel _levelFor(ProcessStream stream) =>
      stream == ProcessStream.stderr
          ? WebsiteLogLevel.warning
          : WebsiteLogLevel.info;

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
    // Don't leave the dev server orphaned when the module deactivates.
    unawaited(_serverHandle?.kill());
    super.dispose();
  }
}
