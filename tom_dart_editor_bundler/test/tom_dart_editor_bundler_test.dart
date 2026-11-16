import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_build_base/tom_build_base_v2.dart';
import 'package:tom_dart_editor_bundler/tom_dart_editor_bundler.dart';
import 'package:test/test.dart';

void main() {
  group('dartEditorBundlerTool definition', () {
    test('name matches the buildkit config key', () {
      expect(dartEditorBundlerTool.name, 'dart-editor-bundler');
    });

    test('is a single-command tool', () {
      expect(dartEditorBundlerTool.mode, ToolMode.singleCommand);
    });

    test('reports the package version', () {
      expect(
        dartEditorBundlerTool.version,
        DartEditorBundlerVersionInfo.version,
      );
      expect(
        dartEditorBundlerTool.versionString,
        contains('tom_dart_editor_bundler'),
      );
    });

    test('declares the --config and --bundle options', () {
      final names = dartEditorBundlerTool.globalOptions
          .map((o) => o.name)
          .toSet();
      expect(names, containsAll(<String>['config', 'bundle']));
    });
  });

  group('executors', () {
    test('single command registered under the default key', () {
      final executors = createDartEditorBundlerExecutors();
      expect(executors.keys, equals({kDartEditorBundlerCommand}));
      expect(
        executors[kDartEditorBundlerCommand],
        isA<DartEditorBundlerExecutor>(),
      );
    });
  });

  group('runs through ToolRunner', () {
    late Directory dir;
    late String previous;
    late StringBuffer out;

    setUp(() {
      previous = Directory.current.path;
      dir = Directory(
        Directory.systemTemp
            .createTempSync('bundler_run_')
            .resolveSymbolicLinksSync(),
      );
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: host\n');
      File(p.join(dir.path, 'buildkit.yaml')).writeAsStringSync('''
dart-editor-bundler:
  out-dir: out
  generated-helper: lib/scopes.g.dart
  bundles:
    - name: dart-plain
      sdk-only: true
''');
      Directory.current = dir.path;
      out = StringBuffer();
    });
    tearDown(() {
      Directory.current = previous;
      dir.deleteSync(recursive: true);
    });

    Future<(ToolResult, String)> run(List<String> args) async {
      final lines = <String>[];
      final result = await runZoned(
        () => ToolRunner(
          tool: dartEditorBundlerTool,
          executors: createDartEditorBundlerExecutors(),
          output: out,
        ).run(args),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => lines.add(line),
        ),
      );
      return (result, '$out${lines.join('\n')}');
    }

    test(
      '-n names what it would build and writes nothing [2026-11-16]',
      () async {
        final (result, text) = await run(['-n']);
        expect(result.success, isTrue, reason: text);
        expect(text, contains('[DRY RUN] would build'));
        expect(text, contains(p.join('out', 'sdk_summary.sum')));
        expect(text, contains('dart-plain'));
        expect(text, contains(p.join('lib', 'scopes.g.dart')));
        expect(Directory(p.join(dir.path, 'out')).existsSync(), isFalse);
        expect(
          File(p.join(dir.path, 'lib', 'scopes.g.dart')).existsSync(),
          isFalse,
        );
      },
    );

    test('a config that is not there fails the run [2026-11-16]', () async {
      final (result, text) = await run(['--config', 'missing.yaml']);
      expect(result.success, isFalse, reason: text);
    });
  });
}
