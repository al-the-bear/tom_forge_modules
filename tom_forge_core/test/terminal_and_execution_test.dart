import 'dart:async';

import 'package:test/test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

// Uses the DefaultTerminalManager + DefaultTerminal from tom_forge_ui
// which are the concrete stub implementations. For core tests, we test
// the abstract contract through a minimal concrete implementation.

/// Minimal terminal for testing the core abstract contract.
class _TestTerminal implements ForgeTerminal {
  @override
  final String name;

  final StreamController<String> _outputController =
      StreamController<String>.broadcast();

  bool disposed = false;
  bool closed = false;

  _TestTerminal(this.name);

  @override
  Stream<String> get onOutput => _outputController.stream;

  @override
  void sendText(String text, {bool addNewLine = true}) {
    _outputController.add('\$ $text');
  }

  @override
  void show({bool preserveFocus = true}) {}

  @override
  void close() {
    closed = true;
    _outputController.close();
  }

  @override
  void dispose() {
    disposed = true;
    _outputController.close();
  }
}

/// Minimal terminal manager for testing.
class _TestTerminalManager implements ForgeTerminalManager {
  final List<_TestTerminal> _terminals = [];
  _TestTerminal? _active;

  final StreamController<ForgeTerminal> _openCtrl =
      StreamController<ForgeTerminal>.broadcast();
  final StreamController<ForgeTerminal> _closeCtrl =
      StreamController<ForgeTerminal>.broadcast();
  final StreamController<ForgeTerminal?> _activeCtrl =
      StreamController<ForgeTerminal?>.broadcast();

  @override
  ForgeTerminal create({
    String? name,
    String? shellPath,
    String? cwd,
    ForgeOutputChannel? outputChannel,
  }) {
    final t = _TestTerminal(name ?? 'Terminal ${_terminals.length + 1}');
    _terminals.add(t);
    _active = t;
    _openCtrl.add(t);
    _activeCtrl.add(t);
    return t;
  }

  @override
  List<ForgeTerminal> get terminals => List.unmodifiable(_terminals);

  @override
  ForgeTerminal? get activeTerminal => _active;

  @override
  void setActive(ForgeTerminal terminal) {
    if (_terminals.contains(terminal)) {
      _active = terminal as _TestTerminal;
      _activeCtrl.add(terminal);
    }
  }

  @override
  Stream<ForgeTerminal> get onDidOpen => _openCtrl.stream;
  @override
  Stream<ForgeTerminal> get onDidClose => _closeCtrl.stream;
  @override
  Stream<ForgeTerminal?> get onDidChangeActive => _activeCtrl.stream;

  @override
  void detach(ForgeTerminal terminal) {
    if (terminal is _TestTerminal) {
      removeTerminal(terminal);
    }
  }

  void removeTerminal(_TestTerminal t) {
    _terminals.remove(t);
    _closeCtrl.add(t);
    if (_active == t) {
      _active = _terminals.isNotEmpty ? _terminals.last : null;
      _activeCtrl.add(_active);
    }
  }

  void dispose() {
    _openCtrl.close();
    _closeCtrl.close();
    _activeCtrl.close();
  }
}

void main() {
  // ─── Terminal Manager ─────────────────────────────────────

  group('ForgeTerminalManager', () {
    late _TestTerminalManager manager;

    setUp(() {
      manager = _TestTerminalManager();
    });

    tearDown(() {
      manager.dispose();
    });

    test('create adds terminal and sets active', () {
      final t = manager.create(name: 'bash');
      expect(manager.terminals, hasLength(1));
      expect(manager.activeTerminal, equals(t));
      expect(t.name, 'bash');
    });

    test('create multiple terminals', () {
      final t1 = manager.create(name: 'bash');
      final t2 = manager.create(name: 'zsh');
      expect(manager.terminals, hasLength(2));
      // Last created is active
      expect(manager.activeTerminal, equals(t2));
      expect(t1.name, 'bash');
      expect(t2.name, 'zsh');
    });

    test('setActive switches terminal', () {
      final t1 = manager.create(name: 'first');
      manager.create(name: 'second');
      expect(manager.activeTerminal!.name, 'second');
      manager.setActive(t1);
      expect(manager.activeTerminal, equals(t1));
    });

    test('setActive ignores unknown terminal', () {
      manager.create(name: 'known');
      final unknown = _TestTerminal('unknown');
      manager.setActive(unknown);
      expect(manager.activeTerminal!.name, 'known');
    });

    test('onDidOpen emits on create', () async {
      final names = <String>[];
      manager.onDidOpen.listen((t) => names.add(t.name));
      manager.create(name: 'a');
      manager.create(name: 'b');
      await Future<void>.delayed(Duration.zero);
      expect(names, ['a', 'b']);
    });

    test('onDidChangeActive emits on create and setActive', () async {
      final names = <String?>[];
      manager.onDidChangeActive.listen((t) => names.add(t?.name));
      final t1 = manager.create(name: 'first');
      manager.create(name: 'second');
      manager.setActive(t1);
      await Future<void>.delayed(Duration.zero);
      expect(names, ['first', 'second', 'first']);
    });

    test('removeTerminal emits onDidClose', () async {
      final closed = <String>[];
      manager.onDidClose.listen((t) => closed.add(t.name));
      final t = manager.create(name: 'temp') as _TestTerminal;
      manager.removeTerminal(t);
      await Future<void>.delayed(Duration.zero);
      expect(closed, ['temp']);
      expect(manager.terminals, isEmpty);
    });

    test('removeTerminal falls back to last terminal', () {
      final t1 = manager.create(name: 'first');
      final t2 = manager.create(name: 'second') as _TestTerminal;
      expect(manager.activeTerminal, equals(t2));
      manager.removeTerminal(t2);
      expect(manager.activeTerminal, equals(t1));
    });

    test('removeTerminal nullifies active when empty', () {
      final t = manager.create(name: 'only') as _TestTerminal;
      manager.removeTerminal(t);
      expect(manager.activeTerminal, isNull);
    });

    test('default name generation', () {
      final t = manager.create();
      expect(t.name, 'Terminal 1');
    });
  });

  // ─── Terminal ─────────────────────────────────────────────

  group('ForgeTerminal', () {
    test('sendText emits on onOutput', () async {
      final t = _TestTerminal('test');
      final output = <String>[];
      t.onOutput.listen(output.add);
      t.sendText('hello');
      await Future<void>.delayed(Duration.zero);
      expect(output, [r'$ hello']);
    });

    test('close sets closed flag', () {
      final t = _TestTerminal('test');
      t.close();
      expect(t.closed, isTrue);
    });

    test('dispose sets disposed flag', () {
      final t = _TestTerminal('test');
      t.dispose();
      expect(t.disposed, isTrue);
    });
  });

  // ─── Execution Monitor ────────────────────────────────────

  group('ForgeExecutionMonitor', () {
    late DefaultExecutionMonitor monitor;

    setUp(() {
      monitor = DefaultExecutionMonitor();
    });

    tearDown(() {
      monitor.dispose();
    });

    test('start creates running execution', () {
      final exec = monitor.start(id: 'build-1', label: 'Build project');
      expect(exec.id, 'build-1');
      expect(exec.label, 'Build project');
      expect(exec.state, ExecutionState.running);
      expect(monitor.executions, hasLength(1));
      expect(monitor.running, hasLength(1));
    });

    test('complete marks execution as completed', () {
      monitor.start(id: 'build-1', label: 'Build');
      monitor.complete('build-1');
      expect(monitor.executions.first.state, ExecutionState.completed);
      expect(monitor.executions.first.endTime, isNotNull);
      expect(monitor.running, isEmpty);
    });

    test('fail marks execution as failed', () {
      monitor.start(id: 'test-1', label: 'Tests');
      monitor.fail('test-1');
      expect(monitor.executions.first.state, ExecutionState.failed);
      expect(monitor.running, isEmpty);
    });

    test('cancel marks execution as cancelled', () {
      monitor.start(id: 'deploy-1', label: 'Deploy');
      monitor.cancel('deploy-1');
      expect(monitor.executions.first.state, ExecutionState.cancelled);
      expect(monitor.running, isEmpty);
    });

    test('remove removes execution from tracking', () {
      monitor.start(id: 'x', label: 'X');
      monitor.complete('x');
      monitor.remove('x');
      expect(monitor.executions, isEmpty);
    });

    test('multiple running executions tracked', () {
      monitor.start(id: 'a', label: 'A');
      monitor.start(id: 'b', label: 'B');
      monitor.start(id: 'c', label: 'C');
      expect(monitor.running, hasLength(3));
      monitor.complete('b');
      expect(monitor.running, hasLength(2));
    });

    test('onDidStart emits on start', () async {
      final labels = <String>[];
      monitor.onDidStart.listen((e) => labels.add(e.label));
      monitor.start(id: '1', label: 'First');
      monitor.start(id: '2', label: 'Second');
      await Future<void>.delayed(Duration.zero);
      expect(labels, ['First', 'Second']);
    });

    test('onDidFinish emits on complete/fail/cancel', () async {
      final states = <ExecutionState>[];
      monitor.onDidFinish.listen((e) => states.add(e.state));
      monitor.start(id: 'a', label: 'A');
      monitor.start(id: 'b', label: 'B');
      monitor.start(id: 'c', label: 'C');
      monitor.complete('a');
      monitor.fail('b');
      monitor.cancel('c');
      await Future<void>.delayed(Duration.zero);
      expect(states, [
        ExecutionState.completed,
        ExecutionState.failed,
        ExecutionState.cancelled,
      ]);
    });

    test('onRunningCountChanged tracks count', () async {
      final counts = <int>[];
      monitor.onRunningCountChanged.listen(counts.add);
      monitor.start(id: '1', label: 'A');
      monitor.start(id: '2', label: 'B');
      monitor.complete('1');
      monitor.complete('2');
      await Future<void>.delayed(Duration.zero);
      expect(counts, [1, 2, 1, 0]);
    });

    test('duration is calculated after completion', () {
      final exec = monitor.start(id: 'x', label: 'X');
      expect(exec.duration, isNull);
      monitor.complete('x');
      expect(exec.duration, isNotNull);
      expect(exec.duration!.inMicroseconds, greaterThanOrEqualTo(0));
    });

    test('complete/fail/cancel with unknown id is no-op', () {
      monitor.complete('nonexistent');
      monitor.fail('nonexistent');
      monitor.cancel('nonexistent');
      expect(monitor.executions, isEmpty);
    });

    test('long-running scenario: overlapping builds and tests', () async {
      // Simulate real workload: build starts, tests start during build,
      // build completes, tests fail.
      final finished = <String>[];
      monitor.onDidFinish.listen((e) => finished.add('${e.id}:${e.state}'));

      monitor.start(id: 'build', label: 'Build project');
      expect(monitor.running, hasLength(1));

      monitor.start(id: 'tests', label: 'Run tests');
      expect(monitor.running, hasLength(2));

      monitor.complete('build');
      expect(monitor.running, hasLength(1));

      monitor.fail('tests');
      expect(monitor.running, isEmpty);

      await Future<void>.delayed(Duration.zero);
      expect(finished, [
        'build:${ExecutionState.completed}',
        'tests:${ExecutionState.failed}',
      ]);
    });
  });
}
