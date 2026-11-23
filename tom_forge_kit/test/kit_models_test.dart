/// The models an element draws (action state, action bar, menu, command
/// list) and the routing of the standard editing actions and their keys.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/text_types.dart' show StandardEditingActions;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

class _NoHost implements ForgeEditorHost {
  @override
  Future<void> showEditor(ForgeEditor editor, {bool focus = true}) async {}

  @override
  Future<bool> closeEditor(ForgeEditor editor) async => true;

  @override
  void bringToFront(ForgeEditor editor) {}

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri) async => null;
}

ForgeAction _action(
  String id, {
  String? label,
  ForgeMenuLocation menu = ForgeMenuLocation.commandPalette,
  String? group,
  int priority = 0,
  bool enabled = true,
  bool visible = true,
}) => ForgeAction(
  id: id,
  label: label ?? id,
  menu: menu,
  group: group,
  priority: priority,
  execute: (_) async => null,
  isEnabled: () => enabled,
  isVisible: () => visible,
);

void main() {
  late DefaultKitApi api;

  setUp(() {
    api = DefaultKitApi(
      editorHost: _NoHost(),
      fileSystem: TomMemoryFileSystem(),
      stateStore: ForgeMemoryStateStore(),
    );
  });

  test('KM-1: ForgeActionState reads label, key and state from the kit', () {
    final action = _action('m.run', label: 'Run', enabled: false);
    api.actionRegistry.registerAction(action);
    api.shortcuts.rebind(
      action,
      const ForgeShortcutKey(
        key: LogicalKeyboardKey.keyR,
        primaryModifier: true,
      ),
    );
    final state = ForgeActionState.of(api, 'm.run')!;
    expect(state.label, 'Run');
    expect(state.enabled, isFalse);
    expect(state.visible, isTrue);
    expect(state.shortcut, isNotNull);
    expect(ForgeActionState.of(api, 'm.unknown'), isNull);
  });

  test('KM-2: an action bar model resolves its sections, leaving out '
      'unknown and invisible actions', () {
    api.actionRegistry
      ..registerAction(_action('b.one'))
      ..registerAction(_action('b.hidden', visible: false));
    final resolved = const ForgeActionBarModel(
      sections: [
        ForgeActionBarSection(id: 's1', actionIds: ['b.one', 'b.unknown']),
        ForgeActionBarSection(id: 's2', actionIds: ['b.hidden']),
      ],
    ).resolve(api);
    expect([for (final (s, _) in resolved) s.id], ['s1', 's2']);
    expect([for (final a in resolved[0].$2) a.id], ['b.one']);
    expect(resolved[1].$2, isEmpty);
  });

  test('KM-3: a menu model groups the actions of its location by group and '
      'priority, with separators', () {
    api.actionRegistry
      ..registerAction(_action('a', menu: ForgeMenuLocation.edit))
      ..registerAction(
        _action('b', menu: ForgeMenuLocation.edit, group: 'g', priority: 2),
      )
      ..registerAction(
        _action('c', menu: ForgeMenuLocation.edit, group: 'g', priority: 1),
      )
      ..registerAction(_action('d', menu: ForgeMenuLocation.file));
    final model = ForgeMenuModel.of(api, ForgeMenuLocation.edit);
    expect(model.title, 'Edit');
    expect(
      [
        for (final entry in model.entries)
          switch (entry) {
            ForgeMenuActionEntry(:final action) => action.id,
            ForgeMenuSeparatorEntry() => '-',
          },
      ],
      ['a', '-', 'c', 'b'],
    );
    expect(ForgeMenuModel.of(api, ForgeMenuLocation.help).isEmpty, isTrue);
  });

  test('KM-4: the command list holds the visible actions by label, '
      'narrowed by a query', () {
    api.actionRegistry
      ..registerAction(_action('x.zeta', label: 'Zeta'))
      ..registerAction(_action('x.alpha', label: 'Alpha'))
      ..registerAction(_action('x.secret', visible: false));
    final all = ForgeCommandListModel.of(api);
    final ids = [for (final c in all.commands) c.id];
    expect(ids.indexOf('x.alpha'), lessThan(ids.indexOf('x.zeta')));
    expect(ids, isNot(contains('x.secret')));
    expect(
      [
        for (final c in ForgeCommandListModel.of(api, query: 'ZET').commands)
          c.id,
      ],
      ['x.zeta'],
    );
  });

  test('KM-5: the standard editing actions are installed once with their '
      'keys, and a key names its action', () {
    installForgeStandardEditingActions(api);
    installForgeStandardEditingActions(api);
    final undo = api.actionRegistry.getAction(
      StandardEditingActions.undoActionId,
    );
    expect(undo, isNotNull);
    final key = api.shortcuts.getBinding(StandardEditingActions.undoActionId)!;
    expect(
      forgeActionIdForKey(api.shortcuts, key.key),
      StandardEditingActions.undoActionId,
    );
    expect(
      forgeActionIdForKey(
        api.shortcuts,
        const ForgeShortcutKey(key: LogicalKeyboardKey.f13),
      ),
      isNull,
    );
    // No active editor: the kit refuses the editing actions.
    expect(api.undo(), isFalse);
    expect(api.state, isA<ForgeEditorStateSink>());
  });
}
