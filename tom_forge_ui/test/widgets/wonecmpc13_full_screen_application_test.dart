/// Full-screen applications in the shell (wonecmpc13).
///
/// An application with a [FullScreenLayout] fills the content area with one
/// view: no side, bottom or middle panels and no in-window menu bar, with the
/// title bar's application switcher and the status bar still there. Switching
/// between it and a panel application keeps both: the view's widget state and
/// focus, the panel application's open editors.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  setUp(() {
    final oldOnError = FlutterError.onError;
    // The default test surface is too small for the full scaffold; overflow
    // is irrelevant here.
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);
  });

  group('a full-screen application', () {
    testWidgets('FS-1: renders its one view with the switcher and the status '
        'bar, and no panels or menu bar', (tester) async {
      final h = _Harness.create(startFullScreen: true);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      expect(find.byKey(_Harness.counterKey), findsOneWidget);
      expect(find.byTooltip('Switch Application'), findsOneWidget);
      expect(find.text('Webwork'), findsWidgets);
      expect(find.byType(ForgeStatusBarWidget), findsOneWidget);
      expect(find.byType(ForgeMenuBar), findsNothing);
      // No panel application has been shown, so the panel area is not built.
      expect(find.text('Editor: notes.md', skipOffstage: false), findsNothing);
    });

    testWidgets('FS-2: switching to a panel application and back keeps the '
        "view's state and focus, and the panel application's editors", (
      tester,
    ) async {
      final h = _Harness.create(startFullScreen: false);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      h.layout.openEditor(h.editor, h.editor.uri);
      await tester.pumpAndSettle();
      expect(h.systemState.openEditors, [h.editor]);
      expect(find.byType(ForgeMenuBar), findsOneWidget);

      await h.switchTo(tester, h.fullScreen);
      expect(find.byType(ForgeMenuBar), findsNothing);
      expect(find.text('Editor: notes.md'), findsNothing);
      expect(h.systemState.openEditors, isEmpty);

      // Change the view's state and give its field the focus.
      await tester.tap(find.byKey(_Harness.counterKey));
      await tester.tap(find.byKey(_Harness.counterKey));
      await tester.tap(find.byKey(_Harness.fieldKey));
      await tester.enterText(find.byKey(_Harness.fieldKey), 'draft');
      await tester.pumpAndSettle();
      expect(find.text('count 2'), findsOneWidget);
      final field = tester.widget<TextField>(find.byKey(_Harness.fieldKey));
      expect(field.focusNode!.hasFocus, isTrue);

      await h.switchTo(tester, h.panels);
      expect(find.text('Editor: notes.md'), findsOneWidget);
      expect(h.systemState.openEditors, [h.editor]);
      expect(h.systemState.activeEditor, h.editor);
      // Offstage, out of focus traversal, but alive.
      expect(field.focusNode!.hasFocus, isFalse);
      expect(find.text('count 2', skipOffstage: false), findsOneWidget);

      await h.switchTo(tester, h.fullScreen);
      expect(find.text('count 2'), findsOneWidget);
      expect(find.text('draft'), findsOneWidget);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(h.systemState.openEditors, isEmpty);
    });

    testWidgets('FS-3: the switcher in the title bar switches to and from it', (
      tester,
    ) async {
      final h = _Harness.create(startFullScreen: false);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Switch Application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Webwork').last);
      await tester.pumpAndSettle();
      expect(h.systemState.activeApplication, h.fullScreen);
      expect(find.byKey(_Harness.counterKey), findsOneWidget);

      await tester.tap(find.byTooltip('Switch Application'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panels').last);
      await tester.pumpAndSettle();
      expect(h.systemState.activeApplication, h.panels);
      expect(find.byKey(_Harness.counterKey), findsNothing);
    });

    testWidgets("FS-4: a key the view does not handle reaches the shell's "
        'global shortcuts', (tester) async {
      final h = _Harness.create(startFullScreen: true);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      h.shell.actionRegistry.registerAction(
        ForgeAction(
          id: 'file.saveAll',
          label: 'Save All',
          execute: (_) async {
            h.executed.add('file.saveAll');
            return null;
          },
          isEnabled: () => true,
          isVisible: () => true,
        ),
      );

      await tester.tap(find.byKey(_Harness.fieldKey));
      await tester.pumpAndSettle();
      final modifier = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();

      expect(h.executed, contains('file.saveAll'));
    });
  });

  group('the system state', () {
    test('FS-5: switching back restores the editor instances an application '
        'had; an application never active starts with none', () {
      final a = ForgeApplication(title: 'A');
      final b = ForgeApplication(title: 'B');
      final state = DefaultSystemState(initialApplication: a)
        ..setApplications([a, b]);
      final editor = _StubEditor('one.md');
      state
        ..addOpenEditor(editor)
        ..setActiveEditor(editor);

      state.setActiveApplication(b);
      expect(state.openEditors, isEmpty);
      expect(state.activeEditor, isNull);

      state.setActiveApplication(a);
      expect(state.openEditors, [editor]);
      expect(state.activeEditor, editor);
    });

    test('FS-6: a panel layout and a full-screen layout answer what the shell '
        'asks', () {
      final view = _CounterView();
      final full = ForgeApplication(
        title: 'F',
        layout: FullScreenLayout(view: view),
      );
      final panels = ForgeApplication(
        title: 'P',
        layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
      );
      expect(full.isFullScreen, isTrue);
      expect(full.panelLayout.middlePanels, isEmpty);
      expect(panels.isFullScreen, isFalse);
      expect(panels.panelLayout.middlePanels, hasLength(1));
    });
  });
}

class _Harness {
  _Harness._(this.shell, this.panels, this.fullScreen, this.editor);

  static const counterKey = ValueKey('wonecmpc13.counter');
  static const fieldKey = ValueKey('wonecmpc13.field');

  final DefaultShellApi shell;
  final ForgeApplication panels;
  final ForgeApplication fullScreen;
  final _StubEditor editor;
  final executed = <String>[];
  final _active = ValueNotifier<ForgeApplication?>(null);

  DefaultLayoutController get layout =>
      shell.layout as DefaultLayoutController;
  DefaultSystemState get systemState => shell.systemState as DefaultSystemState;

  static _Harness create({required bool startFullScreen}) {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Full-screen test',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final panels = ForgeApplication(
      title: 'Panels',
      layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
    );
    final fullScreen = ForgeApplication(
      title: 'Webwork',
      layout: FullScreenLayout(view: _CounterView()),
    );
    final state = shell.systemState as DefaultSystemState
      ..setApplications([panels, fullScreen]);
    final first = startFullScreen ? fullScreen : panels;
    state.setActiveApplication(first);
    final h = _Harness._(shell, panels, fullScreen, _StubEditor('notes.md'));
    h._active.value = first;
    return h;
  }

  Widget app() => MaterialApp(
    home: ValueListenableBuilder<ForgeApplication?>(
      valueListenable: _active,
      builder: (context, application, _) => ForgeShellScaffold(
        shell: shell,
        application: application!,
        layoutController: layout,
        systemState: systemState,
        statusBarController: shell.statusBar,
        notificationManager: shell.notifications as DefaultNotificationManager,
        onApplicationSwitch: (app) => _active.value = app,
      ),
    ),
  );

  /// Switches the way a host does: the system state, then the scaffold.
  Future<void> switchTo(WidgetTester tester, ForgeApplication app) async {
    systemState.setActiveApplication(app);
    _active.value = app;
    await tester.pumpAndSettle();
  }
}

/// A view with state of its own: a counter and a text field.
class _CounterView extends ForgeView {
  @override
  ValueListenable<String> get title => ValueNotifier('Counter');

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.add;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const _Counter();

  @override
  Widget buildCopy(BuildContext context) => const _Counter();
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _count = 0;
  final _focus = FocusNode();
  final _text = TextEditingController();

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        key: _Harness.counterKey,
        onPressed: () => setState(() => _count++),
        child: Text('count $_count'),
      ),
      SizedBox(
        width: 200,
        child: TextField(
          key: _Harness.fieldKey,
          focusNode: _focus,
          controller: _text,
        ),
      ),
    ],
  );
}

class _StubEditor extends ForgeEditor {
  _StubEditor(this._name);

  final String _name;
  final _dirty = ValueNotifier(false);

  @override
  ValueNotifier<String> get title => ValueNotifier(_name);

  @override
  ValueNotifier<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.description;

  @override
  Uri get uri => Uri.parse('file:///$_name');

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => Text('Editor: $_name');

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}
