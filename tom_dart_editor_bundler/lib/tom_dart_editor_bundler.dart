/// tom_dart_editor_bundler — public library surface.
///
/// Exposes the tool definition and executor so they can be embedded by the CLI
/// entry-point (`bin/dart_editor_bundler.dart`) and exercised by tests. Bundle
/// generation internals are added by later plan items.
library;

export 'src/asset_layout.dart';
export 'src/bundle_generator.dart';
export 'src/bundler_config.dart';
export 'src/helper_writer.dart';
export 'src/bundler_tool.dart';
export 'src/bundler_executor.dart';
export 'src/version.versioner.dart';
