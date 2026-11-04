/// The undo keys (wonecmpc18).
///
/// One layer owns them: the shell's binding table. Primary+Z undoes,
/// Shift+Primary+Z redoes, and on Windows and Linux Ctrl+Y redoes too; Delete
/// Line is Shift+Primary+K. The shell routes a bound key to the focused
/// editor, leaves a text-editing key typed into a text field outside the
/// editors to that field, and does not consume a key whose action did
/// nothing. Editors build their local key maps from the same table and
/// rebuild them when a key is rebound. The macOS menu runs once per
/// keystroke.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions, buildEditorShortcutMap;
import 'package:tom_editors_shared/tom_editors_shared.dart' as shared
    show ForgeShortcutKey;
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

  group('the shell routes the undo keys', () {
    testWidgets('KR-1: Primary+Z undoes and Shift+Primary+Z redoes in the '
        'focused editor; the shell\'s manager is not touched', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await h.focusEditor(tester);

      await _press(tester, LogicalKeyboardKey.keyZ, primary: true);
      await _press(tester, LogicalKeyboardKey.keyZ, primary: true, shift: true);
      expect(h.editor.ran, [
        StandardEditingActions.undoActionId,
        StandardEditingActions.redoActionId,
      ]);
      expect(h.shell.undoManager.undoCount + h.shell.undoManager.redoCount, 0);
    });

    testWidgets('KR-2: Ctrl+Y redoes on Windows and Linux and means nothing '
        'else', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await h.focusEditor(tester);

      await _press(tester, LogicalKeyboardKey.keyY, primary: true);
      expect(
        h.editor.ran,
        shared.ForgeShortcutKey.primaryIsMeta
            ? isEmpty
            : [StandardEditingActions.redoActionId],
      );
      expect(
        h.editor.ran,
        isNot(contains(StandardEditingActions.deleteLineActionId)),
      );
    });

    testWidgets('KR-3: Primary+Z typed into a text field outside the editors '
        'stays with that field', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_SideField.fieldKey));
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.keyZ, primary: true);
      await _press(tester, LogicalKeyboardKey.keyZ, primary: true, shift: true);
      expect(h.editor.ran, isEmpty, reason: 'the document is left alone');
    });

    testWidgets('KR-4: a key whose action did nothing is not consumed', (
      tester,
    ) async {
      final h = _Harness(editorCanUndo: false);
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await h.focusEditor(tester);

      await _press(tester, LogicalKeyboardKey.keyZ, primary: true);
      expect(h.editor.ran, isEmpty);
      expect(
        h.passedThrough,
        contains(LogicalKeyboardKey.keyZ),
        reason: 'the key went on past the shell',
      );
    });
  });

  group('one key, one meaning', () {
    test('KR-5: no two bindings in the shell\'s table share a key, and the '
        'undo keys are the platform\'s', () {
      final shell = _newShell();
      TomForgeShellModule().activate(shell);
      final integration = _integration(shell);
      addTearDown(integration.dispose);

      final seen = <ForgeShortcutKey, String>{};
      for (final binding in shell.shortcuts.allBindings) {
        if (binding.isChord) continue;
        final other = seen[binding.key];
        expect(
          other,
          isNull,
          reason: '${binding.action.id} and $other share ${binding.key}',
        );
        seen[binding.key] = binding.action.id;
      }
      expect(
        seen[const ForgeShortcutKey(
          key: LogicalKeyboardKey.keyZ,
          primaryModifier: true,
        )],
        StandardEditingActions.undoActionId,
      );
      expect(
        seen[const ForgeShortcutKey(
          key: LogicalKeyboardKey.keyZ,
          primaryModifier: true,
          shift: true,
        )],
        StandardEditingActions.redoActionId,
      );
      expect(
        seen[const ForgeShortcutKey(
          key: LogicalKeyboardKey.keyK,
          primaryModifier: true,
          shift: true,
        )],
        StandardEditingActions.deleteLineActionId,
      );
    });

    test('KR-6: an editor\'s local key map says what the shell\'s table says',
        () {
      final shell = _newShell();
      TomForgeShellModule().activate(shell);
      final integration = _integration(shell);
      addTearDown(integration.dispose);

      final local = buildEditorShortcutMap(integration);
      expect(local, isNotEmpty);
      for (final binding in shell.shortcuts.allBindings) {
        if (binding.isChord) continue;
        final id = binding.action.id;
        if (!StandardEditingActions.standardActionIds.contains(id)) continue;
        final want = binding.key.toActivator();
        final mapped = [
          for (final entry in local.entries)
            if (_sameActivator(entry.key, want)) entry.value,
        ];
        expect(mapped, [id], reason: id);
      }
    });
  });

  group('rebinding', () {
    testWidgets('KR-7: a rebound undo key reaches a focused editor at once; '
        'the old key no longer undoes', (tester) async {
      final shell = _newShell();
      final module = TomForgeShellModule()..activate(shell);
      final editor = ForgePlainTextEditor.fromContent(
        content: 'one',
        uri: Uri.parse('file:///notes.txt'),
        module: module,
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Builder(builder: editor.buildMain))),
      );
      await tester.enterText(find.byType(TextField), 'one two');
      await tester.pump(const Duration(milliseconds: 400));

      final undo = shell.shortcuts.getBinding(
        StandardEditingActions.undoActionId,
      )!;
      shell.shortcuts.rebind(
        undo.action,
        const ForgeShortcutKey(key: LogicalKeyboardKey.f7),
      );
      await tester.pump();

      await _press(tester, LogicalKeyboardKey.keyZ, primary: true);
      expect(editor.controller.markdown, 'one two', reason: 'old key unbound');
      await _press(tester, LogicalKeyboardKey.f7);
      expect(editor.controller.markdown, 'one');
      await tester.pump(const Duration(seconds: 2)); // the typing pause
    });
  });

  group('the macOS menu', () {
    testWidgets('KR-8: the Undo menu item does not run again for the '
        'keystroke the shell already routed; a click runs it', (tester) async {
      final h = _Harness();
      final menuRuns = <String>[];
      h.shell.actionRegistry.registerAction(
        ForgeAction(
          id: 'edit.undo',
          label: 'Undo',
          execute: (_) async {
            menuRuns.add('edit.undo');
            return null;
          },
          isEnabled: () => true,
          isVisible: () => true,
        ),
      );
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await h.focusEditor(tester);

      final undoItem = _menuItem(tester, 'Undo');
      expect(
        undoItem.shortcut,
        isA<SingleActivator>()
            .having((a) => a.trigger, 'trigger', LogicalKeyboardKey.keyZ)
            .having((a) => a.meta, 'meta', isTrue)
            .having((a) => a.shift, 'shift', isFalse),
        reason: 'the accelerator is the binding table\'s',
      );

      // The keystroke: Flutter routes it, then the menu reports the same key.
      await _press(tester, LogicalKeyboardKey.keyZ, primary: true);
      undoItem.onSelected!();
      expect(h.editor.ran, [StandardEditingActions.undoActionId]);
      expect(menuRuns, isEmpty, reason: 'the echo is not run again');

      // A click: the last key-down was something else.
      await _press(tester, LogicalKeyboardKey.keyA);
      undoItem.onSelected!();
      expect(menuRuns, ['edit.undo']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}

/// Presses and releases [key] with the platform's primary modifier and
/// Shift as asked.
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool primary = false,
  bool shift = false,
}) async {
  final modifier = shared.ForgeShortcutKey.primaryIsMeta
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  if (primary) await tester.sendKeyDownEvent(modifier);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (primary) await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

/// [SingleActivator] has no value equality.
bool _sameActivator(ShortcutActivator a, SingleActivator b) =>
    a is SingleActivator &&
    a.trigger == b.trigger &&
    a.meta == b.meta &&
    a.control == b.control &&
    a.shift == b.shift &&
    a.alt == b.alt;

PlatformMenuItem _menuItem(WidgetTester tester, String label) {
  final bar = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar));
  PlatformMenuItem? found;
  void walk(List<PlatformMenuItem> items) {
    for (final item in items) {
      if (item is PlatformMenu) {
        walk(item.menus);
      } else if (item is PlatformMenuItemGroup) {
        walk(item.members);
      } else if (item.label == label) {
        found ??= item;
      }
    }
  }

  walk(bar.menus);
  return found!;
}

DefaultShellApi _newShell() => DefaultShellApi.withDefaultsAndFileSystem(
  fileSystem: TomMemoryFileSystem(),
  appName: 'Undo key routing test',
  navigatorKey: GlobalKey<NavigatorState>(),
);

/// An integration as a text editor makes one: the standard editing actions
/// registered with the shell.
ShellEditorIntegration _integration(DefaultShellApi shell) {
  final integration = ShellEditorIntegration(
    shellApi: shell,
    editorId: 'kr-editor',
    editorTypeId: 'plaintext',
  )..descriptors = StandardEditingActions.descriptors;
  for (final id in StandardEditingActions.standardActionIds) {
    integration.registerAction(id, () {}, isEnabled: () => true);
  }
  return integration;
}

/// A shell with one application: a side panel holding a text field, and an
/// editor that records the standard editing actions it is asked to run.
class _Harness {
  _Harness({bool editorCanUndo = true})
    : editor = _RecordingEditor(canUndo: editorCanUndo) {
    shell.applications.add(
      ForgeApplication(
        id: 'forge',
        title: 'forge',
        layout: PanelLayout(
          leftPanel: PanelConfig(
            initialSize: 280,
            tabs: [
              PanelTabConfig(
                title: 'Find',
                icon: Icons.search,
                sections: [_SideField()],
              ),
            ],
          ),
          middlePanels: [
            MiddlePanelConfig(tabs: [MiddleTabConfig(editor: editor)]),
          ],
        ),
      ),
    );
  }

  final shell = _newShell();
  final _RecordingEditor editor;
  final passedThrough = <LogicalKeyboardKey>[];

  Widget app() => MaterialApp(
    home: Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) passedThrough.add(event.logicalKey);
        return KeyEventResult.ignored;
      },
      child: ForgeShellScaffold(
        shell: shell,
        layoutController: shell.layout as DefaultLayoutController,
        systemState: shell.systemState as DefaultSystemState,
        statusBarController: shell.statusBar,
        notificationManager: shell.notifications as DefaultNotificationManager,
      ),
    ),
  );

  Future<void> focusEditor(WidgetTester tester) async {
    editor.focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(shell.systemState.activeEditor, editor);
  }
}

class _RecordingEditor extends ForgeEditor {
  _RecordingEditor({required this.canUndo});

  final bool canUndo;
  final ran = <String>[];
  final focusNode = FocusNode(debugLabel: 'recording editor');
  final _dirty = ValueNotifier(false);

  static const _actions = {
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
    StandardEditingActions.deleteLineActionId,
  };

  @override
  Set<String> get supportedActionIds => _actions;

  @override
  bool isActionEnabled(String actionId) =>
      canUndo && _actions.contains(actionId);

  @override
  bool executeAction(String actionId) {
    if (!isActionEnabled(actionId)) return false;
    ran.add(actionId);
    return true;
  }

  @override
  ValueNotifier<String> get title => ValueNotifier('doc.txt');

  @override
  ValueNotifier<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.description;

  @override
  Uri get uri => Uri.parse('file:///doc.txt');

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) =>
      Focus(focusNode: focusNode, child: const Text('the document'));

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// A side-panel view with a text field — a find box.
class _SideField extends ForgeView {
  static const fieldKey = ValueKey('kr.sideField');

  @override
  ValueListenable<String> get title => ValueNotifier('Find');

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.search;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) =>
      const TextField(key: fieldKey);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}
