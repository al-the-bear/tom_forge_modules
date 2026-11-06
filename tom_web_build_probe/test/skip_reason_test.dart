/// When the web-build test runs and why it does not: every skip names what
/// would make it run, and a set-up app with a flutter runs.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:tom_web_build_probe/tom_web_build_probe.dart';

void main() {
  late Directory scratch;
  late Directory app;
  late Map<String, String> env;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('web_build_probe');
    app = Directory(p.join(scratch.path, 'app'))..createSync();
    Directory(p.join(app.path, 'web')).createSync();
    File(p.join(app.path, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{}');
    final flutter = File(
      p.join(scratch.path, 'flutter', 'bin',
          Platform.isWindows ? 'flutter.bat' : 'flutter'),
    )..createSync(recursive: true);
    env = {'FLUTTER_ROOT': flutter.parent.parent.path};
  });
  tearDown(() => scratch.deleteSync(recursive: true));

  String? reason() =>
      webBuildSkipReason(appDirectory: app.path, environment: env);

  test('WB-1: a set-up companion app with a flutter runs', () {
    expect(reason(), isNull);
  });

  test('WB-2: TOM_SKIP_WEB_BUILD=1 skips, and says how to measure', () {
    env['TOM_SKIP_WEB_BUILD'] = '1';
    expect(reason(), contains('unset it'));
  });

  test('WB-3: a missing companion app skips, naming where it was looked for',
      () {
    app.deleteSync(recursive: true);
    expect(reason(), contains(app.path));
  });

  test('WB-4: an app without web/ skips, naming the command that adds it', () {
    Directory(p.join(app.path, 'web')).deleteSync();
    expect(reason(), contains('flutter create --platforms=web'));
  });

  test('WB-5: an app without resolved packages skips, naming pub get', () {
    Directory(p.join(app.path, '.dart_tool')).deleteSync(recursive: true);
    expect(reason(), contains('flutter pub get'));
  });

  test('WB-6: no flutter at FLUTTER_ROOT skips, naming what it was', () {
    env['FLUTTER_ROOT'] = p.join(scratch.path, 'nowhere');
    expect(reason(), contains('nowhere'));
    env.remove('FLUTTER_ROOT');
    expect(reason(), contains('unset'));
  });
}
