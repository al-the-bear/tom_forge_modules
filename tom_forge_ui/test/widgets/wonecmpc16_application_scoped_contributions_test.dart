/// Views, editors, actions and status items scoped to an application
/// (wonecmpc16).
///
/// A factory makes each application from a [ForgeApplicationContext]; the
/// views and contributions it lays out are bound to that context, so two
/// applications of one kind show the same views with their own content.
/// Actions, shortcuts, status-bar items and context-menu entries an
/// application contributes follow the active application, and each panel
/// application keeps its own layout: middle editor groups, panel sizes, side
/// panel tabs.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
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

  group('views bound to their application', () {
    testWidgets('AS-1: two applications of one kind show the same view, each '
        'bound to its own context', (tester) async {
      final h = _Harness();
      final webwork = h.openQuest('webwork');
      final core = h.openQuest('tom_core');
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      expect(find.text('PROCESS of tom_core (active)'), findsOneWidget);
      expect(
        find.text('PROCESS of webwork', skipOffstage: false),
        findsNothing,
      );

      h.shell.applications.activate(webwork.id);
      await tester.pumpAndSettle();
      expect(find.text('PROCESS of webwork (active)'), findsOneWidget);
      expect(find.textContaining('PROCESS of tom_core'), findsNothing);

      final context = h.factory.contexts[core.id]!;
      expect(context.application, core);
      expect(context.payload, {'quest': 'tom_core'});
      expect(context.isActive, isFalse);
    });
  });

  group('contributions follow the active application', () {
    testWidgets('AS-2: one action id runs the active application\'s action — '
        'from code and from its shortcut; closing rebinds', (tester) async {
      final h = _Harness();
      final webwork = h.openQuest('webwork');
      final core = h.openQuest('tom_core');
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      expect(h.shell.executeAction('quest.refresh'), isTrue);
      await tester.pumpAndSettle();
      h.shell.applications.activate(webwork.id);
      await tester.pumpAndSettle();
      expect(h.shell.executeAction('quest.refresh'), isTrue);
      await tester.pumpAndSettle();
      expect(h.factory.refreshed, ['tom_core', 'webwork']);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.f6);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.f6);
      await tester.pumpAndSettle();
      expect(h.factory.refreshed.last, 'webwork');

      await h.shell.applications.close(webwork.id);
      await tester.pumpAndSettle();
      expect(h.shell.applications.active, core);
      expect(h.shell.executeAction('quest.refresh'), isTrue);
      await tester.pumpAndSettle();
      expect(h.factory.refreshed.last, 'tom_core');
      final before = h.factory.refreshed.length;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f6);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.f6);
      await tester.pumpAndSettle();
      expect(
        h.factory.refreshed,
        hasLength(before + 1),
        reason: 'the shortcut is bound again for the application now active',
      );
      expect(h.factory.refreshed.last, 'tom_core');

      h.shell.applications.activate('forge');
      await tester.pumpAndSettle();
      expect(
        h.shell.actionRegistry.getAction('quest.refresh'),
        isNull,
        reason: 'the forge application contributes no such action',
      );
    });

    testWidgets('AS-3: the status bar shows the active application\'s items', (
      tester,
    ) async {
      final h = _Harness();
      final webwork = h.openQuest('webwork');
      h.openQuest('tom_core');
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(find.text('Quest tom_core'), findsOneWidget);
      expect(find.text('Quest webwork'), findsNothing);

      h.shell.applications.activate(webwork.id);
      await tester.pumpAndSettle();
      expect(find.text('Quest webwork'), findsOneWidget);
      expect(find.text('Quest tom_core'), findsNothing);
    });

    test('AS-4: context-menu entries are the active application\'s', () {
      final h = _Harness();
      final webwork = h.openQuest('webwork');
      h.openQuest('tom_core');
      const target = ForgeContextTarget(kind: 'quest.todo');
      List<String> labels() => [
        for (final entry in h.shell.contextMenus.entriesFor(target))
          entry.label,
      ];
      expect(labels(), ['Refresh tom_core']);
      h.shell.applications.activate(webwork.id);
      expect(labels(), ['Refresh webwork']);
      h.shell.applications.activate('forge');
      expect(labels(), isEmpty);
    });

    test('AS-5: an application action whose id a module registers is not '
        'bound, and the collision is reported', () {
      final h = _Harness();
      var moduleRuns = 0;
      h.shell.actionRegistry.registerAction(
        ForgeAction(
          id: 'quest.refresh',
          label: 'Module refresh',
          execute: (_) async {
            moduleRuns++;
            return null;
          },
          isEnabled: () => true,
          isVisible: () => true,
        ),
      );
      final reported = <Object>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => reported.add(details.exception);
      addTearDown(() => FlutterError.onError = previous);

      h.openQuest('webwork');
      expect(reported, [isA<StateError>()]);
      expect(h.shell.executeAction('quest.refresh'), isTrue);
      expect(moduleRuns, 1);
      expect(h.factory.refreshed, isEmpty);

      h.shell.applications.activate('forge');
      expect(
        h.shell.actionRegistry.getAction('quest.refresh'),
        isNotNull,
        reason: 'switching away does not unbind what was never bound',
      );
    });
  });

  group('each panel application keeps its own layout', () {
    test('AS-6: a first show opens the declared middle groups; switching away '
        'and back restores groups, editors, active group and panel sizes; a '
        'full-screen application in between leaves them', () {
      final h = _Harness();
      final layout = h.shell.layout as DefaultLayoutController;
      final state = h.shell.systemState as DefaultSystemState;

      // 'forge' is shown first and declares one empty group.
      expect(layout.middlePanels.value, [isEmpty]);
      final notes = _StubEditor('notes.md');
      layout.openEditor(notes, notes.uri);
      layout.splitMiddlePanel();
      layout.setActiveMiddlePanelIndex(1);
      layout.setPanelSize(ForgePanelLocation.left, 333);

      final quest = h.openQuest('webwork');
      final document = h.factory.documents[quest.id]!;
      final trail = h.factory.trails[quest.id]!;
      expect(layout.middlePanels.value, [
        [document],
        [trail],
      ]);
      expect(layout.leftPanel.value.size, 280, reason: 'its declared size');
      expect(state.openEditors, unorderedEquals([document, trail]));

      final full = ForgeApplication(
        id: 'full',
        title: 'full',
        layout: FullScreenLayout(view: _LabelView('full screen')),
      );
      h.shell.applications.add(full, activate: true);
      expect(
        layout.middlePanels.value,
        [
          [document],
          [trail],
        ],
        reason: 'a full-screen application leaves the layout alone',
      );

      h.shell.applications.activate('forge');
      expect(layout.middlePanels.value, [
        [notes],
        isEmpty,
      ]);
      expect(layout.activeMiddlePanelIndex, 1);
      expect(layout.leftPanel.value.size, 333);
      expect(state.openEditors, [notes]);

      h.shell.applications.activate(quest.id);
      expect(layout.middlePanels.value, [
        [document],
        [trail],
      ]);
      expect(layout.leftPanel.value.size, 280);
    });

    testWidgets('AS-7: the side panel keeps each application\'s selected tab', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final h = _Harness();
      final webwork = h.openQuest('webwork');
      final core = h.openQuest('tom_core');
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Notes').first);
      await tester.pumpAndSettle();
      expect(find.text('NOTES of tom_core'), findsOneWidget);

      h.shell.applications.activate(webwork.id);
      await tester.pumpAndSettle();
      expect(
        find.text('PROCESS of webwork (active)'),
        findsOneWidget,
        reason: 'webwork starts on its first tab',
      );

      h.shell.applications.activate(core.id);
      await tester.pumpAndSettle();
      expect(
        find.text('NOTES of tom_core'),
        findsOneWidget,
        reason: 'tom_core comes back on the tab it left',
      );
    });
  });
}

/// A shell with a static 'forge' application and the quest factory.
class _Harness {
  _Harness() {
    shell.applications
      ..add(
        ForgeApplication(
          id: 'forge',
          title: 'forge',
          layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
        ),
      )
      ..registerFactory(factory);
  }

  final shell = DefaultShellApi.withDefaultsAndFileSystem(
    fileSystem: TomMemoryFileSystem(),
    appName: 'Scoped contributions test',
    navigatorKey: GlobalKey<NavigatorState>(),
  );
  final factory = _QuestFactory();

  ForgeApplication openQuest(String quest) =>
      shell.applications.open('quest', title: quest, payload: {'quest': quest});

  Widget app() => MaterialApp(
    home: ForgeShellScaffold(
      shell: shell,
      layoutController: shell.layout as DefaultLayoutController,
      systemState: shell.systemState as DefaultSystemState,
      statusBarController: shell.statusBar,
      notificationManager: shell.notifications as DefaultNotificationManager,
    ),
  );
}

/// Makes quest applications: a PROCESS and a NOTES view, a document and a
/// trail editor, a `quest.refresh` action on F6, a status item and a
/// context-menu entry — all bound to the application's context.
class _QuestFactory implements ForgeApplicationFactory {
  final contexts = <String, ForgeApplicationContext>{};
  final documents = <String, ForgeEditor>{};
  final trails = <String, ForgeEditor>{};
  final refreshed = <String>[];

  @override
  String get kind => 'quest';

  @override
  ForgeApplication create(ForgeApplicationContext context, String title) {
    contexts[context.id] = context;
    final quest = context.payload['quest']! as String;
    final refresh = ForgeAction(
      id: 'quest.refresh',
      label: 'Refresh $quest',
      execute: (_) async {
        refreshed.add(quest);
        return null;
      },
      isEnabled: () => true,
      isVisible: () => true,
    );
    final document = _StubEditor('$quest/overview.md');
    final trail = _StubEditor('$quest/live-trail.md');
    documents[context.id] = document;
    trails[context.id] = trail;
    return ForgeApplication(
      id: context.id,
      title: title,
      kind: kind,
      payload: context.payload,
      layout: PanelLayout(
        leftPanel: PanelConfig(
          initialSize: 280,
          tabs: [
            PanelTabConfig(
              title: 'Process',
              icon: Icons.account_tree,
              sections: [_ProcessView(context, quest)],
            ),
            PanelTabConfig(
              title: 'Notes',
              icon: Icons.notes,
              sections: [_LabelView('NOTES of $quest')],
            ),
          ],
        ),
        middlePanels: [
          MiddlePanelConfig(tabs: [MiddleTabConfig(editor: document)]),
          MiddlePanelConfig(tabs: [MiddleTabConfig(editor: trail)]),
        ],
      ),
      contributions: ForgeApplicationContributions(
        actions: [refresh],
        shortcuts: [
          ForgeShortcutBinding(
            action: refresh,
            key: const ForgeShortcutKey(key: LogicalKeyboardKey.f6),
          ),
        ],
        statusBarItems: [
          StatusBarItem(
            text: ValueNotifier('Quest $quest'),
            isActive: (_) => true,
          ),
        ],
        contextMenus: const [
          ForgeContextMenuContribution(
            targetKind: 'quest.todo',
            actionId: 'quest.refresh',
          ),
        ],
      ),
    );
  }
}

/// A view bound to its application's context: it names its quest and says
/// whether its application is the active one.
class _ProcessView extends _LabelView {
  _ProcessView(this.context, String quest) : super('PROCESS of $quest');

  final ForgeApplicationContext context;

  @override
  Widget buildMain(BuildContext buildContext) =>
      ValueListenableBuilder<List<ForgeApplication>>(
        valueListenable: context.registry,
        builder: (_, _, _) =>
            Text(context.isActive ? '$label (active)' : label),
      );
}

class _LabelView extends ForgeView {
  _LabelView(this.label);

  final String label;

  @override
  ValueListenable<String> get title => ValueNotifier(label);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.flag;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => Text(label);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
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
