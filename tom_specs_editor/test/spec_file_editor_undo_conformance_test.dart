/// The TomSpecs document editor under Forge's undo conformance harness
/// (`package:tom_forge_ui_testing/tom_forge_ui_testing.dart`): every document
/// editor runs the same six checks
/// (`tom_ai/forge_modules/_agent_guidelines/editor_component_contract.md` §2). The
/// subject types into a content field, the way an input method does.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_specs_editor/tom_specs_editor.dart';

const _overview = 'D00/D00-OVR';

Map<String, dynamic> _json() => {
  'roots': [
    {'type': 'DemoDoc', 'title': 'Demo Document', 'sectionId': 'D00'},
  ],
  'classes': {
    'DemoDoc': {
      'name': 'DemoDoc',
      'sectionId': 'D00',
      'fields': [
        {'name': 'overview', 'kind': 'content', 'sectionId': 'D00-OVR'},
      ],
    },
  },
};

/// The `*.docspecs.yaml` text of a document whose overview is [text]: the
/// shape `SpecDocumentController.encodeDocSpecs` writes, with the value as a
/// double-quoted scalar (JSON's string syntax is YAML's).
String _document(String text) =>
    '# TomSpecs document (*.docspecs.yaml). Hierarchical format v2.\n'
    'version: 2\n'
    'document:\n'
    '  D00 DemoDoc:\n'
    '    D00-OVR overview: ${jsonEncode(text)}\n'
    'review: {}\n';

class _SpecFileSubject extends ForgeUndoSubject {
  _SpecFileSubject(String saved) {
    final fs = TomMemoryFileSystem(
      seed: {'/ws/demo.docspecs.yaml': _document(saved)},
    );
    editor = SpecFileEditor(
      uri: fs.uriOf('/ws/demo.docspecs.yaml'),
      fileSystem: fs,
      model: Future.value(SpecModel.fromJson(_json())),
    );
  }

  @override
  late final SpecFileEditor editor;

  Finder _field(Finder view) => find.descendant(
    of: find.descendant(
      of: view,
      matching: find.byKey(const ValueKey('content:$_overview')),
    ),
    matching: find.byType(EditableText),
  );

  /// The content field: an empty one is a chip until it is opened.
  Future<Finder> _open(WidgetTester tester, Finder view) async {
    if (_field(view).evaluate().isEmpty) {
      await tester.tap(
        find.descendant(
          of: view,
          matching: find.widgetWithText(ActionChip, 'overview'),
        ),
      );
      await tester.pump();
    }
    return _field(view).first;
  }

  @override
  TextEditingController controllerOf(WidgetTester tester, Finder view) =>
      tester.widget<EditableText>(_field(view).first).controller;

  Future<void> _input(WidgetTester tester, TextEditingValue value) async {
    tester.testTextInput.updateEditingValue(value);
    await tester.pump();
  }

  @override
  Future<void> type(WidgetTester tester, String text) async {
    final field = await _open(tester, find.byKey(forgeUndoMainView));
    await tester.showKeyboard(field);
    final value = tester.widget<EditableText>(field).controller.value;
    final at = value.selection.isValid
        ? value.selection.extentOffset
        : value.text.length;
    await _input(
      tester,
      TextEditingValue(
        text: value.text.replaceRange(at, at, text),
        selection: TextSelection.collapsed(offset: at + text.length),
      ),
    );
  }

  @override
  Future<void> moveCaret(WidgetTester tester, int offset) async {
    final field = await _open(tester, find.byKey(forgeUndoMainView));
    await tester.showKeyboard(field);
    final text = tester.widget<EditableText>(field).controller.text;
    await _input(
      tester,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset),
      ),
    );
  }

  @override
  String textOf(WidgetTester tester) =>
      editor.controller.content(_overview) ?? '';

  @override
  String contentFor(String text) => _document(text);

  @override
  void dispose() => editor.controller.dispose();
}

void main() {
  runForgeUndoConformance('TomSpecs file editor', _SpecFileSubject.new);
}
