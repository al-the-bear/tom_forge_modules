import 'package:tom_forge_core/tom_forge_core.dart';

/// Event emitted during progress tracking.
class ProgressEvent {
  final String title;
  final int? increment;
  final String? message;

  const ProgressEvent({required this.title, this.increment, this.message});
}

/// Progress indicator management.
abstract class ForgeProgressManager {
  /// Stream of progress events for active tasks.
  Stream<ProgressEvent> get onProgress;

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
