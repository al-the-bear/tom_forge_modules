// GENERATED — do not edit. Produced by tom_dart_editor_bundler.
import 'package:tom_dart_editor/tom_dart_editor.dart';

abstract final class SummaryScopes {
  static const dartEditor = 'dart-editor';

  /// Loads + parses every bundle once and registers it by name. Idempotent.
  static Future<void> initialize() async {
    await SummaryScopeRegistry.instance.register(
      const SummaryScopeAsset(
        name: dartEditor,
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: 'assets/summaries/dart-editor/packages.sum',
        implicitImports: ['dart:async', 'dart:collection', 'dart:math', 'package:dcli/dcli.dart', 'package:path/path.dart'],
      ),
    );
  }
}
