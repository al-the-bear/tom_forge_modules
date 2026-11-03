import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// Golden test configuration for zero-debounce synchronous behavior.
const _goldenConfig = ForgeConfig(
  performance: ForgePerformanceConfig(diagnosticDebounceWindow: Duration.zero),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Golden: Shell layout', () {
    testWidgets('dark theme default layout', (WidgetTester tester) async {
      final harness = _GoldenHarness.create(themeMode: ThemeMode.dark);

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ForgeShellScaffold),
        matchesGoldenFile('goldens/shell_dark.png'),
      );
    });

    testWidgets('default theme layout parity checkpoint', (
      WidgetTester tester,
    ) async {
      final harness = _GoldenHarness.create(themeMode: ThemeMode.light);

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ForgeShellScaffold),
        matchesGoldenFile('goldens/shell_light.png'),
      );
    });

    testWidgets('theme parity checkpoint for default/dark/high-contrast', (
      WidgetTester tester,
    ) async {
      final defaultTheme = ForgeShellTheme.light();
      final darkTheme = ForgeShellTheme.dark();
      final highContrast = ForgeShellTheme.highContrast();

      // Keep a quick parity checkpoint in addition to goldens so theme-token
      // regressions are caught before pixel-level snapshots diverge.
      expect(defaultTheme.panelSurface, isNot(darkTheme.panelSurface));
      expect(highContrast.panelDivider, equals(const Color(0xFFFFFFFF)));
      expect(highContrast.focusRing, equals(const Color(0xFFFFFFFF)));
      expect(
        defaultTheme.statusBarBackground,
        isNot(highContrast.statusBarBackground),
      );
      expect(
        darkTheme.statusBarBackground,
        isNot(highContrast.statusBarBackground),
      );
    });

    testWidgets('high contrast theme default layout', (
      WidgetTester tester,
    ) async {
      final harness = _GoldenHarness.create(themeMode: ThemeMode.system);

      await tester.pumpWidget(
        harness.buildApp(shellTheme: ForgeShellTheme.highContrast()),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ForgeShellScaffold),
        matchesGoldenFile('goldens/shell_high_contrast.png'),
      );
    });

    testWidgets('status bar renders with diagnostic counts', (
      WidgetTester tester,
    ) async {
      final harness = _GoldenHarness.create(themeMode: ThemeMode.dark);

      // Add some diagnostics for status bar rendering.
      final diag = harness.shell.diagnostics as DefaultDiagnosticManager;
      final collection = diag.createCollection('test');
      final uri = Uri.parse('file:///main.dart');
      collection.set(uri, [
        ForgeDiagnostic(
          uri: uri,
          message: 'Unused import',
          severity: ForgeSeverity.warning,
          source: 'analyzer',
          range: const ForgeTextRange(
            start: ForgeTextPosition(line: 0, column: 0),
            end: ForgeTextPosition(line: 0, column: 20),
          ),
        ),
        ForgeDiagnostic(
          uri: uri,
          message: 'Syntax error',
          severity: ForgeSeverity.error,
          source: 'analyzer',
          range: const ForgeTextRange(
            start: ForgeTextPosition(line: 5, column: 0),
            end: ForgeTextPosition(line: 5, column: 10),
          ),
        ),
      ]);

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ForgeStatusBarWidget),
        matchesGoldenFile('goldens/status_bar_diagnostics.png'),
      );
    });
  });
}

// ── Harness ───────────────────────────────────────────────────

class _GoldenHarness {
  final DefaultShellApi shell;
  final ForgeApplication application;
  final ThemeMode themeMode;

  _GoldenHarness._({
    required this.shell,
    required this.application,
    required this.themeMode,
  });

  static _GoldenHarness create({ThemeMode themeMode = ThemeMode.dark}) {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {
        '/src/main.dart': 'void main() => print("Hello");',
        '/src/app.dart': 'class App {}',
        '/README.md': '# Golden Test\n\nProject readme.',
        '/pubspec.yaml': 'name: golden_test\nversion: 0.1.0',
      },
      appName: 'Golden Test',
      navigatorKey: navigatorKey,
      initialConfig: _goldenConfig,
    );

    final shellModule = TomForgeShellModule();
    shellModule.activate(shell);

    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(shellModule);

    final application = ForgeApplication(
      title: 'Golden Test IDE',
      layout: const PanelLayout(
        leftPanel: PanelConfig(initialSize: 250, tabs: []),
        rightPanel: PanelConfig(initialSize: 220, tabs: []),
        bottomPanel: PanelConfig(initialSize: 180, tabs: []),
        middlePanels: [MiddlePanelConfig()],
      ),
    );

    return _GoldenHarness._(
      shell: shell,
      application: application,
      themeMode: themeMode,
    );
  }

  Widget buildApp({ForgeShellTheme? shellTheme}) {
    final theme = shellTheme ?? ForgeShellTheme.forMode(themeMode);
    final brightness = themeMode == ThemeMode.light
        ? Brightness.light
        : Brightness.dark;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: brightness, extensions: [theme]),
      home: SizedBox(
        width: 1280,
        height: 720,
        child: ForgeShellScaffold(
          shell: shell,
          application: application,
          layoutController: shell.layout as DefaultLayoutController,
          systemState: shell.systemState as DefaultSystemState,
          statusBarController: shell.statusBar,
          notificationManager:
              shell.notifications as DefaultNotificationManager,
        ),
      ),
    );
  }
}
