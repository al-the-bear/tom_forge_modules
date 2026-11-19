/// The integrated UX patterns that no other suite pins
/// (`tom_forge/_agent_guidelines/integrated_ux_patterns.md`).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  test('UX-1: opening a file that is open activates its editor; no second '
      'editor of the document is made', () async {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {'/w/a.txt': 'alpha', '/w/b.txt': 'beta'},
      appName: 'test',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    (shell.modules as DefaultModuleRegistry).register(TomForgeShellModule());
    final a = Uri.file('/w/a.txt'), b = Uri.file('/w/b.txt');

    shell.layout.openFile(a);
    await pumpEventQueue();
    shell.layout.openFile(b);
    await pumpEventQueue();
    expect(shell.systemState.activeEditor?.uri, b);

    shell.layout.openFile(a);
    await pumpEventQueue();
    expect(shell.systemState.activeEditor?.uri, a);
    expect(
      shell.systemState.openEditors.where((e) => e.uri == a),
      hasLength(1),
      reason: 'one document, one editor: a second open focuses it',
    );
    expect(shell.systemState.openEditors, hasLength(2));
  });
}
