// The editors of the setting kinds with behaviour: fonts, key bindings and
// chords, the key binding table, tool paths, actions and flows, status
// lines, run-time choices, scaled numbers, dates and times, the colour
// picker and groups — each run through the values service's hooks.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show TomTextResourceProvider;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'support/behaviour_configuration.dart';
import 'support/demo_configuration.dart' show demoPage;

const _settle = Duration(milliseconds: 600);

Finder _entry(ForgeSetting<Object> setting) => find.byKey(
  ValueKey('forge.configuration.setting.${forgeSettingEntryKey(setting)}'),
);

Finder _in(ForgeSetting<Object> setting, Finder finder) =>
    find.descendant(of: _entry(setting), matching: finder);

void main() {
  late ForgeMemoryStateStore store;
  late ForgeConfigurationValues values;
  late BehaviourHooks hooks;

  Future<void> start(
    WidgetTester tester, {
    Map<String, Object?> initial = const {},
    ForgeHelpPanelBuilder? buildHelpPanel,
    ForgePathPicker? pickPath,
  }) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    store = ForgeMemoryStateStore(initial: initial);
    hooks = BehaviourHooks();
    values = ForgeConfigurationValues(
      store,
      descriptions: [behaviourDescription],
      hooks: hooks.hooks,
    );
    await tester.runAsync(values.load);
    await tester.pumpWidget(
      demoPage(
        forgeConfigurationTiles(
          values,
          buildHelpPanel: buildHelpPanel,
          pickPath: pickPath,
        ),
        tileWidth: 640,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(_settle);
    await tester.runAsync(values.flushed);
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(_settle);
    values.dispose();
    await hooks.dispose();
  }

  setUp(() {
    TomTextResourceProvider.setAppResourceProvider(
      TomTextResourceProvider.from(<String, dynamic>{}),
    );
  });

  tearDown(TomTextResourceProvider.clearAppResourceProvider);

  test('the description is sound with its hooks', () {
    expect(
      behaviourDescription.problems(hooks: BehaviourHooks().hooks),
      isEmpty,
    );
  });

  group('font family', () {
    testWidgets('the picker lists the provider\'s fonts, filters, stores', (
      tester,
    ) async {
      await start(tester);
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.font.pick.codeFont')),
      );
      await tester.pump();
      await tester.pump();
      // Monospace: the provider is asked with the key `monospace`.
      expect(hooks.fontKeys.last, 'monospace');
      final dialog = find.byType(AlertDialog);
      expect(
        find.descendant(of: dialog, matching: find.text('Default font')),
        findsOneWidget,
      );
      expect(find.text('JetBrains Mono'), findsOneWidget);
      expect(find.text('Fira Code'), findsOneWidget);
      expect(find.text('Arial'), findsNothing);
      expect(find.text('monospace'), findsOneWidget);

      // Every font: the provider asked without the key.
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.font.monospace')).first,
      );
      await tester.pump();
      await tester.pump();
      expect(hooks.fontKeys.last, isNull);
      expect(find.text('Arial'), findsOneWidget);

      // Search narrows the list; the name is drawn in its font.
      await tester.enterText(
        find.byKey(const ValueKey('forge.configuration.font.search')),
        'men',
      );
      await tester.pump();
      expect(find.text('Fira Code'), findsNothing);
      final menlo = tester.widget<Text>(find.text('Menlo'));
      expect(menlo.style?.fontFamily, 'Menlo');
      await tester.tap(find.text('Menlo'));
      await flush(tester);
      expect(store.snapshot()['demo.codeFont'], 'Menlo');
      expect(
        tester
            .widget<TextField>(_in(fontSetting, find.byType(TextField)))
            .controller!
            .text,
        'Menlo',
      );

      // A custom name is offered when typed.
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.font.pick.codeFont')),
      );
      await tester.pump();
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('forge.configuration.font.search')),
        'My Font',
      );
      await tester.pump();
      await tester.tap(find.text('Use "My Font"'));
      await flush(tester);
      expect(store.snapshot()['demo.codeFont'], 'My Font');
      await finish(tester);
    });
  });

  group('key bindings', () {
    testWidgets('a combination is captured, Escape cancels, Clear unbinds', (
      tester,
    ) async {
      await start(tester);
      expect(_in(quickOpenSetting, find.text('Not bound')), findsOneWidget);
      await tester.tap(_in(quickOpenSetting, find.text('Not bound')));
      await tester.pump();
      expect(
        _in(quickOpenSetting, find.text('Press a key combination…')),
        findsOneWidget,
      );
      // A modifier alone captures nothing.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        _in(quickOpenSetting, find.text('Press a key combination…')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await flush(tester);
      expect(store.snapshot()['demo.quickOpen'], {
        'keyId': LogicalKeyboardKey.keyP.keyId,
        'primaryModifier': true,
        'control': false,
        'shift': false,
        'alt': false,
      });
      expect(_in(quickOpenSetting, find.text('Ctrl+P')), findsOneWidget);

      // Escape stops capturing and keeps the binding.
      await tester.tap(_in(quickOpenSetting, find.text('Ctrl+P')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_in(quickOpenSetting, find.text('Ctrl+P')), findsOneWidget);
      expect(
        values.valueOf(quickOpenSetting),
        ForgeKeyStroke(LogicalKeyboardKey.keyP.keyId, primaryModifier: true),
      );

      // Clear unbinds.
      await tester.tap(_in(quickOpenSetting, find.byTooltip('Clear')));
      await flush(tester);
      expect(store.snapshot()['demo.quickOpen'], {'keyId': 0});
      expect(_in(quickOpenSetting, find.text('Not bound')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('labels follow the platform\'s primary modifier', (
      tester,
    ) async {
      final stroke = ForgeKeyStroke(
        LogicalKeyboardKey.keyK.keyId,
        primaryModifier: true,
        shift: true,
      );
      expect(forgeKeyStrokeLabel(stroke, primaryIsMeta: false), 'Ctrl+Shift+K');
      expect(forgeKeyStrokeLabel(stroke, primaryIsMeta: true), '⇧⌘K');
      expect(
        forgeKeyChordLabel(
          ForgeKeyChord([
            stroke,
            ForgeKeyStroke(LogicalKeyboardKey.keyS.keyId),
          ]),
          primaryIsMeta: false,
        ),
        'Ctrl+Shift+K S',
      );
      expect(forgePrimaryIsMeta(TargetPlatform.macOS), isTrue);
      expect(forgePrimaryIsMeta(TargetPlatform.linux), isFalse);
    });

    testWidgets('a chord is captured stroke after stroke', (tester) async {
      await start(tester);
      await tester.tap(_in(chordSetting, find.text('Not bound')));
      await tester.pump();
      expect(
        _in(chordSetting, find.text('Press the keys one after the other…')),
        findsOneWidget,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(_in(chordSetting, find.text('Ctrl+K …')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pump();
      // Done ends it before the third stroke.
      await tester.tap(_in(chordSetting, find.byTooltip('Done')));
      await flush(tester);
      final chord = values.valueOf(chordSetting);
      expect(chord.strokes, [
        ForgeKeyStroke(LogicalKeyboardKey.keyK.keyId, primaryModifier: true),
        ForgeKeyStroke(LogicalKeyboardKey.keyS.keyId),
      ]);
      expect(
        (store.snapshot()['demo.chord'] as Map).keys,
        containsAll(['firstKey', 'secondKey']),
      );
      expect(_in(chordSetting, find.text('Ctrl+K S')), findsOneWidget);

      // Reaching the most strokes ends it by itself.
      await tester.tap(_in(chordSetting, find.text('Ctrl+K S')));
      await tester.pump();
      for (final key in [
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyC,
      ]) {
        await tester.sendKeyEvent(key);
      }
      await flush(tester);
      expect(values.valueOf(chordSetting).strokes, hasLength(3));
      expect(_in(chordSetting, find.text('A B C')), findsOneWidget);

      // One stroke is too few: refused with the reason.
      await tester.tap(_in(chordSetting, find.text('A B C')));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
      await tester.pump();
      await tester.tap(_in(chordSetting, find.byTooltip('Done')));
      await flush(tester);
      expect(values.valueOf(chordSetting).strokes, hasLength(3));
      expect(
        _in(chordSetting, find.text('A chord of 2 to 3 keys.')),
        findsOneWidget,
      );
      await finish(tester);
    });
  });

  group('key binding table', () {
    Finder row(String id) =>
        find.byKey(ValueKey('forge.configuration.keyTable.row.$id'));
    Finder inRow(String id, Finder finder) =>
        find.descendant(of: row(id), matching: finder);

    testWidgets('rows, a conflict, search, per-row reset and reset all', (
      tester,
    ) async {
      await start(tester);
      // The catalogue's actions with their defaults, grouped.
      for (final id in ['md.bold', 'md.italic', 'app.save', 'app.find']) {
        expect(row(id), findsOneWidget, reason: id);
      }
      expect(_in(shortcutsSetting, find.text('Markdown')), findsOneWidget);
      expect(_in(shortcutsSetting, find.text('Application')), findsOneWidget);
      expect(inRow('md.bold', find.text('Ctrl+B')), findsOneWidget);
      expect(inRow('md.bold', find.text('In markdown')), findsOneWidget);
      expect(
        _in(shortcutsSetting, find.byIcon(Icons.warning_amber)),
        findsNothing,
      );

      // Bind Find to Ctrl+B: it collides with Bold (Find is everywhere).
      await tester.tap(inRow('app.find', find.text('Ctrl+F')));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await flush(tester);
      expect(store.snapshot()['demo.shortcuts'], {
        'app.find': {
          'keyId': LogicalKeyboardKey.keyB.keyId,
          'primaryModifier': true,
          'control': false,
          'shift': false,
          'alt': false,
        },
      });
      expect(
        inRow('app.find', find.text('Also bound to Bold.')),
        findsOneWidget,
      );
      expect(
        inRow('md.bold', find.text('Also bound to Find.')),
        findsOneWidget,
      );
      expect(
        _in(shortcutsSetting, find.byIcon(Icons.warning_amber)),
        findsNWidgets(2),
      );

      // Search keeps the matching rows (label, id, binding).
      final search = find.byKey(
        const ValueKey('forge.configuration.keyTable.search.shortcuts'),
      );
      await tester.enterText(search, 'ital');
      await tester.pump();
      expect(row('md.italic'), findsOneWidget);
      expect(row('md.bold'), findsNothing);
      await tester.enterText(search, 'ctrl+b');
      await tester.pump();
      expect(row('md.bold'), findsOneWidget);
      expect(row('app.find'), findsOneWidget);
      expect(row('app.save'), findsNothing);
      await tester.enterText(search, 'zzz');
      await tester.pump();
      expect(find.text('Nothing matches.'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pump();

      // The row's reset brings its default back.
      await tester.tap(
        find.byKey(
          const ValueKey('forge.configuration.keyTable.reset.app.find'),
        ),
      );
      await flush(tester);
      expect(store.snapshot()['demo.shortcuts'], isEmpty);
      expect(
        _in(shortcutsSetting, find.byIcon(Icons.warning_amber)),
        findsNothing,
      );

      // Remove a binding (kept in the companion), bind one for every editor.
      await tester.tap(inRow('app.save', find.byTooltip('Remove binding')));
      await flush(tester);
      expect(store.snapshot()['demo.deletedBindings'], ['app.save']);
      expect(inRow('app.save', find.text('Not bound')), findsOneWidget);
      expect(
        inRow('app.find', find.byTooltip('Bind for every editor')),
        findsNothing,
      );
      await tester.tap(
        inRow('md.bold', find.byTooltip('Bind for every editor')),
      );
      await flush(tester);
      expect((store.snapshot()['demo.shortcuts'] as Map).keys, ['*.bold']);
      expect(inRow('*.bold', find.text('All editors')), findsOneWidget);

      // Reset all clears the overrides and the deletions.
      await tester.tap(
        find.byKey(
          const ValueKey('forge.configuration.keyTable.resetAll.shortcuts'),
        ),
      );
      await flush(tester);
      expect(store.snapshot().containsKey('demo.shortcuts'), isFalse);
      expect(store.snapshot().containsKey('demo.deletedBindings'), isFalse);
      expect(row('*.bold'), findsNothing);
      expect(inRow('app.save', find.text('Ctrl+S')), findsOneWidget);
      await finish(tester);
    });
  });

  group('tool path', () {
    testWidgets(
      'state, detect with progress, pick a candidate, help, actions',
      (tester) async {
        ForgePathSetting? browsed;
        await start(
          tester,
          buildHelpPanel: (context, id, setting) =>
              Text('help panel $id for ${setting.id}'),
          pickPath: (setting, current) async {
            browsed = setting;
            return '/somewhere/else';
          },
        );
        // Empty: what the usual search finds.
        expect(_in(toolSetting, find.text('Version 3.1')), findsOneWidget);
        expect(
          _in(toolSetting, find.text('/usr/local/bin/pandoc (PATH)')),
          findsOneWidget,
        );
        expect(find.textContaining('help panel'), findsNothing);

        // Detect: progress while it searches, then the candidates.
        hooks.detectGate = Completer<void>();
        await tester.tap(_in(toolSetting, find.text('Detect')));
        await tester.pump();
        await tester.pump();
        expect(_in(toolSetting, find.text('Looking in PATH')), findsOneWidget);
        expect(
          _in(toolSetting, find.byType(LinearProgressIndicator)),
          findsOneWidget,
        );
        expect(hooks.detectHints?.executableNames, ['pandoc']);
        hooks.detectGate!.complete();
        await tester.pump();
        await tester.pump();
        expect(
          _in(toolSetting, find.text('/opt/pandoc/bin/pandoc')),
          findsOneWidget,
        );
        expect(
          _in(toolSetting, find.text('Version 1.9 · too old')),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: find.byKey(
              const ValueKey('forge.configuration.toolPath.candidate.0'),
            ),
            matching: find.text('Use'),
          ),
        );
        await flush(tester);
        expect(store.snapshot()['demo.tool'], '/opt/pandoc/bin/pandoc');
        expect(_in(toolSetting, find.text('Version 3.5')), findsOneWidget);

        // Browse: the application's picker, asked for a path setting.
        await tester.tap(_in(toolSetting, find.text('Browse…')));
        await flush(tester);
        expect(browsed?.id, 'tool');
        expect(store.snapshot()['demo.tool'], '/somewhere/else');
        // Not usable: the reason and the application's help panel.
        expect(_in(toolSetting, find.text('no such file')), findsOneWidget);
        expect(
          find.text('help panel demo.installHelp for tool'),
          findsOneWidget,
        );

        // The setting's own action, with its result.
        await tester.tap(_in(toolSetting, find.text('Download')));
        await tester.pump();
        await tester.pump();
        expect(_in(toolSetting, find.text('No network.')), findsOneWidget);
        await finish(tester);
      },
    );
  });

  group('actions, flows and status', () {
    testWidgets('an action shows its progress, then its result', (
      tester,
    ) async {
      await start(tester);
      hooks.reloadGate = Completer<void>();
      final statusBefore = hooks.statusReads;
      await tester.tap(_in(reloadSetting, find.text('Reload')));
      await tester.pump();
      await tester.pump();
      expect(_in(reloadSetting, find.text('Reading files')), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        _in(reloadSetting, find.byType(LinearProgressIndicator)),
      );
      expect(bar.value, 0.25);
      expect(_in(reloadSetting, find.text('Stop')), findsOneWidget);
      hooks.reloadGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(hooks.reloads, 1);
      expect(
        _in(reloadSetting, find.text('Reloaded 3 files.')),
        findsOneWidget,
      );
      expect(_in(reloadSetting, find.text('Stop')), findsNothing);
      // An action entry keeps no value: no reset button.
      expect(
        find.byKey(const ValueKey('forge.configuration.reset.#reload')),
        findsNothing,
      );
      // Its result asked for a refresh of the same setting only.
      expect(hooks.statusReads, statusBefore);

      // Stop: the run ends as cancelled.
      hooks.reloadGate = Completer<void>();
      await tester.tap(_in(reloadSetting, find.text('Reload')));
      await tester.pump();
      await tester.tap(_in(reloadSetting, find.text('Stop')));
      hooks.reloadGate!.complete();
      await tester.pump();
      await tester.pump();
      expect(_in(reloadSetting, find.text('Cancelled.')), findsOneWidget);
      expect(hooks.reloads, 1);
      await finish(tester);
    });

    testWidgets('a flow runs its steps in a dialog', (tester) async {
      await start(tester);
      await tester.tap(_in(signInSetting, find.text('Sign in')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Sign in to Demo'), findsOneWidget);
      expect(find.text('WDJB-MJHT'), findsOneWidget);
      expect(find.text('https://example.invalid/device'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Enter the code'), findsOneWidget);
      final otp = find.byKey(
        const ValueKey('forge.configuration.flow.field.otp'),
      );
      // Too short: refused before it is sent.
      await tester.enterText(otp, '12');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(hooks.codes, isEmpty);
      // A wrong code: the step comes back with the session's error.
      await tester.enterText(otp, '000000');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();
      expect(hooks.codes, ['000000']);
      expect(find.text('That code is not right.'), findsOneWidget);
      await tester.enterText(otp, '123456');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);
      expect(_in(signInSetting, find.text('Signed in as al.')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a status is read, followed while streamed, items capped', (
      tester,
    ) async {
      await start(tester);
      expect(_in(healthSetting, find.text('Index is stale')), findsOneWidget);
      expect(_in(healthSetting, find.text('12 files changed')), findsOneWidget);
      expect(_in(healthSetting, find.text('a.md')), findsOneWidget);
      expect(_in(healthSetting, find.text('c.md')), findsNothing);
      expect(_in(healthSetting, find.text('and 1 more')), findsOneWidget);
      hooks.statusStream.add(
        const ForgeStatusInfo(
          level: ForgeStatusLevel.ok,
          message: ForgeText('demo.health.ok', 'Index is current'),
        ),
      );
      await tester.pump();
      expect(_in(healthSetting, find.text('Index is current')), findsOneWidget);
      expect(_in(healthSetting, find.text('a.md')), findsNothing);
      expect(
        _in(healthSetting, find.byIcon(Icons.check_circle)),
        findsOneWidget,
      );
      await finish(tester);
    });
  });

  group('values', () {
    testWidgets('run-time choices: loading, then the choices and None', (
      tester,
    ) async {
      final gate = Completer<void>();
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store = ForgeMemoryStateStore();
      hooks = BehaviourHooks()..editorsAnswer = gate;
      values = ForgeConfigurationValues(
        store,
        descriptions: [behaviourDescription],
        hooks: hooks.hooks,
      );
      await tester.runAsync(values.load);
      await tester.pumpWidget(
        demoPage(forgeConfigurationTiles(values), tileWidth: 640),
      );
      await tester.pump();
      expect(_in(openerSetting, find.text('Loading…')), findsOneWidget);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(_in(openerSetting, find.text('Loading…')), findsNothing);
      // Nothing chosen: None.
      expect(_in(openerSetting, find.text('None')), findsOneWidget);
      await tester.tap(_in(openerSetting, find.text('None')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plain text').last);
      await tester.pumpAndSettle();
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.opener'], 'text');
      // None again stores "".
      await tester.tap(_in(openerSetting, find.text('Plain text')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.opener'], '');
      await finish(tester);
    });

    testWidgets('a map asks its provider per key, the default key first', (
      tester,
    ) async {
      await start(tester);
      expect(hooks.editorKeys, containsAll(['*', '.md']));
      final rows = find.descendant(
        of: _entry(openersSetting),
        matching: find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'forge.configuration.map.openers.',
              ),
        ),
      );
      expect(
        tester.widgetList(rows).map((w) => (w.key! as ValueKey<String>).value),
        [
          'forge.configuration.map.openers.*',
          'forge.configuration.map.openers..md',
        ],
      );
      expect(
        _in(openersSetting, find.text('Every other file')),
        findsOneWidget,
      );
      // The default key's row cannot be removed.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('forge.configuration.map.openers.*')),
          matching: find.byTooltip('Remove'),
        ),
        findsNothing,
      );
      // A new key is normalised (TXT → .txt).
      await tester.enterText(
        _in(openersSetting, find.byType(TextField)).last,
        'TXT',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await flush(tester);
      expect(
        (store.snapshot()['demo.openers'] as Map).keys,
        containsAll(['*', '.md', '.txt']),
      );
      await finish(tester);
    });

    testWidgets('a scaled number shows the shown unit and stores scaled', (
      tester,
    ) async {
      await start(tester);
      final field = _in(limitSetting, find.byType(TextField));
      expect(tester.widget<TextField>(field).controller!.text, '5');
      expect(_in(limitSetting, find.text('MB')), findsOneWidget);
      await tester.enterText(field, '12');
      await flush(tester);
      expect(store.snapshot()['demo.limit'], 12 * 1048576);
      await tester.enterText(field, '0.5');
      await flush(tester);
      expect(store.snapshot()['demo.limit'], 524288);
      // Reset shows the default in the shown unit again.
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.reset.demo.limit')),
      );
      await flush(tester);
      expect(
        tester
            .widget<TextField>(_in(limitSetting, find.byType(TextField)))
            .controller!
            .text,
        '5',
      );
      await finish(tester);
    });

    testWidgets('a date is picked with the date picker', (tester) async {
      await start(tester);
      expect(_in(sinceSetting, find.text('Nov 10, 2026')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.pick.since')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.since'], '2026-11-15');
      expect(_in(sinceSetting, find.text('Nov 15, 2026')), findsOneWidget);
      // Clear: no date.
      await tester.tap(_in(sinceSetting, find.byTooltip('Clear')));
      await flush(tester);
      expect(store.snapshot()['demo.since'], '');
      expect(_in(sinceSetting, find.text('No date')), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a time and a point in time are picked', (tester) async {
      await start(tester);
      // The Times group starts folded.
      expect(_entry(quietSetting), findsNothing);
      await tester.tap(find.text('Times'));
      await tester.pump();
      expect(_in(quietSetting, find.text('10:00 PM')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.pick.quiet')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final inputs = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(inputs.at(0), '7');
      await tester.enterText(inputs.at(1), '30');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.quiet'], '19:30');

      // Date then time.
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.pick.until')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.runAsync(values.flushed);
      expect(store.snapshot()['demo.until'], '2026-11-20T08:00:00');
      expect(
        _in(untilSetting, find.text('Nov 20, 2026 8:00 AM')),
        findsOneWidget,
      );
      await finish(tester);
    });

    testWidgets('the colour picker chooses a swatch and a typed value', (
      tester,
    ) async {
      await start(tester);
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.colour.pick.highlight')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a colour'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('forge.configuration.colour.opacity')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.colour.swatch.9')),
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('forge.configuration.colour.hex')),
            )
            .controller!
            .text,
        '#4CAF50',
      );
      await tester.tap(find.text('OK'));
      await flush(tester);
      expect(store.snapshot()['demo.highlight'], 0xFF4CAF50);
      expect(_in(highlightSetting, find.text('#4CAF50')), findsOneWidget);

      // A typed hex value, and the hue slider moves with it.
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.colour.pick.highlight')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('forge.configuration.colour.hex')),
        '#0000FF',
      );
      await tester.pump();
      final hue = tester.widget<Slider>(
        find.byKey(const ValueKey('forge.configuration.colour.hue')),
      );
      expect(hue.value, closeTo(240, 0.5));
      await tester.tap(find.text('OK'));
      await flush(tester);
      expect(store.snapshot()['demo.highlight'], 0xFF0000FF);

      // Cancel keeps the value.
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.colour.pick.highlight')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('forge.configuration.colour.swatch.0')),
      );
      await tester.tap(find.text('Cancel'));
      await flush(tester);
      expect(store.snapshot()['demo.highlight'], 0xFF0000FF);
      await finish(tester);
    });

    testWidgets('groups: headers, help, folding', (tester) async {
      await start(tester);
      final keys = find.byKey(const ValueKey('forge.configuration.group.keys'));
      expect(keys, findsOneWidget);
      expect(find.text('Keyboard'), findsOneWidget);
      expect(_entry(quickOpenSetting), findsOneWidget);
      // The group's help on request.
      await tester.tap(
        find.descendant(of: keys, matching: find.byTooltip('Show help')),
      );
      await tester.pump();
      expect(find.text('Single keys and chords.'), findsOneWidget);
      // Folding hides its settings, unfolding shows them.
      await tester.tap(find.text('Keyboard'));
      await tester.pump();
      expect(_entry(quickOpenSetting), findsNothing);
      expect(_entry(chordSetting), findsNothing);
      await tester.tap(find.text('Keyboard'));
      await tester.pump();
      expect(_entry(chordSetting), findsOneWidget);
      // The folded Times group.
      expect(find.text('Times'), findsOneWidget);
      expect(_entry(untilSetting), findsNothing);
      await finish(tester);
    });

    testWidgets('the trail logs the hook runs while its switch is on', (
      tester,
    ) async {
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      kConfigurationUiDebug = true;
      try {
        await start(tester);
        await tester.tap(_in(reloadSetting, find.text('Reload')));
        await tester.pump();
        await tester.pump();
        await finish(tester);
      } finally {
        kConfigurationUiDebug = false;
        debugPrint = previous;
      }
      for (final event in [
        'action demo.reload for reload: run',
        'action demo.reload for reload: success',
        'refresh #reload',
        'status demo.health: read',
        'catalogue demo.actions: 4 actions',
        'check demo.detector',
      ]) {
        expect(
          lines.any((l) => l.contains(event)),
          isTrue,
          reason: '$event in\n${lines.join('\n')}',
        );
      }
    });
  });
}
