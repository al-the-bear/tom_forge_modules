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
      expect(dartEditorBundlerTool.version, DartEditorBundlerVersionInfo.version);
      expect(dartEditorBundlerTool.versionString, contains('tom_dart_editor_bundler'));
    });

    test('declares the --config and --bundle options', () {
      final names = dartEditorBundlerTool.globalOptions.map((o) => o.name).toSet();
      expect(names, containsAll(<String>['config', 'bundle']));
    });
  });

  group('executors', () {
    test('single command registered under the default key', () {
      final executors = createDartEditorBundlerExecutors();
      expect(executors.keys, equals({kDartEditorBundlerCommand}));
      expect(executors[kDartEditorBundlerCommand], isA<DartEditorBundlerExecutor>());
    });
  });
}
