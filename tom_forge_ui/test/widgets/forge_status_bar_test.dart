import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  // ─── DefaultStatusBarController ─────────────────────────────

  group('DefaultStatusBarController', () {
    test('aggregates items from all modules', () {
      final harness = _StatusBarHarness.create();
      final moduleA = _TestStatusBarModuleA(items: [_item('a1'), _item('a2')]);
      final moduleB = _TestStatusBarModuleB(items: [_item('b1')]);
      harness.registerTyped<_TestStatusBarModuleA>(moduleA);
      harness.registerTyped<_TestStatusBarModuleB>(moduleB);

      final items = harness.shell.statusBar.items;
      expect(items.length, 3);
    });

    test('returns empty list when no modules registered', () {
      final harness = _StatusBarHarness.create();
      expect(harness.shell.statusBar.items, isEmpty);
    });

    test('sorts items by priority descending', () {
      final harness = _StatusBarHarness.create();
      final module = _TestStatusBarModule(
        name: 'Prio',
        items: [
          _item('low', priority: 10),
          _item('high', priority: 100),
          _item('mid', priority: 50),
        ],
      );
      harness.register(module);

      final texts = harness.shell.statusBar.items
          .map((i) => i.text.value)
          .toList();
      expect(texts, ['high', 'mid', 'low']);
    });

    test('items from multiple modules are merged and sorted', () {
      final harness = _StatusBarHarness.create();
      harness.registerTyped<_TestStatusBarModuleA>(
        _TestStatusBarModuleA(items: [_item('f1', priority: 20)]),
      );
      harness.registerTyped<_TestStatusBarModuleB>(
        _TestStatusBarModuleB(items: [_item('s1', priority: 30)]),
      );

      final texts = harness.shell.statusBar.items
          .map((i) => i.text.value)
          .toList();
      expect(texts, ['s1', 'f1']);
    });
  });

  // ─── ForgeStatusBarWidget rendering ─────────────────────────

  group('ForgeStatusBarWidget', () {
    testWidgets('renders left/center/right items in correct order', (
      WidgetTester tester,
    ) async {
      final harness = _StatusBarHarness.create();
      harness.register(
        _TestStatusBarModule(
          name: 'Layout',
          items: [
            _item('Left', alignment: StatusBarAlignment.left),
            _item('Center', alignment: StatusBarAlignment.center),
            _item('Right', alignment: StatusBarAlignment.right),
          ],
        ),
      );

      await tester.pumpWidget(harness.buildApp());

      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Center'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    });

    testWidgets('keeps left/center/right items in segmented layout', (
      WidgetTester tester,
    ) async {
      final harness = _StatusBarHarness.create();
      harness.register(
        _TestStatusBarModule(
          name: 'Segments',
          items: [
            _item(
              'LeftSegment',
              alignment: StatusBarAlignment.left,
              priority: 50,
            ),
            _item(
              'CenterSegment',
              alignment: StatusBarAlignment.center,
              priority: 50,
            ),
            _item(
              'RightSegment',
              alignment: StatusBarAlignment.right,
              priority: 50,
            ),
          ],
        ),
      );

      await tester.pumpWidget(harness.buildApp());

      final leftX = tester.getCenter(find.text('LeftSegment')).dx;
      final centerX = tester.getCenter(find.text('CenterSegment')).dx;
      final rightX = tester.getCenter(find.text('RightSegment')).dx;
      final barX = tester.getCenter(find.byType(ForgeStatusBarWidget)).dx;

      expect(leftX, lessThan(centerX));
      expect(centerX, lessThan(rightX));
      expect((centerX - barX).abs(), lessThan(120));
    });

    testWidgets('orders items by priority within alignment zone', (
      WidgetTester tester,
    ) async {
      final harness = _StatusBarHarness.create();
      harness.register(
        _TestStatusBarModule(
          name: 'PriorityZone',
          items: [
            _item('left-low', alignment: StatusBarAlignment.left, priority: 10),
            _item(
              'left-high',
              alignment: StatusBarAlignment.left,
              priority: 100,
            ),
          ],
        ),
      );

      await tester.pumpWidget(harness.buildApp());

      final highX = tester.getCenter(find.text('left-high')).dx;
      final lowX = tester.getCenter(find.text('left-low')).dx;
      expect(highX, lessThan(lowX));
    });

    testWidgets('filters items by isActive', (WidgetTester tester) async {
      final harness = _StatusBarHarness.create();
      harness.register(
        _TestStatusBarModule(
          name: 'Active',
          items: [
            _item('always', isActive: (_) => true),
            _item('never', isActive: (_) => false),
          ],
        ),
      );

      await tester.pumpWidget(harness.buildApp());

      expect(find.text('always'), findsOneWidget);
      expect(find.text('never'), findsNothing);
    });

    testWidgets('rebuilds when focus changes', (WidgetTester tester) async {
      final harness = _StatusBarHarness.create();
      var showItem = false;
      harness.register(
        _TestStatusBarModule(
          name: 'Dynamic',
          items: [_item('dynamic', isActive: (_) => showItem)],
        ),
      );

      await tester.pumpWidget(harness.buildApp());
      expect(find.text('dynamic'), findsNothing);

      // Trigger a focus change to cause rebuild.
      showItem = true;
      harness.systemState.setFocusedComponent(null);
      await tester.pump();

      expect(find.text('dynamic'), findsOneWidget);
    });

    testWidgets('shows progress indicator', (WidgetTester tester) async {
      final harness = _StatusBarHarness.create();

      await tester.pumpWidget(harness.buildApp());
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Use a Completer to control when the task finishes.
      final completer = Completer<void>();

      // ignore: unawaited_futures
      harness.shell.progress.withProgress(
        title: 'Building',
        location: ForgeProgressLocation.statusBar,
        task: (r) => completer.future,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Building'), findsOneWidget);

      // Complete the task to clean up.
      completer.complete();
      await tester.pump();
    });

    testWidgets('uses static progress indicator when animations disabled', (
      WidgetTester tester,
    ) async {
      final harness = _StatusBarHarness.create();

      await tester.pumpWidget(
        harness.buildApp(
          mediaQueryData: const MediaQueryData(disableAnimations: true),
        ),
      );

      final completer = Completer<void>();

      // ignore: unawaited_futures
      harness.shell.progress.withProgress(
        title: 'Indexing',
        location: ForgeProgressLocation.statusBar,
        task: (r) => completer.future,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.sync), findsOneWidget);

      completer.complete();
      await tester.pump();
    });

    testWidgets('uses static progress indicator in high-contrast mode', (
      WidgetTester tester,
    ) async {
      final harness = _StatusBarHarness.create();

      await tester.pumpWidget(
        harness.buildApp(
          mediaQueryData: const MediaQueryData(highContrast: true),
        ),
      );

      final completer = Completer<void>();

      // ignore: unawaited_futures
      harness.shell.progress.withProgress(
        title: 'Syncing',
        location: ForgeProgressLocation.statusBar,
        task: (r) => completer.future,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.sync), findsOneWidget);

      completer.complete();
      await tester.pump();
    });

    testWidgets('tap handler fires', (WidgetTester tester) async {
      var tapped = false;
      final harness = _StatusBarHarness.create();
      harness.register(
        _TestStatusBarModule(
          name: 'Tap',
          items: [_item('clickMe', onTap: () => tapped = true)],
        ),
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.tap(find.text('clickMe'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('ValueListenable text updates live', (
      WidgetTester tester,
    ) async {
      final textNotifier = ValueNotifier<String>('initial');
      final harness = _StatusBarHarness.create();
      harness.register(
        _TestStatusBarModule(
          name: 'Live',
          items: [StatusBarItem(text: textNotifier, isActive: (_) => true)],
        ),
      );

      await tester.pumpWidget(harness.buildApp());
      expect(find.text('initial'), findsOneWidget);

      textNotifier.value = 'updated';
      await tester.pump();

      expect(find.text('updated'), findsOneWidget);
      expect(find.text('initial'), findsNothing);
    });

    testWidgets('an item is shown while visible, and the bar rebuilds when '
        'that changes (02b_woneb2)', (WidgetTester tester) async {
      final visible = ValueNotifier<bool>(false);
      final harness = _StatusBarHarness.create();
      harness.register(
        _TestStatusBarModule(
          name: 'Visible',
          items: [
            StatusBarItem(
              text: ValueNotifier<String>('syncing'),
              visible: visible,
              isActive: (_) => true,
            ),
          ],
        ),
      );

      await tester.pumpWidget(harness.buildApp());
      expect(find.text('syncing'), findsNothing);
      visible.value = true;
      await tester.pump();
      expect(find.text('syncing'), findsOneWidget);
      visible.value = false;
      await tester.pump();
      expect(find.text('syncing'), findsNothing);
    });

    testWidgets('the shell renders through the shared ForgeStatusBar', (
      WidgetTester tester,
    ) async {
      final harness = _StatusBarHarness.create();
      harness.register(
        _TestStatusBarModule(name: 'Shared', items: [_item('shared')]),
      );
      await tester.pumpWidget(harness.buildApp());
      expect(
        find.descendant(
          of: find.byType(ForgeStatusBar),
          matching: find.text('shared'),
        ),
        findsOneWidget,
      );
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────────

StatusBarItem _item(
  String label, {
  StatusBarAlignment alignment = StatusBarAlignment.left,
  int priority = 0,
  VoidCallback? onTap,
  bool Function(ForgeSystemState)? isActive,
}) {
  return StatusBarItem(
    text: ValueNotifier<String>(label),
    alignment: alignment,
    priority: priority,
    onTap: onTap,
    isActive: isActive ?? (_) => true,
  );
}

class _StatusBarHarness {
  final DefaultShellApi shell;
  DefaultSystemState get systemState => shell.systemState as DefaultSystemState;

  _StatusBarHarness._(this.shell);

  static _StatusBarHarness create() {
    final navigatorKey = GlobalKey<NavigatorState>();
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'StatusBar Test',
      navigatorKey: navigatorKey,
    );
    return _StatusBarHarness._(shell);
  }

  void register(_TestStatusBarModule module) {
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
  }

  void registerTyped<T extends ForgeModule>(T module) {
    module.activate(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
  }

  Widget buildApp({MediaQueryData? mediaQueryData}) {
    final data = mediaQueryData ?? const MediaQueryData();
    return MaterialApp(
      home: MediaQuery(
        data: data,
        child: Scaffold(
          body: ForgeStatusBarWidget(
            controller: shell.statusBar,
            systemState: shell.systemState,
            progressManager: shell.progress,
          ),
        ),
      ),
    );
  }
}

class _TestStatusBarModule extends ForgeModule {
  final String name;
  final List<StatusBarItem> _items;

  _TestStatusBarModule({required this.name, List<StatusBarItem>? items})
    : _items = items ?? [];

  @override
  String get displayName => name;

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

  @override
  List<StatusBarItem> get statusBarItems => _items;
}

/// Separate module types so [DefaultModuleRegistry] (keyed by [Type])
/// can store multiple modules simultaneously.
class _TestStatusBarModuleA extends _TestStatusBarModule {
  _TestStatusBarModuleA({super.items}) : super(name: 'A');
}

class _TestStatusBarModuleB extends _TestStatusBarModule {
  _TestStatusBarModuleB({super.items}) : super(name: 'B');
}
