import 'package:path/path.dart' as p;
import 'package:tom_dart_editor_bundler/tom_dart_editor_bundler.dart';
import 'package:test/test.dart';

BundlerConfig _config({String outDir = 'assets/summaries'}) => BundlerConfig(
      outDir: outDir,
      generatedHelper: 'lib/generated/summary_scopes.g.dart',
      sdkSummary: 'sdk_summary.sum',
      bundles: const [
        SummaryBundleSpec(name: 'dart-plain', sdkOnly: true),
        SummaryBundleSpec(name: 'd4rt-flutter', packages: ['pkgs/x']),
      ],
    );

void main() {
  group('SummaryAssetLayout segments', () {
    test('the SDK summary sits directly under out-dir', () {
      expect(SummaryAssetLayout.sdkSummarySegments(_config()),
          ['assets/summaries', 'sdk_summary.sum']);
    });

    test('a package scope gets its own sub-dir under out-dir', () {
      final config = _config();
      expect(
        SummaryAssetLayout.packagesSegments(config, config.bundles[1]),
        ['assets/summaries', 'd4rt-flutter', 'packages.sum'],
      );
    });

    test('an sdk-only scope has no packages.sum at all', () {
      final config = _config();
      expect(SummaryAssetLayout.packagesSegments(config, config.bundles[0]),
          isNull);
    });
  });

  group('SummaryAssetLayout.assetKey', () {
    test('joins with forward slashes and flattens embedded separators', () {
      expect(SummaryAssetLayout.assetKey(['assets/summaries', 'a', 'b.sum']),
          'assets/summaries/a/b.sum');
    });

    test('normalizes a backslash-configured out-dir to a POSIX asset key', () {
      // Flutter asset keys are POSIX whatever the host OS, so a Windows-style
      // out-dir must not leak backslashes into the generated helper.
      final config = _config(outDir: r'assets\summaries');
      expect(
        SummaryAssetLayout.assetKey(
            SummaryAssetLayout.packagesSegments(config, config.bundles[1])!),
        'assets/summaries/d4rt-flutter/packages.sum',
      );
    });

    test('drops empty segments rather than emitting a doubled slash', () {
      expect(SummaryAssetLayout.assetKey(['assets//summaries', '', 'x.sum']),
          'assets/summaries/x.sum');
    });
  });

  group('SummaryAssetLayout.filePath', () {
    test('resolves a relative out-dir against the base dir', () {
      final config = _config();
      expect(
        SummaryAssetLayout.filePath(
            p.join('any', 'base'), SummaryAssetLayout.sdkSummarySegments(config)),
        p.normalize(p.join('any', 'base', 'assets', 'summaries',
            'sdk_summary.sum')),
      );
    });

    test('honors an absolute out-dir verbatim', () {
      final absolute = p.absolute(p.join('elsewhere', 'summaries'));
      final config = _config(outDir: absolute);
      expect(
        SummaryAssetLayout.filePath(
            p.join('any', 'base'), SummaryAssetLayout.sdkSummarySegments(config)),
        p.join(absolute, 'sdk_summary.sum'),
      );
    });
  });
}
