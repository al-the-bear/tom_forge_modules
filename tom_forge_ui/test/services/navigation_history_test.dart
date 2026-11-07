/// The shell's navigation history (`ForgeNavigationHistory`), as VS Code's
/// Go Back / Go Forward: every move between documents, or jump within one,
/// records the place left; Back returns there, reopening a closed file;
/// Forward undoes a Back (`tom_forge/_copilot_guidelines/integrated_ux_patterns.md`
/// P11).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeTextPosition;
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// A test editor whose reveal moves the caret, as the shell's text editors
/// do.
class _CaretEditor extends ForgeTestTextEditor {
  _CaretEditor(super.module, String path)
    : super(
        document: ForgeTestDocument(
          uri: Uri.file(path),
          content: List.generate(40, (i) => 'line $i').join('\n'),
        ),
      );

  @override
  void revealPosition(ForgeTextPosition position) {
    super.revealPosition(position);
    setCursorPosition(position);
  }

  ComponentHistoryManager? ownHistory;

  @override
  ComponentHistoryManager? get historyManager => ownHistory;
}

class _OwnHistory implements ComponentHistoryManager {
  final back = ValueNotifier(false);
  final forward = ValueNotifier(false);
  int backs = 0;
  int forwards = 0;

  @override
  ValueListenable<bool> get canGoBack => back;

  @override
  ValueListenable<bool> get canGoForward => forward;

  @override
  void goBack() => backs++;

  @override
  void goForward() => forwards++;

  @override
  String get currentLabel => 'own';
}

class _Fixture {
  _Fixture() {
    shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {'/w/c.txt': 'gamma\n'},
      appName: 'test',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final registry = shell.modules as DefaultModuleRegistry;
    registry.register(TomForgeShellModule()..activate(shell));
    module = ForgeTestModule();
    registry.register(module);
    a = _CaretEditor(module, '/w/a.test');
    b = _CaretEditor(module, '/w/b.test');
  }

  late final DefaultShellApi shell;
  late final ForgeTestModule module;
  late final _CaretEditor a;
  late final _CaretEditor b;

  DefaultLayoutController get layout => shell.layout as DefaultLayoutController;
  ForgeNavigationHistory get history => shell.navigationHistory;
  Uri? get active => shell.systemState.activeEditor?.uri;

  void open(ForgeEditor editor, {int? panel}) =>
      layout.openEditor(editor, editor.uri, middlePanelIndex: panel);

  ({bool back, bool forward}) get enabled =>
      (back: history.canGoBack.value, forward: history.canGoForward.value);
}

void main() {
  test('NH-1: a move to another editor records the place left; Back returns '
      'there and Forward undoes it; each is enabled exactly when there is '
      'somewhere to go', () {
    final f = _Fixture();
    expect(f.enabled, (back: false, forward: false));

    f.open(f.a);
    expect(f.enabled, (back: false, forward: false), reason: 'nothing left');
    f.a.setCursorPosition(const ForgeTextPosition(line: 7, column: 3));
    f.open(f.b);
    expect(f.history.backLocations.single.uri, f.a.uri);
    expect(f.history.backLocations.single.line, 7);
    expect(f.enabled, (back: true, forward: false));

    expect(f.history.goBack(), isTrue);
    expect(f.active, f.a.uri);
    expect(
      f.a.cursorPosition.value,
      const ForgeTextPosition(line: 7, column: 3),
    );
    expect(f.enabled, (back: false, forward: true));
    expect(f.history.goBack(), isFalse, reason: 'nowhere further back');

    expect(f.history.goForward(), isTrue);
    expect(f.active, f.b.uri);
    expect(f.enabled, (back: true, forward: false));
    expect(f.history.goForward(), isFalse);
  });

  test('NH-2: opening the active file at another line is a jump: Back '
      'returns to the line it left', () {
    final f = _Fixture();
    f.open(f.a);
    f.a.setCursorPosition(const ForgeTextPosition(line: 2, column: 0));

    f.layout.openFile(f.a.uri, line: 30, column: 4);
    expect(f.a.cursorPosition.value.line, 30);
    expect(f.history.backLocations.single.line, 2);

    f.history.goBack();
    expect(f.a.cursorPosition.value.line, 2);
    f.history.goForward();
    expect(
      f.a.cursorPosition.value,
      const ForgeTextPosition(line: 30, column: 4),
    );
  });

  test('NH-3: a new move after Back drops what Forward had', () {
    final f = _Fixture();
    f.open(f.a);
    f.open(f.b);
    f.history.goBack();
    expect(f.enabled.forward, isTrue);

    f.a.setCursorPosition(const ForgeTextPosition(line: 1, column: 0));
    f.layout.openFile(f.a.uri, line: 20);
    expect(f.enabled, (back: true, forward: false));
  });

  test('NH-4: Back reopens a closed file, and its arrival is no move of '
      'the user\'s', () async {
    final f = _Fixture();
    final c = Uri.file('/w/c.txt');
    f.layout.openFile(c);
    await pumpEventQueue();
    expect(f.active, c);
    f.open(f.a);
    final closed = f.shell.systemState.openEditors.firstWhere(
      (e) => e.uri == c,
    );
    f.layout.closeEditor(closed);
    expect(f.shell.systemState.openEditors.any((e) => e.uri == c), isFalse);

    expect(f.history.goBack(), isTrue);
    await pumpEventQueue();
    expect(f.active, c, reason: 'the closed file is open again');
    expect(f.history.forwardLocations.single.uri, f.a.uri);
    expect(f.history.backLocations, isEmpty);

    f.history.goForward();
    expect(f.active, f.a.uri);
  });

  test('NH-5: Back and Forward cross applications and their middle panels', () {
    final f = _Fixture();
    final one = ForgeApplication(
      id: 'one',
      title: 'One',
      layout: const PanelLayout(
        middlePanels: [MiddlePanelConfig(), MiddlePanelConfig()],
      ),
    );
    final two = ForgeApplication(
      id: 'two',
      title: 'Two',
      layout: const PanelLayout(middlePanels: [MiddlePanelConfig()]),
    );
    f.shell.applications.add(one, activate: true);
    f.shell.applications.add(two);
    f.open(f.a, panel: 1);
    f.a.setCursorPosition(const ForgeTextPosition(line: 5, column: 0));

    f.shell.applications.activate('two');
    f.open(f.b);
    expect(f.history.backLocations.last.applicationId, 'one');
    expect(f.history.backLocations.last.middlePanelIndex, 1);

    f.history.goBack();
    expect(f.shell.applications.active?.id, 'one');
    expect(f.active, f.a.uri);
    expect(
      f.layout.middlePanels.value[1],
      contains(f.a),
      reason: 'in the middle panel it was left in',
    );
    expect(f.a.cursorPosition.value.line, 5);

    f.history.goForward();
    expect(f.shell.applications.active?.id, 'two');
    expect(f.active, f.b.uri);
  });

  test('NH-6: the editors an application declares are its layout, not '
      'places the user moved through', () {
    final f = _Fixture();
    f.shell.applications.add(
      ForgeApplication(
        id: 'declared',
        title: 'Declared',
        layout: PanelLayout(
          middlePanels: [
            MiddlePanelConfig(
              tabs: [
                MiddleTabConfig(editor: f.a),
                MiddleTabConfig(editor: f.b),
              ],
            ),
          ],
        ),
      ),
      activate: true,
    );
    expect(f.shell.systemState.openEditors, containsAll([f.a, f.b]));
    expect(f.history.backLocations, isEmpty);
    expect(f.enabled, (back: false, forward: false));
  });

  test('NH-7: an editor\'s own history is the editor\'s part of the chain: '
      'while it can go, Back and Forward go through it', () {
    final f = _Fixture();
    final own = _OwnHistory();
    f.b.ownHistory = own;
    f.open(f.a);
    f.open(f.b);

    own.back.value = true;
    expect(f.history.goBack(), isTrue);
    expect(own.backs, 1);
    expect(f.active, f.b.uri, reason: 'the editor went back within itself');

    own.back.value = false;
    expect(f.enabled.forward, isFalse);
    own.forward.value = true;
    expect(f.enabled.forward, isTrue, reason: 'the editor can go forward');
    own.forward.value = false;

    f.history.goBack();
    expect(f.active, f.a.uri, reason: 'its history done, the shell\'s goes');
  });

  test('NH-8: Go Back and Go Forward are shell actions on ⌃- / ⌃⇧- '
      '(Ctrl+- / Ctrl+Shift+- on Windows and Linux), enabled from the '
      'history, sharing their keys with no other binding', () {
    final f = _Fixture();
    final shortcuts = f.shell.shortcuts.allBindings.where((b) => !b.isChord);
    String? boundTo(ForgeShortcutKey key) => shortcuts
        .where((b) => b.key == key)
        .map((b) => b.action.id)
        .singleOrNull;
    const back = ForgeShortcutKey(key: LogicalKeyboardKey.minus, control: true);
    const forward = ForgeShortcutKey(
      key: LogicalKeyboardKey.minus,
      control: true,
      shift: true,
    );
    expect(boundTo(back), TomForgeShellModule.navigateBackActionId);
    expect(boundTo(forward), TomForgeShellModule.navigateForwardActionId);

    expect(
      f.shell.executeAction(TomForgeShellModule.navigateBackActionId),
      isFalse,
      reason: 'disabled with nowhere to go',
    );
    f.open(f.a);
    f.open(f.b);
    expect(
      f.shell.isActionEnabled(TomForgeShellModule.navigateBackActionId),
      isTrue,
    );
    expect(
      f.shell.isActionEnabled(TomForgeShellModule.navigateForwardActionId),
      isFalse,
    );
    expect(
      f.shell.executeAction(TomForgeShellModule.navigateBackActionId),
      isTrue,
    );
    expect(f.active, f.a.uri);
    expect(
      f.shell.executeAction(TomForgeShellModule.navigateForwardActionId),
      isTrue,
    );
    expect(f.active, f.b.uri);
  });

  test('NH-9: a Control key is the primary modifier on Windows and Linux, '
      'and a key of its own on macOS', () {
    const control = ForgeShortcutKey(
      key: LogicalKeyboardKey.minus,
      control: true,
    );
    const primary = ForgeShortcutKey(
      key: LogicalKeyboardKey.minus,
      primaryModifier: true,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      expect(control, primary);
      expect(control.toActivator().control, isTrue);
      expect(control.toDisplayString(), 'Ctrl+-');
      expect(
        ForgeShortcutKey.fromPressed(LogicalKeyboardKey.minus, {
          LogicalKeyboardKey.controlLeft,
        }),
        control,
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(control, isNot(primary));
      final activator = control.toActivator();
      expect((activator.control, activator.meta), (true, false));
      expect(control.toDisplayString(), '⌃-');
      expect(
        ForgeShortcutKey.fromPressed(LogicalKeyboardKey.minus, {
          LogicalKeyboardKey.controlLeft,
        }),
        control,
      );
      expect(
        ForgeShortcutKey.fromPressed(LogicalKeyboardKey.minus, {
          LogicalKeyboardKey.metaLeft,
        }),
        primary,
      );
      expect(
        ForgeShortcutKey.fromPressed(LogicalKeyboardKey.metaLeft, const {}),
        isNull,
        reason: 'a modifier alone is no key',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
