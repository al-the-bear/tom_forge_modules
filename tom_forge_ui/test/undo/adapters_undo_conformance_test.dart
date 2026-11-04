/// Forge's text editors under the undo conformance harness (wonecmpc19).
///
/// Every check an editor does not meet yet is skipped with the todo that
/// makes it pass; that todo removes the skip. Measured 2026-11-04: the
/// plain-text editor meets only replaceContentClearsHistory (its undo is
/// refused while typing is pending, its copy keeps a second history, dirty is
/// "anything changed"); the Dart editor meets every check (wonecmpc21); the
/// YAML editor meets every check in both modes (wonecmpc20): in source mode
/// its document is the text, in tree mode the text is the value of one string
/// field. The Markdown editor joins this file in wonecmpc22, which writes its
/// subject.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart' show DartCodeController;
import 'package:tom_forge_ui/testing.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart'
    show StringEditor, YamlEditorController, kYamlEditorDebug;

DefaultShellApi _shell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {},
  appName: 'Undo conformance',
  navigatorKey: GlobalKey<NavigatorState>(),
);

ForgeModule _module() => TomForgeShellModule()..activate(_shell());

const _plainText = 'wonecmpc23 (the plain-text editor rebuilt on ForgeFileSession)';

void main() {
  // The YAML editor's debug trail replaces FlutterError.onError, which a
  // failing widget test cannot survive.
  setUp(() => kYamlEditorDebug = false);

  runForgeUndoConformance(
    'YAML editor, source mode',
    (saved) => _Subject(
      ForgeYamlEditor(
        controller: YamlEditorController(initialYaml: saved)..textMode = true,
        module: _module(),
      ),
    ),
  );

  runForgeUndoConformance('YAML editor, tree mode', _YamlTreeSubject.new);

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
  );
}

class _Subject extends ForgeUndoSubject {
  _Subject(this.editor);

  @override
  final ForgeEditor editor;
}

/// The YAML editor in tree mode: the document is `v: <text>`, and the text
/// is edited in that one string field.
class _YamlTreeSubject extends ForgeUndoSubject {
  _YamlTreeSubject(String saved)
    : editor = ForgeYamlEditor(
        controller: YamlEditorController(initialYaml: _yaml(saved)),
        module: _module(),
      );

  static String _yaml(String text) => 'v: "$text"\n';

  @override
  final ForgeYamlEditor editor;

  @override
  String contentFor(String text) => _yaml(text);

  @override
  TextEditingController controllerOf(WidgetTester tester, Finder view) =>
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.descendant(of: view, matching: find.byType(StringEditor)),
              matching: find.byType(EditableText),
            ),
          )
          .controller;

  @override
  String textOf(WidgetTester tester) {
    final value = editor.controller.document.nodeAt(const ['v'])?.value;
    return (value ?? '').toString();
  }
}
