import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Service-level unit tests for config, diagnostics, notifications,
/// undo, module storage, output channels, and quality gates —
/// completing Section 28, Row 4.
void main() {
  // ── DefaultConfigManager ─────────────────────────────────

  group('DefaultConfigManager', () {
    test('initial config uses defaults', () {
      final mgr = DefaultConfigManager();
      expect(mgr.current.autoSave.enabled, isTrue);
    });

    test('initial config uses provided value', () {
      final mgr = DefaultConfigManager(
        initial: const ForgeConfig(autoSave: AutoSaveConfig(enabled: false)),
      );
      expect(mgr.current.autoSave.enabled, isFalse);
    });

    test('update fires onDidChange', () async {
      final mgr = DefaultConfigManager();
      var fired = false;
      mgr.onDidChange.listen((_) => fired = true);

      mgr.update((config) {});

      // Give stream time to deliver.
      await Future<void>.delayed(Duration.zero);
      expect(fired, isTrue);
      mgr.dispose();
    });

    test('setModuleConfig stores and retrieves typed config', () {
      final mgr = DefaultConfigManager();
      mgr.setModuleConfig<String>('mod-a', 'hello');
      expect(mgr.getModuleConfig<String>('mod-a'), 'hello');
    });

    test('getModuleConfig returns null for unknown id', () {
      final mgr = DefaultConfigManager();
      expect(mgr.getModuleConfig<String>('missing'), isNull);
    });

    test('resetToDefaults clears module configs', () {
      final mgr = DefaultConfigManager();
      mgr.setModuleConfig<int>('mod-a', 42);
      mgr.resetToDefaults();
      expect(mgr.getModuleConfig<int>('mod-a'), isNull);
    });

    test('toJson round-trips through loadFromJson', () {
      final mgr = DefaultConfigManager();
      mgr.setModuleConfig<String>('my-mod', 'value');
      final json = mgr.toJson();

      final mgr2 = DefaultConfigManager();
      mgr2.loadFromJson(json);
      expect(mgr2.getModuleConfig<String>('my-mod'), 'value');
    });
  });

  // ── DefaultDiagnosticManager ────────────────────────────

  group('DefaultDiagnosticManager service tests', () {
    late DefaultDiagnosticManager mgr;

    setUp(() {
      mgr = DefaultDiagnosticManager(refreshDebounce: Duration.zero);
    });

    tearDown(() {
      mgr.dispose();
    });

    test('createCollection returns unique instances', () {
      final a = mgr.createCollection('lint');
      final b = mgr.createCollection('analyze');
      expect(a, isNot(same(b)));
      expect(a.name, 'lint');
      expect(b.name, 'analyze');
    });

    test('forUri returns empty for unknown URIs', () {
      expect(mgr.forUri(Uri.parse('file:///unknown.dart')), isEmpty);
    });

    test('set diagnostics updates forUri', () {
      final uri = Uri.parse('file:///main.dart');
      final collection = mgr.createCollection('test');
      collection.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          message: 'test',
          severity: ForgeSeverity.error,
          range: const ForgeTextRange.empty(),
          source: 'test',
        ),
      ]);
      expect(mgr.forUri(uri), hasLength(1));
    });

    test('delete removes diagnostics for URI', () {
      final uri = Uri.parse('file:///main.dart');
      final collection = mgr.createCollection('test');
      collection.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          message: 'err',
          severity: ForgeSeverity.error,
          range: const ForgeTextRange.empty(),
          source: 'test',
        ),
      ]);
      expect(mgr.forUri(uri), hasLength(1));

      collection.delete(uri);
      expect(mgr.forUri(uri), isEmpty);
    });

    test('multiple collections aggregate in all', () {
      final uri = Uri.parse('file:///main.dart');
      final a = mgr.createCollection('lint');
      final b = mgr.createCollection('analyze');
      a.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          message: 'warning',
          severity: ForgeSeverity.warning,
          range: const ForgeTextRange.empty(),
          source: 'lint',
        ),
      ]);
      b.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          message: 'error',
          severity: ForgeSeverity.error,
          range: const ForgeTextRange.empty(),
          source: 'analyze',
        ),
      ]);
      expect(mgr.all, hasLength(2));
    });

    test('clear removes all diagnostics from collection', () {
      final uri = Uri.parse('file:///a.dart');
      final collection = mgr.createCollection('test');
      collection.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          message: 'x',
          severity: ForgeSeverity.info,
          range: const ForgeTextRange.empty(),
          source: 'test',
        ),
      ]);
      expect(mgr.forUri(uri), hasLength(1));

      collection.clear();
      expect(mgr.forUri(uri), isEmpty);
    });
  });

  // ── DefaultNotificationManager ─────────────────────────

  group('DefaultNotificationManager service tests', () {
    late DefaultNotificationManager mgr;

    setUp(() {
      // Use a long auto-dismiss to avoid timer interference.
      mgr = DefaultNotificationManager(
        autoDismissDuration: const Duration(hours: 1),
      );
    });

    tearDown(() {
      mgr.dispose();
    });

    test('showInformation adds info notification', () {
      mgr.showInformation('Test info');
      expect(mgr.notifications.value, hasLength(1));
      expect(
          mgr.notifications.value.first.severity, NotificationSeverity.info);
    });

    test('showWarning adds warning notification', () {
      mgr.showWarning('Test warning');
      expect(mgr.notifications.value, hasLength(1));
      expect(
          mgr.notifications.value.first.severity, NotificationSeverity.warning);
    });

    test('showError adds error notification', () {
      mgr.showError('Test error');
      expect(mgr.notifications.value, hasLength(1));
      expect(
          mgr.notifications.value.first.severity, NotificationSeverity.error);
    });

    test('remove dismisses notification', () {
      mgr.showInformation('Test');
      final item = mgr.notifications.value.first;
      mgr.remove(item);
      expect(mgr.notifications.value, isEmpty);
    });

    test('multiple notifications maintain order', () {
      mgr.showInformation('first');
      mgr.showWarning('second');
      mgr.showError('third');

      expect(mgr.notifications.value, hasLength(3));
      expect(mgr.notifications.value[0].message, 'first');
      expect(mgr.notifications.value[1].message, 'second');
      expect(mgr.notifications.value[2].message, 'third');
    });

    test('dismiss completes response future', () {
      final future = mgr.showInformation('Test');
      final item = mgr.notifications.value.first;
      item.dismiss('ok');
      expect(future, completion('ok'));
    });
  });

  // ── DefaultUndoManager ─────────────────────────────────

  group('DefaultUndoManager service tests', () {
    late DefaultUndoManager mgr;

    setUp(() {
      mgr = DefaultUndoManager();
    });

    tearDown(() {
      mgr.dispose();
    });

    test('initially empty', () {
      expect(mgr.canUndo.value, isFalse);
      expect(mgr.canRedo.value, isFalse);
    });

    test('push enables undo', () {
      mgr.push(UndoEntry(
        undo: () async {},
        redo: () async {},
      ));
      expect(mgr.canUndo.value, isTrue);
    });

    test('undo executes entry and enables redo', () async {
      var undone = false;
      mgr.push(UndoEntry(
        undo: () async => undone = true,
        redo: () async {},
      ));
      await mgr.undo();
      expect(undone, isTrue);
      expect(mgr.canRedo.value, isTrue);
    });

    test('redo executes entry', () async {
      var redone = false;
      mgr.push(UndoEntry(
        undo: () async {},
        redo: () async => redone = true,
      ));
      await mgr.undo();
      await mgr.redo();
      expect(redone, isTrue);
    });

    test('push after undo clears redo stack', () async {
      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      await mgr.undo();
      expect(mgr.canRedo.value, isTrue);

      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      expect(mgr.canRedo.value, isFalse);
    });

    test('clear resets both stacks', () {
      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      mgr.clear();
      expect(mgr.canUndo.value, isFalse);
      expect(mgr.canRedo.value, isFalse);
    });

    test('multiple undo/redo cycles', () async {
      final log = <String>[];
      mgr.push(UndoEntry(
        undo: () async => log.add('u1'),
        redo: () async => log.add('r1'),
      ));
      mgr.push(UndoEntry(
        undo: () async => log.add('u2'),
        redo: () async => log.add('r2'),
      ));

      await mgr.undo(); // u2
      await mgr.undo(); // u1
      await mgr.redo(); // r1
      await mgr.redo(); // r2

      expect(log, ['u2', 'u1', 'r1', 'r2']);
    });
  });

  // ── DefaultUndoManager — Composite Grouping ────────────

  group('DefaultUndoManager composite grouping', () {
    late DefaultUndoManager mgr;

    setUp(() {
      mgr = DefaultUndoManager();
    });

    tearDown(() {
      mgr.dispose();
    });

    test('beginUndoGroup/endUndoGroup groups entries atomically', () async {
      final log = <String>[];
      mgr.beginUndoGroup(label: 'format');
      mgr.push(UndoEntry(
        undo: () async => log.add('u1'),
        redo: () async => log.add('r1'),
        label: 'op1',
      ));
      mgr.push(UndoEntry(
        undo: () async => log.add('u2'),
        redo: () async => log.add('r2'),
        label: 'op2',
      ));
      // Inside group, nothing pushed to stack yet.
      expect(mgr.canUndo.value, isFalse);
      mgr.endUndoGroup();
      // After end, one composite entry on stack.
      expect(mgr.canUndo.value, isTrue);
      expect(mgr.undoCount, 1);

      // Undo undoes both in reverse order.
      await mgr.undo();
      expect(log, ['u2', 'u1']);
      expect(mgr.canRedo.value, isTrue);

      // Redo redoes both in forward order.
      await mgr.redo();
      expect(log, ['u2', 'u1', 'r1', 'r2']);
    });

    test('nested groups commit on outermost end', () async {
      final log = <String>[];
      mgr.beginUndoGroup(label: 'outer');
      mgr.push(UndoEntry(
        undo: () async => log.add('u1'),
        redo: () async => log.add('r1'),
      ));
      mgr.beginUndoGroup(label: 'inner');
      mgr.push(UndoEntry(
        undo: () async => log.add('u2'),
        redo: () async => log.add('r2'),
      ));
      mgr.endUndoGroup(); // inner
      // Still inside outer group.
      expect(mgr.canUndo.value, isFalse);
      mgr.endUndoGroup(); // outer
      expect(mgr.undoCount, 1);

      await mgr.undo();
      expect(log, ['u2', 'u1']);
    });

    test('empty group does not push entry', () {
      mgr.beginUndoGroup(label: 'empty');
      mgr.endUndoGroup();
      expect(mgr.canUndo.value, isFalse);
      expect(mgr.undoCount, 0);
    });

    test('endUndoGroup without begin is no-op', () {
      mgr.endUndoGroup();
      expect(mgr.undoCount, 0);
    });

    test('clear resets group state', () {
      mgr.beginUndoGroup(label: 'will-clear');
      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      mgr.clear();
      expect(mgr.canUndo.value, isFalse);
      // endUndoGroup after clear should not push anything.
      mgr.endUndoGroup();
      expect(mgr.undoCount, 0);
    });
  });

  // ── DefaultUndoManager — Memory Budget ─────────────────

  group('DefaultUndoManager memory budget', () {
    test('prunes oldest entries beyond maxEntries', () {
      final mgr = DefaultUndoManager(maxEntries: 3);
      for (var i = 0; i < 5; i++) {
        mgr.push(UndoEntry(
          undo: () async {},
          redo: () async {},
          label: 'entry-$i',
        ));
      }
      expect(mgr.undoCount, 3);
      mgr.dispose();
    });
  });

  // ── DefaultUndoManager — Event Stream ──────────────────

  group('DefaultUndoManager event stream', () {
    late DefaultUndoManager mgr;

    setUp(() {
      mgr = DefaultUndoManager();
    });

    tearDown(() {
      mgr.dispose();
    });

    test('emits pushed event on push', () async {
      final events = <UndoEvent>[];
      mgr.onUndoEvent.listen(events.add);
      mgr.push(UndoEntry(
        undo: () async {},
        redo: () async {},
        label: 'test-push',
      ));
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.first.type, UndoEventType.pushed);
      expect(events.first.label, 'test-push');
    });

    test('emits undone/redone events', () async {
      final events = <UndoEvent>[];
      mgr.push(UndoEntry(
        undo: () async {},
        redo: () async {},
        label: 'entry',
      ));
      mgr.onUndoEvent.listen(events.add);
      await mgr.undo();
      await mgr.redo();
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.type == UndoEventType.undone), hasLength(1));
      expect(events.where((e) => e.type == UndoEventType.redone), hasLength(1));
    });

    test('emits cleared event on clear', () async {
      final events = <UndoEvent>[];
      mgr.onUndoEvent.listen(events.add);
      mgr.push(UndoEntry(undo: () async {}, redo: () async {}));
      mgr.clear();
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e.type == UndoEventType.cleared), hasLength(1));
    });
  });

  // ── UndoEntry — Serializable Data ──────────────────────

  group('UndoEntry serializable data', () {
    test('data field is optional and preserved', () {
      final entry = UndoEntry(
        undo: () async {},
        redo: () async {},
        label: 'text-edit',
        data: {
          'type': 'text-edit',
          'editorId': 'dart-123',
          'timestamp': '2026-03-31T10:00:00Z',
        },
      );
      expect(entry.data, isNotNull);
      expect(entry.data!['type'], 'text-edit');
      expect(entry.data!['editorId'], 'dart-123');
    });

    test('data is null by default', () {
      final entry = UndoEntry(
        undo: () async {},
        redo: () async {},
      );
      expect(entry.data, isNull);
    });
  });

  // ── DefaultModuleStorage (in-memory) ───────────────────

  group('DefaultModuleStorage', () {
    test('forModule returns store per module', () {
      final storage = DefaultModuleStorage();
      final store = storage.forModule(_TestModule('mod-a'));
      expect(store, isNotNull);
    });

    test('separate modules get separate stores', () async {
      final storage = DefaultModuleStorage();
      final a = storage.forModule(_TestModule('mod-a'));
      final b = storage.forModule(_TestModule('mod-b'));
      await a.set('key', 'val-a');
      expect(b.get<String>('key'), isNull);
    });

    test('store round-trips string values', () async {
      final storage = DefaultModuleStorage();
      final store = storage.forModule(_TestModule('mod'));
      await store.set('name', 'forge');
      expect(store.get<String>('name'), 'forge');
    });

    test('store round-trips int values', () async {
      final storage = DefaultModuleStorage();
      final store = storage.forModule(_TestModule('mod'));
      await store.set('count', 42);
      expect(store.get<int>('count'), 42);
    });

    test('store round-trips bool values', () async {
      final storage = DefaultModuleStorage();
      final store = storage.forModule(_TestModule('mod'));
      await store.set('flag', true);
      expect(store.get<bool>('flag'), isTrue);
    });

    test('store remove deletes value', () async {
      final storage = DefaultModuleStorage();
      final store = storage.forModule(_TestModule('mod'));
      await store.set('key', 'val');
      await store.remove('key');
      expect(store.get<String>('key'), isNull);
    });

    test('same module returns same store instance', () {
      final storage = DefaultModuleStorage();
      final mod = _TestModule('mod');
      final a = storage.forModule(mod);
      final b = storage.forModule(mod);
      expect(identical(a, b), isTrue);
    });

    test('keys list reflects stored entries', () async {
      final storage = DefaultModuleStorage();
      final store = storage.forModule(_TestModule('mod'));
      await store.set('a', 1);
      await store.set('b', 2);
      expect(store.keys, containsAll(['a', 'b']));
    });
  });

  // ── DefaultOutputChannelManager ────────────────────────

  group('DefaultOutputChannelManager', () {
    test('create returns channel with correct name', () {
      final mgr = DefaultOutputChannelManager();
      final ch = mgr.create('Build');
      expect(ch.name, 'Build');
    });

    test('get returns created channel by name', () {
      final mgr = DefaultOutputChannelManager();
      final ch = mgr.create('Build');
      expect(mgr.get('Build'), same(ch));
    });

    test('get returns null for unknown name', () {
      final mgr = DefaultOutputChannelManager();
      expect(mgr.get('missing'), isNull);
    });

    test('create returns same instance for duplicate name', () {
      final mgr = DefaultOutputChannelManager();
      final a = mgr.create('Build');
      final b = mgr.create('Build');
      expect(identical(a, b), isTrue);
    });

    test('append adds text to channel contents', () {
      final mgr = DefaultOutputChannelManager();
      final ch = mgr.create('Build') as DefaultOutputChannel;
      ch.appendLine('line 1');
      ch.appendLine('line 2');
      expect(ch.contents, contains('line 1'));
      expect(ch.contents, contains('line 2'));
    });

    test('channels list returns all created channels', () {
      final mgr = DefaultOutputChannelManager();
      mgr.create('Build');
      mgr.create('Tests');
      expect(mgr.channels, hasLength(2));
    });

    test('clear removes channel content', () {
      final mgr = DefaultOutputChannelManager();
      final ch = mgr.create('Build') as DefaultOutputChannel;
      ch.appendLine('some text');
      ch.clear();
      expect(ch.contents, isEmpty);
    });
  });

  // ── DefaultProgressManager ──────────────────────────────

  group('DefaultProgressManager', () {
    test('withProgress runs task to completion', () async {
      final mgr = DefaultProgressManager();
      final result = await mgr.withProgress(
        title: 'Loading',
        location: ForgeProgressLocation.statusBar,
        task: (reporter) async {
          reporter.report(increment: 50, message: 'Halfway');
          return 42;
        },
      );
      expect(result, 42);
      mgr.dispose();
    });

    test('onProgress emits events', () async {
      final mgr = DefaultProgressManager();
      final events = <ProgressEvent>[];
      mgr.onProgress.listen(events.add);

      await mgr.withProgress(
        title: 'Building',
        location: ForgeProgressLocation.overlay,
        task: (reporter) async {
          reporter.report(increment: 100, message: 'Done');
        },
      );

      // Should have at least Started, report, Completed events.
      expect(events.where((e) => e.title == 'Building'), isNotEmpty);
      mgr.dispose();
    });

    test('withProgress rethrows on task error', () async {
      final mgr = DefaultProgressManager();
      expect(
        () => mgr.withProgress(
          title: 'Fail',
          location: ForgeProgressLocation.statusBar,
          task: (_) async => throw StateError('boom'),
        ),
        throwsStateError,
      );
      mgr.dispose();
    });
  });

  // ── ForgeQualityGate ────────────────────────────────────

  group('ForgeQualityGate', () {
    test('passed is true when all results pass', () {
      const gate = ForgeQualityGate(
        name: 'Test Gate',
        results: [
          ForgeGateResult(description: 'A', passed: true),
          ForgeGateResult(description: 'B', passed: true),
        ],
      );
      expect(gate.passed, isTrue);
      expect(gate.passedCount, 2);
      expect(gate.failedCount, 0);
    });

    test('passed is false when any result fails', () {
      const gate = ForgeQualityGate(
        name: 'Test Gate',
        results: [
          ForgeGateResult(description: 'A', passed: true),
          ForgeGateResult(description: 'B', passed: false, detail: 'fail'),
        ],
      );
      expect(gate.passed, isFalse);
      expect(gate.failedCount, 1);
      expect(gate.failures, hasLength(1));
    });

    test('summary includes name and counts', () {
      const gate = ForgeQualityGate(
        name: 'Merge Gate',
        results: [
          ForgeGateResult(description: 'A', passed: true),
          ForgeGateResult(description: 'B', passed: false),
        ],
      );
      expect(gate.summary, contains('Merge Gate'));
      expect(gate.summary, contains('1/2'));
    });
  });

  // ── ForgePromotionGate ──────────────────────────────────

  group('ForgePromotionGate', () {
    test('evaluate passes with full green metrics', () {
      const gate = ForgePromotionGate();
      final result = gate.evaluate(
        analyzerClean: true,
        allTestsPass: true,
        coverageByLayer: {
          ForgeTestLayer.unit: 95.0,
          ForgeTestLayer.widget: 85.0,
          ForgeTestLayer.integration: 75.0,
          ForgeTestLayer.e2e: 55.0,
        },
        goldenFilesPresent: true,
        noRegressions: true,
        integrationMatrixReady: true,
      );
      expect(result.passed, isTrue);
    });

    test('evaluate fails with low coverage', () {
      const gate = ForgePromotionGate();
      final result = gate.evaluate(
        analyzerClean: true,
        allTestsPass: true,
        coverageByLayer: {
          ForgeTestLayer.unit: 50.0, // below 90% target
          ForgeTestLayer.widget: 85.0,
          ForgeTestLayer.integration: 75.0,
          ForgeTestLayer.e2e: 55.0,
        },
        goldenFilesPresent: true,
        noRegressions: true,
        integrationMatrixReady: true,
      );
      expect(result.passed, isFalse);
      expect(result.failures.any((r) => r.description.contains('unit')),
          isTrue);
    });

    test('evaluate fails with analyzer errors', () {
      const gate = ForgePromotionGate();
      final result = gate.evaluate(
        analyzerClean: false,
        allTestsPass: true,
        coverageByLayer: {
          ForgeTestLayer.unit: 95.0,
          ForgeTestLayer.widget: 85.0,
          ForgeTestLayer.integration: 75.0,
          ForgeTestLayer.e2e: 55.0,
        },
        goldenFilesPresent: true,
        noRegressions: true,
        integrationMatrixReady: true,
      );
      expect(result.passed, isFalse);
    });

    test('evaluate fails when tests fail', () {
      const gate = ForgePromotionGate();
      final result = gate.evaluate(
        analyzerClean: true,
        allTestsPass: false,
        coverageByLayer: {
          ForgeTestLayer.unit: 95.0,
          ForgeTestLayer.widget: 85.0,
          ForgeTestLayer.integration: 75.0,
          ForgeTestLayer.e2e: 55.0,
        },
        goldenFilesPresent: true,
        noRegressions: true,
        integrationMatrixReady: true,
      );
      expect(result.passed, isFalse);
    });

    test('evaluate fails without golden files', () {
      const gate = ForgePromotionGate();
      final result = gate.evaluate(
        analyzerClean: true,
        allTestsPass: true,
        coverageByLayer: {
          ForgeTestLayer.unit: 95.0,
          ForgeTestLayer.widget: 85.0,
          ForgeTestLayer.integration: 75.0,
          ForgeTestLayer.e2e: 55.0,
        },
        goldenFilesPresent: false,
        noRegressions: true,
        integrationMatrixReady: true,
      );
      expect(result.passed, isFalse);
    });
  });

  // ── ForgeMergeGate ──────────────────────────────────────

  group('ForgeMergeGate', () {
    test('evaluate passes with all green', () {
      final gate = ForgeMergeGate();
      final result = gate.evaluate(
        analyzerClean: true,
        allTestsPass: true,
        noEditorRegressions: true,
        noCommandRegressions: true,
        noShortcutRegressions: true,
      );
      expect(result.passed, isTrue);
      expect(result.name, 'Merge Gate');
    });

    test('evaluate fails on editor regression', () {
      final gate = ForgeMergeGate();
      final result = gate.evaluate(
        analyzerClean: true,
        allTestsPass: true,
        noEditorRegressions: false,
        noCommandRegressions: true,
        noShortcutRegressions: true,
      );
      expect(result.passed, isFalse);
    });

    test('evaluate fails on command regression', () {
      final gate = ForgeMergeGate();
      final result = gate.evaluate(
        analyzerClean: true,
        allTestsPass: true,
        noEditorRegressions: true,
        noCommandRegressions: false,
        noShortcutRegressions: true,
      );
      expect(result.passed, isFalse);
    });

    test('evaluate fails on shortcut regression', () {
      final gate = ForgeMergeGate();
      final result = gate.evaluate(
        analyzerClean: true,
        allTestsPass: true,
        noEditorRegressions: true,
        noCommandRegressions: true,
        noShortcutRegressions: false,
      );
      expect(result.passed, isFalse);
    });
  });

  // ── ForgeCoverageTargets ────────────────────────────────

  group('ForgeCoverageTargets', () {
    test('default targets match spec', () {
      const targets = ForgeCoverageTargets();
      expect(targets.unitMinPercent, 90.0);
      expect(targets.widgetMinPercent, 80.0);
      expect(targets.integrationMinPercent, 70.0);
      expect(targets.e2eMinPercent, 50.0);
      expect(targets.goldenRequired, isTrue);
    });

    test('targetFor returns correct value per layer', () {
      const targets = ForgeCoverageTargets();
      expect(targets.targetFor(ForgeTestLayer.unit), 90.0);
      expect(targets.targetFor(ForgeTestLayer.widget), 80.0);
      expect(targets.targetFor(ForgeTestLayer.integration), 70.0);
      expect(targets.targetFor(ForgeTestLayer.e2e), 50.0);
      expect(targets.targetFor(ForgeTestLayer.golden), 0.0);
    });

    test('custom targets override defaults', () {
      const targets = ForgeCoverageTargets(
        unitMinPercent: 85.0,
        widgetMinPercent: 75.0,
      );
      expect(targets.unitMinPercent, 85.0);
      expect(targets.widgetMinPercent, 75.0);
    });
  });

  // ── ForgeMilestoneGate ──────────────────────────────────

  group('ForgeMilestoneGate', () {
    test('forgeWorkspace contains all four packages', () {
      expect(ForgeMilestoneGate.forgeWorkspace, hasLength(4));
      final paths = ForgeMilestoneGate.forgeWorkspace
          .map((g) => g.packagePath)
          .toList();
      expect(paths, contains('tom_forge_core'));
      expect(paths, contains('tom_forge_ui'));
      expect(paths, contains('tom_forge_ui_test'));
      expect(paths, contains('tom_forge_app'));
    });

    test('each gate requires analyze and test', () {
      for (final gate in ForgeMilestoneGate.forgeWorkspace) {
        expect(gate.commands, contains(ForgeMilestoneCommand.analyze));
        expect(gate.commands, contains(ForgeMilestoneCommand.test));
      }
    });
  });

  // ── ForgeStagingRuntimeContract ─────────────────────────

  group('ForgeStagingRuntimeContract', () {
    test('verify passes with all criteria met', () {
      const contract = ForgeStagingRuntimeContract();
      final result = contract.verify(
        hasShell: true,
        hasModuleRegistry: true,
        hasFileSystem: true,
        hasWorkspaceSeed: true,
        hasQualityGateIntegration: true,
      );
      expect(result.passed, isTrue);
      expect(result.name, 'Staging Runtime Contract');
    });

    test('verify fails when shell is missing', () {
      const contract = ForgeStagingRuntimeContract();
      final result = contract.verify(
        hasShell: false,
        hasModuleRegistry: true,
        hasFileSystem: true,
        hasWorkspaceSeed: true,
        hasQualityGateIntegration: true,
      );
      expect(result.passed, isFalse);
      expect(result.failedCount, 1);
    });

    test('verify fails when quality gate integration is absent', () {
      const contract = ForgeStagingRuntimeContract();
      final result = contract.verify(
        hasShell: true,
        hasModuleRegistry: true,
        hasFileSystem: true,
        hasWorkspaceSeed: true,
        hasQualityGateIntegration: false,
      );
      expect(result.passed, isFalse);
    });
  });
}

// ── Test helpers ──────────────────────────────────────────

class _TestModule extends ForgeModule {
  final String _name;
  _TestModule(this._name);

  @override
  String get displayName => _name;

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}
