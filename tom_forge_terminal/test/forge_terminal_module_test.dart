// The terminal module tells an application where its terminals go: the
// panel shell makes its terminal tab from the contributed placement.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart';
import 'package:tom_forge_terminal/tom_forge_terminal.dart';

void main() {
  test('the module contributes the terminals\' placement, from which the '
      'shell makes its terminal tab', () {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'Terminal module',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    expect(forgeTerminalSectionsHint(shell.modules), isNull);
    expect(forgeContributedTerminalTab(shell.modules), isNull);

    shell.registerModule(forgeTerminalModule());
    expect(
      forgeTerminalSectionsHint(shell.modules),
      same(forgeTerminalViewPlacement),
    );
    final tab = forgeContributedTerminalTab(shell.modules)!;
    expect(tab.title, 'Terminal');
    expect(tab.icon, Icons.code);
    expect(tab.terminalSections, isTrue);
    expect(tab.sections, isEmpty);
    tab.sections.add(_NoView());
    expect(tab.sections, hasLength(1));
  });
}

/// Stands for a terminal's section: the tab's sections are growable.
class _NoView extends ForgeView {
  @override
  ValueListenable<String> get title => ValueNotifier('t');

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.code;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const SizedBox();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox();
}
