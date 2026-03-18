import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';

import '../theme/md_editor_theme.dart';

/// Shared syntax-highlighting helpers used by both preview and edit overlays.
class MdCodeHighlighting {
  MdCodeHighlighting._();

  static const Map<String, String> _languageAliases = {
    'js': 'javascript',
    'ts': 'typescript',
    'py': 'python',
    'yml': 'yaml',
    'sh': 'bash',
    'shell': 'bash',
    'zsh': 'bash',
    'c++': 'cpp',
  };

  static String? normalizeLanguage(String? language) {
    if (language == null) return null;
    final normalized = language.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return _languageAliases[normalized] ?? normalized;
  }

  static bool isDarkCodeTheme(MdBasicTheme basic) {
    return basic.codeBackground.computeLuminance() < 0.5;
  }

  static Map<String, TextStyle> buildTheme(MdBasicTheme basic) {
    final isDark = isDarkCodeTheme(basic);
    final base = isDark ? atomOneDarkTheme : githubTheme;

    final attr = isDark
        ? const Color(0xFF7DCFFF)
        : const Color(0xFF005CC5);
    final string = isDark
        ? const Color(0xFF98C379)
        : const Color(0xFF116329);
    final number = isDark
        ? const Color(0xFFD19A66)
        : const Color(0xFF9A6700);
    final literal = isDark
        ? const Color(0xFF56B6C2)
        : const Color(0xFF1B7F83);
    final keyword = isDark
        ? const Color(0xFFC678DD)
        : const Color(0xFF6F42C1);
    final comment = isDark
        ? const Color(0xFF7F848E)
        : const Color(0xFF6A737D);

    return {
      ...base,
      'root': TextStyle(
        color: basic.text,
        backgroundColor: Colors.transparent,
        fontFamily: basic.monoFontFamily,
        fontSize: basic.baseFontSize * 0.9,
        height: basic.lineHeight,
      ),
      'attr': TextStyle(color: attr, fontWeight: FontWeight.w600),
      'attribute': TextStyle(color: attr, fontWeight: FontWeight.w600),
      'string': TextStyle(color: string),
      'subst': TextStyle(color: string),
      'number': TextStyle(color: number),
      'literal': TextStyle(color: literal, fontWeight: FontWeight.w600),
      'keyword': TextStyle(color: keyword, fontWeight: FontWeight.w600),
      'built_in': TextStyle(color: keyword),
      'type': TextStyle(color: keyword),
      'comment': TextStyle(color: comment, fontStyle: FontStyle.italic),
      'quote': TextStyle(color: comment, fontStyle: FontStyle.italic),
      // YAML/JSON tend to use symbol-like tokens for punctuation and sometimes
      // scalar variants; keep them away from attr color to improve readability.
      'symbol': TextStyle(color: number),
      'bullet': TextStyle(color: number),
    };
  }
}