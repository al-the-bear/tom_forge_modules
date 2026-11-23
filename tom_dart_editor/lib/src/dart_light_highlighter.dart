/// The Dart editor's light highlighter: lexical, without the analyzer.
library;

import 'package:tom_text_highlight/tom_text_highlight.dart';

import 'highlight_types.dart';

/// A lexical Dart highlighter of our own: keywords, strings with their
/// interpolations, numbers, comments, annotations and rainbow brackets,
/// found by scanning the text — no parser, no analyzer.
///
/// It is the `DartCodeEditor`'s highlighter when none is given; the
/// analyzer-based one with its semantic pass is `tom_dart_analysis`'s
/// `DartSyntaxHighlighter`. Its token classes (highlight.js class names and
/// dotted refinements, the classes [dartHighlightClass] gives the editor's
/// kinds):
///
/// | Class | What |
/// | --- | --- |
/// | `keyword`, `keyword.control`, `keyword.builtin` | reserved words; control flow (`if`, `return`, `await`, ...); built-in identifiers (`import`, `late`, `required`, ...) |
/// | `variable.language` | `this` |
/// | `literal.boolean`, `literal.null` | `true`, `false`; `null` |
/// | `string` | a string literal, raw or not, single or triple quoted, without its interpolations |
/// | `subst` | an interpolation: `$name`, and the `${` and `}` around an interpolated expression (the expression inside is highlighted as code) |
/// | `number` | an integer, double or hexadecimal literal |
/// | `comment`, `comment.doc` | `//` and `/* */` (nested); `///` and `/** */` |
/// | `meta` | an annotation: `@` with its (dotted) name |
/// | `type` | a name starting with an upper-case letter, and `int`, `double`, `num`, `bool` |
/// | `operator`, `punctuation` | operators; `; , . : #` |
/// | `punctuation.bracket.<n>` | `( ) [ ] { }`, `<n>` the nesting depth modulo 6 |
///
/// The tokens are in order and never overlap. An unterminated string ends at
/// its line's end (a triple-quoted one at the text's end), an unterminated
/// block comment at the text's end.
class DartLightHighlighter extends TokenHighlighter {
  DartLightHighlighter({super.theme});

  /// Reserved words and other keywords without a class of their own.
  static const Set<String> keywords = {
    'async',
    'class',
    'const',
    'enum',
    'extends',
    'final',
    'in',
    'is',
    'new',
    'sealed',
    'super',
    'sync',
    'var',
    'void',
    'when',
    'with',
  };

  /// Control-flow keywords (`keyword.control`).
  static const Set<String> controlKeywords = {
    'if',
    'else',
    'for',
    'while',
    'do',
    'switch',
    'case',
    'default',
    'break',
    'continue',
    'return',
    'throw',
    'try',
    'catch',
    'finally',
    'rethrow',
    'assert',
    'yield',
    'await',
  };

  /// Built-in identifiers (`keyword.builtin`).
  static const Set<String> builtInKeywords = {
    'abstract',
    'as',
    'covariant',
    'deferred',
    'dynamic',
    'export',
    'extension',
    'external',
    'factory',
    'Function',
    'get',
    'implements',
    'import',
    'interface',
    'late',
    'library',
    'mixin',
    'operator',
    'part',
    'required',
    'set',
    'static',
    'typedef',
    'on',
    'show',
    'hide',
  };

  /// Lower-case names of core types, highlighted as `type`.
  static const Set<String> coreTypes = {'int', 'double', 'num', 'bool'};

  static const String _operatorChars = '+-*/%=<>!&|^~?';
  static const String _punctuationChars = ';,.:#';

  @override
  List<HighlightToken> tokenize(String source) {
    final scan = _Scan(source);
    scan.code(0, untilBrace: false);
    return scan.tokens;
  }
}

/// One scan of a source: its tokens and the bracket depth.
class _Scan {
  _Scan(this.s);

  final String s;
  final List<HighlightToken> tokens = [];
  int depth = 0;

  void add(int start, int end, String type) {
    if (end > start) tokens.add(HighlightToken(start, end, type));
  }

  /// Scans code from [i]; with [untilBrace], stops at the `}` that closes an
  /// interpolation (`${...}`) and answers its offset, else the text's end.
  int code(int i, {required bool untilBrace}) {
    var braces = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        i++;
      } else if (c == '/' && _at(i + 1, '/')) {
        final nl = s.indexOf('\n', i);
        final end = nl < 0 ? s.length : nl;
        final doc = _at(i + 2, '/') && !_at(i + 3, '/');
        add(i, end, doc ? 'comment.doc' : 'comment');
        i = end;
      } else if (c == '/' && _at(i + 1, '*')) {
        i = _blockComment(i);
      } else if (c == "'" || c == '"') {
        i = _string(i, raw: false);
      } else if (c == '@') {
        i = _annotation(i);
      } else if (_isDigit(c) ||
          (c == '.' && _isDigitAt(i + 1) && !_isIdentPartAt(i - 1))) {
        i = _number(i);
      } else if (_isIdentStart(c)) {
        var j = i + 1;
        while (j < s.length && _isIdentPart(s[j])) {
          j++;
        }
        final word = s.substring(i, j);
        if (word == 'r' && (_at(j, "'") || _at(j, '"'))) {
          i = _string(i, raw: true);
          continue;
        }
        final type = _wordClass(word);
        if (type != null) add(i, j, type);
        i = j;
      } else if (c == '(' || c == '[' || c == '{') {
        if (c == '{') braces++;
        add(i, i + 1, '$dartBracketClassPrefix.${depth % 6}');
        depth++;
        i++;
      } else if (c == ')' || c == ']' || c == '}') {
        if (c == '}') {
          if (untilBrace && braces == 0) return i;
          if (braces > 0) braces--;
        }
        depth = depth > 0 ? depth - 1 : 0;
        add(i, i + 1, '$dartBracketClassPrefix.${depth % 6}');
        i++;
      } else if (DartLightHighlighter._operatorChars.contains(c)) {
        var j = i + 1;
        while (j < s.length &&
            DartLightHighlighter._operatorChars.contains(s[j]) &&
            !(s[j] == '/' && (_at(j + 1, '/') || _at(j + 1, '*')))) {
          j++;
        }
        add(i, j, 'operator');
        i = j;
      } else if (DartLightHighlighter._punctuationChars.contains(c)) {
        var j = i + 1;
        if (c == '.') {
          while (j < s.length && s[j] == '.' && j < i + 3) {
            j++;
          }
        }
        add(i, j, 'punctuation');
        i = j;
      } else {
        i++;
      }
    }
    return s.length;
  }

  String? _wordClass(String word) {
    if (word == 'this') return 'variable.language';
    if (word == 'true' || word == 'false') return 'literal.boolean';
    if (word == 'null') return 'literal.null';
    if (DartLightHighlighter.controlKeywords.contains(word)) {
      return 'keyword.control';
    }
    if (DartLightHighlighter.builtInKeywords.contains(word)) {
      return 'keyword.builtin';
    }
    if (DartLightHighlighter.keywords.contains(word)) return 'keyword';
    if (DartLightHighlighter.coreTypes.contains(word)) return 'type';
    final first = word.codeUnitAt(0);
    if (first >= 0x41 && first <= 0x5A) return 'type';
    if (word.length > 1 && (first == 0x5F || first == 0x24)) {
      final second = word.codeUnitAt(1);
      if (second >= 0x41 && second <= 0x5A) return 'type';
    }
    return null;
  }

  int _blockComment(int i) {
    final doc = _at(i + 2, '*') && !_at(i + 3, '/') && !_at(i + 3, '*');
    var nesting = 0;
    var j = i;
    while (j < s.length) {
      if (s[j] == '/' && _at(j + 1, '*')) {
        nesting++;
        j += 2;
      } else if (s[j] == '*' && _at(j + 1, '/')) {
        nesting--;
        j += 2;
        if (nesting == 0) break;
      } else {
        j++;
      }
    }
    add(i, j, doc ? 'comment.doc' : 'comment');
    return j;
  }

  /// A string from [i] (its `r` prefix when [raw]); answers its end.
  int _string(int i, {required bool raw}) {
    final open = raw ? i + 1 : i;
    final quote = s[open];
    final triple = s.startsWith(quote * 3, open);
    final delimiter = triple ? quote * 3 : quote;
    var j = open + delimiter.length;
    var segment = i;
    while (j < s.length) {
      if (s.startsWith(delimiter, j)) {
        j += delimiter.length;
        add(segment, j, 'string');
        return j;
      }
      final c = s[j];
      if (c == '\n' && !triple) break;
      if (!raw && c == '\\') {
        j += 2;
      } else if (!raw && c == r'$' && _at(j + 1, '{')) {
        add(segment, j, 'string');
        add(j, j + 2, 'subst');
        final close = code(j + 2, untilBrace: true);
        if (close >= s.length) return s.length;
        add(close, close + 1, 'subst');
        j = close + 1;
        segment = j;
      } else if (!raw &&
          c == r'$' &&
          j + 1 < s.length &&
          _isInterpolationStart(s[j + 1])) {
        add(segment, j, 'string');
        var k = j + 2;
        while (k < s.length && _isInterpolationPart(s[k])) {
          k++;
        }
        add(j, k, 'subst');
        j = k;
        segment = j;
      } else {
        j++;
      }
    }
    final end = j > s.length ? s.length : j;
    add(segment, end, 'string');
    return end;
  }

  int _annotation(int i) {
    var j = i + 1;
    while (j < s.length && _isIdentStart(s[j])) {
      j++;
      while (j < s.length && _isIdentPart(s[j])) {
        j++;
      }
      if (_at(j, '.') && j + 1 < s.length && _isIdentStart(s[j + 1])) {
        j++;
      } else {
        break;
      }
    }
    add(i, j, 'meta');
    return j;
  }

  static final RegExp _hex = RegExp(r'0[xX][0-9a-fA-F_]+');
  static final RegExp _decimal = RegExp(
    r'(?:[0-9][0-9_]*)?(?:\.[0-9][0-9_]*)?(?:[eE][+-]?[0-9]+)?',
  );

  int _number(int i) {
    final hex = _hex.matchAsPrefix(s, i);
    var end = hex?.end ?? _decimal.matchAsPrefix(s, i)?.end ?? i;
    if (end <= i) end = i + 1;
    add(i, end, 'number');
    return end;
  }

  bool _at(int i, String c) => i >= 0 && i < s.length && s[i] == c;
  bool _isDigitAt(int i) => i >= 0 && i < s.length && _isDigit(s[i]);
  bool _isIdentPartAt(int i) => i >= 0 && i < s.length && _isIdentPart(s[i]);

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 0x30 && u <= 0x39;
  }

  static bool _isInterpolationStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 0x41 && u <= 0x5A) || (u >= 0x61 && u <= 0x7A) || u == 0x5F;
  }

  static bool _isInterpolationPart(String c) =>
      _isInterpolationStart(c) || _isDigit(c);

  static bool _isIdentStart(String c) => _isInterpolationStart(c) || c == r'$';

  static bool _isIdentPart(String c) => _isIdentStart(c) || _isDigit(c);
}

/// The [HighlighterFallback] that answers `dart` with a
/// [DartLightHighlighter] styled by the given theme.
TokenHighlighter? dartCodeBlockHighlighter(
  String language,
  HighlightTheme theme,
) =>
    language == 'dart' ? DartLightHighlighter(theme: theme) : null;

/// Makes `tom_text_highlight`'s `highlighterForLanguage('dart')` answer the
/// [DartLightHighlighter] (Markdown code blocks, any source view that looks a
/// language up), by registering [dartCodeBlockHighlighter] as a fallback.
/// Nothing is registered by default; a fallback registered earlier (e.g.
/// `tom_highlight_js`'s, in Tom Forge) is asked first and keeps `dart`.
void registerDartCodeBlockHighlighting() =>
    registerHighlighterFallback(dartCodeBlockHighlighter);

/// Removes what [registerDartCodeBlockHighlighting] registered.
void unregisterDartCodeBlockHighlighting() =>
    unregisterHighlighterFallback(dartCodeBlockHighlighter);
