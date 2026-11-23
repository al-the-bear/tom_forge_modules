import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/text_types.dart' show StandardEditingActions;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// An editor of one document whose unsaved state a test sets.
class _FakeEditor extends ForgeEditor {
  _FakeEditor(this.uri, {this.content = 'text', Set<String>? actions})
    : _actions = actions ?? const {};

  @override
  final Uri uri;

  String content;
  final Set<String> _actions;
  final List<String> executed = [];
  final ValueNotifier<bool> _dirty = ValueNotifier(false);

  set dirty(bool value) => _dirty.value = value;

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  String? getContent() => content;

  @override
  ValueListenable<String> get title => ValueNotifier(uri.pathSegments.last);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => const IconData(0xe000);

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const SizedBox();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox();

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.accept;

  @override
  Set<String> get supportedActionIds => _actions;

  @override
  bool isActionEnabled(String actionId) => _actions.contains(actionId);

  @override
  bool executeAction(String actionId) {
    executed.add(actionId);
    return true;
  }
}

/// An editor host that records what the kit asks of it and shows a fake
/// editor for every resource.
class _RecordingEditorHost implements ForgeEditorHost {
  _RecordingEditorHost(this.state);

  final DefaultKitState state;
  final List<String> calls = [];
  bool opens = true;

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {
    calls.add(
      'show ${editor.uri.path} focus=$focus'
      '${placement == null ? '' : ' at $placement'}',
    );
    state.addOpenEditor(editor);
    if (focus) state.setActiveEditor(editor);
  }

  @override
  Future<bool> closeEditor(ForgeEditor editor) async {
    calls.add('close ${editor.uri.path}');
    state.removeOpenEditor(editor);
    return true;
  }

  @override
  void bringToFront(ForgeEditor editor) {
    calls.add('front ${editor.uri.path}');
    state.setActiveEditor(editor);
  }

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async {
    calls.add(
      'openFor ${uri.path}${placement == null ? '' : ' at $placement'}',
    );
    if (!opens) return null;
    final editor = _FakeEditor(uri);
    await showEditor(editor, placement: placement);
    return editor;
  }
}

class _Module extends ForgeKitModule {
  _Module({this.claims = const {}, List<ForgeAction>? actions})
    : _actions = actions ?? const [];

  final Set<String> claims;
  final List<ForgeAction> _actions;
  final List<Uri> opened = [];
  ForgeKitApi? api;

  @override
  String get displayName => 'Module';

  @override
  void activate(ForgeKitApi api) => this.api = api;

  @override
  void deactivate() => api = null;

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => _actions;

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeContextMenuContribution> get contextMenus => [
    for (final action in _actions)
      ForgeContextMenuContribution(
        targetKind: 'thing',
        actionId: action.id,
        group: 'module',
      ),
  ];

  @override
  bool openUri(Uri uri) {
    if (!claims.contains(uri.path)) return false;
    opened.add(uri);
    return true;
  }
}

class _ModuleWithExtras extends _Module implements ForgeModuleExtrasProvider {
  @override
  List<ForgeModuleExtra> get ownExtras => const [
    ForgeModuleExtra(kind: 'test.settings', value: 'section'),
  ];
}

ForgeAction _action(String id, {bool enabled = true, List<String>? log}) =>
    ForgeAction(
      id: id,
      label: 'Label $id',
      execute: (_) async {
        log?.add(id);
        return null;
      },
      isEnabled: () => enabled,
      isVisible: () => true,
    );

void main() {
  group('DefaultKitApi.openFile', () {
    late DefaultKitState state;
    late _RecordingEditorHost host;
    late DefaultKitApi api;

    setUp(() {
      state = DefaultKitState();
      host = _RecordingEditorHost(state);
      api = DefaultKitApi(
        editorHost: host,
        fileSystem: TomMemoryFileSystem(seed: const {'a.txt': 'a'}),
        state: state,
      );
    });

    tearDown(() => api.dispose());

    test(
      'asks the modules first: a module that claims the file opens it',
      () async {
        final module = _Module(claims: {'/bundle.pkg'});
        api.registerModule(module);
        expect(module.api, same(api));

        final opened = await api.openFile(Uri.file('/bundle.pkg'));

        expect(opened, isTrue);
        expect(module.opened, [Uri.file('/bundle.pkg')]);
        expect(host.calls, isEmpty);
      },
    );

    test('then the editor host, which chooses and shows the editor', () async {
      api.registerModule(_Module(claims: {'/other'}));

      final opened = await api.openFile(Uri.file('/a.txt'));

      expect(opened, isTrue);
      expect(host.calls, ['openFor /a.txt', 'show /a.txt focus=true']);
      expect(state.activeEditor?.uri, Uri.file('/a.txt'));
      expect(state.openEditors, hasLength(1));
    });

    test('passes the placement hint through to the editor host', () async {
      // The kit never reads the hint: what the host recorded (e.g. a
      // ForgeNavigationLocation's placement) reaches it unchanged.
      final location = ForgeNavigationLocation(
        uri: Uri.file('/a.txt'),
        placement: 'right column',
      );

      final opened = await api.openFile(
        location.uri,
        placement: location.placement,
      );

      expect(opened, isTrue);
      expect(host.calls, [
        'openFor /a.txt at right column',
        'show /a.txt focus=true at right column',
      ]);
    });

    test('a module that claims the file takes it whatever the hint', () async {
      final module = _Module(claims: {'/bundle.pkg'});
      api.registerModule(module);

      final opened = await api.openFile(Uri.file('/bundle.pkg'), placement: 1);

      expect(opened, isTrue);
      expect(module.opened, [Uri.file('/bundle.pkg')]);
      expect(host.calls, isEmpty);
    });

    test('answers false when nothing can open the file', () async {
      host.opens = false;
      expect(await api.openFile(Uri.file('/nothing')), isFalse);
    });

    test('undo and redo go to the active editor', () async {
      final editor = _FakeEditor(
        Uri.file('/a.txt'),
        actions: {StandardEditingActions.undoActionId},
      );
      expect(api.undo(), isFalse, reason: 'no active editor');
      await host.showEditor(editor);

      expect(api.undo(), isTrue);
      expect(api.redo(), isFalse, reason: 'redo is not enabled');
      expect(editor.executed, [StandardEditingActions.undoActionId]);
    });

    test('a module registers its actions and is deactivated on dispose', () {
      final log = <String>[];
      final module = _Module(actions: [_action('m.run', log: log)]);
      api.registerModule(module);

      expect(api.isActionEnabled('m.run'), isTrue);
      expect(api.executeAction('m.run'), isTrue);
      expect(log, ['m.run']);

      api.dispose();
      expect(module.api, isNull);
      api = DefaultKitApi(editorHost: host, fileSystem: TomMemoryFileSystem());
    });
  });

  group('DefaultKitState', () {
    test('follows the unsaved state of the editors it was told about', () {
      final state = DefaultKitState();
      addTearDown(state.dispose);
      final editor = _FakeEditor(Uri.file('/a.txt'));
      final events = <DirtyStateEvent>[];
      final sub = state.onDirtyStateChanged.listen(events.add);
      addTearDown(sub.cancel);

      state.addOpenEditor(editor);
      editor.dirty = true;
      expect(state.dirtyEditors, [editor]);
      expect(state.hasUnsavedChanges, isTrue);

      state.removeOpenEditor(editor);
      expect(state.openEditors, isEmpty);
      expect(state.hasUnsavedChanges, isFalse);
    });
  });

  group('ForgeKitModule extras', () {
    tearDown(() => ForgeModuleExtras.removeResolver(_resolver));

    test('a module without extras has none', () {
      expect(_Module().extras, isEmpty);
    });

    test('a provider answers its own extras', () {
      final ForgeKitModule module = _ModuleWithExtras();
      expect(module.extras.single.kind, 'test.settings');
      expect(module.extras.single.value, 'section');
    });

    test('a registered resolver adds extras to any module', () {
      ForgeModuleExtras.addResolver(_resolver);
      ForgeModuleExtras.addResolver(_resolver);

      final extras = _ModuleWithExtras().extras;
      expect(extras.map((e) => e.kind), ['test.settings', 'test.resolved']);
    });
  });

  group('ForgeAutosaveController', () {
    test('saves unsaved editors after the debounce', () async {
      final state = DefaultKitState();
      final fs = TomMemoryFileSystem(seed: const {'a.txt': 'old'});
      final editor = _FakeEditor(fs.uriOf('a.txt'), content: 'new');
      state.addOpenEditor(editor);
      final controller = ForgeAutosaveController(
        state: state,
        fileSystem: fs,
        debounce: const Duration(milliseconds: 100),
      );
      addTearDown(() {
        controller.dispose();
        state.dispose();
      });

      editor.dirty = true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(editor.isDirty.value, isTrue, reason: 'still within debounce');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(editor.isDirty.value, isFalse);
      expect(await fs.readText(fs.uriOf('a.txt')), 'new');
    });

    test('saveNow saves every unsaved editor at once', () async {
      final state = DefaultKitState();
      final fs = TomMemoryFileSystem();
      final a = _FakeEditor(fs.uriOf('a.txt'), content: 'A');
      final b = _FakeEditor(fs.uriOf('b.txt'), content: 'B');
      state
        ..addOpenEditor(a)
        ..addOpenEditor(b);
      final saveNow = StreamController<void>.broadcast();
      final controller = ForgeAutosaveController(
        state: state,
        fileSystem: fs,
        debounce: const Duration(hours: 1),
        saveNow: saveNow.stream,
      );
      addTearDown(() {
        controller.dispose();
        saveNow.close();
        state.dispose();
      });

      a.dirty = true;
      b.dirty = true;
      saveNow.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(a.isDirty.value, isFalse);
      expect(b.isDirty.value, isFalse);
      expect(await fs.readText(fs.uriOf('b.txt')), 'B');
    });
  });

  group('ForgeContextMenuController', () {
    test('resolves module contributions, then the more contributions, then '
        "the target's own items", () async {
      final log = <String>[];
      final actions = DefaultActionRegistry();
      final module = _Module(actions: [_action('m.open', log: log)]);
      final registry = DefaultKitModuleRegistry<ForgeKitModule>(
        actionRegistry: actions,
      )..register(module);
      actions.registerAction(_action('app.share', log: log));
      actions.registerAction(_action('app.off', enabled: false));
      final controller = ForgeContextMenuController(
        modules: registry,
        actions: actions,
        moreContributions: () => const [
          ForgeContextMenuContribution(
            targetKind: 'thing',
            actionId: 'app.share',
          ),
          ForgeContextMenuContribution(
            targetKind: 'thing',
            actionId: 'app.off',
          ),
          ForgeContextMenuContribution(
            targetKind: 'other',
            actionId: 'app.share',
          ),
        ],
      );
      final target = ForgeContextTarget(
        kind: 'thing',
        items: [
          ForgeContextMenuItem(id: 'own', label: 'Own', run: () async {}),
        ],
      );

      final entries = controller.entriesFor(target);

      expect(entries.map((e) => e.id), [
        'm.open',
        'app.share',
        'app.off',
        'own',
      ]);
      expect(entries.map((e) => e.enabled), [true, true, false, true]);
      await entries.first.run();
      expect(log, ['m.open']);
      expect(
        await controller.show(target, Offset.zero),
        isFalse,
        reason: 'no presenter bound',
      );
    });

    test('without more contributions, the modules alone', () {
      final actions = DefaultActionRegistry();
      final registry = DefaultKitModuleRegistry<ForgeKitModule>(
        actionRegistry: actions,
      )..register(_Module(actions: [_action('m.open')]));
      final controller = ForgeContextMenuController(
        modules: registry,
        actions: actions,
      );

      final entries = controller.entriesFor(
        const ForgeContextTarget(kind: 'thing'),
      );
      expect(entries.map((e) => e.id), ['m.open']);
    });
  });
}

List<ForgeModuleExtra>? _resolver(ForgeKitModule module) => const [
  ForgeModuleExtra(kind: 'test.resolved', value: 1),
];
