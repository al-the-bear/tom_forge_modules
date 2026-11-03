/// Applications that come and go at run time (wonecmpc14).
///
/// The shell's application registry (`ForgeShellApi.applications`) holds the
/// open applications by a stable id. Modules register a factory per kind and
/// open applications of it at run time, several of one kind at once; the
/// registry renames and removes them, the switcher follows live, and the
/// restorable ones open at exit come back at the next start through their
/// factories.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  group('the registry', () {
    test(
      'DA-1: the first application added becomes active; ids are unique',
      () {
        final registry = DefaultSystemState();
        final forge = _static('forge');
        registry.add(forge);
        expect(registry.active, forge);
        expect(forge.isActive, isTrue);
        expect(() => registry.add(_static('forge')), throwsStateError);
      },
    );

    test('DA-2: a factory opens several applications of one kind, each with '
        'its own id, payload and kind', () {
      final registry = DefaultSystemState()..add(_static('forge'));
      registry.registerFactory(_QuestFactory());
      final a = registry.open(
        'quest',
        title: 'webwork',
        payload: {'quest': 'webwork'},
      );
      final b = registry.open(
        'quest',
        title: 'tom_core',
        payload: {'quest': 'tom_core'},
      );
      expect(a.id, isNot(b.id));
      expect(a.kind, 'quest');
      expect(b.payload, {'quest': 'tom_core'});
      expect(registry.all, hasLength(3));
      expect(registry.active, b, reason: 'open activates by default');
      expect(
        () => registry.open('unknown', title: 'x'),
        throwsStateError,
        reason: 'no factory for the kind',
      );
      expect(
        () => registry.registerFactory(_QuestFactory()),
        throwsStateError,
        reason: 'one factory per kind',
      );
    });

    test('DA-3: rename and activate notify; remove activates the previously '
        'active application and drops the removed one\'s state', () {
      final registry = DefaultSystemState()..add(_static('forge'));
      registry.registerFactory(_QuestFactory());
      final a = registry.open('quest', title: 'A');
      final b = registry.open('quest', title: 'B');
      var notified = 0;
      registry.listenable.addListener(() => notified++);

      registry.rename(a.id, 'A renamed');
      expect(a.title, 'A renamed');
      expect(notified, 1);

      registry.activate(a.id);
      registry.activate(b.id);
      final editor = _StubEditor('b.md');
      registry
        ..addOpenEditor(editor)
        ..setActiveEditor(editor);

      registry.remove(b.id);
      expect(registry.active, a, reason: 'the one active before b');
      expect(registry.byId(b.id), isNull);
      expect(registry.openEditors, isEmpty);

      registry.remove(a.id);
      expect(registry.active!.id, 'forge');
      expect(
        () => registry.remove('forge'),
        throwsStateError,
        reason: 'the last application stays',
      );
    });

    test('DA-4: a snapshot holds the restorable applications only; restore '
        'recreates them through their factories and activates the saved one; '
        'an entry whose kind has no factory is kept, not lost', () {
      final before = DefaultSystemState()..add(_static('forge'));
      before.registerFactory(_QuestFactory());
      final a = before.open('quest', title: 'A', payload: {'quest': 'a'});
      before.open('quest', title: 'B', payload: {'quest': 'b'});
      before.rename(a.id, 'A renamed');
      before.activate(a.id);
      final snapshot =
          jsonDecode(jsonEncode(before.snapshot())) as Map<String, Object?>;
      (snapshot['applications']! as List).add({
        'id': 'chat-1',
        'kind': 'chat',
        'title': 'Chat',
        'payload': <String, Object?>{},
      });

      final after = DefaultSystemState()..add(_static('forge'));
      after.registerFactory(_QuestFactory());
      after.restore(snapshot);
      expect(after.all.map((app) => app.title), ['forge', 'A renamed', 'B']);
      expect(after.active!.id, a.id);
      expect(after.byId(a.id)!.payload, {'quest': 'a'});
      final again = after.snapshot()['applications']! as List;
      expect(
        again.map((e) => (e as Map)['id']),
        contains('chat-1'),
        reason: 'an unrestorable entry is written back',
      );
    });
  });

  group('the shell', () {
    testWidgets('DA-5: the switcher follows the registry live — an opened '
        'application is shown, a rename is listed, a removal switches away', (
      tester,
    ) async {
      final shell = _shell();
      shell.applications
        ..add(_static('forge'))
        ..registerFactory(_QuestFactory());
      await tester.pumpWidget(_app(shell));
      await tester.pumpAndSettle();
      expect(find.text('forge'), findsWidgets);

      final quest = shell.applications.open('quest', title: 'webwork');
      await tester.pumpAndSettle();
      expect(find.text('Quest webwork'), findsOneWidget);
      expect(find.text('webwork'), findsWidgets);

      shell.applications.rename(quest.id, 'webwork (2)');
      await tester.pumpAndSettle();
      expect(find.text('webwork (2)'), findsWidgets);
      await tester.tap(find.byTooltip('Switch Application'));
      await tester.pumpAndSettle();
      expect(find.text('webwork (2)'), findsWidgets);
      await tester.tap(find.text('forge').last);
      await tester.pumpAndSettle();
      expect(shell.applications.active!.id, 'forge');

      shell.applications.activate(quest.id);
      await tester.pumpAndSettle();
      shell.applications.remove(quest.id);
      await tester.pumpAndSettle();
      expect(shell.applications.active!.id, 'forge');
      expect(find.text('Quest webwork', skipOffstage: false), findsNothing);
    });

    test('DA-6: after a restart the applications open at exit come back, with '
        'their ids, titles and payloads, and the active one active', () async {
      final workspace = Directory.systemTemp.createTempSync('wonecmpc14_');
      addTearDown(() => workspace.deleteSync(recursive: true));

      final first = await _startedShell(workspace);
      final a = first.applications.open(
        'quest',
        title: 'webwork',
        payload: {'quest': 'webwork'},
      );
      first.applications.open(
        'quest',
        title: 'tom_core',
        payload: {'quest': 'tom_core'},
      );
      first.applications.rename(a.id, 'webwork, renamed');
      first.applications.activate(a.id);
      await first.applicationsWritten();

      final second = await _startedShell(workspace);
      expect(second.applications.all.map((app) => app.title), [
        'forge',
        'webwork, renamed',
        'tom_core',
      ]);
      expect(second.applications.active!.id, a.id);
      expect(second.applications.byId(a.id)!.payload, {'quest': 'webwork'});
      expect(second.applications.byId(a.id)!.kind, 'quest');
      await second.applicationsWritten();
    });

    test('DA-7: removing an application deletes its stored per-application '
        'state', () async {
      final workspace = Directory.systemTemp.createTempSync('wonecmpc14_');
      addTearDown(() => workspace.deleteSync(recursive: true));
      final shell = await _startedShell(workspace);
      final quest = shell.applications.open('quest', title: 'webwork');
      final state = shell.workspaceState as DefaultWorkspaceStateManager;
      await state.saveApplicationState(quest.id, {'openEditors': <String>[]});
      expect(await state.loadApplicationState(quest.id), isNotNull);

      shell.applications.remove(quest.id);
      await shell.applicationsWritten();
      expect(await state.loadApplicationState(quest.id), isNull);
    });
  });
}

/// A static application (no kind) with [id] as its title.
ForgeApplication _static(String id) => ForgeApplication(
  id: id,
  title: id,
  layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
);

/// Makes full-screen quest applications; the view shows the title it was
/// made with.
class _QuestFactory implements ForgeApplicationFactory {
  @override
  String get kind => 'quest';

  @override
  ForgeApplication create({
    required String id,
    required String title,
    required Map<String, Object?> payload,
  }) => ForgeApplication(
    id: id,
    title: title,
    kind: kind,
    payload: payload,
    layout: FullScreenLayout(view: _LabelView('Quest $title')),
  );
}

DefaultShellApi _shell({ForgeWorkspaceStateManager? workspaceState}) =>
    DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: TomMemoryFileSystem(),
      appName: 'Dynamic applications test',
      navigatorKey: GlobalKey<NavigatorState>(),
      workspaceState: workspaceState,
    );

/// A start the way a host makes one: workspace state initialized, the
/// static application and the factory registered, then the restore.
Future<DefaultShellApi> _startedShell(Directory workspace) async {
  final state = DefaultWorkspaceStateManager();
  await state.initialize(workspace.path);
  final shell = _shell(workspaceState: state);
  shell.applications
    ..add(_static('forge'))
    ..registerFactory(_QuestFactory());
  await shell.restoreApplications();
  return shell;
}

Widget _app(DefaultShellApi shell) => MaterialApp(
  home: ForgeShellScaffold(
    shell: shell,
    layoutController: shell.layout as DefaultLayoutController,
    systemState: shell.systemState as DefaultSystemState,
    statusBarController: shell.statusBar,
    notificationManager: shell.notifications as DefaultNotificationManager,
  ),
);

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
  Widget buildMain(BuildContext context) => Center(child: Text(label));

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
