/// `ForgeModule.openUri`: a module that owns a kind of document opens it
/// itself, before the shell reads the file as text.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

class _ClaimingModule extends ForgeTestModule {
  final opened = <Uri>[];

  @override
  bool openUri(Uri uri, {int? middlePanelIndex}) {
    if (!uri.path.endsWith('.bundle')) return false;
    opened.add(uri);
    return true;
  }
}

void main() {
  test('a claiming module opens its own documents; others pass through', () {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {'/w/notes.txt': 'hello'},
      appName: 'test',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final module = _ClaimingModule();
    (shell.modules as DefaultModuleRegistry).register(module);

    // Not in the file system at all: the text read would fail, so reaching
    // the module proves it was asked first.
    final bundle = Uri.file('/w/doc.bundle');
    shell.layout.openFile(bundle);
    expect(module.opened, [bundle]);

    shell.layout.openFile(Uri.file('/w/notes.txt'));
    expect(module.opened, [bundle], reason: 'an ordinary file is not claimed');
  });

  test('openFileWith asks the module first as well', () async {
    final shell = DefaultShellApi.withDefaults(
      fileSystemSeed: const {},
      appName: 'test',
      navigatorKey: GlobalKey<NavigatorState>(),
    );
    final module = _ClaimingModule();
    (shell.modules as DefaultModuleRegistry).register(module);
    await shell.layout.openFileWith(Uri.file('/w/other.bundle'));
    expect(module.opened.single.path, '/w/other.bundle');
  });

  test('a module claims nothing by default', () {
    expect(ForgeTestModule().openUri(Uri.file('/w/doc.bundle')), isFalse);
  });
}
