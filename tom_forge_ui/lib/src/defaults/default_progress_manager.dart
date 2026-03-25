import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

import '../services/forge_progress_manager.dart';

/// Default implementation of [ForgeProgressManager].
///
/// Tracks active progress tasks and notifies listeners via streams.
class DefaultProgressManager implements ForgeProgressManager {
  static bool debugEnabled = false;

  final StreamController<ProgressEvent> _eventController =
      StreamController<ProgressEvent>.broadcast();

  @override
  Future<T> withProgress<T>({
    required String title,
    required ForgeProgressLocation location,
    required Future<T> Function(ForgeProgressReporter reporter) task,
    bool cancellable = false,
  }) async {
    final reporter = DefaultProgressReporter(
      title: title,
      onReport: (increment, message) {
        _eventController.add(ProgressEvent(
          title: title,
          increment: increment,
          message: message,
        ));
      },
    );

    _eventController.add(ProgressEvent(title: title, message: 'Started'));
    try {
      final result = await task(reporter);
      _eventController.add(ProgressEvent(title: title, message: 'Completed'));
      return result;
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultProgressManager] withProgress error: $e');
      }
      _eventController.add(ProgressEvent(title: title, message: 'Failed'));
      rethrow;
    }
  }

  /// Stream of progress events for widget layer consumption.
  Stream<ProgressEvent> get onProgress => _eventController.stream;

  /// Dispose resources.
  void dispose() {
    _eventController.close();
  }
}

/// Default implementation of [ForgeProgressReporter].
class DefaultProgressReporter implements ForgeProgressReporter {
  final String title;
  final void Function(int? increment, String? message) onReport;

  DefaultProgressReporter({required this.title, required this.onReport});

  @override
  void report({int? increment, String? message}) {
    onReport(increment, message);
  }
}

/// Event emitted during progress tracking.
class ProgressEvent {
  final String title;
  final int? increment;
  final String? message;

  const ProgressEvent({required this.title, this.increment, this.message});
}
