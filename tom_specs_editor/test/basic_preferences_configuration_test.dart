// The basic preferences (`tom_specs_editor_specification.md` §12) are a
// configuration description: kept in `.tom/editor_preferences.yaml` and the
// agent settings as before, the profiles offered from the profile store,
// contributed by the config module with its bindings and hooks.
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_specs_editor/src/config/config_specs.dart';
import 'package:tom_specs_editor/src/config/editor_preferences.dart';
import 'package:tom_specs_editor/src/config/raw_file_module.dart';
import 'package:tom_specs_editor/src/config/specs_basic_preferences_configuration.dart';
import 'package:tom_specs_editor/src/config/specs_config_module.dart';

typedef _B = SpecsBasicPreferencesConfiguration;

void main() {
  late TomMemoryFileSystem fs;
  late SpecsConfigSpecs specs;
  late EditorPreferencesStore preferencesStore;
  late List<EditorPreferences> told;
  late ForgeConfigurationValues values;

  Future<ForgeConfigurationValues> open() async {
    final opened = ForgeConfigurationValues(
      ForgeMemoryStateStore(),
      descriptions: [_B.description],
      bindings: [
        SpecsEditorPreferencesBinding(preferencesStore, onChanged: told.add),
        SpecsAgentSettingsBinding(specs.agentSettings),
      ],
      hooks: _B.hooks(specs.profiles),
    );
    await opened.load();
    return opened;
  }

  setUp(() async {
    fs = TomMemoryFileSystem();
    specs = SpecsConfigSpecs(fileSystem: fs);
    preferencesStore = EditorPreferencesStore.resolveDefault(fs);
    told = [];
    values = await open();
  });

  tearDown(() => values.dispose());

  test('the description is sound with its hooks', () {
    expect(_B.description.problems(hooks: _B.hooks(specs.profiles)), isEmpty);
  });

  test('without a file: the editor preferences\' defaults, no profile', () {
    const defaults = EditorPreferences();
    expect(values.valueOf(_B.themeMode), defaults.themeMode);
    expect(values.valueOf(_B.fontFamily), defaults.fontFamily);
    expect(values.valueOf(_B.defaultApplication), defaults.defaultApplication);
    expect(
      values.valueOf(_B.strictHeadlineEditing),
      defaults.strictHeadlineEditing,
    );
    expect(values.valueOf(_B.defaultProfile), '');
  });

  test('a change is saved to the preferences file and told to the host; '
      'a new values service reads it back', () async {
    expect(await values.set(_B.themeMode, 'light'), isNull);
    expect(await values.set(_B.strictHeadlineEditing, false), isNull);
    await values.flushed();
    final saved = await preferencesStore.load();
    expect(saved.themeMode, 'light');
    expect(saved.strictHeadlineEditing, isFalse);
    expect(saved.fontFamily, 'system', reason: 'the other fields are kept');
    expect(told.last.strictHeadlineEditing, isFalse);

    final again = await open();
    addTearDown(again.dispose);
    expect(again.valueOf(_B.themeMode), 'light');
  });

  test('an unknown theme is refused', () async {
    expect(await values.set(_B.themeMode, 'sepia'), isNotNull);
  });

  test('the default profile: the profiles offered, the choice stored in the '
      'agent settings with the rest of them kept, none clears it', () async {
    await specs.profiles.save(const [
      AgentProfile(id: 'p1', name: 'Primary'),
      AgentProfile(id: 'p2', name: 'Second'),
    ]);
    await specs.agentSettings.save(const AgentSettings(maxRounds: 7));

    final provider = _B
        .hooks(specs.profiles)
        .choices(SpecsBasicPreferencesConfiguration.profilesProvider)!;
    final choices = await provider.choices(
      ForgeSettingContext(
        setting: _B.defaultProfile,
        value: '',
        hooks: _B.hooks(specs.profiles),
      ),
    );
    expect([for (final c in choices) c.value], ['p1', 'p2']);
    expect(choices.first.label.fallback, 'Primary');

    expect(await values.set(_B.defaultProfile, 'p2'), isNull);
    await values.flushed();
    var settings = await specs.agentSettings.load();
    expect(settings.defaultProfileId, 'p2');
    expect(settings.maxRounds, 7);

    expect(await values.set(_B.defaultProfile, ''), isNull);
    await values.flushed();
    settings = await specs.agentSettings.load();
    expect(settings.defaultProfileId, isNull);
    expect(settings.maxRounds, 7);
  });

  test('the config module contributes the description, the bindings and '
      'the hooks', () {
    final module = SpecsConfigModule(
      specs: specs,
      rawFileModule: RawFileModule(),
      preferencesStore: preferencesStore,
    );
    final extras = module.ownExtras;
    expect(
      extras
          .whereType<ForgeConfigurationDescriptionsExtra>()
          .single
          .descriptions
          .single
          .id,
      _B.descriptionId,
    );
    expect(
      [
        for (final b
            in extras
                .whereType<ForgeConfigurationBindingsExtra>()
                .single
                .bindings)
          b.id,
      ],
      [
        SpecsEditorPreferencesBinding.bindingId,
        SpecsAgentSettingsBinding.bindingId,
      ],
    );
    expect(
      extras.whereType<ForgeConfigurationHooksExtra>().single.hooks.choices(
        _B.profilesProvider,
      ),
      isNotNull,
    );
  });
}
