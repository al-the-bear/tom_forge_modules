// The panel shell takes a module written against the kit alone
// (`ForgeKitModule`): its registry registers it, `DefaultShellApi`
// activates it with the shell's API and the shell reads its kit members and
// its extras. Its editor host (`ForgeTabEditorHost`) honours the kit's
// layout-free placement hint: the index of a middle panel.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_shell/tom_forge_shell.dart';

/// An editor of one document.
class _Editor extends ForgeEditor {
  _Editor(this.uri);

  @override
  final Uri uri;

  final ValueNotifier<bool> _dirty = ValueNotifier(false);

  @override
  ValueListenable<bool> get isDirty => _dirty;

  @override
  void markClean() => _dirty.value = false;

  @override
  String? getContent() => '';

  @override
  ValueListenable<String> get title => ValueNotifier(uri.pathSegments.last);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.note;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const SizedBox();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox();

  @override
  FileHandlingResult canHandle(Uri uri) => uri.path.endsWith('.kit')
      ? FileHandlingResult.accept
      : FileHandlingResult.reject;

  @override
  Set<String> get supportedActionIds => const {};

  @override
  bool isActionEnabled(String actionId) => false;

  @override
  bool executeAction(String actionId) => false;
}

/// A module written against the kit alone, with a status item and a
/// settings section as extras.
class _KitModule extends ForgeKitModule implements ForgeModuleExtrasProvider {
  _KitModule(this.editor);

  final _Editor editor;
  ForgeKitApi? api;
  final List<Uri> claimed = [];
  final List<String> chosen = [];

  static final settings = ForgeConfigPanel(
    id: 'kit.settings',
    title: 'Kit settings',
    icon: Icons.settings,
    builder: (_) => const SizedBox(),
  );

  @override
  String get displayName => 'Kit module';

  @override
  void activate(ForgeKitApi api) => this.api = api;

  @override
  void deactivate() => api = null;

  @override
  List<ForgeEditor> get editors => [editor];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => [
    ForgeAction(
      id: 'kit.run',
      label: 'Run kit',
      execute: (_) async => null,
      isEnabled: () => true,
      isVisible: () => true,
    ),
  ];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  bool openUri(Uri uri) {
    if (!uri.path.endsWith('.bundle')) return false;
    claimed.add(uri);
    return true;
  }

  @override
  List<ForgeKitEditorChoice> editorChoicesFor(Uri uri) => [
    if (uri.path.endsWith('.two'))
      for (final id in ['first', 'second'])
        ForgeKitEditorChoice(
          id: id,
          label: id,
          icon: Icons.note,
          open: (uri) => chosen.add('$id ${uri.path}'),
        ),
  ];

  @override
  List<ForgeModuleExtra> get ownExtras => [
    ForgeKitStatusItemsExtra([
      ForgeKitStatusItem(text: 'kit status', priority: 5),
    ]),
    ForgeSettingsSectionExtra(settings),
  ];
}

DefaultShellApi _shell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {
    '/doc.kit': 'kit document',
    '/other.kit': 'other',
    '/third.kit': 'third',
  },
  appName: 'test',
  navigatorKey: GlobalKey<NavigatorState>(),
  stateStore: ForgeMemoryStateStore(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the panel shell registers a ForgeKitModule', () {
    late DefaultShellApi shell;
    late _KitModule module;

    setUp(() {
      shell = _shell();
      module = _KitModule(_Editor(shell.fileSystem.uriOf('/doc.kit')));
      shell.registerModule(module);
    });

    tearDown(() => shell.dispose());

    test('activates it with the shell API and registers it', () {
      expect(module.api, same(shell));
      final registry = shell.modules;
      expect(registry.allKitModules, contains(module));
      expect(
        registry.allModules,
        isNot(contains(module)),
        reason: 'allModules keeps answering the ForgeModules',
      );
      expect(registry.get<_KitModule>(), same(module));
      expect(shell.actionRegistry.getAction('kit.run'), isNotNull);
      expect(
        (registry as DefaultModuleRegistry).moduleStateOf(module),
        ModuleState.active,
      );
    });

    test('reads its extras: status items and a settings section', () {
      final status = shell.statusBar.items.where(
        (item) => item.text.value == 'kit status',
      );
      expect(status, hasLength(1));
      expect(status.single.isActive(shell.systemState), isTrue);
      expect(forgeModuleSettingsSections(module), [_KitModule.settings]);
      expect(forgeModuleExternalTools(module), isEmpty);
    });

    test('opens a document it claims, and its editors take files', () async {
      expect(await shell.openFile(Uri.file('/x.bundle')), isTrue);
      expect(module.claimed, [Uri.file('/x.bundle')]);

      final uri = shell.fileSystem.uriOf('/doc.kit');
      expect(await shell.openFile(uri), isTrue);
      expect(shell.systemState.activeEditor, same(module.editor));
    });

    test(
      'Open With offers its choices in the middle panel asked for',
      () async {
        final layout = shell.layout as DefaultLayoutController;
        layout.splitMiddlePanel();
        layout.setActiveMiddlePanelIndex(0);
        final uri = Uri.file('/y.two');

        await layout.openFileWith(uri);

        final (_, choices) = layout.pendingEditorChoice.value!;
        expect(choices.map((c) => c.id), ['first', 'second']);
        choices.last.open(uri, middlePanelIndex: 1);
        expect(module.chosen, ['second /y.two']);
        expect(layout.activeMiddlePanelIndex, 1);
      },
    );

    test('is deactivated with the shell', () {
      shell.dispose();
      expect(module.api, isNull);
      shell = _shell();
    });
  });

  group('ForgeTabEditorHost honours the placement hint', () {
    late DefaultShellApi shell;
    late DefaultLayoutController layout;

    setUp(() {
      shell = _shell();
      layout = shell.layout as DefaultLayoutController;
      layout.splitMiddlePanel();
      layout.setActiveMiddlePanelIndex(0);
    });

    tearDown(() => shell.dispose());

    int panelOf(ForgeEditor editor) =>
        layout.middlePanels.value.indexWhere((panel) => panel.contains(editor));

    test('showEditor puts the editor in the middle panel it names', () async {
      final named = _Editor(Uri.file('/named.kit'));
      final unnamed = _Editor(Uri.file('/unnamed.kit'));
      final outOfRange = _Editor(Uri.file('/far.kit'));

      await shell.editorHost.showEditor(named, placement: 1);
      layout.setActiveMiddlePanelIndex(0);
      await shell.editorHost.showEditor(unnamed);
      await shell.editorHost.showEditor(outOfRange, placement: 7);

      expect(panelOf(named), 1);
      expect(panelOf(unnamed), 0, reason: 'no hint: the active panel');
      expect(panelOf(outOfRange), 0, reason: 'no such panel: the active one');
    });

    test('openEditorFor opens the chosen editor where the hint says', () async {
      final module = _KitModule(_Editor(shell.fileSystem.uriOf('/doc.kit')));
      shell.registerModule(module);

      final editor = await shell.editorHost.openEditorFor(
        shell.fileSystem.uriOf('/doc.kit'),
        placement: 1,
      );

      expect(editor, same(module.editor));
      expect(panelOf(module.editor), 1);
    });

    test(
      'a navigation location\'s placement brings the editor back there',
      () async {
        final editor = _Editor(Uri.file('/back.kit'));
        // Other editors keep both panels open while this one is closed.
        await shell.editorHost.showEditor(
          _Editor(Uri.file('/left.kit')),
          placement: 0,
        );
        await shell.editorHost.showEditor(
          _Editor(Uri.file('/right.kit')),
          placement: 1,
        );
        await shell.editorHost.showEditor(editor, placement: 1);
        final location = ForgeNavigationLocation(
          uri: editor.uri,
          placement: panelOf(editor),
        );
        await shell.editorHost.closeEditor(editor);
        expect(panelOf(editor), -1);

        layout.setActiveMiddlePanelIndex(0);
        await shell.editorHost.showEditor(
          editor,
          placement: location.placement,
        );

        expect(location.middlePanelIndex, 1);
        expect(panelOf(editor), 1);
      },
    );

    test('middlePanelIndexOf reads only an index of an existing panel', () {
      expect(ForgeTabEditorHost.middlePanelIndexOf(2), 2);
      expect(ForgeTabEditorHost.middlePanelIndexOf('2'), isNull);
      expect(ForgeTabEditorHost.middlePanelIndexOf(-1), isNull);
      expect(
        ForgeTabEditorHost.middlePanelIndexOf(2, middlePanelCount: 2),
        isNull,
      );
    });
  });
}
