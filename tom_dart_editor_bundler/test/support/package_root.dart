import 'dart:isolate';

import 'package:path/path.dart' as p;

/// This package's own folder, found through the package configuration.
///
/// Not `Directory.current`: the test files of one run share a process, and
/// `tom_dart_editor_bundler_test.dart` moves the process into a temporary
/// project while it drives the tool, so a test in another file that read the
/// current directory then would look in the wrong place.
final String bundlerPackageRoot = p.dirname(
  p.dirname(
    Isolate.resolvePackageUriSync(
      Uri.parse('package:tom_dart_editor_bundler/tom_dart_editor_bundler.dart'),
    )!.toFilePath(),
  ),
);
