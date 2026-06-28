/// tom_dart_editor_bundler — Command executor.
///
/// Scaffold executor for the single-command bundler. Bundle generation (config
/// parsing, `.sum` emission, helper writing) is implemented in later plan items
/// (2–6); for now the executor reports that generation is not yet wired so the
/// CLI is runnable end-to-end while `--help` / `--version` work via the
/// [ToolRunner].
library;

import 'package:tom_build_base/tom_build_base_v2.dart';

/// Executor key for the bundler's single command.
const String kDartEditorBundlerCommand = 'default';

/// Default (single-command) executor for the bundler.
class DartEditorBundlerExecutor extends CommandExecutor {
  @override
  Future<ItemResult> execute(CommandContext context, CliArgs args) async {
    // TODO(plan item 5): read config, build the .sum set, and emit the helper.
    // Implemented in tom_dart_editor_summary_scoping_plan.md items 2–6.
    return ItemResult.success(
      path: context.path,
      name: context.name,
      message: 'tom_dart_editor_bundler scaffold — bundle generation not yet '
          'implemented (see tom_dart_editor_summary_scoping_plan.md items 2-6)',
    );
  }
}

/// Builds the executor map for the bundler (single command keyed `default`).
Map<String, CommandExecutor> createDartEditorBundlerExecutors() {
  return {kDartEditorBundlerCommand: DartEditorBundlerExecutor()};
}
