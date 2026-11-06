import 'package:flutter/material.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

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

/// A highlight token with type and position.
class HighlightToken {
  final HighlightType type;
  final int offset;
  final int length;

  const HighlightToken({
    required this.type,
    required this.offset,
    required this.length,
  });

  int get end => offset + length;

  @override
  String toString() => 'HighlightToken($type, $offset-$end)';
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

/// Dart syntax highlighter using the analyzer's scanner and AST.
class DartSyntaxHighlighter {
  /// Tokenizes Dart code and returns highlight tokens.
  static List<HighlightToken> tokenize(String code) {
    if (code.isEmpty) return [];

    final tokens = <HighlightToken>[];
    int bracketDepth = 0;

    try {
      final result = parseString(content: code, throwIfDiagnostics: false);
      var token = result.unit.beginToken;

      // First pass: collect tokens with bracket depth tracking
      while (token.type != TokenType.EOF) {
        // Handle preceding comments
        Token? commentToken = token.precedingComments;
        while (commentToken != null) {
          tokens.add(
            HighlightToken(
              type: HighlightType.comment,
              offset: commentToken.offset,
              length: commentToken.length,
            ),
          );
          commentToken = commentToken.next;
        }

        // Track bracket depth for rainbow brackets
        final tokenType = token.type;
        if (_isOpeningBracket(tokenType)) {
          tokens.add(
            HighlightToken(
              type: _bracketTypeForDepth(bracketDepth),
              offset: token.offset,
              length: token.length,
            ),
          );
          bracketDepth++;
        } else if (_isClosingBracket(tokenType)) {
          bracketDepth = (bracketDepth - 1).clamp(0, 999);
          tokens.add(
            HighlightToken(
              type: _bracketTypeForDepth(bracketDepth),
              offset: token.offset,
              length: token.length,
            ),
          );
        } else {
          // Classify other tokens
          final highlightType = _classifyToken(token);
          if (highlightType != HighlightType.plain ||
              token.type == TokenType.IDENTIFIER) {
            tokens.add(
              HighlightToken(
                type: highlightType,
                offset: token.offset,
                length: token.length,
              ),
            );
          }
        }

        token = token.next!;
      }

      // Handle trailing comments
      Token? trailingComment = token.precedingComments;
      while (trailingComment != null) {
        tokens.add(
          HighlightToken(
            type: HighlightType.comment,
            offset: trailingComment.offset,
            length: trailingComment.length,
          ),
        );
        trailingComment = trailingComment.next;
      }

      // Second pass: AST visitor for semantic highlighting
      final semanticTokens = <HighlightToken>[];
      result.unit.accept(_SemanticHighlightVisitor(semanticTokens));

      // Merge semantic tokens (they override lexical tokens)
      tokens.addAll(semanticTokens);
    } catch (e) {
      debugPrint('Tokenization failed: $e');
    }

    tokens.sort((a, b) => a.offset.compareTo(b.offset));
    return _deduplicateTokens(tokens);
  }

  /// Extract bracket pairs for matching highlight.
  static List<BracketPair> extractBracketPairs(String code) {
    if (code.isEmpty) return [];

    final pairs = <BracketPair>[];
    final stacks = <String, List<int>>{'()': [], '[]': [], '{}': []};

    try {
      final result = parseString(content: code, throwIfDiagnostics: false);
      var token = result.unit.beginToken;

      while (token.type != TokenType.EOF) {
        final type = token.type;
        if (type == TokenType.OPEN_PAREN) {
          stacks['()']!.add(token.offset);
        } else if (type == TokenType.CLOSE_PAREN && stacks['()']!.isNotEmpty) {
          pairs.add(
            BracketPair(
              openOffset: stacks['()']!.removeLast(),
              closeOffset: token.offset,
              type: '()',
            ),
          );
        } else if (type == TokenType.OPEN_SQUARE_BRACKET) {
          stacks['[]']!.add(token.offset);
        } else if (type == TokenType.CLOSE_SQUARE_BRACKET &&
            stacks['[]']!.isNotEmpty) {
          pairs.add(
            BracketPair(
              openOffset: stacks['[]']!.removeLast(),
              closeOffset: token.offset,
              type: '[]',
            ),
          );
        } else if (type == TokenType.OPEN_CURLY_BRACKET) {
          stacks['{}']!.add(token.offset);
        } else if (type == TokenType.CLOSE_CURLY_BRACKET &&
            stacks['{}']!.isNotEmpty) {
          pairs.add(
            BracketPair(
              openOffset: stacks['{}']!.removeLast(),
              closeOffset: token.offset,
              type: '{}',
            ),
          );
        }
        token = token.next!;
      }
    } catch (e) {
      debugPrint('Bracket extraction failed: $e');
    }

    return pairs;
  }

  /// Find the matching bracket for a given cursor position.
  static int? findMatchingBracket(String code, int cursorOffset) {
    final pairs = extractBracketPairs(code);
    for (final pair in pairs) {
      if (pair.openOffset == cursorOffset ||
          pair.openOffset == cursorOffset - 1) {
        return pair.closeOffset;
      }
      if (pair.closeOffset == cursorOffset ||
          pair.closeOffset == cursorOffset - 1) {
        return pair.openOffset;
      }
    }
    return null;
  }

  static List<HighlightToken> _deduplicateTokens(List<HighlightToken> tokens) {
    // Semantic tokens should override lexical tokens at same position
    final Map<int, HighlightToken> tokenMap = {};
    for (final token in tokens) {
      final existing = tokenMap[token.offset];
      if (existing == null || _isSemanticType(token.type)) {
        tokenMap[token.offset] = token;
      }
    }
    final result = tokenMap.values.toList();
    result.sort((a, b) => a.offset.compareTo(b.offset));
    return result;
  }

  static bool _isSemanticType(HighlightType type) {
    return type == HighlightType.className ||
        type == HighlightType.function ||
        type == HighlightType.methodCall ||
        type == HighlightType.variable ||
        type == HighlightType.parameter ||
        type == HighlightType.property ||
        type == HighlightType.constant;
  }

  static bool _isOpeningBracket(TokenType type) {
    return type == TokenType.OPEN_PAREN ||
        type == TokenType.OPEN_SQUARE_BRACKET ||
        type == TokenType.OPEN_CURLY_BRACKET;
  }

  static bool _isClosingBracket(TokenType type) {
    return type == TokenType.CLOSE_PAREN ||
        type == TokenType.CLOSE_SQUARE_BRACKET ||
        type == TokenType.CLOSE_CURLY_BRACKET;
  }

  static HighlightType _bracketTypeForDepth(int depth) {
    return switch (depth % 6) {
      0 => HighlightType.bracket0,
      1 => HighlightType.bracket1,
      2 => HighlightType.bracket2,
      3 => HighlightType.bracket3,
      4 => HighlightType.bracket4,
      _ => HighlightType.bracket5,
    };
  }

  static HighlightType _classifyToken(Token token) {
    final type = token.type;
    final lexeme = token.lexeme;

    // Keywords
    if (type.isKeyword) {
      // Control flow keywords
      if (_isControlKeyword(lexeme)) {
        return HighlightType.controlKeyword;
      }
      // Built-in identifiers
      if (_isBuiltInKeyword(lexeme)) {
        return HighlightType.builtInKeyword;
      }
      // this keyword
      if (lexeme == 'this') {
        return HighlightType.thisKeyword;
      }
      // true, false
      if (lexeme == 'true' || lexeme == 'false') {
        return HighlightType.boolLiteral;
      }
      // null
      if (lexeme == 'null') {
        return HighlightType.nullLiteral;
      }
      return HighlightType.keyword;
    }

    // Strings
    if (type == TokenType.STRING ||
        type == TokenType.STRING_INTERPOLATION_EXPRESSION ||
        type == TokenType.STRING_INTERPOLATION_IDENTIFIER) {
      return HighlightType.string;
    }

    // Numbers
    if (type == TokenType.INT ||
        type == TokenType.DOUBLE ||
        type == TokenType.HEXADECIMAL) {
      return HighlightType.number;
    }

    // Operators
    if (_isOperator(type)) {
      return HighlightType.operator;
    }

    // Punctuation (not brackets)
    if (_isPunctuation(type)) {
      return HighlightType.punctuation;
    }

    // Identifiers - basic classification
    if (type == TokenType.IDENTIFIER) {
      // Types start with uppercase
      if (lexeme.isNotEmpty && _isUpperCase(lexeme[0])) {
        return HighlightType.type;
      }
      // Annotation after @
      if (token.previous?.lexeme == '@') {
        return HighlightType.annotation;
      }
    }

    // @ symbol
    if (lexeme == '@') {
      return HighlightType.annotation;
    }

    return HighlightType.plain;
  }

  static bool _isControlKeyword(String lexeme) {
    const control = {
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
    return control.contains(lexeme);
  }

  static bool _isBuiltInKeyword(String lexeme) {
    const builtIn = {
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
    return builtIn.contains(lexeme);
  }

  static bool _isOperator(TokenType type) {
    return type == TokenType.PLUS ||
        type == TokenType.MINUS ||
        type == TokenType.STAR ||
        type == TokenType.SLASH ||
        type == TokenType.TILDE_SLASH ||
        type == TokenType.PERCENT ||
        type == TokenType.EQ ||
        type == TokenType.EQ_EQ ||
        type == TokenType.BANG_EQ ||
        type == TokenType.LT ||
        type == TokenType.GT ||
        type == TokenType.LT_EQ ||
        type == TokenType.GT_EQ ||
        type == TokenType.AMPERSAND ||
        type == TokenType.AMPERSAND_AMPERSAND ||
        type == TokenType.BAR ||
        type == TokenType.BAR_BAR ||
        type == TokenType.CARET ||
        type == TokenType.TILDE ||
        type == TokenType.LT_LT ||
        type == TokenType.GT_GT ||
        type == TokenType.GT_GT_GT ||
        type == TokenType.QUESTION ||
        type == TokenType.QUESTION_QUESTION ||
        type == TokenType.QUESTION_PERIOD ||
        type == TokenType.BANG ||
        type == TokenType.PLUS_PLUS ||
        type == TokenType.MINUS_MINUS ||
        type == TokenType.PLUS_EQ ||
        type == TokenType.MINUS_EQ ||
        type == TokenType.STAR_EQ ||
        type == TokenType.SLASH_EQ ||
        type == TokenType.PERCENT_EQ ||
        type == TokenType.AMPERSAND_EQ ||
        type == TokenType.BAR_EQ ||
        type == TokenType.CARET_EQ ||
        type == TokenType.GT_GT_EQ ||
        type == TokenType.LT_LT_EQ ||
        type == TokenType.QUESTION_QUESTION_EQ ||
        type == TokenType.FUNCTION;
  }

  static bool _isPunctuation(TokenType type) {
    return type == TokenType.SEMICOLON ||
        type == TokenType.COMMA ||
        type == TokenType.PERIOD ||
        type == TokenType.PERIOD_PERIOD ||
        type == TokenType.PERIOD_PERIOD_PERIOD ||
        type == TokenType.COLON ||
        type == TokenType.HASH;
  }

  static bool _isUpperCase(String char) {
    return char.toUpperCase() == char && char.toLowerCase() != char;
  }
}

/// AST visitor for semantic syntax highlighting.
class _SemanticHighlightVisitor extends RecursiveAstVisitor<void> {
  final List<HighlightToken> tokens;

  _SemanticHighlightVisitor(this.tokens);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _addToken(node.namePart.typeName, HighlightType.className);
    super.visitClassDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addToken(node.name, HighlightType.function);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addToken(node.name, HighlightType.function);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName;
    _addIdentifier(methodName, HighlightType.methodCall);
    super.visitMethodInvocation(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    // Function calls like myFunc()
    final function = node.function;
    if (function is SimpleIdentifier) {
      _addIdentifier(function, HighlightType.methodCall);
    }
    super.visitFunctionExpressionInvocation(node);
  }

  // analyzer 14 folds the simple, function-typed and default-value parameter
  // nodes into RegularFormalParameter.
  @override
  void visitRegularFormalParameter(RegularFormalParameter node) {
    final name = node.name;
    if (name != null) {
      tokens.add(
        HighlightToken(
          type: HighlightType.parameter,
          offset: name.offset,
          length: name.length,
        ),
      );
    }
    super.visitRegularFormalParameter(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    final name = node.name;
    tokens.add(
      HighlightToken(
        type: HighlightType.parameter,
        offset: name.offset,
        length: name.length,
      ),
    );
    super.visitFieldFormalParameter(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final name = node.name;
    _addToken(name, HighlightType.type);
    super.visitNamedType(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _addIdentifier(node.propertyName, HighlightType.property);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Could be property access like obj.property
    _addIdentifier(node.identifier, HighlightType.property);
    super.visitPrefixedIdentifier(node);
  }

  void _addToken(Token token, HighlightType type) {
    tokens.add(
      HighlightToken(type: type, offset: token.offset, length: token.length),
    );
  }

  void _addIdentifier(SimpleIdentifier identifier, HighlightType type) {
    tokens.add(
      HighlightToken(
        type: type,
        offset: identifier.offset,
        length: identifier.length,
      ),
    );
  }
}

/// Builds TextSpans with syntax highlighting.
class HighlightedTextBuilder {
  final String code;
  final List<HighlightToken> tokens;
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
