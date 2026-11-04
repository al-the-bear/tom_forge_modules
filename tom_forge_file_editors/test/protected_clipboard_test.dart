import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_file_editors/tom_forge_file_editors.dart';

void main() {
  testWidgets('PC-1: a copied secret is cleared after the timeout, unless '
      'something else was copied', (tester) async {
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map)['text'] as String?;
        } else if (call.method == 'Clipboard.getData') {
          return {'text': clip};
        }
        return null;
      },
    );
    final clipboard = ForgeSystemProtectedClipboard(
      clearAfter: const Duration(seconds: 5),
    );
    await clipboard.copy('secret');
    expect(clip, 'secret');
    await tester.pump(const Duration(seconds: 6));
    expect(clip, '');

    await clipboard.copy('secret');
    clip = 'something else';
    await tester.pump(const Duration(seconds: 6));
    expect(clip, 'something else');
  });
}
