/// The application lifecycle (wonecmpc15).
///
/// An application's [ForgeApplicationLifecycle] hears when it is created,
/// activated, deactivated, asked to close (and may veto with a reason) and
/// closed. An application with background work keeps its state however many
/// others are switched through, is closed only once its veto is answered, and
/// shows what it is busy with in the application switcher.
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

  group('the hooks', () {
    test('LC-1: created, activated and deactivated as applications are added '
        'and switched, then closing, deactivated and closed when the active '
        'one closes', () async {
      final events = <String>[];
      final registry = DefaultSystemState();
      final a = _app('a', _Recorder('a', events));
      final b = _app('b', _Recorder('b', events));
      registry.add(a);
      registry.add(b);
      registry.activate(b.id);
      registry.activate(a.id);
      expect(await registry.close(a.id), isTrue);
      expect(events, [
        'a created',
        'a activated',
        'b created',
        'a deactivated',
        'b activated',
        'b deactivated',
        'a activated',
        'a closing',
        'a deactivated',
        'b activated',
        'a closed',
      ]);
    });

    test('LC-2: a veto stands without a confirmer and when declined; a '
        'confirmed veto closes; the reason reaches the confirmer', () async {
      final events = <String>[];
      final registry = DefaultSystemState()..add(_app('forge', null));
      final busy = _Recorder(
        'quest',
        events,
        veto: 'The queue is still sending three prompts.',
      );
      final quest = _app('quest', busy);
      registry.add(quest, activate: true);

      expect(await registry.close(quest.id), isFalse);
      expect(registry.byId(quest.id), quest, reason: 'no one to ask');

      final asked = <String>[];
      var answer = false;
      registry.confirmClose = (application, reason) async {
        asked.add('${application.id}: $reason');
        return answer;
      };
      expect(await registry.close(quest.id), isFalse);
      expect(registry.byId(quest.id), quest, reason: 'declined');

      answer = true;
      expect(await registry.close(quest.id), isTrue);
      expect(registry.byId(quest.id), isNull);
      expect(asked, [
        'quest: The queue is still sending three prompts.',
        'quest: The queue is still sending three prompts.',
      ]);
      expect(events.where((e) => e.endsWith('closed')), ['quest closed']);
      expect(
        events.indexOf('quest closed'),
        greaterThan(events.lastIndexOf('quest deactivated')),
      );
    });

    test('LC-3: two closes of one application ask once', () async {
      final events = <String>[];
      final registry = DefaultSystemState()..add(_app('forge', null));
      final quest = _app('quest', _Recorder('quest', events, veto: 'busy'));
      registry.add(quest);
      var asked = 0;
      registry.confirmClose = (_, _) async {
        asked++;
        return true;
      };
      final results = await Future.wait([
        registry.close(quest.id),
        registry.close(quest.id),
      ]);
      expect(results, [isTrue, isTrue]);
      expect(asked, 1);
      expect(events.where((e) => e == 'quest closed'), hasLength(1));
    });
  });

  group('background work', () {
    test('LC-4: an application with background work keeps its state '
        'however many others are switched through; one without is evicted', () {
      final registry = DefaultSystemState(maxApplicationStates: 1);
      final background = _Recorder('bg', [])..background.value = true;
      final quest = _app('quest', background);
      final plain = _app('plain', null);
      final others = [for (var i = 0; i < 3; i++) _app('other$i', null)];
      registry
        ..add(quest)
        ..add(plain);
      for (final app in others) {
        registry.add(app);
      }

      final questEditor = _StubEditor('quest.md');
      registry
        ..addOpenEditor(questEditor)
        ..setActiveEditor(questEditor);
      registry.activate(plain.id);
      final plainEditor = _StubEditor('plain.md');
      registry
        ..addOpenEditor(plainEditor)
        ..setActiveEditor(plainEditor);
      for (final app in others) {
        registry.activate(app.id);
      }

      registry.activate(quest.id);
      expect(registry.openEditors, [questEditor]);
      registry.activate(plain.id);
      expect(
        registry.openEditors,
        isEmpty,
        reason: 'evicted under maxApplicationStates: 1',
      );
    });

    testWidgets('LC-5: the switcher shows what an application is busy with, '
        'in its list and, from another application, beside the switcher', (
      tester,
    ) async {
      final shell = _shell();
      final background = _Recorder('quest', []);
      final quest = _app('quest', background);
      shell.applications
        ..add(_app('forge', null))
        ..add(quest);
      await tester.pumpWidget(_scaffold(shell));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('forge.application.busyElsewhere')),
        findsNothing,
      );

      background.busyLabel.value = 'Queue running';
      await tester.pumpAndSettle();
      final elsewhere = find.byKey(
        const ValueKey('forge.application.busyElsewhere'),
      );
      expect(elsewhere, findsOneWidget);
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: elsewhere, matching: find.byType(Tooltip)).first,
            )
            .message,
        'quest: Queue running',
      );

      await tester.tap(find.byTooltip('Switch Application'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('forge.application.busy.quest')),
        findsOneWidget,
      );
      await tester.tap(find.text('quest').last);
      await tester.pumpAndSettle();
      expect(
        elsewhere,
        findsNothing,
        reason: 'the badge beside the switcher is for applications not shown',
      );

      background.busyLabel.value = null;
      await tester.pumpAndSettle();
      shell.applications.activate('forge');
      await tester.pumpAndSettle();
      expect(elsewhere, findsNothing);
    });

    testWidgets('LC-6: Close Application asks with the veto\'s reason; Keep '
        'open keeps it, Close anyway closes it and switches away', (
      tester,
    ) async {
      final shell = _shell();
      final events = <String>[];
      shell.applications
        ..add(_app('forge', null))
        ..add(
          _app(
            'quest',
            _Recorder('quest', events, veto: 'Three prompts left.'),
          ),
          activate: true,
        );
      await tester.pumpWidget(_scaffold(shell));
      await tester.pumpAndSettle();

      shell.executeAction('forge.application.close');
      await tester.pumpAndSettle();
      expect(find.text('Close quest?'), findsOneWidget);
      expect(find.text('Three prompts left.'), findsOneWidget);
      await tester.tap(find.text('Keep open'));
      await tester.pumpAndSettle();
      expect(shell.applications.byId('quest'), isNotNull);
      expect(shell.applications.active!.id, 'quest');

      shell.executeAction('forge.application.close');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close anyway'));
      await tester.pumpAndSettle();
      expect(shell.applications.byId('quest'), isNull);
      expect(shell.applications.active!.id, 'forge');
      expect(events.last, 'quest closed');
      expect(
        shell.isActionEnabled('forge.application.close'),
        isFalse,
        reason: 'the last application cannot be closed',
      );
    });
  });

  group('shutdown', () {
    test('LC-7: disposing the shell tells every open application closed and '
        'keeps them in the file for the next start', () async {
      final workspace = Directory.systemTemp.createTempSync('wonecmpc15_');
      addTearDown(() => workspace.deleteSync(recursive: true));
      final events = <String>[];
      final state = DefaultWorkspaceStateManager();
      await state.initialize(workspace.path);
      final shell = _shell(workspaceState: state);
      shell.applications
        ..add(_app('forge', _Recorder('forge', events)))
        ..registerFactory(_QuestFactory(events));
      await shell.restoreApplications();
      shell.applications.open('quest', title: 'webwork');
      await shell.applicationsWritten();

      shell.dispose();
      expect(events.where((e) => e.endsWith('closed')), [
        'forge closed',
        'webwork closed',
      ]);
      final saved =
          jsonDecode(
                File(
                  '${workspace.path}/.forge/state/applications.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect((saved['applications']! as List).map((e) => (e as Map)['title']), [
        'webwork',
      ]);
    });
  });
}

/// Records every hook as `<name> <hook>`; vetoes a close with [veto] when
/// set; [background] and [busyLabel] are what it reports.
class _Recorder extends ForgeApplicationLifecycle {
  _Recorder(this.name, this.events, {this.veto});

  final String name;
  final List<String> events;
  final String? veto;
  final background = ValueNotifier(false);
  final busyLabel = ValueNotifier<String?>(null);

  @override
  void created(ForgeApplication application) => events.add('$name created');

  @override
  void activated(ForgeApplication application) => events.add('$name activated');

  @override
  void deactivated(ForgeApplication application) =>
      events.add('$name deactivated');

  @override
  Future<String?> closing(ForgeApplication application) async {
    events.add('$name closing');
    return veto;
  }

  @override
  void closed(ForgeApplication application) => events.add('$name closed');

  @override
  ValueListenable<bool> get hasBackgroundWork => background;

  @override
  ValueListenable<String?> get busy => busyLabel;
}

class _QuestFactory implements ForgeApplicationFactory {
  _QuestFactory(this.events);

  final List<String> events;

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
    lifecycle: _Recorder(title, events),
    layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
  );
}

ForgeApplication _app(String id, ForgeApplicationLifecycle? lifecycle) =>
    ForgeApplication(
      id: id,
      title: id,
      lifecycle: lifecycle ?? ForgeApplicationLifecycle.none,
      layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
    );

DefaultShellApi _shell({ForgeWorkspaceStateManager? workspaceState}) =>
    DefaultShellApi.withDefaultsAndFileSystem(
      fileSystem: TomMemoryFileSystem(),
      appName: 'Application lifecycle test',
      navigatorKey: GlobalKey<NavigatorState>(),
      workspaceState: workspaceState,
    );

Widget _scaffold(DefaultShellApi shell) => MaterialApp(
  home: ForgeShellScaffold(
    shell: shell,
    layoutController: shell.layout as DefaultLayoutController,
    systemState: shell.systemState as DefaultSystemState,
    statusBarController: shell.statusBar,
    notificationManager: shell.notifications as DefaultNotificationManager,
  ),
);

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
