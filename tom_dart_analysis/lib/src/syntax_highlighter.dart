import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:tom_dart_editor/tom_dart_editor.dart';

/// The Dart editor's semantic highlighter: the analyzer's scanner for the
/// lexical kinds (keywords, strings, numbers, comments, rainbow brackets),
/// then a pass over the AST for the semantic ones (class, function, method
/// call, parameter, property and type names).
///
/// A `tom_text_highlight` [TokenHighlighter]: the editor takes it through
/// `DartCodeEditor.highlighter` (the summary-backed editors of this package
/// do so by default) and styles its token classes with the editor theme;
/// [tokenize] yields each kind's class ([dartHighlightClass]). Without this
/// package the editor uses `tom_dart_editor`'s light, lexical
/// `DartLightHighlighter`.
class DartSyntaxHighlighter extends TokenHighlighter {
  DartSyntaxHighlighter({super.theme});

  @override
  List<HighlightToken> tokenize(String source) => [
        for (final token in tokenizeKinds(source))
          if (dartHighlightClass(token.type) case final type?)
            HighlightToken(token.offset, token.end, type),
      ];

  /// Tokenizes Dart code and returns its tokens with their kinds, in order.
  static List<DartHighlightToken> tokenizeKinds(String code) {
    if (code.isEmpty) return [];

    final tokens = <DartHighlightToken>[];
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
            DartHighlightToken(
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
            DartHighlightToken(
              type: _bracketTypeForDepth(bracketDepth),
              offset: token.offset,
              length: token.length,
            ),
          );
          bracketDepth++;
        } else if (_isClosingBracket(tokenType)) {
          bracketDepth = (bracketDepth - 1).clamp(0, 999);
          tokens.add(
            DartHighlightToken(
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
              DartHighlightToken(
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
          DartHighlightToken(
            type: HighlightType.comment,
            offset: trailingComment.offset,
            length: trailingComment.length,
          ),
        );
        trailingComment = trailingComment.next;
      }

      // Second pass: AST visitor for semantic highlighting
      final semanticTokens = <DartHighlightToken>[];
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

  static List<DartHighlightToken> _deduplicateTokens(
      List<DartHighlightToken> tokens) {
    // Semantic tokens should override lexical tokens at same position
    final Map<int, DartHighlightToken> tokenMap = {};
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
  final List<DartHighlightToken> tokens;

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
        DartHighlightToken(
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
      DartHighlightToken(
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
      DartHighlightToken(
          type: type, offset: token.offset, length: token.length),
    );
  }

  void _addIdentifier(SimpleIdentifier identifier, HighlightType type) {
    tokens.add(
      DartHighlightToken(
        type: type,
        offset: identifier.offset,
        length: identifier.length,
      ),
    );
  }
}
