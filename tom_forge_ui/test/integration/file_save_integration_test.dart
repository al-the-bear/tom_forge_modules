import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Integration tests for end-to-end file save lifecycle and full
/// shell path scenarios (Section 28, Row 6).
void main() {
  group('File save lifecycle integration', () {
    late _FileLifecycleHarness harness;

    setUp(() {
      harness = _FileLifecycleHarness.create();
    });

    test('open seeded file via layout openFile', () async {
      harness.shell.layout.openFile(Uri.parse('file:///notes.txt'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final active = harness.shell.systemState.activeEditor;
      expect(active, isNotNull);
      expect(active!.uri.path, '/notes.txt');
    });

    test('save persists content to memory filesystem', () async {
      final uri = Uri.parse('file:///notes.txt');

      // Write new content.
      await harness.shell.fileSystem.writeText(uri, 'updated content');

      // Save.
      await harness.shell.fileSystem.save(uri);

      // Read back.
      final content = await harness.shell.fileSystem.readText(uri);
      expect(content, 'updated content');
    });

    test('onDidSave fires after save', () async {
      final uri = Uri.parse('file:///notes.txt');
      final savedUris = <Uri>[];
      harness.shell.fileSystem.onDidSave.listen(savedUris.add);

      await harness.shell.fileSystem.save(uri);
      await Future<void>.delayed(Duration.zero);

      expect(savedUris, contains(uri));
    });

    test('onWillSave fires before save', () async {
      final uri = Uri.parse('file:///notes.txt');
      var willSaveFired = false;
      harness.shell.fileSystem.onWillSave.listen((_) => willSaveFired = true);

      await harness.shell.fileSystem.save(uri);
      await Future<void>.delayed(Duration.zero);

      expect(willSaveFired, isTrue);
    });

    test('write then save round-trip', () async {
      final uri = Uri.parse('file:///new_file.dart');
      await harness.shell.fileSystem.writeText(uri, 'void main() {}');
      await harness.shell.fileSystem.save(uri);

      final exists = await harness.shell.fileSystem.exists(uri);
      expect(exists, isTrue);

      final content = await harness.shell.fileSystem.readText(uri);
      expect(content, 'void main() {}');
    });
  });

  group('Shell path integration', () {
    late _FileLifecycleHarness harness;

    setUp(() {
      harness = _FileLifecycleHarness.create();
    });

    test('shell provides all required services', () {
      expect(harness.shell.fileSystem, isNotNull);
      expect(harness.shell.diagnostics, isNotNull);
      expect(harness.shell.notifications, isNotNull);
      expect(harness.shell.config, isNotNull);
      expect(harness.shell.undoManager, isNotNull);
      expect(harness.shell.layout, isNotNull);
      expect(harness.shell.systemState, isNotNull);
      expect(harness.shell.modules, isNotNull);
    });

    test('module registration round-trip', () {
      final modules = harness.shell.modules;
      // Shell module + test module = ≥ 2.
      expect(modules.allModules.length, greaterThanOrEqualTo(2));
    });

    test('diagnostics flow through to allNotifier', () {
      final diagMgr = harness.shell.diagnostics as DefaultDiagnosticManager;
      final collection = diagMgr.createCollection('test');
      final uri = Uri.parse('file:///notes.txt');

      collection.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          message: 'unused variable',
          severity: ForgeSeverity.warning,
          range: const ForgeTextRange.empty(),
          source: 'analyzer',
        ),
      ]);

      expect(diagMgr.forUri(uri), hasLength(1));
      expect(diagMgr.all, hasLength(1));
    });

    test('notifications show and remove', () {
      final notifMgr =
          harness.shell.notifications as DefaultNotificationManager;
      notifMgr.showInformation('Build succeeded');
      expect(notifMgr.notifications.value, hasLength(1));

      notifMgr.remove(notifMgr.notifications.value.first);
      expect(notifMgr.notifications.value, isEmpty);
    });

    test('undo manager tracks entries', () async {
      final undoMgr = harness.shell.undoManager as DefaultUndoManager;
      var undone = false;
      undoMgr.push(UndoEntry(
        undo: () async => undone = true,
        redo: () async {},
        label: 'test edit',
      ));

      expect(undoMgr.canUndo.value, isTrue);
      await undoMgr.undo();
      expect(undone, isTrue);
      expect(undoMgr.canRedo.value, isTrue);
    });

    test('config update round-trip', () async {
      final configMgr = harness.shell.config as DefaultConfigManager;
      var eventFired = false;
      configMgr.onDidChange.listen((_) => eventFired = true);

      configMgr.setModuleConfig<String>('test-mod', 'hello');
      await Future<void>.delayed(Duration.zero);

      expect(configMgr.getModuleConfig<String>('test-mod'), 'hello');
      expect(eventFired, isTrue);
    });
  });
}

// ── Test harness ─────────────────────────────────────────

class _FileLifecycleHarness {
  final DefaultShellApi shell;
  final TomForgeShellModule shellModule;
  final ForgeApplication application;

  _FileLifecycleHarness._({
    required this.shell,
    required this.shellModule,
    required this.application,
  });

  static _FileLifecycleHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/notes.txt': 'Initial content for testing',
        '/src/main.dart': 'void main() => print("hello");',
      },
      appName: 'File Lifecycle Test',
      navigatorKey: navigatorKey,
      initialConfig: const ForgeConfig(
        performance: ForgePerformanceConfig(
          diagnosticDebounceWindow: Duration.zero,
        ),
      ),
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final testModule = _ShellProbeModule();
    testModule.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);
    registry.register(testModule);

    final application = ForgeApplication(
      title: 'File Lifecycle Test',
      layout: const PanelLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );

    return _FileLifecycleHarness._(
      shell: shell,
      shellModule: shellModule,
      application: application,
    );
  }
}

class _ShellProbeModule extends ForgeModule {
  @override
  String get displayName => 'Shell Probe';

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
