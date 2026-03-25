import 'package:flutter/widgets.dart';

import 'forge_disposable.dart';

/// File decoration badge/color in the explorer.
class ForgeFileDecoration {
  final String? badge;
  final String? tooltip;
  final Color? color;
  final bool propagate;

  const ForgeFileDecoration({
    this.badge,
    this.tooltip,
    this.color,
    this.propagate = false,
  });
}

/// Provides file decorations for URIs.
abstract class ForgeFileDecorationProvider {
  ForgeFileDecoration? provideDecoration(Uri uri);
  Stream<Uri?> get onDidChange;
}

/// Registry for file decoration providers.
abstract class ForgeFileDecorationManager {
  ForgeDisposable registerProvider(ForgeFileDecorationProvider provider);
}
