import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeTextSettings;
import 'package:tom_forge_ui/src/services/forge_preferences_service.dart';
import 'package:tom_forge_ui/src/actions/forge_shortcut_binding.dart';

void main() {
  group('ForgePreferencesService editor settings persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('round-trips editor text settings by editor type', () async {
      final first = ForgePreferencesService();
      await first.load();

      const mdSettings = ForgeTextSettings(
        fontFamily: 'Fira Code',
        fontSize: 16,
        lineHeight: 1.6,
        tabSize: 4,
        insertSpaces: true,
        showWhitespace: true,
        wordWrap: false,
        showLineNumbers: true,
        highlightCurrentLine: true,
        maxUndoHistory: 250,
      );
      const dartSettings = ForgeTextSettings(
        fontFamily: 'JetBrains Mono',
        fontSize: 14,
        lineHeight: 1.4,
        tabSize: 2,
        insertSpaces: true,
        showWhitespace: false,
        wordWrap: true,
        showLineNumbers: true,
        highlightCurrentLine: true,
        maxUndoHistory: 500,
      );

      first.setEditorTextSettings('md', mdSettings);
      first.setEditorTextSettings('dart', dartSettings);
      await first.save();

      final second = ForgePreferencesService();
      await second.load();

      expect(second.getEditorTextSettings('md'), equals(mdSettings));
      expect(second.getEditorTextSettings('dart'), equals(dartSettings));
    });
  });

  group('ForgePreferencesService file type and shortcuts persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('round-trips file type default editor overrides', () async {
      final first = ForgePreferencesService();
      await first.load();

      first.setFileTypeDefaultEditor('.txt', 'plaintext');
      first.setFileTypeDefaultEditor('json', 'yaml');
      await first.save();

      final second = ForgePreferencesService();
      await second.load();

      expect(second.fileTypeDefaultEditors['.txt'], 'plaintext');
      expect(second.fileTypeDefaultEditors['.json'], 'yaml');
    });

    test('round-trips shortcut overrides', () async {
      final first = ForgePreferencesService();
      await first.load();

      const override = ForgeShortcutKey(
        key: LogicalKeyboardKey.keyK,
        primaryModifier: true,
        shift: true,
      );
      first.setShortcutOverride('editor.find', override);
      await first.save();

      final second = ForgePreferencesService();
      await second.load();

      expect(second.shortcutOverrides['editor.find'], override);
    });
  });
}
