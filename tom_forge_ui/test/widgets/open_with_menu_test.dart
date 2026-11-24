/// forgerestruct13 — Open With ▸ in the panel shell's explorer and tab menus.
///
/// A Markdown file has two editors (the Markdown editor type and the shell's
/// plain text), a text file one (plain text). The explorer's row menu and the
/// editor tab's menu show **Open With ▸** for the Markdown file only: a click
/// on an editor opens the file in it once and leaves the default; the inner
/// **Set default for .md ▸** moves the checkmark, which is stored, read by a
/// new shell over the same state, and listed in the configuration's file-type
/// defaults, where it is reset. The configuration's File Types choices
/// offer every editor the editor picker knows, a module's included
/// (forgerestruct13a).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'support/shell_test_utils.dart';

const _workspace = '/workspace';
const _notesMd = '$_workspace/notes.md';
const _notesTxt = '$_workspace/notes.txt';

void main() {
  final openWith = find.byKey(forgeContextMenuEntryKey(forgeOpenWithMenuId));
  final setDefault = find.byKey(
    forgeContextMenuEntryKey(forgeOpenWithSetDefaultMenuId),
  );
  Finder openOnce(String id) =>
      find.byKey(forgeContextMenuEntryKey(forgeOpenWithChoiceMenuId(id)));
  Finder makeDefault(String id) =>
      find.byKey(forgeContextMenuEntryKey(forgeOpenWithDefaultMenuId(id)));
  Finder checkOnChoice(String id) =>
      find.byKey(forgeContextMenuCheckKey(forgeOpenWithChoiceMenuId(id)));
  Finder checkOnDefault(String id) =>
      find.byKey(forgeContextMenuCheckKey(forgeOpenWithDefaultMenuId(id)));
  Finder row(String path) =>
      find.byKey(ValueKey<String>('forge-explorer-entry:$path'));
  final mdTab = find.descendant(
    of: find.byType(ForgeEditorTabBar),
    matching: find.text('notes.md'),
  );

  Future<void> rightClick(WidgetTester tester, Finder target) async {
    await tester.tap(target.first, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
  }

  Future<void> dismiss(WidgetTester tester) async {
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
  }

  Iterable<ForgeEditor> plainTextEditors(_Harness harness) =>
      harness.shell.systemState.openEditors.where(
        (e) =>
            forgeEditorTypeIdOf(e) == DefaultLayoutController.plainTextTypeId,
      );

  testWidgets('OPENWITH-1: the explorer row menu offers Open With for a file '
      'with two editors only; a click opens it once, Set default moves the '
      'checkmark and stores it', (tester) async {
    suppressOverflowErrorsForTest();
    await prepareLargeSurface(tester);
    final harness = _Harness.create(ForgeMemoryStateStore());
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();

    // One editor (plain text): no submenu.
    await rightClick(tester, row(_notesTxt));
    expect(find.text('Rename...'), findsOneWidget);
    expect(openWith, findsNothing);
    await dismiss(tester);

    // Two editors: the submenu with both, no default yet.
    await rightClick(tester, row(_notesMd));
    expect(openWith, findsOneWidget);
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    expect(find.text('Markdown editor'), findsOneWidget);
    expect(find.text('Plain text'), findsOneWidget);
    expect(find.text('Set default for .md'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    // Opened once in plain text: the default stays unset.
    await tester.tap(openOnce('plaintext'));
    await tester.pumpAndSettle();
    expect(plainTextEditors(harness).single.uri, Uri.file(_notesMd));
    expect(harness.shell.getFileTypeDefaults().containsKey('.md'), isFalse);

    // Set default for .md ▸ Plain text: stored, nothing else opened.
    final openBefore = harness.shell.systemState.openEditors.length;
    await rightClick(tester, row(_notesMd));
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    await tester.tap(setDefault);
    await tester.pumpAndSettle();
    await tester.tap(makeDefault('plaintext'));
    await tester.pumpAndSettle();
    expect(harness.shell.getFileTypeDefaults()['.md'], 'plaintext');
    expect(harness.preferences.fileTypeDefaultEditors['.md'], 'plaintext');
    expect(harness.shell.systemState.openEditors, hasLength(openBefore));
    expect(
      jsonDecode(
        harness.store.snapshot()['forge.files.typeDefaults']! as String,
      ),
      containsPair('.md', 'plaintext'),
    );

    // The editors list marks the default, the inner submenu checks it.
    await rightClick(tester, row(_notesMd));
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    expect(find.text('Plain text (default for .md)'), findsOneWidget);
    expect(checkOnChoice('plaintext'), findsOneWidget);
    expect(checkOnChoice('md'), findsNothing);
    await tester.tap(setDefault);
    await tester.pumpAndSettle();
    expect(checkOnDefault('plaintext'), findsOneWidget);
    expect(checkOnDefault('md'), findsNothing);
    await dismiss(tester);
  });

  testWidgets('OPENWITH-2: the editor tab menu offers Open With; a click opens '
      'the file once in that panel, Set default moves the checkmark', (
    tester,
  ) async {
    suppressOverflowErrorsForTest();
    await prepareLargeSurface(tester);
    final harness = _Harness.create(ForgeMemoryStateStore());
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    harness.layout.openFile(Uri.file(_notesMd));
    await tester.pumpAndSettle();
    expect(harness.shell.systemState.activeEditor, isA<_MarkdownEditor>());

    await rightClick(tester, mdTab);
    expect(find.text('Close Others'), findsOneWidget);
    expect(openWith, findsOneWidget);
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    expect(find.text('Markdown editor'), findsOneWidget);
    await tester.tap(openOnce('plaintext'));
    await tester.pumpAndSettle();
    final plain = plainTextEditors(harness).single;
    expect(plain.uri, Uri.file(_notesMd));
    expect(harness.layout.middlePanels.value.first, contains(plain));
    expect(harness.shell.getFileTypeDefaults().containsKey('.md'), isFalse);

    // Set default from the tab: the Markdown editor.
    await rightClick(tester, mdTab);
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    await tester.tap(setDefault);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.tap(makeDefault('md'));
    await tester.pumpAndSettle();
    expect(harness.shell.getFileTypeDefaults()['.md'], 'md');
    expect(harness.preferences.fileTypeDefaultEditors['.md'], 'md');

    await rightClick(tester, mdTab);
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    expect(find.text('Markdown editor (default for .md)'), findsOneWidget);
    expect(checkOnChoice('md'), findsOneWidget);
    await tester.tap(setDefault);
    await tester.pumpAndSettle();
    expect(checkOnDefault('md'), findsOneWidget);
    expect(checkOnDefault('plaintext'), findsNothing);
    await dismiss(tester);
  });

  testWidgets('OPENWITH-3: the default is kept for a new shell over the same '
      'state, listed in the configuration\'s file-type defaults and reset '
      'there', (tester) async {
    suppressOverflowErrorsForTest();
    await prepareLargeSurface(tester);
    final first = _Harness.create(ForgeMemoryStateStore());
    await tester.pumpWidget(first.app());
    await tester.pumpAndSettle();
    await rightClick(tester, row(_notesMd));
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    await tester.tap(setDefault);
    await tester.pumpAndSettle();
    await tester.tap(makeDefault('plaintext'));
    await tester.pumpAndSettle();

    // A new shell over the stored state.
    final harness = _Harness.create(
      ForgeMemoryStateStore(initial: first.store.snapshot()),
    );
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(harness.shell.getFileTypeDefaults()['.md'], 'plaintext');
    await rightClick(tester, row(_notesMd));
    await tester.tap(openWith);
    await tester.pumpAndSettle();
    expect(checkOnChoice('plaintext'), findsOneWidget);
    await dismiss(tester);

    // The configuration lists it, follows a default moved meanwhile, and
    // resets it.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeConfigurationPanel(
            preferencesService: harness.preferences,
            shellApi: harness.shell,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('File Types').first);
    await tester.pumpAndSettle();
    final mdEditor = find.byKey(const Key('file-type-editor-.md'));
    expect(
      find.descendant(of: mdEditor, matching: find.text('Plain Text')),
      findsOneWidget,
    );

    harness.shell.editorPicker.setDefaultId(
      ForgeContentItem(Uri.file(_notesMd)),
      'md',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: mdEditor, matching: find.text('Markdown')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('file-type-remove-.md')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('file-type-row-.md')), findsNothing);
    expect(harness.shell.getFileTypeDefaults().containsKey('.md'), isFalse);
    expect(
      harness.preferences.fileTypeDefaultEditors.containsKey('.md'),
      isFalse,
    );
    expect(
      (await harness.shell.editorPicker.choicesFor(
        ForgeContentItem(Uri.file(_notesMd)),
      )).defaultChoice,
      isNull,
    );
  });

  testWidgets('OPENWITH-4: a File Types choice offers a module\'s editor '
      'for the extension; choosing it sets the default', (tester) async {
    suppressOverflowErrorsForTest();
    await prepareLargeSurface(tester);
    final harness = _Harness.create(
      ForgeMemoryStateStore(),
      extraModule: _PreviewModule(),
    );
    // Loaded, as the application loads them at start.
    await harness.preferences.load();
    harness.shell.setFileTypeDefault('.md', 'md');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeConfigurationPanel(
            preferencesService: harness.preferences,
            shellApi: harness.shell,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('File Types').first);
    await tester.pumpAndSettle();

    final mdEditor = find.byKey(const Key('file-type-editor-.md'));
    await tester.tap(mdEditor);
    await tester.pumpAndSettle();
    expect(find.text('Markdown preview'), findsWidgets);
    await tester.tap(find.text('Markdown preview').last);
    await tester.pumpAndSettle();

    expect(harness.shell.getFileTypeDefaults()['.md'], _PreviewModule.id);
    expect(
      harness.preferences.fileTypeDefaultEditors['.md'],
      _PreviewModule.id,
    );
    expect(
      find.descendant(of: mdEditor, matching: find.text('Markdown preview')),
      findsOneWidget,
    );
    expect(
      (await harness.shell.editorPicker.choicesFor(
        ForgeContentItem(Uri.file(_notesMd)),
      )).defaultChoice?.id,
      _PreviewModule.id,
    );

    // A .dart row has no module editor: its choices stay the section's own.
    await tester.tap(find.byKey(const Key('file-type-editor-.dart')));
    await tester.pumpAndSettle();
    expect(find.text('Markdown preview'), findsOneWidget);
  });
}

class _Harness {
  _Harness._(this.shell, this.store);

  final DefaultShellApi shell;
  final ForgeMemoryStateStore store;

  DefaultLayoutController get layout => shell.layout as DefaultLayoutController;

  ForgePreferencesService get preferences =>
      ForgePreferencesService.forStore(store);

  static _Harness create(
    ForgeMemoryStateStore store, {
    ForgeModule? extraModule,
  }) {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {_notesMd: '# Notes\n', _notesTxt: 'notes\n'},
      appName: 'openwith',
      navigatorKey: GlobalKey<NavigatorState>(),
      stateStore: store,
      components: ForgeShellComponents(
        editorTypes: [
          ForgeEditorType(
            id: 'md',
            label: 'Markdown editor',
            description: 'Edit Markdown',
            extensions: const ['md'],
            create: (request) => _MarkdownEditor(request.uri),
          ),
        ],
      ),
    );
    (shell.systemState as DefaultSystemState).setWorkspaceRootPath(_workspace);
    final module = _ExplorerModule(shell);
    (shell.modules as DefaultModuleRegistry).register(module);
    if (extraModule != null) {
      (shell.modules as DefaultModuleRegistry).register(extraModule);
    }
    shell.applications.add(
      ForgeApplication(
        id: 'openwith',
        title: 'openwith',
        layout: PanelLayout(
          leftPanel: PanelConfig(
            initialSize: 260,
            tabs: [
              PanelTabConfig(
                title: 'Explorer',
                icon: Icons.folder,
                sections: [module.explorer],
              ),
            ],
          ),
          rightPanel: const PanelConfig(initialSize: 200, tabs: []),
          bottomPanel: const PanelConfig(initialSize: 160, tabs: []),
          middlePanels: const [MiddlePanelConfig()],
        ),
      ),
    );
    return _Harness._(shell, store);
  }

  // Keyed: each harness's app is a new scaffold, not the last one updated.
  Widget app() => MaterialApp(
    key: ObjectKey(this),
    home: ForgeShellScaffold(
      shell: shell,
      layoutController: layout,
      systemState: shell.systemState as DefaultSystemState,
      statusBarController: shell.statusBar,
      notificationManager: shell.notifications as DefaultNotificationManager,
    ),
  );
}

/// Contributes the explorer over the shell, its Open With built from the
/// shell's editor picker.
class _ExplorerModule extends ForgeModule {
  _ExplorerModule(ForgeShellApi shell)
    : explorer = ForgeFileExplorerView(
        fileSystem: shell.fileSystem,
        openFile: forgeOpenFileAtOf(shell),
        rootUri: Uri.file(_workspace),
        selection: shell.systemState as DefaultSystemState,
        contextMenus: shell.contextMenus,
        editorPicker: shell.editorPicker,
      );

  final ForgeFileExplorerView explorer;

  @override
  String get displayName => 'Explorer';

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => [explorer];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeAction> get actions => const [];
}

/// A module with an editor of its own for Markdown files.
class _PreviewModule extends ForgeModule {
  static const id = 'mdpreview';

  @override
  String get displayName => 'Preview';

  @override
  List<ForgeEditorChoice> editorChoicesFor(Uri uri) => [
    if (uri.path.endsWith('.md'))
      ForgeEditorChoice(
        id: id,
        label: 'Markdown preview',
        icon: Icons.preview,
        open: (uri, {middlePanelIndex}) {},
      ),
  ];

  @override
  void activate(ForgeShellApi shell) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeAction> get actions => const [];
}

/// The Markdown editor type's editor: shows the file's name.
class _MarkdownEditor extends ForgeEditor implements ForgeEditorOfType {
  _MarkdownEditor(this.uri);

  @override
  final Uri uri;

  @override
  String get editorTypeId => 'md';

  final _dirty = ValueNotifier<bool>(false);

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
  IconData get icon => Icons.description;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const Center(child: Text('md'));

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;
}
