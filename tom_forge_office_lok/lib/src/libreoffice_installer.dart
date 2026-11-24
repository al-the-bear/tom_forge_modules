import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:tom_office_editor/io.dart';
import 'package:tom_office_editor/tom_office_editor.dart';

import 'forge_office_trail.dart';

/// Starts an install command (default: `Process.start`): the install
/// runner's one door to processes, so a test gives a fake command.
typedef ForgeInstallProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      Map<String, String>? environment,
    });

Future<Process> _startProcess(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) => Process.start(executable, arguments, environment: environment);

/// What a managed download fetches over HTTP (default:
/// [ForgeInstallHttpClient]); a test gives a fake.
abstract class ForgeInstallHttp {
  /// A const constructor for subclasses.
  const ForgeInstallHttp();

  /// The text at [url] (the published hash).
  Future<String> getText(Uri url);

  /// Writes what [url] answers into [target]; stops with
  /// [ForgeInstallCancelled] once [cancelled] says so. [progress] hears the
  /// bytes received and the total, when known.
  Future<void> download(
    Uri url,
    File target, {
    required bool Function() cancelled,
    void Function(int received, int? total)? progress,
  });
}

/// The user stopped the run.
class ForgeInstallCancelled implements Exception {
  /// The exception.
  const ForgeInstallCancelled();

  @override
  String toString() => 'Stopped.';
}

/// [ForgeInstallHttp] over `dart:io`'s [HttpClient] (redirects followed, as
/// TDF's download server sends each file to a mirror).
class ForgeInstallHttpClient extends ForgeInstallHttp {
  /// The client.
  const ForgeInstallHttpClient();

  Future<HttpClientResponse> _get(HttpClient client, Uri url) async {
    final response = await (await client.getUrl(url)).close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    return response;
  }

  @override
  Future<String> getText(Uri url) async {
    final client = HttpClient();
    try {
      final response = await _get(client, url);
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> download(
    Uri url,
    File target, {
    required bool Function() cancelled,
    void Function(int received, int? total)? progress,
  }) async {
    final client = HttpClient();
    final sink = target.openWrite();
    try {
      final response = await _get(client, url);
      final total = response.contentLength < 0 ? null : response.contentLength;
      var received = 0;
      await for (final chunk in response) {
        if (cancelled()) throw const ForgeInstallCancelled();
        sink.add(chunk);
        received += chunk.length;
        progress?.call(received, total);
      }
    } finally {
      await sink.close();
      client.close(force: true);
    }
  }
}

/// [path] (a `PATH` value) with the folders a GUI app on [platform] often
/// lacks added at its end: on macOS Homebrew's `/opt/homebrew/bin` (Apple
/// silicon) and `/usr/local/bin` (Intel), since an app started from Finder
/// gets launchd's short `PATH`. Other platforms: [path] as it is.
String forgeInstallSearchPath(String path, TomToolPlatform platform) {
  if (platform != TomToolPlatform.macos) return path;
  final dirs = path.split(':').where((d) => d.isNotEmpty).toList();
  for (final extra in const ['/opt/homebrew/bin', '/usr/local/bin']) {
    if (!dirs.contains(extra)) dirs.add(extra);
  }
  return dirs.join(':');
}

/// The PowerShell arguments that run [executable] with [arguments] in an
/// elevated PowerShell (Chocolatey's way, [TomInstallElevation.elevatedShell]):
/// `Start-Process powershell -Verb RunAs -Wait -PassThru` asks for the rights
/// (UAC), the elevated shell runs the command with all its output redirected
/// into [logPath] (an elevated window's output cannot be piped back), and its
/// exit code becomes the outer shell's. The inner command goes as
/// `-EncodedCommand`, so no argument needs quoting twice.
List<String> forgeElevatedPowerShellArguments(
  String executable,
  List<String> arguments,
  String logPath,
) {
  String q(String s) => "'${s.replaceAll("'", "''")}'";
  final inner =
      '& ${q(executable)} ${arguments.map(q).join(' ')} '
      '*> ${q(logPath)}; exit \$LASTEXITCODE';
  final encoded = base64Encode([
    for (final unit in inner.codeUnits) ...[unit & 0xff, unit >> 8],
  ]);
  return [
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    '\$p = Start-Process -FilePath powershell.exe -ArgumentList '
        "'-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded' "
        '-Verb RunAs -Wait -PassThru; exit \$p.ExitCode',
  ];
}

/// The files under [root] matching [pattern] (`/`-separated segments, `*`
/// within a segment), sorted.
List<String> forgeInstallGlob(Directory root, String pattern) {
  var current = [root.path];
  for (final segment in pattern.split('/').where((s) => s.isNotEmpty)) {
    final re = RegExp('^${segment.split('*').map(RegExp.escape).join('.*')}\$');
    current = [
      for (final dir in current)
        if (Directory(dir).existsSync())
          for (final entry in Directory(dir).listSync(followLinks: false))
            if (re.hasMatch(entry.path.split(Platform.pathSeparator).last))
              entry.path,
    ];
  }
  return current.where(FileSystemEntity.isFileSync).toList()..sort();
}

/// Runs LibreOffice install routes for the install help (DPLD-3): what
/// `TomLibreOfficeInstallHelp.onInstall` calls once the user confirmed a
/// route.
///
/// - A package-manager route runs its commands in order (the next only after
///   the one before exited 0), elevated the route's way: Homebrew as the
///   user; winget as the user, its installer raising UAC; Chocolatey in an
///   elevated PowerShell ([forgeElevatedPowerShellArguments]); apt, dpkg and
///   rpm through `pkexec`, as their commands carry it.
/// - A managed download (Linux: TDF's `.deb` / `.rpm` archive) fetches the
///   archive into a scratch folder under the system's temporary folder,
///   fetches its published SHA-256 (`<url>.sha256`) and compares it — a
///   mismatch stops it, nothing is unpacked or run — unpacks it with
///   `tar -xzf`, collects the packages and runs the route's commands with
///   them; the scratch folder is removed at the end.
///
/// Every command runs with `PATH` extended by [forgeInstallSearchPath] and
/// its executable found on it. Its output streams into the run; *Stop*
/// kills the running process. When the run has ended, `onExit` runs (the
/// module: detection again).
class ForgeLibreOfficeInstaller {
  /// The runner. Each parameter defaults to the desktop's: processes through
  /// `Process.start`, HTTP through [ForgeInstallHttpClient], this process's
  /// environment, the platform this runs on, files on disk. Tests give
  /// fakes; a test never runs a real install.
  ForgeLibreOfficeInstaller({
    ForgeInstallProcessStarter? startProcess,
    ForgeInstallHttp? http,
    Map<String, String>? environment,
    TomToolPlatform? platform,
    bool Function(String path)? executableExists,
    this.tool = TomLibreOfficeTool.standard,
  }) : startProcess = startProcess ?? _startProcess,
       http = http ?? const ForgeInstallHttpClient(),
       platform =
           platform ??
           TomToolPlatform.fromName(Platform.operatingSystem) ??
           TomToolPlatform.macos,
       _environment = environment,
       _executableExists = executableExists;

  /// Starts the commands.
  final ForgeInstallProcessStarter startProcess;

  /// Fetches a managed download's archive and hash.
  final ForgeInstallHttp http;

  /// The platform whose routes are offered and run.
  final TomToolPlatform platform;

  /// The descriptor whose routes are offered.
  final TomLibreOfficeTool tool;

  final Map<String, String>? _environment;
  final bool Function(String path)? _executableExists;

  bool get _windows => platform == TomToolPlatform.windows;

  /// `PATH` as the commands get it and their executables are looked up on.
  late final String searchPath = forgeInstallSearchPath(
    (_environment ?? Platform.environment)['PATH'] ??
        (_environment ?? Platform.environment)['Path'] ??
        '',
    platform,
  );

  /// The platform's routes.
  List<TomInstallRoute> get routes => tool.routes(platform);

  /// Which of [routes] can run here, by route id: their package managers on
  /// [searchPath] (`installRouteAvailability`). Read once.
  late final Map<String, bool> routeAvailability = _availability();

  Map<String, bool> _availability() {
    if (_executableExists == null) {
      return installRouteAvailability(
        routes,
        searchPath: searchPath,
        platform: platform,
      );
    }
    return {
      for (final route in routes)
        route.id:
            route.packageManager?.executables.every((e) => resolve(e) != e) ??
            true,
    };
  }

  bool _exists(String path) =>
      (_executableExists ?? (p) => File(p).existsSync())(path);

  /// [name]'s full path on [searchPath] (on Windows also with `.exe`,
  /// `.cmd`, `.bat`), or [name] itself when it is not there.
  String resolve(String name) {
    if (name.contains('/') || name.contains(r'\')) return name;
    final separator = _windows ? ';' : ':';
    final names = _windows
        ? [name, '$name.exe', '$name.cmd', '$name.bat']
        : [name];
    for (final dir in searchPath.split(separator)) {
      if (dir.isEmpty) continue;
      for (final n in names) {
        final candidate = _windows ? '$dir\\$n' : '$dir/$n';
        if (_exists(candidate)) return candidate;
      }
    }
    return name;
  }

  /// Runs [route] and answers the run the install help shows; [onExit] runs
  /// once it has ended.
  TomLibreOfficeInstallRun run(
    TomInstallRoute route, {
    Future<void> Function()? onExit,
  }) {
    late final _InstallJob job;
    final controller = TomLibreOfficeInstallRunController(
      onCancel: () => job.cancel(),
    );
    job = _InstallJob(this, route, controller);
    unawaited(job.start(onExit));
    return controller.run;
  }
}

/// One run of a route.
class _InstallJob {
  _InstallJob(this.installer, this.route, this.controller);

  final ForgeLibreOfficeInstaller installer;
  final TomInstallRoute route;
  final TomLibreOfficeInstallRunController controller;

  Process? _process;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled || controller.isFinished) return;
    forgeOfficeTrail('install ${route.id}: stop');
    _cancelled = true;
    _process?.kill();
  }

  Future<void> start(Future<void> Function()? onExit) async {
    forgeOfficeTrail('install ${route.id}: start (${route.kind.name})');
    (int, String?) end;
    try {
      end = switch (route.kind) {
        TomInstallRouteKind.managedDownload => await _managed(),
        TomInstallRouteKind.packageManager => await _commands(route.commands),
        TomInstallRouteKind.byHand => (
          -1,
          'This route is installed by hand from the download page.',
        ),
      };
    } on ForgeInstallCancelled {
      end = (-1, 'Stopped.');
    } catch (e, s) {
      forgeOfficeReport(e, s, 'installing LibreOffice (${route.id})');
      end = (-1, '$e');
    }
    if (_cancelled) end = (-1, 'Stopped.');
    forgeOfficeTrail('install ${route.id}: exit ${end.$1}');
    controller.finish(end.$1, message: end.$2);
    if (onExit == null) return;
    try {
      await onExit();
    } catch (e, s) {
      forgeOfficeReport(e, s, 'detecting LibreOffice after the install');
    }
  }

  /// Runs [commands] in order, each only after the one before exited 0.
  Future<(int, String?)> _commands(List<List<String>> commands) async {
    for (final argv in commands) {
      if (_cancelled) throw const ForgeInstallCancelled();
      final code = await _run(argv, elevate: true);
      if (_cancelled) throw const ForgeInstallCancelled();
      if (code != 0) return (code, '${argv.join(' ')} exited with $code');
    }
    return (0, null);
  }

  /// Runs one command; answers its exit code.
  Future<int> _run(List<String> argv, {required bool elevate}) async {
    var executable = installer.resolve(argv.first);
    var arguments = argv.sublist(1);
    File? log;
    Directory? logDir;
    if (elevate) {
      switch (route.elevation) {
        case TomInstallElevation.elevatedShell:
          logDir = await Directory.systemTemp.createTemp('forge_install_');
          log = File('${logDir.path}${Platform.pathSeparator}install.log');
          arguments = forgeElevatedPowerShellArguments(
            executable,
            arguments,
            log.path,
          );
          executable = installer.resolve('powershell');
        case TomInstallElevation.pkexec when argv.first != 'pkexec':
          arguments = [argv.first, ...arguments];
          executable = installer.resolve('pkexec');
        case _:
          break;
      }
    }
    controller.add('\$ ${argv.join(' ')}\n');
    forgeOfficeTrail('install ${route.id}: run ${argv.first}');
    try {
      final process = await installer.startProcess(
        executable,
        arguments,
        environment: {'PATH': installer.searchPath},
      );
      _process = process;
      if (_cancelled) process.kill();
      const decoder = Utf8Decoder(allowMalformed: true);
      final out = process.stdout
          .transform(decoder)
          .listen(controller.add)
          .asFuture<void>();
      final err = process.stderr
          .transform(decoder)
          .listen(controller.add)
          .asFuture<void>();
      final code = await process.exitCode;
      await Future.wait([out, err]).catchError((_) => const <void>[]);
      _process = null;
      if (log != null && log.existsSync()) {
        controller.add(log.readAsStringSync());
      }
      return code;
    } finally {
      if (logDir != null) {
        try {
          await logDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// A managed download: fetch, check, unpack, install.
  Future<(int, String?)> _managed() async {
    final download = route.download;
    if (download == null) return (-1, 'The route names no download.');
    final scratch = await Directory.systemTemp.createTemp('forge_libreoffice_');
    final sep = Platform.pathSeparator;
    try {
      final archive = File('${scratch.path}$sep${download.fileName()}');
      controller.add('Downloading ${download.url()}\n');
      var shown = -1;
      await installer.http.download(
        Uri.parse(download.url()),
        archive,
        cancelled: () => _cancelled,
        progress: (received, total) {
          if (total == null || total == 0) return;
          final tenth = received * 10 ~/ total;
          if (tenth == shown) return;
          shown = tenth;
          controller.add('  ${tenth * 10} % of ${total ~/ 1048576} MB\n');
        },
      );
      if (_cancelled) throw const ForgeInstallCancelled();
      controller.add('Checking its SHA-256 against ${download.hashUrl()}\n');
      final published = TomDownloadHashCheck.digestIn(
        await installer.http.getText(Uri.parse(download.hashUrl())),
      );
      if (published == null) {
        return (-1, 'The published SHA-256 could not be read.');
      }
      final actual = (await sha256.bind(archive.openRead()).first).toString();
      if (actual != published) {
        forgeOfficeTrail('install ${route.id}: SHA-256 mismatch');
        return (
          -1,
          'The SHA-256 does not match (published $published, downloaded '
              '$actual); nothing was installed',
        );
      }
      controller.add('SHA-256 matches: $actual\n');
      final unpacked = Directory('${scratch.path}${sep}unpacked');
      await unpacked.create();
      final tar = await _run([
        'tar',
        '-xzf',
        archive.path,
        '-C',
        unpacked.path,
      ], elevate: false);
      if (_cancelled) throw const ForgeInstallCancelled();
      if (tar != 0) return (tar, 'Unpacking the archive failed');
      final packages = forgeInstallGlob(unpacked, download.packageGlob);
      if (packages.isEmpty) {
        return (-1, 'The archive holds no ${download.packageGlob}');
      }
      controller.add('${packages.length} packages to install\n');
      return await _commands(route.commandsWith(packages));
    } finally {
      try {
        await scratch.delete(recursive: true);
      } catch (_) {}
    }
  }
}
