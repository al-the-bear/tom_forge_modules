/// tom_dart_editor_bundler — Command executor.
///
/// Single-command executor that reads the `dart-editor-bundler` config from the
/// processed project (or `--config`), generates the summary `.sum` asset tree
/// via [BundleGenerator], and reports the outcome. The generated scope-init
/// helper file is written by a later plan item (6); this item owns the `.sum`
/// emission only.
library;

import 'dart:io';

import 'package:tom_build_base/tom_build_base_v2.dart';

import 'bundle_generator.dart';
import 'bundler_config.dart';

/// Executor key for the bundler's single command.
const String kDartEditorBundlerCommand = 'default';

/// Default (single-command) executor for the bundler.
class DartEditorBundlerExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    final verbose = args.verbose;
    try {
      final loaded = loadBundlerConfig(
        projectDir: context.path,
        configPath: args.configPath,
      );
      final bundleFilter = args.extraOptions['bundle'] as String?;

      final result = await BundleGenerator().generate(
        config: loaded.config,
        baseDir: loaded.baseDir,
        bundleFilter: bundleFilter,
        log: verbose ? print : null,
      );

      // The single-command ToolRunner path prints only the folder header and the
      // exit code, so surface the outcome here for an informative CLI.
      final message = _summarize(result);
      stdout.writeln(message);
      return ItemResult.success(
        path: context.path,
        name: context.name,
        message: message,
      );
    } on BundlerConfigException catch (e) {
      stderr.writeln('dart-editor-bundler: ${e.toString()}');
      return ItemResult.failure(
        path: context.path,
        name: context.name,
        error: e.toString(),
      );
    }
  }

  String _summarize(BundleGenerationResult result) {
    final pkgScopes = result.bundles.where((b) => !b.sdkOnly).length;
    final sdkScopes = result.bundles.where((b) => b.sdkOnly).length;
    final sdkNote = result.sdkSummaryBuilt ? 'built' : 'reused';
    return 'SDK summary $sdkNote; $pkgScopes package bundle(s), '
        '$sdkScopes sdk-only scope(s)';
  }
}

/// Builds the executor map for the bundler (single command keyed `default`).
Map<String, CommandExecutor> createDartEditorBundlerExecutors() {
  return {kDartEditorBundlerCommand: DartEditorBundlerExecutor()};
}
