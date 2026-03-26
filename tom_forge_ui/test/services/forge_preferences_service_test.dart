import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_forge_ui/src/services/forge_preferences_service.dart';

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
}
