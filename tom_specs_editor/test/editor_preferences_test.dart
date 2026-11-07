/// The editor preferences store reads and writes `.tom/editor_preferences.yaml`
/// through the workspace's file system (`tom_specs_editor_specification.md`
/// §12 — basic prefs).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_specs_editor/src/config/editor_preferences.dart';

void main() {
  test(
    'PREF-1: a missing, empty or malformed file loads the defaults',
    () async {
      final fs = TomMemoryFileSystem();
      final store = EditorPreferencesStore.resolveDefault(fs);
      expect(store.uri, fs.uriOf('.tom/editor_preferences.yaml'));
      expect((await store.load()).themeMode, 'dark');

      await fs.writeTextMakingFolder(store.uri, '   ');
      expect((await store.load()).strictHeadlineEditing, isTrue);

      await fs.writeText(store.uri, 'preferences: [not, a, map]');
      expect((await store.load()).defaultApplication, 'DocSpecs');
    },
  );

  test('PREF-2: save makes the folder and load reads the saved values back; '
      'TOM_SPECS_PREFS_FILE moves the file', () async {
    final fs = TomMemoryFileSystem();
    final store = EditorPreferencesStore.resolveDefault(fs);
    const prefs = EditorPreferences(
      themeMode: 'light',
      fontFamily: 'Menlo',
      defaultApplication: 'CodeSpecs',
      strictHeadlineEditing: false,
    );
    await store.save(prefs);
    final loaded = await EditorPreferencesStore.resolveDefault(fs).load();
    expect(loaded.toYaml(), prefs.toYaml());

    final moved = EditorPreferencesStore.resolveDefault(
      fs,
      overridePath: 'config/prefs.yaml',
    );
    await moved.save(prefs);
    expect(await fs.exists(fs.uriOf('config/prefs.yaml')), isTrue);
  });
}
