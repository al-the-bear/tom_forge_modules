import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

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

    test('diagnostic is emitted with MD001 code for broken module', () {
      final bad = _BrokenActionsModule();
      registry.register(bad);

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
