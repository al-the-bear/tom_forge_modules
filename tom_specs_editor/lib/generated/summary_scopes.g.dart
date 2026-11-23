// GENERATED — do not edit. Produced by tom_dart_editor_bundler.
import 'package:tom_dart_analysis/tom_dart_analysis.dart';

abstract final class SummaryScopes {
  static const dartPlain = 'dart-plain';
  static const d4rtFlutter = 'd4rt-flutter';

  /// Loads + parses every bundle once and registers it by name. Idempotent.
  static Future<void> initialize() async {
    await SummaryScopeRegistry.instance.register(
      const SummaryScopeAsset(
        name: dartPlain,
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: null,
        implicitImports: ['dart:async', 'dart:collection', 'dart:math'],
      ),
    );
    await SummaryScopeRegistry.instance.register(
      const SummaryScopeAsset(
        name: d4rtFlutter,
        sdkSummaryAsset: 'assets/summaries/sdk_summary.sum',
        packageSummaryAsset: 'assets/summaries/d4rt-flutter/packages.sum',
        implicitImports: ['package:flutter/material.dart'],
      ),
    );
  }
}
