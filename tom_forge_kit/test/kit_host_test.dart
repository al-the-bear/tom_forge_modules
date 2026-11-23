import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/text_types.dart' show ForgeTextSettings;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'support/throwing_preferences_store.dart';

/// An editor of one document.
class _Editor extends ForgeEditor {
  _Editor(this.uri);

  @override
  final Uri uri;

  @override
  ValueListenable<bool> get isDirty => ValueNotifier(false);

  @override
  void markClean() {}

  @override
  String? getContent() => '';

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
}

/// An editor host that is no layout at all: it tells the kit state what is
/// shown.
class _FakeEditorHost implements ForgeEditorHost {
  _FakeEditorHost(this.state);

  final DefaultKitState state;

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {
    state.addOpenEditor(editor);
    if (focus) state.setActiveEditor(editor);
  }

  @override
  Future<bool> closeEditor(ForgeEditor editor) async {
    state.removeOpenEditor(editor);
    return true;
  }

  @override
  void bringToFront(ForgeEditor editor) => state.setActiveEditor(editor);

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async {
    final editor = _Editor(uri);
    await showEditor(editor);
    return editor;
  }
}

/// A module contributing one action with a default key.
class _KeyModule extends ForgeKitModule {
  static final ForgeAction action = ForgeAction(
    id: 'kit.find',
    label: 'Find',
    execute: (_) async => null,
    isEnabled: () => true,
    isVisible: () => true,
  );

  static const defaultKey = ForgeShortcutKey(
    key: LogicalKeyboardKey.keyF,
    primaryModifier: true,
  );

  @override
  String get displayName => 'Keys';

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
  List<ForgeShortcutBinding> get shortcuts => [
    ForgeShortcutBinding(action: action, key: defaultKey),
  ];

  @override
  List<ForgeContextMenuContribution> get contextMenus => const [];
}

DefaultKitApi _api(ForgeStateStore store, TomFileSystem fileSystem) {
  final state = DefaultKitState();
  return DefaultKitApi(
    editorHost: _FakeEditorHost(state),
    fileSystem: fileSystem,
    stateStore: store,
    state: state,
  );
}

void main() {
  late ThrowingPreferencesStore platform;

  setUp(() => platform = ThrowingPreferencesStore.install());
  tearDown(ThrowingPreferencesStore.uninstall);

  test(
    'a host over a memory store and a memory file system keeps the '
    'preferences and the workspace state across two DefaultKitApi '
    'instances, without shared_preferences and without .forge files',
    () async {
      final store = ForgeMemoryStateStore();
      final editorUri = Uri.file('/docs/notes.md');
      const settings = ForgeTextSettings(
        fontFamily: 'JetBrains Mono',
        fontSize: 15,
        tabSize: 4,
        wordWrap: false,
      );
      const override = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyK,
        primaryModifier: true,
        shift: true,
      );

      // ── First run ──
      final firstFs = TomMemoryFileSystem(seed: const {'/docs/notes.md': '#'});
      final first = _api(store, firstFs);
      await first.restore();
      expect(first.stateStore, same(store));
      expect(first.preferences.stateStore, same(store));
      expect(first.workspaceState.isInitialized, isTrue);

      first.setTextSettings('md', settings);
      first.setFileTypeDefault('txt', 'plain');
      first.preferences.setShortcutOverride(_KeyModule.action.id, override);
      final opened = await first.openFile(editorUri);
      expect(opened, isTrue);
      await first.workspaceState.saveEditorState(editorUri, <String, dynamic>{
        'cursor': 12,
        'scroll': 3.5,
      });
      first.dispose();
      await first.flushed();

      // Nothing reached the workspace's file system: the store holds it all.
      expect(await firstFs.exists(firstFs.uriOf('.forge/')), isFalse);
      expect(
        await store.keys(prefix: 'forge.'),
        containsAll(<String>[
          'forge.editor.textSettings',
          'forge.files.typeDefaults',
          'forge.shortcuts.overrides',
        ]),
      );
      expect(await store.keys(prefix: 'state/editors/'), hasLength(1));

      // ── Second run, over the same store and a fresh file system ──
      final secondFs = TomMemoryFileSystem();
      final second = _api(store, secondFs);
      addTearDown(second.dispose);
      // Before the restore, the defaults.
      expect(second.getTextSettings('md'), const ForgeTextSettings());
      await second.restore();

      expect(second.getTextSettings('md'), settings);
      expect(second.getFileTypeDefaults(), {'.txt': 'plain'});
      expect(second.preferences.shortcutOverrides, {
        _KeyModule.action.id: override,
      });
      // The override applies to the action when its module registers it.
      second.registerModule(_KeyModule());
      expect(second.shortcuts.getBinding(_KeyModule.action.id)?.key, override);
      final editorState = await second.workspaceState.loadEditorState(
        editorUri,
      );
      expect(editorState?['cursor'], 12);
      expect(editorState?['scroll'], 3.5);
      expect(editorState?['_uri'], editorUri.toString());
      expect(await secondFs.exists(secondFs.uriOf('.forge/')), isFalse);

      expect(platform.calls, 0, reason: 'no shared_preferences call');
    },
  );

  test('a setting changed before the restore is not written and the restore '
      'reads the stored one over it', () async {
    final store = ForgeMemoryStateStore(
      initial: {'forge.files.typeDefaults': '{".md":"markdown"}'},
    );
    final api = _api(store, TomMemoryFileSystem());
    addTearDown(api.dispose);
    api.setFileTypeDefault('md', 'plain');
    await api.flushed();
    expect(store.writes, isEmpty);
    await api.restore();
    expect(api.getFileTypeDefaults(), {'.md': 'markdown'});
    expect(platform.calls, 0);
  });

  test('one gesture writes each key once, the last value', () async {
    final store = ForgeMemoryStateStore();
    final api = _api(store, TomMemoryFileSystem());
    addTearDown(api.dispose);
    await api.restore();
    store.writes.clear();

    for (final size in [12.0, 13.0, 14.0]) {
      api.setTextSettings('md', ForgeTextSettings(fontSize: size));
    }
    api.setFileTypeDefault('a', 'x');
    api.setFileTypeDefault('b', 'y');
    await api.flushed();

    expect(
      [for (final w in store.writes) w.key],
      ['forge.editor.textSettings', 'forge.files.typeDefaults'],
    );
    expect(api.getTextSettings('md').fontSize, 14.0);
    expect(platform.calls, 0);
  });
}
