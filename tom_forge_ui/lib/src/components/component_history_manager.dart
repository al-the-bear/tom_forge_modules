import 'package:flutter/foundation.dart';

/// History manager for back/forward navigation within a component.
abstract class ComponentHistoryManager {
  /// Whether back navigation is available.
  ValueListenable<bool> get canGoBack;

  /// Whether forward navigation is available.
  ValueListenable<bool> get canGoForward;

  /// Navigate back.
  void goBack();

  /// Navigate forward.
  void goForward();

  /// The current history entry's label.
  String get currentLabel;
}
