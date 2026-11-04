/// Forge's text editors under the undo conformance harness (wonecmpc19).
///
/// Every check an editor does not meet yet is skipped with the todo that
/// makes it pass; that todo removes the skip. Measured 2026-11-04: the
/// plain-text editor meets only replaceContentClearsHistory (its undo is
/// refused while typing is pending, its copy keeps a second history, dirty is
/// "anything changed"); the Dart editor meets typingUndoneWithinPause and
/// replaceContentClearsHistory (its document text lags the view, dirty is
/// "anything changed", the copy keeps a second history). The Markdown and
/// YAML editors join this file in wonecmpc22 and wonecmpc20, which write
/// their subjects (neither edits through one plain text field).
library;

import 'package:flutter/material.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart' show DartCodeController;
import 'package:tom_forge_ui/testing.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

DefaultShellApi _shell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {},
  appName: 'Undo conformance',
  navigatorKey: GlobalKey<NavigatorState>(),
);

ForgeModule _module() => TomForgeShellModule()..activate(_shell());

const _plainText = 'wonecmpc23 (the plain-text editor rebuilt on ForgeFileSession)';
const _dart = 'wonecmpc21 (the Dart editor on the contract)';

void main() {
  runForgeUndoConformance(
    'plain-text editor',
    (saved) => _Subject(
      ForgePlainTextEditor.fromContent(
        content: saved,
        uri: Uri.parse('file:///notes.txt'),
        module: _module(),
      ),
    ),
    skip: const {
      ForgeUndoCheck.dirtyFollowsSavedState: _plainText,
      ForgeUndoCheck.caretAfterUndoAndRedo: _plainText,
      ForgeUndoCheck.typingUndoneWithinPause: _plainText,
      ForgeUndoCheck.noRedoAfterTyping: _plainText,
      ForgeUndoCheck.splitCopiesShareHistory: _plainText,
    },
  );

  runForgeUndoConformance(
    'Dart editor',
    (saved) => _Subject(
      ForgeDartEditor(
        controller: DartCodeController(initialCode: saved),
        module: _module(),
      ),
    ),
    skip: const {
      ForgeUndoCheck.dirtyFollowsSavedState: _dart,
      ForgeUndoCheck.caretAfterUndoAndRedo: _dart,
      ForgeUndoCheck.noRedoAfterTyping: _dart,
      ForgeUndoCheck.splitCopiesShareHistory: _dart,
    },
  );
}

class _Subject extends ForgeUndoSubject {
  _Subject(this.editor);

  @override
  final ForgeEditor editor;
}
