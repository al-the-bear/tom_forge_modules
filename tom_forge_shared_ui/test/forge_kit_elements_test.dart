/// Every element of the package over the kit's models, on a bare
/// `DefaultKitApi` (a memory state store and file system, no shell): the
/// action bar, the status bar, the context menu, the quick pick, the input
/// box, the notifications, the focus indicator, the menus and the command
/// list.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuContribution, ForgeContextTarget;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

import 'support/bare_kit.dart';

void main() {
  group('action bar (ForgeActionBarModel)', () {
    testWidgets('FKE-1: draws the model\'s actions from the registry, '
        'follows their state and runs them through the kit', (tester) async {
      final api = bareKit();
      final runs = <String>[];
      var saveEnabled = false;
      api.actionRegistry
        ..registerAction(
          recordingAction('a.open', runs, label: 'Open', icon: Icons.folder),
        )
        ..registerAction(
          recordingAction(
            'a.save',
            runs,
            label: 'Save',
            icon: Icons.save,
            isEnabled: () => saveEnabled,
          ),
        )
        ..registerAction(
          recordingAction('a.hidden', runs, isVisible: () => false),
        );
      await tester.pumpWidget(
        themed(
          ForgeKitActionBar(
            api: api,
            model: const ForgeActionBarModel(
              sections: [
                ForgeActionBarSection(id: 'file', actionIds: ['a.open']),
                ForgeActionBarSection(
                  id: 'more',
                  actionIds: ['a.save', 'a.hidden', 'a.unknown'],
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.byIcon(Icons.save), findsOneWidget);
      expect(find.byTooltip('a.hidden'), findsNothing);

      InkWell button(IconData icon) => tester.widget<InkWell>(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(InkWell)),
      );
      expect(button(Icons.save).onTap, isNull);

      await tester.tap(find.byIcon(Icons.folder));
      expect(runs, ['a.open']);

      // A state change of the kit rebuilds the bar.
      saveEnabled = true;
      api.state.setFocusedComponent(PlainComponent('p'));
      await tester.pump();
      expect(button(Icons.save).onTap, isNotNull);
      await tester.tap(find.byIcon(Icons.save));
      expect(runs, ['a.open', 'a.save']);
    });
  });

  group('status bar (ForgeKitStatusItem)', () {
    testWidgets('FKE-2: shows the items active in the kit state and '
        'follows it', (tester) async {
      final api = bareKit();
      final focused = PlainComponent('focused');
      var tapped = 0;
      await tester.pumpWidget(
        themed(
          ForgeKitStatusBar.forApi(
            api: api,
            items: [
              ForgeKitStatusItem(text: 'Always', onTap: () => tapped++),
              ForgeKitStatusItem(
                text: 'Right',
                alignment: StatusBarAlignment.right,
              ),
              ForgeKitStatusItem(
                text: 'When focused',
                isActive: (state) => identical(state.focusedComponent, focused),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Always'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
      expect(find.text('When focused'), findsNothing);

      api.state.setFocusedComponent(focused);
      await tester.pump();
      expect(find.text('When focused'), findsOneWidget);

      await tester.tap(find.text('Always'));
      expect(tapped, 1);
    });
  });

  group('context menu (ForgeContextMenuController)', () {
    testWidgets('FKE-3: the presenter draws the entries the controller '
        'resolves and runs the chosen one', (tester) async {
      final api = bareKit();
      final runs = <String>[];
      api.actionRegistry
        ..registerAction(recordingAction('c.rename', runs, label: 'Rename'))
        ..registerAction(recordingAction('c.delete', runs, label: 'Delete'));
      api.registerModule(
        ContributingModule(const [
          ForgeContextMenuContribution(
            targetKind: 'file',
            actionId: 'c.rename',
          ),
          ForgeContextMenuContribution(
            targetKind: 'file',
            actionId: 'c.delete',
            group: 'danger',
          ),
          ForgeContextMenuContribution(targetKind: 'tab', actionId: 'c.delete'),
        ]),
      );
      await tester.pumpWidget(
        themed(
          ForgeContextMenuPresenter(
            controller: api.contextMenus,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(api.contextMenus.presenter, isNotNull);

      final shown = api.contextMenus.show(
        const ForgeContextTarget(kind: 'file'),
        const Offset(40, 40),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await shown, isTrue);
      expect(runs, ['c.delete']);

      // Out of the tree, it unbinds itself.
      await tester.pumpWidget(themed(const SizedBox()));
      expect(api.contextMenus.presenter, isNull);
    });
  });

  group('dialogs (ForgeDialogManager)', () {
    testWidgets('FKE-4: the kit\'s quick pick is drawn and answers the '
        'chosen item', (tester) async {
      final api = bareKit();
      await tester.pumpWidget(
        themed(
          ForgeDialogLayer(
            dialogs: api.dialogs,
            child: const SizedBox.expand(),
          ),
        ),
      );
      final answer = api.dialogs.showQuickPick<int>(const [
        ForgeQuickPickItem(label: 'One', value: 1),
        ForgeQuickPickItem(label: 'Two', value: 2),
      ], placeholder: 'Pick a number');
      await tester.pump();
      expect(find.byType(ForgeQuickPickOverlay<int>), findsOneWidget);
      expect(find.text('Pick a number'), findsOneWidget);
      await tester.tap(find.text('Two'));
      await tester.pump();
      expect(await answer, 2);
      expect(find.byType(ForgeQuickPickOverlay<int>), findsNothing);
    });

    testWidgets('FKE-5: the kit\'s input box is drawn, validates and '
        'answers the text; Escape answers null', (tester) async {
      final api = bareKit();
      await tester.pumpWidget(
        themed(
          ForgeDialogLayer(
            dialogs: api.dialogs,
            child: const SizedBox.expand(),
          ),
        ),
      );
      final answer = api.dialogs.showInputBox(
        prompt: 'New name',
        value: 'draft',
        validateInput: (v) => v.isEmpty ? 'Required' : null,
      );
      await tester.pump();
      expect(find.text('New name'), findsOneWidget);
      final field = find.byKey(const Key('forge-input-box-field'));
      await tester.enterText(field, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      await tester.enterText(field, 'final');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(await answer, 'final');
      expect(find.byType(ForgeInputBoxOverlay), findsNothing);

      final dismissed = api.dialogs.showInputBox(prompt: 'Again');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(await dismissed, isNull);
    });
  });

  group('notifications (the kit\'s notification manager)', () {
    testWidgets('FKE-6: toasts and the history of api.notifications', (
      tester,
    ) async {
      final api = bareKit();
      await tester.pumpWidget(
        themed(
          ForgeNotificationLayer.forApi(
            api: api,
            child: const SizedBox.expand(),
          ),
        ),
      );
      final answer = api.notifications.showWarning(
        'Disk almost full',
        actions: ['Clean up'],
      );
      await tester.pump();
      expect(find.text('Disk almost full'), findsOneWidget);
      await tester.tap(find.text('Clean up'));
      await tester.pump();
      expect(await answer, 'Clean up');

      forgeNotificationManagerOf(api).popupVisible.value = true;
      await tester.pump();
      expect(find.byType(ForgeNotificationPopup), findsOneWidget);
      expect(find.text('Disk almost full'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ForgeNotificationPopup),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();
      expect(find.byType(ForgeNotificationPopup), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('focus indicator (the kit\'s focused component)', () {
    testWidgets('FKE-7: the ring shows while the component has the kit\'s '
        'focus', (tester) async {
      final api = bareKit();
      final mine = PlainComponent('mine');
      final other = PlainComponent('other');
      await tester.pumpWidget(
        themed(
          ForgeFocusIndicator.kit(
            state: api.state,
            component: mine,
            child: const Text('content'),
          ),
        ),
      );
      bool ringShown() {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(ForgeFocusIndicator),
            matching: find.byType(DecoratedBox),
          ),
        );
        return (box.decoration as BoxDecoration).border != null;
      }

      expect(ringShown(), isFalse);
      api.state.setFocusedComponent(mine);
      await tester.pump();
      await tester.pump();
      expect(ringShown(), isTrue);
      api.state.setFocusedComponent(other);
      // The state reports on a stream: the ring follows a frame later.
      await tester.pump();
      await tester.pump();
      expect(ringShown(), isFalse);
    });
  });

  group('menus (ForgeMenuModel)', () {
    testWidgets('FKE-8: a menu button shows the actions of its location by '
        'group and runs them through the kit', (tester) async {
      final api = bareKit();
      final runs = <String>[];
      api.actionRegistry
        ..registerAction(
          recordingAction(
            'f.close',
            runs,
            label: 'Close',
            menu: ForgeMenuLocation.file,
            group: 'close',
          ),
        )
        ..registerAction(
          recordingAction(
            'f.open',
            runs,
            label: 'Open',
            menu: ForgeMenuLocation.file,
            group: 'open',
          ),
        )
        ..registerAction(
          recordingAction(
            'f.new',
            runs,
            label: 'New',
            menu: ForgeMenuLocation.file,
            group: 'open',
            priority: -1,
          ),
        )
        ..registerAction(
          recordingAction(
            'f.locked',
            runs,
            label: 'Locked',
            menu: ForgeMenuLocation.file,
            group: 'close',
            isEnabled: () => false,
          ),
        )
        ..registerAction(
          recordingAction(
            'e.copy',
            runs,
            label: 'Copy',
            menu: ForgeMenuLocation.edit,
          ),
        );

      final model = ForgeMenuModel.of(api, ForgeMenuLocation.file);
      expect(model.title, 'File');
      expect(
        [
          for (final entry in model.entries)
            switch (entry) {
              ForgeMenuActionEntry(:final action) => action.id,
              ForgeMenuSeparatorEntry() => '-',
            },
        ],
        ['f.close', 'f.locked', '-', 'f.new', 'f.open'],
      );

      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.topLeft,
            child: ForgeMenuButton(api: api, location: ForgeMenuLocation.file),
          ),
        ),
      );
      await tester.tap(find.text('File'));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsNothing);
      expect(
        tester
            .widget<MenuItemButton>(find.byKey(forgeMenuEntryKey('f.locked')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(forgeMenuEntryKey('f.open')));
      await tester.pumpAndSettle();
      expect(runs, ['f.open']);

      // A location without actions shows a disabled button.
      await tester.pumpWidget(
        themed(ForgeMenuButton(api: api, location: ForgeMenuLocation.help)),
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    });
  });

  group('command list (ForgeCommandListModel)', () {
    testWidgets('FKE-9: lists the visible actions, filters them and runs the '
        'chosen one through the kit', (tester) async {
      final api = bareKit();
      final runs = <String>[];
      final ran = <String>[];
      api.actionRegistry
        ..registerAction(recordingAction('cmd.format', runs, label: 'Format'))
        ..registerAction(recordingAction('cmd.build', runs, label: 'Build'))
        ..registerAction(
          recordingAction('cmd.secret', runs, isVisible: () => false),
        );
      await tester.pumpWidget(
        themed(ForgeCommandList(api: api, onRun: ran.add)),
      );
      expect(find.byKey(forgeCommandListEntryKey('cmd.build')), findsOneWidget);
      expect(
        find.byKey(forgeCommandListEntryKey('cmd.format')),
        findsOneWidget,
      );
      expect(find.byKey(forgeCommandListEntryKey('cmd.secret')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('forge.commandList.filter')),
        'form',
      );
      await tester.pump();
      expect(find.byKey(forgeCommandListEntryKey('cmd.build')), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(runs, ['cmd.format']);
      expect(ran, ['cmd.format']);

      await tester.enterText(
        find.byKey(const ValueKey('forge.commandList.filter')),
        '',
      );
      await tester.pump();
      await tester.tap(find.byKey(forgeCommandListEntryKey('cmd.build')));
      expect(runs, ['cmd.format', 'cmd.build']);
    });
  });
}
