import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../services/forge_clipboard.dart';

/// Default implementation of [ForgeClipboard].
///
/// Wraps Flutter's [Clipboard] service.
class DefaultClipboard implements ForgeClipboard {
  @override
  Future<String> readText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text ?? '';
  }

  @override
  Future<void> writeText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
