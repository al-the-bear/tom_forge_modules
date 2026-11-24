// The panel shell's editor picker: the kit's model over the shell's modules,
// editor types and preferences, every choice a ForgeEditorChoice.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_shell/tom_forge_shell.dart';

class _TypeEditor extends ForgeEditor implements ForgeEditorOfType {
  _TypeEditor(this.uri, this.editorTypeId);

  @override
  final Uri uri;

  @override
  final String editorTypeId;

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
  IconData get icon => Icons.note;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const SizedBox();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox();

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;
}

class _KitModule extends ForgeKitModule {
  final List<String> opened = [];

  @override
  String get displayName => 'Kit module';

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
  List<ForgeKitEditorChoice> get contentTypeEditorChoices => [
    ForgeKitEditorChoice(
      id: 'browser',
      label: 'MD Browser',
      icon: Icons.web,
      contentTypes: const ['text/markdown'],
      open: (uri) => opened.add(uri.path),
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('choices, defaults and opening in the panel shell', () async {
    final store = ForgeMemoryStateStore();
    final mdType = ForgeEditorType(
      id: 'md',
      label: 'Markdown editor',
      description: 'Edit Markdown',
      extensions: const ['md'],
      create: (request) => _TypeEditor(request.uri, 'md'),
    );
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {'/a.md': '# A'},
      appName: 'test',
      navigatorKey: GlobalKey<NavigatorState>(),
      stateStore: store,
      components: ForgeShellComponents(editorTypes: [mdType]),
    );
    final preferences = ForgePreferencesService.forStore(store);
    await preferences.load();
    shell.registerModule(TomForgeShellModule());
    final module = _KitModule();
    shell.registerModule(module);
    final picker = shell.editorPicker;
    final file = ForgeContentItem(
      shell.fileSystem.uriOf('/a.md'),
      contentType: 'text/markdown',
    );

    final answer = await picker.choicesFor(file);
    expect(
      [for (final c in answer.choices) c.id],
      ['browser', 'md', 'plaintext'],
    );
    expect(answer.choices, everyElement(isA<ForgeEditorChoice>()));
    final mdChoice = answer.choices[1];
    final plainChoice = answer.choices[2];
    expect(plainChoice.label, 'Plain text');

    // Plain text is offered for text, not for content known to be binary.
    expect(
      forgePlainTextOpens(ForgeContentItem(file.uri, contentType: 'text/x-a')),
      isTrue,
    );
    expect(forgePlainTextOpens(ForgeContentItem(file.uri)), isTrue);
    expect(
      forgePlainTextOpens(
        ForgeContentItem(file.uri, contentType: 'application/pdf'),
      ),
      isFalse,
    );

    // By extension: the shell's file-type defaults and its preferences.
    picker.setDefault(file, mdChoice, scope: ForgeEditorDefaultScope.extension);
    expect(shell.getFileTypeDefaults(), {'.md': 'md'});
    expect(preferences.fileTypeDefaultEditors, {'.md': 'md'});
    expect((await picker.choicesFor(file)).defaultChoice?.id, 'md');

    // By content type: the preferences', ahead of the extension's.
    picker.setDefault(file, answer.choices.first);
    expect(preferences.contentTypeDefaultEditors, {'text/markdown': 'browser'});
    expect((await picker.choicesFor(file)).defaultChoice?.id, 'browser');

    // Opening once leaves the default.
    final md = mdChoice as ForgeEditorChoice;
    md.open(file.uri, middlePanelIndex: 0);
    await pumpEventQueue();
    expect(
      shell.systemState.openEditors.whereType<_TypeEditor>().single.uri,
      file.uri,
    );
    picker.openOnce(file, plainChoice);
    await pumpEventQueue();
    final plain = shell.systemState.openEditors.where(
      (e) => forgeEditorTypeIdOf(e) == DefaultLayoutController.plainTextTypeId,
    );
    expect(plain.single.uri, file.uri);
    picker.openOnce(file, answer.choices.first);
    expect(module.opened, ['/a.md']);
    expect((await picker.choicesFor(file)).defaultChoice?.id, 'browser');

    picker.clearDefault(file, scope: ForgeEditorDefaultScope.extension);
    expect(shell.getFileTypeDefaults(), isEmpty);
    expect(preferences.fileTypeDefaultEditors, isEmpty);
    shell.dispose();
  });
}
