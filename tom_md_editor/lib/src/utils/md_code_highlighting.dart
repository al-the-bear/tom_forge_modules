import 'package:flutter/material.dart';
import 'package:tom_text_highlight/tom_text_highlight.dart';

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
    final base = isDark ? _atomOneDarkTheme : _githubTheme;

    final attr = isDark ? const Color(0xFF7DCFFF) : const Color(0xFF005CC5);
    final string = isDark ? const Color(0xFF98C379) : const Color(0xFF116329);
    final number = isDark ? const Color(0xFFD19A66) : const Color(0xFF9A6700);
    final literal = isDark ? const Color(0xFF56B6C2) : const Color(0xFF1B7F83);
    final keyword = isDark ? const Color(0xFFC678DD) : const Color(0xFF6F42C1);
    final comment = isDark ? const Color(0xFF7F848E) : const Color(0xFF6A737D);

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

  /// A highlighter for [language] (a name or alias) styled for [basic], or
  /// null when `tom_text_highlight` does not highlight the language: YAML,
  /// Markdown, JSON, shell and `.env` are highlighted, any other language is
  /// shown plain.
  static TokenHighlighter? highlighterFor(
    String? language,
    MdBasicTheme basic,
  ) => highlighterForLanguage(
    normalizeLanguage(language),
    theme: HighlightTheme(buildTheme(basic)),
  );
}

// The base colour maps the code-block theme starts from: highlight.js's
// GitHub and Atom One Dark themes as the flutter_highlight package 0.7.0
// ships them (MIT License, Copyright (c) 2019 Rongjian Zhang), kept here so
// the code blocks keep their colours without that package.

const Map<String, TextStyle> _githubTheme = {
  'root': TextStyle(
    color: Color(0xff333333),
    backgroundColor: Color(0xfff8f8f8),
  ),
  'comment': TextStyle(color: Color(0xff999988), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xff999988), fontStyle: FontStyle.italic),
  'keyword': TextStyle(color: Color(0xff333333), fontWeight: FontWeight.bold),
  'selector-tag': TextStyle(
    color: Color(0xff333333),
    fontWeight: FontWeight.bold,
  ),
  'subst': TextStyle(color: Color(0xff333333), fontWeight: FontWeight.normal),
  'number': TextStyle(color: Color(0xff008080)),
  'literal': TextStyle(color: Color(0xff008080)),
  'variable': TextStyle(color: Color(0xff008080)),
  'template-variable': TextStyle(color: Color(0xff008080)),
  'string': TextStyle(color: Color(0xffdd1144)),
  'doctag': TextStyle(color: Color(0xffdd1144)),
  'title': TextStyle(color: Color(0xff990000), fontWeight: FontWeight.bold),
  'section': TextStyle(color: Color(0xff990000), fontWeight: FontWeight.bold),
  'selector-id': TextStyle(
    color: Color(0xff990000),
    fontWeight: FontWeight.bold,
  ),
  'type': TextStyle(color: Color(0xff445588), fontWeight: FontWeight.bold),
  'tag': TextStyle(color: Color(0xff000080), fontWeight: FontWeight.normal),
  'name': TextStyle(color: Color(0xff000080), fontWeight: FontWeight.normal),
  'attribute': TextStyle(
    color: Color(0xff000080),
    fontWeight: FontWeight.normal,
  ),
  'regexp': TextStyle(color: Color(0xff009926)),
  'link': TextStyle(color: Color(0xff009926)),
  'symbol': TextStyle(color: Color(0xff990073)),
  'bullet': TextStyle(color: Color(0xff990073)),
  'built_in': TextStyle(color: Color(0xff0086b3)),
  'builtin-name': TextStyle(color: Color(0xff0086b3)),
  'meta': TextStyle(color: Color(0xff999999), fontWeight: FontWeight.bold),
  'deletion': TextStyle(backgroundColor: Color(0xffffdddd)),
  'addition': TextStyle(backgroundColor: Color(0xffddffdd)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
};

const Map<String, TextStyle> _atomOneDarkTheme = {
  'root': TextStyle(
    color: Color(0xffabb2bf),
    backgroundColor: Color(0xff282c34),
  ),
  'comment': TextStyle(color: Color(0xff5c6370), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xff5c6370), fontStyle: FontStyle.italic),
  'doctag': TextStyle(color: Color(0xffc678dd)),
  'keyword': TextStyle(color: Color(0xffc678dd)),
  'formula': TextStyle(color: Color(0xffc678dd)),
  'section': TextStyle(color: Color(0xffe06c75)),
  'name': TextStyle(color: Color(0xffe06c75)),
  'selector-tag': TextStyle(color: Color(0xffe06c75)),
  'deletion': TextStyle(color: Color(0xffe06c75)),
  'subst': TextStyle(color: Color(0xffe06c75)),
  'literal': TextStyle(color: Color(0xff56b6c2)),
  'string': TextStyle(color: Color(0xff98c379)),
  'regexp': TextStyle(color: Color(0xff98c379)),
  'addition': TextStyle(color: Color(0xff98c379)),
  'attribute': TextStyle(color: Color(0xff98c379)),
  'meta-string': TextStyle(color: Color(0xff98c379)),
  'built_in': TextStyle(color: Color(0xffe6c07b)),
  'attr': TextStyle(color: Color(0xffd19a66)),
  'variable': TextStyle(color: Color(0xffd19a66)),
  'template-variable': TextStyle(color: Color(0xffd19a66)),
  'type': TextStyle(color: Color(0xffd19a66)),
  'selector-class': TextStyle(color: Color(0xffd19a66)),
  'selector-attr': TextStyle(color: Color(0xffd19a66)),
  'selector-pseudo': TextStyle(color: Color(0xffd19a66)),
  'number': TextStyle(color: Color(0xffd19a66)),
  'symbol': TextStyle(color: Color(0xff61aeee)),
  'bullet': TextStyle(color: Color(0xff61aeee)),
  'link': TextStyle(color: Color(0xff61aeee)),
  'meta': TextStyle(color: Color(0xff61aeee)),
  'selector-id': TextStyle(color: Color(0xff61aeee)),
  'title': TextStyle(color: Color(0xff61aeee)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
};
