import 'dart:async';

/// State of a tracked execution.
enum ExecutionState { running, completed, failed, cancelled }

/// A single tracked execution (build, test run, process, etc.).
class ForgeExecution {
  final String id;
  final String label;
  final DateTime startTime;
  DateTime? endTime;
  ExecutionState state;

  ForgeExecution({
    required this.id,
    required this.label,
    DateTime? startTime,
    this.state = ExecutionState.running,
  }) : startTime = startTime ?? DateTime.now();

  Duration? get duration => endTime?.difference(startTime);
}

/// Monitors running executions (builds, tests, processes) and emits
/// lifecycle events for UI surfaces like the status bar and execution list.
abstract class ForgeExecutionMonitor {
  /// Currently tracked executions.
  List<ForgeExecution> get executions;

  /// Active (running) executions only.
  List<ForgeExecution> get running;

  /// Start tracking a new execution.
  ForgeExecution start({required String id, required String label});

  /// Mark an execution as completed.
  void complete(String id);

  /// Mark an execution as failed.
  void fail(String id);

  /// Mark an execution as cancelled.
  void cancel(String id);

  /// Remove a completed/failed/cancelled execution from tracking.
  void remove(String id);

  /// Emitted when an execution starts.
  Stream<ForgeExecution> get onDidStart;

  /// Emitted when an execution finishes (completed, failed, or cancelled).
  Stream<ForgeExecution> get onDidFinish;

  /// Emitted when the running count changes.
  Stream<int> get onRunningCountChanged;
}
