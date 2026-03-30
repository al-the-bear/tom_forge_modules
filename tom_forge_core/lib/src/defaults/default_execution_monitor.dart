import 'dart:async';

import '../services/forge_execution_monitor.dart';

/// Default in-memory implementation of [ForgeExecutionMonitor].
class DefaultExecutionMonitor implements ForgeExecutionMonitor {
  final Map<String, ForgeExecution> _executions = {};

  final StreamController<ForgeExecution> _startController =
      StreamController<ForgeExecution>.broadcast();
  final StreamController<ForgeExecution> _finishController =
      StreamController<ForgeExecution>.broadcast();
  final StreamController<int> _countController =
      StreamController<int>.broadcast();

  @override
  List<ForgeExecution> get executions =>
      List.unmodifiable(_executions.values);

  @override
  List<ForgeExecution> get running => _executions.values
      .where((e) => e.state == ExecutionState.running)
      .toList(growable: false);

  @override
  ForgeExecution start({required String id, required String label}) {
    final execution = ForgeExecution(id: id, label: label);
    _executions[id] = execution;
    _startController.add(execution);
    _countController.add(running.length);
    return execution;
  }

  @override
  void complete(String id) => _finish(id, ExecutionState.completed);

  @override
  void fail(String id) => _finish(id, ExecutionState.failed);

  @override
  void cancel(String id) => _finish(id, ExecutionState.cancelled);

  void _finish(String id, ExecutionState state) {
    final execution = _executions[id];
    if (execution == null) return;
    execution
      ..state = state
      ..endTime = DateTime.now();
    _finishController.add(execution);
    _countController.add(running.length);
  }

  @override
  void remove(String id) {
    _executions.remove(id);
  }

  @override
  Stream<ForgeExecution> get onDidStart => _startController.stream;

  @override
  Stream<ForgeExecution> get onDidFinish => _finishController.stream;

  @override
  Stream<int> get onRunningCountChanged => _countController.stream;

  /// Dispose all streams.
  void dispose() {
    _startController.close();
    _finishController.close();
    _countController.close();
    _executions.clear();
  }
}
