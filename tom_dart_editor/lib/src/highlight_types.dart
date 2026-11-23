/// The highlight kinds of the Dart editor, the tokens and bracket pairs a
/// Dart highlighter yields, and how the kinds map to the token classes of
/// `tom_text_highlight` (highlight.js class names and dotted refinements).
library;

import 'package:flutter/material.dart';
import 'package:tom_text_highlight/tom_text_highlight.dart' show HighlightToken;

/// Token types for syntax highlighting.
enum HighlightType {
  plain,
  keyword,
  builtInKeyword,
  controlKeyword, // if, else, for, while, etc.
  string,
  number,
  comment,
  operator,
  punctuation,
  // Bracket types with depth for rainbow coloring
  bracket0,
  bracket1,
  bracket2,
  bracket3,
  bracket4,
  bracket5,
  // Semantic types
  type,
  className,
  function,
  methodCall,
  variable,
  parameter,
  property,
  constant,
  annotation,
  // Special
  thisKeyword,
  boolLiteral,
  nullLiteral,
}

/// A Dart highlight token: a kind ([HighlightType]) and its place.
///
/// Named apart from `tom_text_highlight`'s `HighlightToken` (a token class
/// name with `[start, end)`), which every highlighter the editor takes
/// yields; [dartHighlightClass] maps a kind to its class.
class DartHighlightToken {
  final HighlightType type;
  final int offset;
  final int length;

  const DartHighlightToken({
    required this.type,
    required this.offset,
    required this.length,
  });

  int get end => offset + length;

  @override
  String toString() => 'DartHighlightToken($type, $offset-$end)';
}

/// Bracket pair for matching bracket highlighting.
class BracketPair {
  final int openOffset;
  final int closeOffset;
  final String type; // '()', '[]', '{}'

  const BracketPair({
    required this.openOffset,
    required this.closeOffset,
    required this.type,
  });
}

/// Builds TextSpans with syntax highlighting.
class HighlightedTextBuilder {
  final String code;
  final List<DartHighlightToken> tokens;
  final DartHighlightTheme theme;
  final int? matchingBracketOffset;

  HighlightedTextBuilder({
    required this.code,
    required this.tokens,
    required this.theme,
    this.matchingBracketOffset,
  });

  List<TextSpan> build() {
    if (code.isEmpty) return [];
    if (tokens.isEmpty) {
      return [TextSpan(text: code, style: theme.plainStyle)];
    }

    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final token in tokens) {
      if (token.offset >= code.length) continue;
      final tokenEnd = token.end.clamp(0, code.length);
      final tokenStart = token.offset.clamp(0, code.length);

      // Add plain text before this token
      if (tokenStart > lastEnd) {
        spans.add(
          TextSpan(
            text: code.substring(lastEnd, tokenStart),
            style: theme.plainStyle,
          ),
        );
      }

      // Add highlighted token
      if (tokenEnd > tokenStart) {
        var style = theme.styleFor(token.type);

        // Highlight matching bracket with background
        if (matchingBracketOffset != null &&
            (token.offset == matchingBracketOffset ||
                token.offset == matchingBracketOffset)) {
          style = style.copyWith(
            backgroundColor: theme.matchingBracketBackground,
          );
        }

        spans.add(
          TextSpan(text: code.substring(tokenStart, tokenEnd), style: style),
        );
      }

      lastEnd = tokenEnd;
    }

    // Add remaining plain text
    if (lastEnd < code.length) {
      spans.add(
        TextSpan(text: code.substring(lastEnd), style: theme.plainStyle),
      );
    }

    return spans;
  }
}

/// Theme for syntax highlighting colors.
class DartHighlightTheme {
  final TextStyle plainStyle;
  final TextStyle keywordStyle;
  final TextStyle builtInKeywordStyle;
  final TextStyle controlKeywordStyle;
  final TextStyle stringStyle;
  final TextStyle numberStyle;
  final TextStyle commentStyle;
  final TextStyle operatorStyle;
  final TextStyle punctuationStyle;
  final TextStyle typeStyle;
  final TextStyle classNameStyle;
  final TextStyle functionStyle;
  final TextStyle methodCallStyle;
  final TextStyle variableStyle;
  final TextStyle parameterStyle;
  final TextStyle propertyStyle;
  final TextStyle constantStyle;
  final TextStyle annotationStyle;
  final TextStyle thisKeywordStyle;
  final TextStyle boolLiteralStyle;
  final TextStyle nullLiteralStyle;
  // Rainbow bracket colors
  final TextStyle bracket0Style;
  final TextStyle bracket1Style;
  final TextStyle bracket2Style;
  final TextStyle bracket3Style;
  final TextStyle bracket4Style;
  final TextStyle bracket5Style;
  // Matching bracket highlight
  final Color matchingBracketBackground;

  const DartHighlightTheme({
    required this.plainStyle,
    required this.keywordStyle,
    required this.builtInKeywordStyle,
    required this.controlKeywordStyle,
    required this.stringStyle,
    required this.numberStyle,
    required this.commentStyle,
    required this.operatorStyle,
    required this.punctuationStyle,
    required this.typeStyle,
    required this.classNameStyle,
    required this.functionStyle,
    required this.methodCallStyle,
    required this.variableStyle,
    required this.parameterStyle,
    required this.propertyStyle,
    required this.constantStyle,
    required this.annotationStyle,
    required this.thisKeywordStyle,
    required this.boolLiteralStyle,
    required this.nullLiteralStyle,
    required this.bracket0Style,
    required this.bracket1Style,
    required this.bracket2Style,
    required this.bracket3Style,
    required this.bracket4Style,
    required this.bracket5Style,
    required this.matchingBracketBackground,
  });

  /// Creates a dark theme with vibrant colors.
  factory DartHighlightTheme.dark({double fontSize = 14.0}) {
    const fontFamily = 'JetBrains Mono, Menlo, Monaco, monospace';
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 1.5,
    );

    return DartHighlightTheme(
      plainStyle: baseStyle.copyWith(color: const Color(0xFFD4D4D4)),
      keywordStyle: baseStyle.copyWith(
        color: const Color(0xFFC586C0), // Purple/magenta for keywords
        fontWeight: FontWeight.w500,
      ),
      builtInKeywordStyle: baseStyle.copyWith(
        color: const Color(0xFF569CD6), // Blue
      ),
      controlKeywordStyle: baseStyle.copyWith(
        color: const Color(0xFFC586C0), // Purple for control flow
        fontWeight: FontWeight.w500,
      ),
      stringStyle: baseStyle.copyWith(color: const Color(0xFFCE9178)), // Orange
      numberStyle: baseStyle.copyWith(
        color: const Color(0xFFB5CEA8),
      ), // Light green
      commentStyle: baseStyle.copyWith(
        color: const Color(0xFF6A9955), // Green
        fontStyle: FontStyle.italic,
      ),
      operatorStyle: baseStyle.copyWith(color: const Color(0xFFD4D4D4)),
      punctuationStyle: baseStyle.copyWith(color: const Color(0xFFD4D4D4)),
      typeStyle: baseStyle.copyWith(color: const Color(0xFF4EC9B0)), // Teal
      classNameStyle: baseStyle.copyWith(
        color: const Color(0xFF4EC9B0), // Teal
        fontWeight: FontWeight.w500,
      ),
      functionStyle: baseStyle.copyWith(
        color: const Color(0xFFDCDCAA),
      ), // Yellow
      methodCallStyle: baseStyle.copyWith(
        color: const Color(0xFFDCDCAA),
      ), // Yellow
      variableStyle: baseStyle.copyWith(
        color: const Color(0xFF9CDCFE),
      ), // Light blue
      parameterStyle: baseStyle.copyWith(
        color: const Color(0xFF9CDCFE),
      ), // Light blue
      propertyStyle: baseStyle.copyWith(
        color: const Color(0xFF9CDCFE),
      ), // Light blue
      constantStyle: baseStyle.copyWith(
        color: const Color(0xFF4FC1FF),
      ), // Bright blue
      annotationStyle: baseStyle.copyWith(
        color: const Color(0xFFDCDCAA),
      ), // Yellow
      thisKeywordStyle: baseStyle.copyWith(
        color: const Color(0xFF569CD6), // Blue
        fontWeight: FontWeight.w500,
      ),
      boolLiteralStyle: baseStyle.copyWith(
        color: const Color(0xFF569CD6), // Blue
        fontWeight: FontWeight.w500,
      ),
      nullLiteralStyle: baseStyle.copyWith(
        color: const Color(0xFF569CD6), // Blue
        fontWeight: FontWeight.w500,
      ),
      // Rainbow brackets - vibrant colors
      bracket0Style: baseStyle.copyWith(color: const Color(0xFFFFD700)), // Gold
      bracket1Style: baseStyle.copyWith(
        color: const Color(0xFFDA70D6),
      ), // Orchid
      bracket2Style: baseStyle.copyWith(
        color: const Color(0xFF87CEEB),
      ), // Sky blue
      bracket3Style: baseStyle.copyWith(
        color: const Color(0xFF98FB98),
      ), // Pale green
      bracket4Style: baseStyle.copyWith(
        color: const Color(0xFFFF6B6B),
      ), // Coral
      bracket5Style: baseStyle.copyWith(
        color: const Color(0xFFFFB347),
      ), // Orange
      matchingBracketBackground: const Color(0xFF3A5A3A), // Green tint
    );
  }

  /// Creates a light theme.
  factory DartHighlightTheme.light({double fontSize = 14.0}) {
    const fontFamily = 'JetBrains Mono, Menlo, Monaco, monospace';
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 1.5,
    );

    return DartHighlightTheme(
      plainStyle: baseStyle.copyWith(color: const Color(0xFF1E1E1E)),
      keywordStyle: baseStyle.copyWith(
        color: const Color(0xFFAF00DB), // Purple
        fontWeight: FontWeight.w500,
      ),
      builtInKeywordStyle: baseStyle.copyWith(color: const Color(0xFF0000FF)),
      controlKeywordStyle: baseStyle.copyWith(
        color: const Color(0xFFAF00DB),
        fontWeight: FontWeight.w500,
      ),
      stringStyle: baseStyle.copyWith(color: const Color(0xFFA31515)),
      numberStyle: baseStyle.copyWith(color: const Color(0xFF098658)),
      commentStyle: baseStyle.copyWith(
        color: const Color(0xFF008000),
        fontStyle: FontStyle.italic,
      ),
      operatorStyle: baseStyle.copyWith(color: const Color(0xFF1E1E1E)),
      punctuationStyle: baseStyle.copyWith(color: const Color(0xFF1E1E1E)),
      typeStyle: baseStyle.copyWith(color: const Color(0xFF267F99)),
      classNameStyle: baseStyle.copyWith(
        color: const Color(0xFF267F99),
        fontWeight: FontWeight.w500,
      ),
      functionStyle: baseStyle.copyWith(color: const Color(0xFF795E26)),
      methodCallStyle: baseStyle.copyWith(color: const Color(0xFF795E26)),
      variableStyle: baseStyle.copyWith(color: const Color(0xFF001080)),
      parameterStyle: baseStyle.copyWith(color: const Color(0xFF001080)),
      propertyStyle: baseStyle.copyWith(color: const Color(0xFF001080)),
      constantStyle: baseStyle.copyWith(color: const Color(0xFF0070C1)),
      annotationStyle: baseStyle.copyWith(color: const Color(0xFF795E26)),
      thisKeywordStyle: baseStyle.copyWith(
        color: const Color(0xFF0000FF),
        fontWeight: FontWeight.w500,
      ),
      boolLiteralStyle: baseStyle.copyWith(
        color: const Color(0xFF0000FF),
        fontWeight: FontWeight.w500,
      ),
      nullLiteralStyle: baseStyle.copyWith(
        color: const Color(0xFF0000FF),
        fontWeight: FontWeight.w500,
      ),
      // Rainbow brackets
      bracket0Style: baseStyle.copyWith(
        color: const Color(0xFFB8860B),
      ), // Dark goldenrod
      bracket1Style: baseStyle.copyWith(
        color: const Color(0xFF9932CC),
      ), // Dark orchid
      bracket2Style: baseStyle.copyWith(
        color: const Color(0xFF4682B4),
      ), // Steel blue
      bracket3Style: baseStyle.copyWith(
        color: const Color(0xFF228B22),
      ), // Forest green
      bracket4Style: baseStyle.copyWith(
        color: const Color(0xFFDC143C),
      ), // Crimson
      bracket5Style: baseStyle.copyWith(
        color: const Color(0xFFFF8C00),
      ), // Dark orange
      matchingBracketBackground: const Color(0xFFE8F5E9), // Light green
    );
  }

  /// Gets the style for a highlight type.
  TextStyle styleFor(HighlightType type) {
    return switch (type) {
      HighlightType.keyword => keywordStyle,
      HighlightType.builtInKeyword => builtInKeywordStyle,
      HighlightType.controlKeyword => controlKeywordStyle,
      HighlightType.string => stringStyle,
      HighlightType.number => numberStyle,
      HighlightType.comment => commentStyle,
      HighlightType.operator => operatorStyle,
      HighlightType.punctuation => punctuationStyle,
      HighlightType.type => typeStyle,
      HighlightType.className => classNameStyle,
      HighlightType.function => functionStyle,
      HighlightType.methodCall => methodCallStyle,
      HighlightType.variable => variableStyle,
      HighlightType.parameter => parameterStyle,
      HighlightType.property => propertyStyle,
      HighlightType.constant => constantStyle,
      HighlightType.annotation => annotationStyle,
      HighlightType.thisKeyword => thisKeywordStyle,
      HighlightType.boolLiteral => boolLiteralStyle,
      HighlightType.nullLiteral => nullLiteralStyle,
      HighlightType.bracket0 => bracket0Style,
      HighlightType.bracket1 => bracket1Style,
      HighlightType.bracket2 => bracket2Style,
      HighlightType.bracket3 => bracket3Style,
      HighlightType.bracket4 => bracket4Style,
      HighlightType.bracket5 => bracket5Style,
      HighlightType.plain => plainStyle,
    };
  }
}

/// The token class of [type], as the editor's highlighters yield it: a
/// highlight.js class name or a dotted refinement of one, so a theme that
/// knows only the class (`keyword`, `punctuation`) styles the refinement too.
/// Null for [HighlightType.plain], which has no class: its text keeps the
/// plain style.
String? dartHighlightClass(HighlightType type) => switch (type) {
      HighlightType.plain => null,
      HighlightType.keyword => 'keyword',
      HighlightType.builtInKeyword => 'keyword.builtin',
      HighlightType.controlKeyword => 'keyword.control',
      HighlightType.string => 'string',
      HighlightType.number => 'number',
      HighlightType.comment => 'comment',
      HighlightType.operator => 'operator',
      HighlightType.punctuation => 'punctuation',
      HighlightType.bracket0 => 'punctuation.bracket.0',
      HighlightType.bracket1 => 'punctuation.bracket.1',
      HighlightType.bracket2 => 'punctuation.bracket.2',
      HighlightType.bracket3 => 'punctuation.bracket.3',
      HighlightType.bracket4 => 'punctuation.bracket.4',
      HighlightType.bracket5 => 'punctuation.bracket.5',
      HighlightType.type => 'type',
      HighlightType.className => 'title.class',
      HighlightType.function => 'title.function',
      HighlightType.methodCall => 'title.function.invoke',
      HighlightType.variable => 'variable',
      HighlightType.parameter => 'params',
      HighlightType.property => 'property',
      HighlightType.constant => 'variable.constant',
      HighlightType.annotation => 'meta',
      HighlightType.thisKeyword => 'variable.language',
      HighlightType.boolLiteral => 'literal.boolean',
      HighlightType.nullLiteral => 'literal.null',
    };

/// The prefix of the bracket token classes: `punctuation.bracket.<depth>`,
/// the depth of rainbow brackets modulo 6.
const String dartBracketClassPrefix = 'punctuation.bracket';

/// The bracket depth (0 to 5) of a bracket token class, else null.
int? dartBracketDepthOfClass(String type) {
  if (!type.startsWith('$dartBracketClassPrefix.')) return null;
  return int.tryParse(type.substring(dartBracketClassPrefix.length + 1));
}

/// The bracket pairs of [source] from a highlighter's bracket tokens
/// (classes starting with [dartBracketClassPrefix]): each `(`, `[` or `{`
/// paired with the next unpaired closing bracket of its kind; a closing
/// bracket without an opening one is left out.
List<BracketPair> bracketPairsOf(
  String source,
  Iterable<HighlightToken> tokens,
) {
  final pairs = <BracketPair>[];
  final stacks = <String, List<int>>{'()': [], '[]': [], '{}': []};
  for (final token in tokens) {
    if (!token.type.startsWith(dartBracketClassPrefix)) continue;
    if (token.end != token.start + 1 || token.start >= source.length) {
      continue;
    }
    final char = source[token.start];
    final kind = switch (char) {
      '(' || ')' => '()',
      '[' || ']' => '[]',
      '{' || '}' => '{}',
      _ => null,
    };
    if (kind == null) continue;
    final stack = stacks[kind]!;
    if (char == kind[0]) {
      stack.add(token.start);
    } else if (stack.isNotEmpty) {
      pairs.add(
        BracketPair(
          openOffset: stack.removeLast(),
          closeOffset: token.start,
          type: kind,
        ),
      );
    }
  }
  return pairs;
}
