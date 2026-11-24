import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// The editor an editor type of the test makes.
class _TypeEditor extends ForgeEditor implements ForgeEditorOfType {
  _TypeEditor(this.uri, this.editorTypeId, this.content);

  @override
  final Uri uri;

  @override
  final String editorTypeId;

  final String content;

  @override
  ValueListenable<bool> get isDirty => ValueNotifier(false);

  @override
  void markClean() {}

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
}

/// An editor host that records the editors it is asked to show.
class _Host implements ForgeEditorHost {
  final List<ForgeEditor> shown = [];

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async => shown.add(editor);

  @override
  Future<bool> closeEditor(ForgeEditor editor) async => true;

  @override
  void bringToFront(ForgeEditor editor) {}

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async =>
      null;
}

/// A module offering editors by extension (Markdown files: an MD Browser)
/// and by content type (Markdown and PDF content, whatever its URI).
class _EditorsModule extends ForgeKitModule {
  final List<(String, Uri)> opened = [];

  ForgeKitEditorChoice _choice(String id, {List<String> types = const []}) =>
      ForgeKitEditorChoice(
        id: id,
        label: id,
        icon: const IconData(0xe001),
        contentTypes: types,
        open: (uri) => opened.add((id, uri)),
      );

  @override
  List<ForgeKitEditorChoice> editorChoicesFor(Uri uri) => [
    if (uri.path.endsWith('.md')) _choice('mdBrowser'),
  ];

  @override
  List<ForgeKitEditorChoice> get contentTypeEditorChoices => [
    _choice('mdBrowser', types: const ['text/markdown']),
    _choice('richMarkdown', types: const ['text/markdown']),
    _choice('pdfium', types: const ['application/pdf']),
    _choice('textAny', types: const ['text/*']),
  ];

  @override
  String get displayName => 'Editors';

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
}

final _mdType = ForgeKitEditorType(
  id: 'md',
  label: 'Markdown editor',
  extensions: const ['md'],
  contentTypes: const ['text/markdown'],
  create: (request) => _TypeEditor(request.uri, 'md', request.content),
);

final _yamlType = ForgeKitEditorType(
  id: 'yaml',
  label: 'YAML editor',
  extensions: const ['yaml'],
  create: (request) => _TypeEditor(request.uri, 'yaml', request.content),
);

final _attachment = ForgeKitEditorChoice(
  id: 'attachment',
  label: 'Attachment',
  icon: const IconData(0xe002),
  open: (_) {},
);

void main() {
  late ForgeMemoryStateStore store;
  late TomMemoryFileSystem fs;
  late _Host host;
  late _EditorsModule module;

  DefaultKitApi makeApi() {
    final api = DefaultKitApi(
      editorHost: host,
      fileSystem: fs,
      stateStore: store,
      editorTypes: [_mdType, _yamlType],
      fallbackEditor: _attachment,
    );
    api.registerModule(module);
    return api;
  }

  List<String> ids(ForgeEditorChoices answer) => [
    for (final choice in answer.choices) choice.id,
  ];

  final readme = Uri.file('/doc/README.md');
  final section = Uri.parse('webwork:/notes/section-3');

  setUp(() {
    store = ForgeMemoryStateStore();
    fs = TomMemoryFileSystem(
      seed: const {'/doc/README.md': '# Hi', '/conf/a.yaml': 'a: 1'},
    );
    host = _Host();
    module = _EditorsModule();
  });

  test('a file without content type: choices by extension', () async {
    final api = makeApi();
    await api.restore();

    final md = await api.editorPicker.choicesFor(ForgeContentItem(readme));
    expect(ids(md), ['mdBrowser', 'md']);
    expect(md.defaultChoice, isNull);
    expect(md.isFallback, isFalse);

    final yaml = await api.editorPicker.choicesFor(
      ForgeContentItem(Uri.file('/conf/a.yaml')),
    );
    expect(ids(yaml), ['yaml']);
    expect(yaml.preferred?.id, 'yaml');
    api.dispose();
  });

  test('content without a file: choices by content type', () async {
    final api = makeApi();
    await api.restore();

    final markdown = await api.editorPicker.choicesFor(
      ForgeContentItem(section, contentType: 'Text/Markdown; charset=utf-8'),
    );
    expect(markdown.item.contentType, 'text/markdown');
    expect(ids(markdown), ['mdBrowser', 'richMarkdown', 'textAny', 'md']);

    final pdf = await api.editorPicker.choicesFor(
      ForgeContentItem(section, contentType: 'application/pdf'),
    );
    expect(ids(pdf), ['pdfium']);
    api.dispose();
  });

  test('a file with a content type: both, each id once', () async {
    final api = makeApi();
    await api.restore();

    final answer = await api.editorPicker.choicesFor(
      ForgeContentItem(readme, contentType: 'text/markdown'),
    );
    expect(ids(answer), ['mdBrowser', 'richMarkdown', 'textAny', 'md']);
    api.dispose();
  });

  test('defaults per extension and per content type are set, persisted '
      'and cleared', () async {
    final api = makeApi();
    await api.restore();
    final picker = api.editorPicker;
    final file = ForgeContentItem(readme);
    final content = ForgeContentItem(section, contentType: 'text/markdown');

    var notified = 0;
    picker.defaultsChanged.addListener(() => notified++);

    final fileChoices = await picker.choicesFor(file);
    expect(picker.setDefault(file, fileChoices.choices.last), isTrue);
    final contentChoices = await picker.choicesFor(content);
    expect(
      picker.setDefault(
        content,
        contentChoices.choices.firstWhere((c) => c.id == 'richMarkdown'),
      ),
      isTrue,
    );
    expect(notified, 2);
    expect(api.getFileTypeDefaults(), {'.md': 'md'});

    var answer = await picker.choicesFor(file);
    expect(answer.defaultChoice?.id, 'md');
    expect(answer.defaultScope, ForgeEditorDefaultScope.extension);
    expect(answer.isDefault(answer.choices.last), isTrue);
    answer = await picker.choicesFor(content);
    expect(answer.defaultChoice?.id, 'richMarkdown');
    expect(answer.defaultScope, ForgeEditorDefaultScope.contentType);

    await api.flushed();
    expect(
      jsonDecode(store.snapshot()['forge.files.typeDefaults']! as String),
      {'.md': 'md'},
    );
    expect(
      jsonDecode(
        store.snapshot()['forge.files.contentTypeDefaults']! as String,
      ),
      {'text/markdown': 'richMarkdown'},
    );
    api.dispose();

    // A second API over the same store restores both.
    module = _EditorsModule();
    final again = makeApi();
    await again.restore();
    expect((await again.editorPicker.choicesFor(file)).defaultChoice?.id, 'md');
    expect(
      (await again.editorPicker.choicesFor(content)).defaultChoice?.id,
      'richMarkdown',
    );

    // A Markdown file with its content type: the content type's default
    // wins; cleared, the extension's is in force again.
    final both = ForgeContentItem(readme, contentType: 'text/markdown');
    expect(
      (await again.editorPicker.choicesFor(both)).defaultChoice?.id,
      'richMarkdown',
    );
    expect(again.editorPicker.clearDefault(both), isTrue);
    answer = await again.editorPicker.choicesFor(both);
    expect(answer.defaultChoice?.id, 'md');
    expect(answer.defaultScope, ForgeEditorDefaultScope.extension);

    expect(again.editorPicker.clearDefault(file), isTrue);
    expect((await again.editorPicker.choicesFor(file)).defaultChoice, isNull);
    await again.flushed();
    expect(
      jsonDecode(store.snapshot()['forge.files.typeDefaults']! as String),
      {},
    );
    expect(
      jsonDecode(
        store.snapshot()['forge.files.contentTypeDefaults']! as String,
      ),
      {},
    );
    // An item with neither key has no default to set.
    expect(
      again.editorPicker.setDefault(ForgeContentItem(section), _attachment),
      isFalse,
    );
    again.dispose();
  });

  test('openOnce opens in the choice and leaves the default', () async {
    final api = makeApi();
    await api.restore();
    final picker = api.editorPicker;
    final file = ForgeContentItem(readme);
    picker.setDefaultId(file, 'mdBrowser');

    final answer = await picker.choicesFor(file);
    final mdType = answer.choices.firstWhere((c) => c.id == 'md');
    picker.openOnce(file, mdType);
    await pumpEventQueue();
    expect(host.shown, hasLength(1));
    final editor = host.shown.single as _TypeEditor;
    expect(editor.editorTypeId, 'md');
    expect(editor.content, '# Hi');
    expect((await picker.choicesFor(file)).defaultChoice?.id, 'mdBrowser');
    expect(api.getFileTypeDefaults(), {'.md': 'mdBrowser'});

    // open() takes the default.
    expect((await picker.open(file))?.id, 'mdBrowser');
    expect(module.opened, [('mdBrowser', readme)]);
    api.dispose();
  });

  test('a content type nobody takes gets the fallback', () async {
    final api = makeApi();
    await api.restore();
    final item = ForgeContentItem(
      section,
      contentType: 'application/vnd.tom.webwork.drawing+yaml',
    );
    final answer = await api.editorPicker.choicesFor(item);
    expect(ids(answer), ['attachment']);
    expect(answer.isFallback, isTrue);
    expect(answer.preferred?.id, 'attachment');

    api.editorPicker.fallback = null;
    expect((await api.editorPicker.choicesFor(item)).isEmpty, isTrue);
    expect(await api.editorPicker.open(item), isNull);
    api.dispose();
  });

  test('an existing per-extension default in the store is honoured', () async {
    store = ForgeMemoryStateStore(
      initial: {
        'forge.files.typeDefaults': jsonEncode({'MD': 'mdBrowser'}),
      },
    );
    final api = makeApi();
    await api.restore();
    expect(api.getFileTypeDefaults(), {'.md': 'mdBrowser'});
    final answer = await api.editorPicker.choicesFor(ForgeContentItem(readme));
    expect(answer.defaultChoice?.id, 'mdBrowser');
    expect(answer.defaultScope, ForgeEditorDefaultScope.extension);

    // The file-type default API and the picker keep the same defaults.
    api.setFileTypeDefault('yaml', 'yaml');
    expect(
      api.editorPicker.defaultIdFor(ForgeContentItem(Uri.file('/x/b.YAML'))),
      ('yaml', ForgeEditorDefaultScope.extension),
    );
    api.dispose();
  });

  test('content types match by family and ignore parameters', () {
    expect(forgeContentTypeAccepted(['text/*'], 'text/plain'), isTrue);
    expect(forgeContentTypeAccepted(['*/*'], 'image/png'), isTrue);
    expect(
      forgeContentTypeAccepted(['text/markdown'], 'TEXT/markdown; x=1'),
      isTrue,
    );
    expect(forgeContentTypeAccepted(['text/markdown'], 'text/plain'), isFalse);
    expect(forgeContentTypeAccepted(['text/markdown'], null), isFalse);
    expect(forgeExtensionOf(Uri.file('/a/.env')), '.env');
    expect(forgeExtensionOf(Uri.file('/a/Makefile')), '');
    expect(forgeExtensionOf(Uri.file('/a/b.TAR.GZ')), '.gz');
  });
}
