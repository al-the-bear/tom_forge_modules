import 'dart:async';

import 'package:flutter/services.dart';

/// Puts a secret on the clipboard so that it is cleared again: Forge's
/// clipboard is text only, so the secret is written as text and taken off
/// after [clearAfter] — unless something else was copied in between.
abstract interface class ForgeProtectedClipboard {
  Future<void> copy(String value);
}

/// The system clipboard, cleared after [clearAfter].
class ForgeSystemProtectedClipboard implements ForgeProtectedClipboard {
  ForgeSystemProtectedClipboard({this.clearAfter = const Duration(seconds: 30)});

  final Duration clearAfter;
  Timer? _clear;

  @override
  Future<void> copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _clear?.cancel();
    _clear = Timer(clearAfter, () async {
      final now = await Clipboard.getData(Clipboard.kTextPlain);
      if (now?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }
}
