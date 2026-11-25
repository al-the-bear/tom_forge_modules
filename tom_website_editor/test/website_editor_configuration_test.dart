// The website editor's settings (§9.2) as a configuration description,
// driven through a real WebsiteEditorController over a stub reader: the
// registered websites are the active website's choices (label preferred),
// choosing one selects it, the reload action re-reads and applies the
// source, and the status reports the last load with its issues.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_website_editor/tom_website_editor.dart';

typedef _W = WebsiteEditorConfiguration;

const _twoSites = '''
version: 1
websites:
  - id: alpha
    label: Alpha Site
    paths: { websiteRoot: "/a" }
  - id: beta
    paths: { websiteRoot: "/b" }
''';

const _invalid = 'version: 1\nwebsites: []\n';

class _StubReader {
  _StubReader(this.source);
  String source;
  Future<String> read() async => source;
}

void main() {
  late _StubReader reader;
  late WebsiteEditorController controller;
  late ForgeSettingHooks hooks;
  late ForgeConfigurationValues values;
  var edited = 0;
  final started = <void Function()>[];

  ForgeSettingContext contextOf(ForgeSetting<Object> setting) =>
      ForgeSettingContext(
        setting: setting,
        value: setting.defaultValue,
        hooks: hooks,
      );

  Future<void> start(String source) async {
    reader = _StubReader(source);
    controller = WebsiteEditorController(configReader: reader.read);
    await controller.load();
    edited = 0;
    hooks = _W.hooks(() => controller, onEditConfiguration: () => edited++);
    values = ForgeConfigurationValues(
      ForgeMemoryStateStore(),
      descriptions: [_W.description],
      bindings: [WebsiteSelectionBinding(() => controller)],
      hooks: hooks,
    );
    await values.load();
    started
      ..add(values.dispose)
      ..add(controller.dispose);
  }

  tearDown(() {
    for (final dispose in started) {
      dispose();
    }
    started.clear();
  });

  test('the description is sound with its hooks', () {
    expect(_W.description.problems(hooks: _W.hooks(() => null)), isEmpty);
  });

  test('TWE-CONFIG-01: the websites are the choices, the active one is the '
      'value', () async {
    await start(_twoSites);
    final choices = await hooks
        .choices(_W.websitesProvider)!
        .choices(contextOf(_W.activeWebsite));
    expect([for (final c in choices) c.value], ['alpha', 'beta']);
    expect(
      [for (final c in choices) c.label.fallback],
      ['Alpha Site', 'beta'],
      reason: 'the label preferred, else the id',
    );
    expect(values.valueOf(_W.activeWebsite), 'alpha');
  });

  test('TWE-CONFIG-02: choosing a website selects it; a selection made '
      'elsewhere is read again', () async {
    await start(_twoSites);
    expect(await values.set(_W.activeWebsite, 'beta'), isNull);
    expect(controller.activeWebsiteId, 'beta');

    controller.selectWebsite('alpha');
    await pumpEventQueue();
    expect(values.valueOf(_W.activeWebsite), 'alpha');
  });

  test('TWE-CONFIG-03: the reload action re-reads and applies the new '
      'source; the edit action opens the configuration file', () async {
    await start(_twoSites);
    reader.source = '''
version: 1
websites:
  - id: gamma
    paths: { websiteRoot: "/g" }
''';
    final reload = hooks.action(_W.reloadAction)!;
    expect(reload.isEnabled(contextOf(_W.reloadConfiguration)), isTrue);
    final result = await reload.run(contextOf(_W.reloadConfiguration));
    expect(result.succeeded, isTrue);
    expect(controller.activeWebsiteId, 'gamma');
    await pumpEventQueue();
    expect(values.valueOf(_W.activeWebsite), 'gamma');

    await hooks.action(_W.editAction)!.run(contextOf(_W.editConfiguration));
    expect(edited, 1);
  });

  test('TWE-CONFIG-04: the status reports the websites, or the issues when '
      'the configuration is invalid', () async {
    await start(_twoSites);
    final status = hooks.status(_W.statusProvider)!;
    var info = await status.current(contextOf(_W.status));
    expect(info.level, ForgeStatusLevel.ok);
    expect(info.message?.params['count'], 2);

    await start(_invalid);
    info = await hooks.status(_W.statusProvider)!.current(contextOf(_W.status));
    expect(info.level, ForgeStatusLevel.error);
    expect(info.message?.fallback, 'No valid configuration loaded.');
    expect(info.items, isNotEmpty);
    expect(values.valueOf(_W.activeWebsite), '');
  });

  test('TWE-CONFIG-05: the module contributes the description, the '
      'binding and the hooks', () {
    final module = WebsiteEditorModule();
    final extras = module.ownExtras;
    expect(
      extras
          .whereType<ForgeConfigurationDescriptionsExtra>()
          .single
          .descriptions
          .single
          .id,
      _W.descriptionId,
    );
    expect(
      extras
          .whereType<ForgeConfigurationBindingsExtra>()
          .single
          .bindings
          .single
          .id,
      WebsiteSelectionBinding.bindingId,
    );
    final moduleHooks = extras
        .whereType<ForgeConfigurationHooksExtra>()
        .single
        .hooks;
    expect(moduleHooks.action(_W.reloadAction), isNotNull);
    expect(moduleHooks.status(_W.statusProvider), isNotNull);
  });
}
