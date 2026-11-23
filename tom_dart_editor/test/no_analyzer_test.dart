// The editor has no analyzer (forgerestruct9): the analysis is the plugin
// package tom_dart_analysis. The package configuration `flutter pub get`
// resolved for this package (its dependencies and dev dependencies) holds no
// `analyzer`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NA-1: no analyzer among the resolved packages', () {
    final config = File('.dart_tool/package_config.json');
    expect(config.existsSync(), isTrue, reason: 'run flutter pub get');
    final packages = [
      for (final p in (jsonDecode(config.readAsStringSync())
          as Map<String, dynamic>)['packages'] as List<dynamic>)
        (p as Map<String, dynamic>)['name'] as String,
    ];
    expect(packages, contains('tom_text_highlight'));
    expect(packages, isNot(contains('analyzer')));
    expect(packages, isNot(contains('tom_dart_analysis')));
  });
}
