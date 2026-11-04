/// A release build tree-shakes the icon fonts, and refuses an `IconData` made
/// at run time ("Avoid non-constant invocations of IconData"). A restored
/// user-created tab is given the picker's icon with its stored code point
/// instead of a rebuilt one, and no library file of this package makes an
/// `IconData` at run time — the build of every app on Forge failed on the one
/// that did.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

void main() {
  test('ICON-1: a stored picker icon comes back, anything else is the '
      'picker\'s default', () {
    expect(forgeUserTabIcon(Icons.language.codePoint), Icons.language);
    expect(forgeUserTabIcon(Icons.bookmark_outlined.codePoint),
        Icons.bookmark_outlined);
    expect(forgeUserTabIcon(-1), Icons.folder_outlined);
  });

  test('ICON-2: no library file makes an IconData at run time', () {
    final made = RegExp(r'(?<!const\s)\bIconData\(');
    final found = <String>[
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          for (final (i, line) in file.readAsLinesSync().indexed)
            if (!line.trimLeft().startsWith('//') && made.hasMatch(line))
              '${file.path}:${i + 1}: ${line.trim()}',
    ];
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
