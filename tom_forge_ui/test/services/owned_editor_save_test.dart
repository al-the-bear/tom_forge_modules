/// A host save never marks a model-owning editor clean on its behalf.
///
/// Such an editor returns null from `getContent()` and advertises
/// `forge.file.save`. An explicit save is handed to it; an automatic one leaves
/// it alone; and the host writes nothing and calls no `markClean` — the editor
/// clears its own state when its write lands. An editor that does not
/// advertise the action is not affected: `saveOwnedEditor` answers null and the
/// caller's own content path runs as before.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

class _OwnedEditor extends ForgeTestTextEditor {
  _OwnedEditor(super.module);

  final executed = <String>[];
  var cleaned = 0;

  @override
  String? getContent() => null;

  @override
  Set<String> get supportedActionIds =>
      const {StandardEditingActions.saveActionId};

  @override
  bool executeAction(String actionId) {
    executed.add(actionId);
    return true;
  }

  @override
  void markClean() => cleaned++;
}

void main() {
  group('saveOwnedEditor', () {
    test('an explicit save is handed to the editor, and nothing marks it '
        'clean', () {
      final editor = _OwnedEditor(ForgeTestModule());
      expect(saveOwnedEditor(editor), isTrue);
      expect(editor.executed, [StandardEditingActions.saveActionId]);
      expect(editor.cleaned, 0,
          reason: 'the host wrote nothing, so it may not say it is saved');
    });

    test('an automatic save leaves a model-owning editor alone', () {
      final editor = _OwnedEditor(ForgeTestModule());
      expect(saveOwnedEditor(editor, trigger: ForgeSaveTrigger.automatic),
          isFalse);
      expect(editor.executed, isEmpty);
      expect(editor.cleaned, 0);
    });

    test('an ordinary editor is not affected', () {
      final editor = ForgeTestTextEditor(ForgeTestModule());
      expect(saveOwnedEditor(editor), isNull,
          reason: 'null hands the save back to the caller\'s content path');
      expect(saveOwnedEditor(editor, trigger: ForgeSaveTrigger.automatic),
          isNull);
    });

    test('the save action is enabled when there is a document', () {
      final rule =
          StandardEditingActions.enablementRule(StandardEditingActions.saveActionId);
      expect(rule(const EditorStateSnapshot(hasContent: true)), isTrue);
      expect(rule(const EditorStateSnapshot()), isFalse);
    });
  });
}
