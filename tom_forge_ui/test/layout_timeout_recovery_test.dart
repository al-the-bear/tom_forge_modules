import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

class _TimeoutMemoryFileSystem extends ForgeMemoryFileSystem {
  int remainingTimeoutReads;
  int readAttempts = 0;

  _TimeoutMemoryFileSystem({
    required this.remainingTimeoutReads,
    required super.seed,
  });

  @override
  Future<ForgeFileContent> read(Uri uri) async {
    readAttempts++;
    if (remainingTimeoutReads > 0) {
      remainingTimeoutReads--;
      throw TimeoutException('network timeout for $uri');
    }
    return super.read(uri);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DefaultLayoutController timeout recovery', () {
    test('openFile retries timeout and eventually opens editor', () async {
      final fs = _TimeoutMemoryFileSystem(
        remainingTimeoutReads: 2,
        seed: {
          '/workspace/retry.dart': 'void main() {}',
        },
      );

      final shell = DefaultShellApi.withDefaultsAndFileSystem(
        fileSystem: fs,
        appName: 'Timeout Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );

      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);

      final uri = Uri.parse('file:///workspace/retry.dart');
      shell.layout.openFile(uri);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(fs.readAttempts, equals(3));
      expect(shell.systemState.openEditors.any((e) => e.uri == uri), isTrue);

      final notifications =
          (shell.notifications as DefaultNotificationManager).notifications.value;
      expect(
        notifications.where((n) => n.severity == NotificationSeverity.warning),
        isNotEmpty,
      );

      shell.dispose();
    });

    test('openFile timeout remains non-fatal after retries exhausted', () async {
      final fs = _TimeoutMemoryFileSystem(
        remainingTimeoutReads: 10,
        seed: {
          '/workspace/never-opens.dart': 'void main() {}',
        },
      );

      final shell = DefaultShellApi.withDefaultsAndFileSystem(
        fileSystem: fs,
        appName: 'Timeout Test',
        navigatorKey: GlobalKey<NavigatorState>(),
      );

      final shellModule = TomForgeShellModule();
      shellModule.activate(shell);
      (shell.modules as DefaultModuleRegistry).register(shellModule);

      final uri = Uri.parse('file:///workspace/never-opens.dart');
      shell.layout.openFile(uri);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(shell.systemState.openEditors.where((e) => e.uri == uri), isEmpty);

      final diagnostics = shell.diagnostics.forUri(uri);
      expect(diagnostics, isNotEmpty);
      expect(diagnostics.first.severity, ForgeSeverity.warning);
      expect(diagnostics.first.code, ForgeErrorCodes.edLoadFailed);

      final notifications =
          (shell.notifications as DefaultNotificationManager).notifications.value;
      expect(
        notifications.where((n) => n.severity == NotificationSeverity.warning),
        isNotEmpty,
      );

      shell.dispose();
    });
  });
}
