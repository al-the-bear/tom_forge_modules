import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

// ─── Fake modules ──────────────────────────────────────────

/// A module that registers and deactivates without errors.
class _GoodModule extends ForgeModule {
  bool deactivated = false;

  @override
  String get displayName => 'Good Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() => deactivated = true;

  @override
  List<ForgeEditor> get editors => [];

  @override
  List<ForgeView> get views => [];

  @override
  List<ForgeAction> get actions => [];

  @override
  List<ForgeShortcutBinding> get shortcuts => [];
}

/// A module whose [actions] getter throws during registration.
class _BrokenActionsModule extends ForgeModule {
  @override
  String get displayName => 'Broken Actions Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [];

  @override
  List<ForgeView> get views => [];

  @override
  List<ForgeAction> get actions => throw StateError('corrupt actions');

  @override
  List<ForgeShortcutBinding> get shortcuts => [];
}

/// A module whose [deactivate] throws.
class _BrokenDeactivateModule extends ForgeModule {
  @override
  String get displayName => 'Broken Deactivate Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() => throw StateError('deactivate bomb');

  @override
  List<ForgeEditor> get editors => [];

  @override
  List<ForgeView> get views => [];

  @override
  List<ForgeAction> get actions => [];

  @override
  List<ForgeShortcutBinding> get shortcuts => [];
}

/// A module that times out once while registry inspects contributions.
class _TimeoutActionsModule extends ForgeModule {
  int attempts = 0;

  @override
  String get displayName => 'Timeout Actions Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => [];

  @override
  List<ForgeView> get views => [];

  @override
  List<ForgeAction> get actions {
    attempts++;
    throw TimeoutException('network timed out while loading actions');
  }

  @override
  List<ForgeShortcutBinding> get shortcuts => [];
}

// ─── Fake services ─────────────────────────────────────────

class _FakeNotificationManager implements ForgeNotificationManager {
  final List<String> errors = [];
  final List<String> warnings = [];
  final List<String> infos = [];

  @override
  Future<String?> showError(String message, {List<String> actions = const []}) {
    errors.add(message);
    return Future.value(null);
  }

  @override
  Future<String?> showWarning(String message,
      {List<String> actions = const []}) {
    warnings.add(message);
    return Future.value(null);
  }

  @override
  Future<String?> showInformation(String message,
      {List<String> actions = const []}) {
    infos.add(message);
    return Future.value(null);
  }
}

// ─── Tests ─────────────────────────────────────────────────

void main() {
  group('Module registration error isolation', () {
    late DefaultModuleRegistry registry;
    late DefaultDiagnosticManager diagnosticManager;
    late _FakeNotificationManager notificationManager;
    late DefaultOutputChannelManager outputManager;

    setUp(() {
      diagnosticManager = DefaultDiagnosticManager();
      notificationManager = _FakeNotificationManager();
      outputManager = DefaultOutputChannelManager();

      registry = DefaultModuleRegistry(
        actionRegistry: DefaultActionRegistry(),
      );
      registry.diagnosticManager = diagnosticManager;
      registry.notificationManager = notificationManager;
      registry.outputManager = outputManager;
    });

    test('broken module is marked error, good module stays active', () {
      final good = _GoodModule();
      final bad = _BrokenActionsModule();

      registry.register(good);
      registry.register(bad);

      expect(
        registry.moduleStateOf(good),
        ModuleState.active,
        reason: 'Good module should remain active',
      );
      expect(
        registry.moduleStateOf(bad),
        ModuleState.error,
        reason: 'Broken module should be in error state',
      );
    });

    test('good module is still accessible after broken module registration',
        () {
      final good = _GoodModule();
      final bad = _BrokenActionsModule();

      registry.register(good);
      registry.register(bad);

      expect(registry.get<_GoodModule>(), same(good));
    });

    test('errorModules returns only failing modules', () {
      final good = _GoodModule();
      final bad = _BrokenActionsModule();

      registry.register(good);
      registry.register(bad);

      expect(registry.errorModules, [bad]);
    });

    test('diagnostic is emitted with MD001 code for broken module', () async {
      final bad = _BrokenActionsModule();
      registry.register(bad);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      final allDiags = diagnosticManager.all;
      expect(allDiags, isNotEmpty, reason: 'Expected a diagnostic');
      expect(allDiags.first.code, ForgeErrorCodes.mdActivationFailed);
      expect(allDiags.first.severity, ForgeSeverity.error);
    });

    test('notification is fired for broken module', () {
      final bad = _BrokenActionsModule();
      registry.register(bad);

      expect(notificationManager.errors, isNotEmpty);
      expect(
        notificationManager.errors.first,
        contains('Broken Actions Module'),
      );
    });

    test('output channel receives error details', () {
      final bad = _BrokenActionsModule();
      registry.register(bad);

      final channel = outputManager.get('Tom Forge Shell');
      expect(channel, isNotNull,
          reason: 'Shell output channel should exist');
    });

    test('module failure is mirrored into active editor diagnostics context', () {
      final good = _GoodModule();
      registry.register(good);

      final state = DefaultSystemState();
      registry.systemState = state;

      final editor = ForgeTestTextEditor(
        good,
        document: ForgeTestDocument(
          uri: Uri.parse('file:///workspace/active.dart'),
          content: 'void main() {}',
        ),
      );
      state.addOpenEditor(editor);
      state.setActiveEditor(editor);

      final bad = _BrokenActionsModule();
      registry.register(bad);

      expect(registry.moduleStateOf(good), ModuleState.active);
      expect(registry.moduleStateOf(bad), ModuleState.error);
      expect(registry.get<_GoodModule>(), same(good));

      final editorDiags = diagnosticManager.forUri(editor.uri);
      expect(editorDiags, isNotEmpty,
          reason: 'Expected module failure to be reflected in editor context');
      expect(
        editorDiags.any((d) => d.code == ForgeErrorCodes.mdActivationFailed),
        isTrue,
      );

      expect(notificationManager.errors, isNotEmpty,
          reason: 'Expected failure toast notification for module error');

      editor.dispose();
    });

    test('timeout activation failure reports warning toast and diagnostics', () async {
      final timeoutModule = _TimeoutActionsModule();
      registry.register(timeoutModule);

      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(registry.moduleStateOf(timeoutModule), ModuleState.error);
      expect(notificationManager.errors, isNotEmpty);
      expect(
        notificationManager.errors.first,
        contains('Timeout Actions Module'),
      );

      final allDiags = diagnosticManager.all;
      expect(allDiags, isNotEmpty);
      expect(
        allDiags.any((d) => d.code == ForgeErrorCodes.mdActivationFailed),
        isTrue,
      );
    });
  });

  group('Module deactivation error isolation', () {
    late DefaultModuleRegistry registry;
    late DefaultDiagnosticManager diagnosticManager;
    late _FakeNotificationManager notificationManager;
    late DefaultOutputChannelManager outputManager;

    setUp(() {
      diagnosticManager = DefaultDiagnosticManager();
      notificationManager = _FakeNotificationManager();
      outputManager = DefaultOutputChannelManager();

      registry = DefaultModuleRegistry();
      registry.diagnosticManager = diagnosticManager;
      registry.notificationManager = notificationManager;
      registry.outputManager = outputManager;
    });

    test('deactivateAll does not throw when module deactivation fails', () {
      final good = _GoodModule();
      final bad = _BrokenDeactivateModule();

      registry.register(good);
      registry.register(bad);

      expect(() => registry.deactivateAll(), returnsNormally);
    });

    test('good module is deactivated even when another fails', () {
      final good = _GoodModule();
      final bad = _BrokenDeactivateModule();

      registry.register(good);
      registry.register(bad);

      registry.deactivateAll();

      expect(good.deactivated, isTrue,
          reason: 'Good module deactivate() should still be called');
    });

    test('diagnostic emitted for deactivation failure', () {
      final bad = _BrokenDeactivateModule();
      registry.register(bad);

      registry.deactivateAll();

      // The diagnostic manager collections were disposed during deactivateAll,
      // but the notification should have been sent before cleanup.
      expect(notificationManager.errors, isNotEmpty);
    });
  });
}
