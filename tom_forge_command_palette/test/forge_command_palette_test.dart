// The command palette on a bare kit: a DefaultKitApi with no shell, the
// palette contributed by its module (for the all and actions modes, below
// quick open), listing the kit's actions and a module's, and running the one
// picked.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_command_palette/tom_forge_command_palette.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

/// An editor host that is no layout.
class _Host implements ForgeEditorHost {
  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {}

  @override
  Future<bool> closeEditor(ForgeEditor editor) async => true;

  @override
  void bringToFront(ForgeEditor editor) {}

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async =>
      null;
}

/// A module with one action of its own, never put into the action registry.
class _ActionModule extends ForgeKitModule {
  _ActionModule(this.action);

  final ForgeAction action;

  @override
  String get displayName => 'Actions';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => [action];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

/// A second module class (the registry keeps one module per class).
class _OtherActionModule extends _ActionModule {
  _OtherActionModule(super.action);
}

/// A quick open of higher priority, as `tom_forge_quick_open` contributes.
class _QuickOpenModule extends ForgeKitModule
    implements ForgeModuleExtrasProvider {
  @override
  String get displayName => 'Quick Open';

  @override
  void activate(ForgeKitApi api) {}

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
  List<ForgeModuleExtra> get ownExtras => [
    ForgeQuickOpenExtra((key, request) => const Text('quick'), priority: 10),
  ];
}

ForgeAction _action(String id, String label, List<String> ran) => ForgeAction(
  id: id,
  label: label,
  execute: (_) async {
    ran.add(id);
    return null;
  },
  isEnabled: () => true,
  isVisible: () => true,
  defaultShortcut: const ForgeShortcutKey(
    key: LogicalKeyboardKey.keyJ,
    primaryModifier: true,
  ),
);

void main() {
  late DefaultKitApi api;

  setUp(() {
    api = DefaultKitApi(editorHost: _Host(), fileSystem: TomMemoryFileSystem());
  });

  tearDown(() => api.dispose());

  test('the module contributes the palette for the all and actions modes, '
      'below quick open', () {
    api.registerModule(forgeCommandPaletteModule());
    expect(
      forgeQuickOpenBuilderFor(api.modules, ForgeQuickOpenMode.all),
      isNotNull,
    );
    expect(
      forgeQuickOpenBuilderFor(api.modules, ForgeQuickOpenMode.actions),
      isNotNull,
    );
    expect(
      forgeQuickOpenBuilderFor(api.modules, ForgeQuickOpenMode.chord),
      isNull,
    );

    api.registerModule(_QuickOpenModule());
    final builder = forgeQuickOpenBuilderFor(
      api.modules,
      ForgeQuickOpenMode.actions,
    )!;
    final shown = builder(
      null,
      ForgeQuickOpenRequest(
        api: api,
        mode: ForgeQuickOpenMode.actions,
        onDismiss: () {},
        searchController: TextEditingController(),
        searchFocusNode: FocusNode(),
      ),
    );
    expect(shown, isA<Text>());
  });

  testWidgets('lists the actions, a module\'s too, and runs the one picked', (
    tester,
  ) async {
    final ran = <String>[];
    var dismissed = 0;
    api.actionRegistry.registerAction(
      _action('test.registered', 'Registered Thing', ran),
    );
    api.registerModule(
      _ActionModule(_action('test.module', 'Module Thing', ran)),
    );
    api.registerModule(forgeCommandPaletteModule());
    final builder = forgeQuickOpenBuilderFor(
      api.modules,
      ForgeQuickOpenMode.all,
    )!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: builder(
            null,
            ForgeQuickOpenRequest(
              api: api,
              mode: ForgeQuickOpenMode.all,
              onDismiss: () => dismissed++,
              searchController: TextEditingController(),
              searchFocusNode: FocusNode(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ForgeCommandPalette), findsOneWidget);
    expect(find.text('Registered Thing'), findsOneWidget);
    expect(find.text('Module Thing'), findsOneWidget);
    expect(find.text('Close Command Palette'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Module');
    await tester.pumpAndSettle();
    expect(find.text('Registered Thing'), findsNothing);

    await tester.tap(find.text('Module Thing'));
    await tester.pumpAndSettle();
    expect(ran, ['test.module']);
    expect(dismissed, 1);
  });

  testWidgets('a module\'s action title is read under the scope the module '
      'was constructed in: two scopes, two wordings', (tester) async {
    installTexts({
      'left': {
        'actions': {
          'runAction': {'label': 'Run on the left'},
        },
      },
      'right': {
        'actions': {
          'runAction': {'label': 'Run on the right'},
        },
      },
    });
    addTearDown(clearTexts);
    ForgeAction titled(String id) => ForgeAction(
      id: id,
      title: const ForgeText.id('actions.runAction.label'),
      execute: (_) async => null,
      isEnabled: () => true,
      isVisible: () => true,
    );
    api.registerModule(
      runInScopePath('left', () => _ActionModule(titled('test.left'))),
    );
    api.registerModule(
      runInScopePath('right', () => _OtherActionModule(titled('test.right'))),
    );
    api.registerModule(forgeCommandPaletteModule());
    final builder = forgeQuickOpenBuilderFor(
      api.modules,
      ForgeQuickOpenMode.actions,
    )!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: builder(
            null,
            ForgeQuickOpenRequest(
              api: api,
              mode: ForgeQuickOpenMode.actions,
              onDismiss: () {},
              searchController: TextEditingController(),
              searchFocusNode: FocusNode(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Run on the left'), findsOneWidget);
    expect(find.text('Run on the right'), findsOneWidget);
    expect(api.actionRegistry.getAction('test.left')!.label, 'Run on the left');
  });
}
