import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  testWidgets('File menu Save executes file.save action', (
    WidgetTester tester,
  ) async {
    final harness = _MenuHarness.create();

    await tester.pumpWidget(harness.buildMenuApp());

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(harness.module.executedActionIds, contains('file.save'));
  });

  testWidgets('File menu Close Editor executes file.close action', (
    WidgetTester tester,
  ) async {
    final harness = _MenuHarness.create();

    await tester.pumpWidget(harness.buildMenuApp());

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close Editor'));
    await tester.pumpAndSettle();

    expect(harness.module.executedActionIds, contains('file.close'));
  });

  testWidgets('Edit menu Undo executes edit.undo action', (
    WidgetTester tester,
  ) async {
    final harness = _MenuHarness.create();

    await tester.pumpWidget(harness.buildMenuApp());

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(harness.module.executedActionIds, contains('edit.undo'));
  });
}

class _MenuHarness {
  _MenuHarness._({
    required this.shell,
    required this.module,
  });

  final DefaultShellApi shell;
  final _TestActionModule module;

  static _MenuHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Menu Test',
      navigatorKey: navigatorKey,
    );

    final module = _TestActionModule();
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);

    return _MenuHarness._(
      shell: shell,
      module: module,
    );
  }

  Widget buildMenuApp() {
    return MaterialApp(
      home: Scaffold(
        body: ForgeMenuBar(
          shellApi: shell,
          onCommandPalette: () {},
        ),
      ),
    );
  }
}

class _TestActionModule extends ForgeModule {
  final List<String> executedActionIds = <String>[];

  @override
  String get displayName => 'Test Menu Module';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => <ForgeAction>[
        _action('file.save'),
        _action('file.saveAll'),
        _action('file.close'),
        _action('edit.undo'),
        _action('edit.redo'),
      ];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  ForgeAction _action(String id) {
    return ForgeAction(
      id: id,
      label: id,
      execute: (_) async {
        executedActionIds.add(id);
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );
  }
}
