/// The committed scope-init helpers in this workspace's consumer apps are not
/// stale relative to their own `buildkit.yaml`.
///
/// The helper is a *committed* generated file, and it is the file that names the
/// asset keys the app loads bundles by. If a scope is added to a config and the
/// bundler is never re-run, the committed helper simply does not register that
/// scope — and an unregistered scope degrades to a plain text field with no
/// error anywhere. That is the same silent-failure shape the layout split had,
/// one step further out, so it gets the same treatment: recompute and compare.
///
/// Recomputing is free here — `generateScopeInitHelper` is pure, with no
/// analyzer and no SDK — so this needs no stamp file, only the config.
///
/// Consumers are *discovered*, not listed: any sibling package under the same
/// parent directory that declares a `dart-editor-bundler` block is checked. The
/// bundler therefore does not have to know that `tom_specs_editor` exists, and a
/// second consumer is covered the day it appears.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_dart_editor_bundler/tom_dart_editor_bundler.dart';
import 'package:test/test.dart';

/// Sibling package dirs whose `buildkit.yaml` declares a bundler config.
List<Directory> _consumerDirs() {
  final siblings = Directory(p.dirname(Directory.current.absolute.path));
  if (!siblings.existsSync()) return const [];
  final found = <Directory>[];
  for (final entry in siblings.listSync(followLinks: false)) {
    if (entry is! Directory) continue;
    if (p.equals(entry.path, Directory.current.absolute.path)) continue;
    final config = File(p.join(entry.path, TomBundlerFiles.buildkit));
    if (!config.existsSync()) continue;
    if (!config.readAsStringSync().contains(kBundlerConfigKey)) continue;
    found.add(entry);
  }
  return found;
}

void main() {
  final consumers = _consumerDirs();

  test('at least one consumer app was found to check', () {
    // "No findings" and "nothing was looked at" print the same; this separates
    // them, so a relocated consumer fails loudly instead of quietly checking
    // nothing.
    expect(consumers, isNotEmpty,
        reason: 'no sibling package declares a "$kBundlerConfigKey" block — '
            'has the consumer app moved out of this directory?');
  });

  for (final dir in consumers) {
    final name = p.basename(dir.path);
    test('$name: the committed scope-init helper matches its buildkit.yaml',
        () {
      final loaded = loadBundlerConfig(projectDir: dir.path);
      final helper = File(p.join(dir.path, loaded.config.generatedHelper));
      expect(helper.existsSync(), isTrue,
          reason: '${loaded.config.generatedHelper} is declared as the '
              'generated-helper but is not committed in $name');
      expect(
        helper.readAsStringSync(),
        generateScopeInitHelper(loaded.config),
        reason: '$name\'s committed helper is stale — re-run the bundler:\n'
            '  cd ${dir.path} && dart run '
            '../tom_dart_editor_bundler/bin/dart_editor_bundler.dart '
            '--config buildkit.yaml',
      );
    });
  }
}
