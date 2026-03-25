import 'package:tom_forge_core/tom_forge_core.dart';

/// Progress indicator management.
abstract class ForgeProgressManager {
  /// Run a task with a progress indicator.
  Future<T> withProgress<T>({
    required String title,
    required ForgeProgressLocation location,
    required Future<T> Function(ForgeProgressReporter reporter) task,
    bool cancellable = false,
  });
}

/// Reports progress increments and messages.
abstract class ForgeProgressReporter {
  void report({int? increment, String? message});
}
