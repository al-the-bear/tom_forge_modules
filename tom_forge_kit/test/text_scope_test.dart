// Texts outside widgets read under the scope their component was
// constructed in (the workspace guideline i18n.md): ForgeTextScope, a
// module's text scope, its actions' titles, its descriptions' scopes and
// notifications worded by text references.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart' show TomScope;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeConfigurationDescription;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_text_testing/tom_text_testing.dart';

const _run = ForgeText.id('actions.runAction.label');

const _description = ForgeConfigurationDescription(
  id: 'scoped',
  title: ForgeText.id('settings.title'),
  sections: [],
);

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

/// A module with one titled action and a description.
class _Module extends ForgeKitModule implements ForgeModuleExtrasProvider {
  _Module(this.actionId);

  final String actionId;

  @override
  String get displayName => 'Scoped';
  @override
  void activate(ForgeKitApi api) {}
  @override
  void deactivate() {}
  @override
  List<ForgeEditor> get editors => const [];
  @override
  List<ForgeView> get views => const [];
  @override
  List<ForgeAction> get actions => [
    ForgeAction(
      id: actionId,
      title: _run,
      execute: (_) async => null,
      isEnabled: () => true,
      isVisible: () => true,
    ),
  ];
  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
  @override
  List<ForgeModuleExtra> get ownExtras => const [
    ForgeConfigurationDescriptionsExtra([_description]),
  ];
}

class _OtherModule extends _Module {
  _OtherModule(super.actionId);
}

class _Notifications implements ForgeNotificationManager {
  String? shown;
  List<String> offered = const [];
  String? answer;

  Future<String?> _show(String message, List<String> actions) async {
    shown = message;
    offered = actions;
    return answer;
  }

  @override
  Future<String?> showInformation(
    String message, {
    List<String> actions = const [],
  }) => _show(message, actions);

  @override
  Future<String?> showWarning(
    String message, {
    List<String> actions = const [],
  }) => _show(message, actions);

  @override
  Future<String?> showError(
    String message, {
    List<String> actions = const [],
  }) => _show(message, actions);
}

void main() {
  setUp(() {
    installTexts({
      'left': {
        'actions': {
          'runAction': {'label': 'Run on the left'},
        },
        'settings': {'title': 'Left settings'},
        'save': {
          'failedMessage': {'text': 'Saving {file} failed: {reason}'},
          'retryAction': {'label': 'Retry'},
        },
        'reason': {
          'diskMessage': {'text': 'the disk is full'},
        },
      },
      'right': {
        'actions': {
          'runAction': {'label': 'Run on the right'},
        },
      },
      'forge': {
        'old': {'label': 'Translated old'},
      },
    });
  });
  tearDown(clearTexts);

  group('ForgeTextScope', () {
    test('captures the scope it is constructed in', () {
      expect(ForgeTextScope().path, '');
      expect(runInScopePath('a.b', () => ForgeTextScope()).path, 'a.b');
      expect(ForgeTextScope.root.path, '');
      expect(ForgeTextScope(TomScope.defaultScope).pathOf('x.y'), 'x.y');
    });

    test('reads an id under its scope: two scopes, two wordings', () {
      final left = runInScopePath('left', () => ForgeTextScope());
      final right = runInScopePath('right', () => ForgeTextScope());
      expect(left.resolve(_run), 'Run on the left');
      expect(right.resolve(_run), 'Run on the right');
      expect(left.text('actions.runAction.label'), 'Run on the left');
    });

    test('an id nothing resolves shows its full path', () {
      final left = runInScopePath('left', () => ForgeTextScope());
      expect(
        left.text('nothing.hereText.label'),
        'left.nothing.hereText.label',
      );
      expect(ForgeTextScope.root.resolve(_run), 'actions.runAction.label');
    });

    test(
      'a key with a fallback resolves as before: scoped, alone, fallback',
      () {
        final left = runInScopePath('left', () => ForgeTextScope());
        expect(
          left.resolve(const ForgeText('settings.title', 'Settings')),
          'Left settings',
        );
        expect(
          left.resolve(const ForgeText('forge.old.label', 'Old')),
          'Translated old',
        );
        expect(left.resolve(const ForgeText('forge.new.label', 'New')), 'New');
        expect(left.resolve(const ForgeText.literal('notes.txt')), 'notes.txt');
      },
    );

    test(
      'fills parameters, a ForgeText parameter resolved under the scope',
      () {
        final left = runInScopePath('left', () => ForgeTextScope());
        expect(
          left.text(
            'save.failedMessage.text',
            params: {
              'file': 'a.md',
              'reason': const ForgeText.id('reason.diskMessage.text'),
            },
          ),
          'Saving a.md failed: the disk is full',
        );
      },
    );

    test('without installed texts: the fallback, or the path', () {
      clearTexts();
      expect(
        ForgeTextScope.root.resolve(const ForgeText('k', 'Fallback')),
        'Fallback',
      );
      expect(ForgeTextScope.root.resolve(_run), 'actions.runAction.label');
    });
  });

  group('a module', () {
    late DefaultKitApi api;
    setUp(
      () => api = DefaultKitApi(
        editorHost: _Host(),
        fileSystem: TomMemoryFileSystem(),
      ),
    );
    tearDown(() => api.dispose());

    test('carries the text scope it was constructed in; its actions\' '
        'titles are read under it, registered and handed out', () {
      final left = runInScopePath('left', () => _Module('test.left'));
      final right = runInScopePath('right', () => _OtherModule('test.right'));
      expect(left.textScope.path, 'left');
      expect(right.textScope.path, 'right');
      api
        ..registerModule(left)
        ..registerModule(right);
      expect(
        api.actionRegistry.getAction('test.left')!.label,
        'Run on the left',
      );
      expect(
        api.actionRegistry.getAction('test.right')!.label,
        'Run on the right',
      );
      expect(forgeModuleActions(right).single.label, 'Run on the right');
      expect(
        left.actions.single.label,
        'actions.runAction.label',
        reason: 'an unbound title is read by its key alone',
      );
    });

    test(
      'an action that names its resolver keeps it; a literal label stays',
      () {
        final right = runInScopePath('right', () => ForgeTextScope());
        final module = runInScopePath('left', () => _Module('x'));
        final bound = ForgeAction(
          id: 'y',
          title: _run,
          textResolver: right,
          execute: (_) async => null,
          isEnabled: () => true,
          isVisible: () => true,
        );
        expect(
          bound.withTextResolver(module.textScope).label,
          'Run on the right',
        );
        final plain = ForgeAction(
          id: 'z',
          label: 'Plain',
          execute: (_) async => null,
          isEnabled: () => true,
          isVisible: () => true,
        );
        expect(
          identical(plain.withTextResolver(module.textScope), plain),
          isTrue,
        );
        expect(plain.label, 'Plain');
      },
    );

    test('its descriptions are read under its text scope', () {
      api.registerModule(runInScopePath('left', () => _Module('a')));
      final scopes = forgeConfigurationTextScopesOf(api);
      expect(scopes['scoped']!.resolve(_description.title), 'Left settings');
      final values = ForgeConfigurationValues(
        ForgeMemoryStateStore(),
        descriptions: [_description],
        textScopes: scopes,
      );
      addTearDown(values.dispose);
      expect(values.textScopeOf('scoped').path, 'left');
      expect(values.textScopeOf('other'), same(ForgeTextScope.root));
    });
  });

  test('notifications worded by text references', () async {
    final left = runInScopePath('left', () => ForgeTextScope());
    final notifications = _Notifications()..answer = 'Retry';
    const retry = ForgeText.id('save.retryAction.label');
    final chosen = await notifications.showErrorText(
      left,
      const ForgeText.id(
        'save.failedMessage.text',
        params: {'file': 'a.md', 'reason': 'locked'},
      ),
      actions: const [retry],
    );
    expect(notifications.shown, 'Saving a.md failed: locked');
    expect(notifications.offered, ['Retry']);
    expect(chosen, retry);
    notifications.answer = null;
    expect(
      await notifications.showInformationText(
        left,
        retry,
        actions: const [retry],
      ),
      isNull,
    );
  });

  testWidgets('ForgeTextScopeWidget hands the scope down, and into a route', (
    tester,
  ) async {
    final left = runInScopePath('left', () => ForgeTextScope());
    late ForgeTextScope seen;
    late ForgeTextScope inRoute;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ForgeTextScopeWidget(
          textScope: left,
          child: Builder(
            builder: (context) {
              seen = ForgeTextScopeWidget.of(context);
              final builder = ForgeTextScopeWidget.keep(context, (context) {
                inRoute = ForgeTextScopeWidget.of(context);
                return const SizedBox();
              });
              return builder(context);
            },
          ),
        ),
      ),
    );
    expect(seen, same(left));
    expect(inRoute, same(left));
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = ForgeTextScopeWidget.of(context);
          return const SizedBox();
        },
      ),
    );
    expect(seen, same(ForgeTextScope.root));
  });
}
