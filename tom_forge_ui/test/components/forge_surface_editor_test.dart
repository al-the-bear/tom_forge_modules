/// A surface: a middle-panel component that is not bound to a document
/// (`tom_ai/forge_modules/_agent_guidelines/editor_component_contract.md` §3).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

class _Queue extends ForgeSurfaceEditor {
  @override
  final Uri uri = Uri(scheme: 'agent', host: 'chat', path: '/queue');

  @override
  final ValueListenable<String> title = ValueNotifier('Queue');

  @override
  final ValueListenable<String?> titleExtension = ValueNotifier(null);

  @override
  IconData get icon => Icons.list;

  @override
  Widget buildMain(BuildContext context) => const Text('queue');

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

void main() {
  test('SURF-1: a surface declines every file, so no document is routed '
      'into it', () {
    final surface = _Queue();
    for (final uri in [
      Uri.file('/ws/notes.md'),
      Uri.file('/ws/pubspec.yaml'),
      surface.uri,
    ]) {
      expect(surface.canHandle(uri), FileHandlingResult.reject);
    }
  });

  test('SURF-2: a surface is never dirty and has nothing to save', () {
    final surface = _Queue();
    expect(surface.isDirty.value, isFalse);
    surface.markClean();
    expect(surface.isDirty.value, isFalse);
    expect(surface.getContent(), isNull);
    expect(surface.isEditor, isTrue, reason: 'it goes in a middle split');
    expect(
      surface.sizeHints.preferredSize,
      const ForgeComponentSizeHints().preferredSize,
    );
  });
}
