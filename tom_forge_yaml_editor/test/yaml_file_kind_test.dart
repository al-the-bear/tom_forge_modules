/// The YAML file kind: it takes `.yaml` and `.yml` files; its editor, made
/// as a file module makes it, saves an edit in place, and a file changed on
/// disk is not written over until the user keeps theirs.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart' show kYamlEditorDebug;

void main() {
  setUp(() => kYamlEditorDebug = false);

  test('YFK-1: the kind takes YAML files, any case', () {
    expect(forgeYamlFileKind.id, 'yaml');
    expect(forgeYamlFileKind.matches('config.yaml'), isTrue);
    expect(forgeYamlFileKind.matches('CONFIG.YML'), isTrue);
    expect(forgeYamlFileKind.matches('config.json'), isFalse);
  });

  testWidgets('YFK-2: an edit saved in place; a file changed on disk is not '
      'written over until the user keeps theirs', (tester) async {
    final bed = ForgeFileKindTestBed();
    addTearDown(bed.dispose);
    await bed.write('/b.yaml', utf8.encode('b: 1\n'));
    final editor = bed.open<ForgeYamlFileEditor>(forgeYamlFileKind, '/b.yaml');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Builder(builder: editor.buildMain)),
      ),
    );
    await tester.pumpAndSettle();
    editor.controller.textMode = true;
    editor.controller.editSource(
      'b: 2\n',
      const TextSelection.collapsed(offset: 4),
    );
    await bed.write('/b.yaml', utf8.encode('b: 3\n'));
    await tester.pumpAndSettle();
    expect(editor.executeAction(StandardEditingActions.saveActionId), isTrue);
    await tester.pumpAndSettle();
    expect(utf8.decode(await bed.read('/b.yaml')), 'b: 3\n');
    expect(find.byKey(const Key('forge-file-changed-on-disk')), findsOneWidget);
    expect(editor.isDirty.value, isTrue);
    await tester.tap(find.text('Keep mine'));
    await tester.pumpAndSettle();
    expect(editor.executeAction(StandardEditingActions.saveActionId), isTrue);
    await tester.pumpAndSettle();
    expect(utf8.decode(await bed.read('/b.yaml')), 'b: 2\n');
    expect(editor.isDirty.value, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });
}
