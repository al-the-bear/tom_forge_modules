import 'dart:convert';
import 'dart:io';

/// Makes `flutter_pty`'s native library loadable under `flutter test`.
///
/// `flutter test` does not build an FFI plugin's native code, and
/// `flutter_pty` opens its library by the relative path
/// `flutter_pty.framework/flutter_pty` (macOS) or `libflutter_pty.so`
/// (Linux), which the dynamic loader resolves against the current
/// directory. This compiles the plugin's C source with `clang` into
/// `build/test_native/` of this package and makes that the current
/// directory; [restore] goes back.
///
/// Returns null when the library is ready, else why it is not (no `clang`,
/// an unsupported platform, the source not found, a failed compile), for
/// the test to skip with.
class PtyNativeLibrary {
  PtyNativeLibrary._(this._previous);

  final Directory _previous;

  /// Builds the library (once per run) and changes into its folder.
  static Future<(PtyNativeLibrary?, String?)> prepare() async {
    if (!Platform.isMacOS && !Platform.isLinux) {
      return (null, 'PTY test runs on macOS and Linux only');
    }
    final packageRoot = Directory.current.absolute;
    final source = await _pluginSource(packageRoot);
    if (source == null) {
      return (null, 'flutter_pty not found in .dart_tool/package_config.json');
    }
    final outDir = Directory('${packageRoot.path}/build/test_native');
    final target = Platform.isMacOS
        ? File('${outDir.path}/flutter_pty.framework/flutter_pty')
        : File('${outDir.path}/libflutter_pty.so');
    if (!target.existsSync()) {
      target.parent.createSync(recursive: true);
      final ProcessResult result;
      try {
        result = await Process.run('clang', [
          '-shared',
          '-fPIC',
          '-DDART_SHARED_LIB',
          '-o',
          target.path,
          '${source.path}/src/flutter_pty.c',
          if (Platform.isLinux) '-lutil',
        ]);
      } on ProcessException catch (e) {
        return (null, 'clang not available: ${e.message}');
      }
      if (result.exitCode != 0) {
        return (null, 'clang failed: ${result.stderr}');
      }
    }
    final previous = Directory.current;
    Directory.current = outDir;
    return (PtyNativeLibrary._(previous), null);
  }

  /// Goes back to the directory [prepare] left.
  void restore() => Directory.current = _previous;

  static Future<Directory?> _pluginSource(Directory packageRoot) async {
    final config = File('${packageRoot.path}/.dart_tool/package_config.json');
    if (!config.existsSync()) return null;
    final json =
        jsonDecode(await config.readAsString()) as Map<String, dynamic>;
    for (final entry in json['packages'] as List<dynamic>) {
      final package = entry as Map<String, dynamic>;
      if (package['name'] != 'flutter_pty') continue;
      final root = Uri.parse(package['rootUri'] as String);
      final dir = Directory.fromUri(
        root.isAbsolute ? root : config.parent.uri.resolveUri(root),
      );
      return dir.existsSync() ? dir : null;
    }
    return null;
  }
}
