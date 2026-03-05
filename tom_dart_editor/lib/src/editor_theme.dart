import 'package:flutter/material.dart';

/// Unified theme for the Dart code editor.
///
/// Contains all customizable colors for:
/// - Editor UI (background, gutter, borders, etc.)
/// - Syntax highlighting (keywords, strings, types, etc.)
/// - Error display (colors, tooltip styling)
/// - Rainbow brackets
class DartEditorTheme {
  /// Editor UI colors
  final EditorColors editor;

  /// Syntax highlighting colors
  final SyntaxColors syntax;

  /// Error/diagnostic styling
  final DiagnosticColors diagnostics;

  /// Rainbow bracket colors
  final BracketColors brackets;

  /// Tooltip styling
  final TooltipStyle tooltip;

  /// Font settings
  final FontSettings font;

  const DartEditorTheme({
    required this.editor,
    required this.syntax,
    required this.diagnostics,
    required this.brackets,
    required this.tooltip,
    required this.font,
  });

  /// Creates a dark theme (VS Code Dark+ inspired).
  factory DartEditorTheme.dark() {
    return const DartEditorTheme(
      editor: EditorColors.dark(),
      syntax: SyntaxColors.dark(),
      diagnostics: DiagnosticColors.dark(),
      brackets: BracketColors.dark(),
      tooltip: TooltipStyle.dark(),
      font: FontSettings(),
    );
  }

  /// Creates a light theme (VS Code Light+ inspired).
  factory DartEditorTheme.light() {
    return const DartEditorTheme(
      editor: EditorColors.light(),
      syntax: SyntaxColors.light(),
      diagnostics: DiagnosticColors.light(),
      brackets: BracketColors.light(),
      tooltip: TooltipStyle.light(),
      font: FontSettings(),
    );
  }

  /// Creates a copy of this theme with the given fields replaced.
  DartEditorTheme copyWith({
    EditorColors? editor,
    SyntaxColors? syntax,
    DiagnosticColors? diagnostics,
    BracketColors? brackets,
    TooltipStyle? tooltip,
    FontSettings? font,
  }) {
    return DartEditorTheme(
      editor: editor ?? this.editor,
      syntax: syntax ?? this.syntax,
      diagnostics: diagnostics ?? this.diagnostics,
      brackets: brackets ?? this.brackets,
      tooltip: tooltip ?? this.tooltip,
      font: font ?? this.font,
    );
  }

  bool get isDark => editor.background.computeLuminance() < 0.5;
}

/// Editor UI colors.
class EditorColors {
  final Color background;
  final Color text;
  final Color gutter;
  final Color lineNumber;
  final Color border;

  /// Width of the outer border drawn around the editor widget.
  final double borderWidth;

  /// Width of the line-number gutter on the left side of the editor.
  final double gutterWidth;

  /// Padding (all sides) inside the text area.
  final double contentPadding;

  /// Corner radius of the outer editor container.
  final double borderRadius;

  final Color placeholder;
  final Color cursor;
  final Color selection;
  final Color currentLine;
  final Color matchingBracketBackground;

  const EditorColors({
    required this.background,
    required this.text,
    required this.gutter,
    required this.lineNumber,
    required this.border,
    this.borderWidth = 1.0,
    this.gutterWidth = 50.0,
    this.contentPadding = 12.0,
    this.borderRadius = 8.0,
    required this.placeholder,
    required this.cursor,
    required this.selection,
    required this.currentLine,
    required this.matchingBracketBackground,
  });

  const EditorColors.dark()
      : background = const Color(0xFF1E1E1E),
        text = const Color(0xFFD4D4D4),
        gutter = const Color(0xFF252526),
        lineNumber = const Color(0xFF858585),
        border = const Color(0xFF3C3C3C),
        borderWidth = 1.0,
        gutterWidth = 50.0,
        contentPadding = 12.0,
        borderRadius = 8.0,
        placeholder = const Color(0xFF6A6A6A),
        cursor = const Color(0xFFAEAFAD),
        selection = const Color(0xFF264F78),
        currentLine = const Color(0xFF2A2A2A),
        matchingBracketBackground = const Color(0xFF3A5A3A);

  const EditorColors.light()
      : background = const Color(0xFFFFFFFF),
        text = const Color(0xFF1E1E1E),
        gutter = const Color(0xFFF3F3F3),
        lineNumber = const Color(0xFF237893),
        border = const Color(0xFFE0E0E0),
        borderWidth = 1.0,
        gutterWidth = 50.0,
        contentPadding = 12.0,
        borderRadius = 8.0,
        placeholder = const Color(0xFFA0A0A0),
        cursor = const Color(0xFF000000),
        selection = const Color(0xFFADD6FF),
        currentLine = const Color(0xFFFFFBE6),
        matchingBracketBackground = const Color(0xFFE8F5E9);

  EditorColors copyWith({
    Color? background,
    Color? text,
    Color? gutter,
    Color? lineNumber,
    Color? border,
    double? borderWidth,
    double? gutterWidth,
    double? contentPadding,
    double? borderRadius,
    Color? placeholder,
    Color? cursor,
    Color? selection,
    Color? currentLine,
    Color? matchingBracketBackground,
  }) {
    return EditorColors(
      background: background ?? this.background,
      text: text ?? this.text,
      gutter: gutter ?? this.gutter,
      lineNumber: lineNumber ?? this.lineNumber,
      border: border ?? this.border,
      borderWidth: borderWidth ?? this.borderWidth,
      gutterWidth: gutterWidth ?? this.gutterWidth,
      contentPadding: contentPadding ?? this.contentPadding,
      borderRadius: borderRadius ?? this.borderRadius,
      placeholder: placeholder ?? this.placeholder,
      cursor: cursor ?? this.cursor,
      selection: selection ?? this.selection,
      currentLine: currentLine ?? this.currentLine,
      matchingBracketBackground:
          matchingBracketBackground ?? this.matchingBracketBackground,
    );
  }
}

/// Syntax highlighting colors.
class SyntaxColors {
  final Color plain;
  final Color keyword;
  final Color builtInKeyword;
  final Color controlKeyword;
  final Color string;
  final Color number;
  final Color comment;
  final Color operator;
  final Color punctuation;
  final Color type;
  final Color className;
  final Color function;
  final Color methodCall;
  final Color variable;
  final Color parameter;
  final Color property;
  final Color constant;
  final Color annotation;
  final Color thisKeyword;
  final Color boolLiteral;
  final Color nullLiteral;

  const SyntaxColors({
    required this.plain,
    required this.keyword,
    required this.builtInKeyword,
    required this.controlKeyword,
    required this.string,
    required this.number,
    required this.comment,
    required this.operator,
    required this.punctuation,
    required this.type,
    required this.className,
    required this.function,
    required this.methodCall,
    required this.variable,
    required this.parameter,
    required this.property,
    required this.constant,
    required this.annotation,
    required this.thisKeyword,
    required this.boolLiteral,
    required this.nullLiteral,
  });

  const SyntaxColors.dark()
      : plain = const Color(0xFFD4D4D4),
        keyword = const Color(0xFFC586C0),
        builtInKeyword = const Color(0xFF569CD6),
        controlKeyword = const Color(0xFFC586C0),
        string = const Color(0xFFCE9178),
        number = const Color(0xFFB5CEA8),
        comment = const Color(0xFF6A9955),
        operator = const Color(0xFFD4D4D4),
        punctuation = const Color(0xFFD4D4D4),
        type = const Color(0xFF4EC9B0),
        className = const Color(0xFF4EC9B0),
        function = const Color(0xFFDCDCAA),
        methodCall = const Color(0xFFDCDCAA),
        variable = const Color(0xFF9CDCFE),
        parameter = const Color(0xFF9CDCFE),
        property = const Color(0xFF9CDCFE),
        constant = const Color(0xFF4FC1FF),
        annotation = const Color(0xFFDCDCAA),
        thisKeyword = const Color(0xFF569CD6),
        boolLiteral = const Color(0xFF569CD6),
        nullLiteral = const Color(0xFF569CD6);

  const SyntaxColors.light()
      : plain = const Color(0xFF1E1E1E),
        keyword = const Color(0xFFAF00DB),
        builtInKeyword = const Color(0xFF0000FF),
        controlKeyword = const Color(0xFFAF00DB),
        string = const Color(0xFFA31515),
        number = const Color(0xFF098658),
        comment = const Color(0xFF008000),
        operator = const Color(0xFF1E1E1E),
        punctuation = const Color(0xFF1E1E1E),
        type = const Color(0xFF267F99),
        className = const Color(0xFF267F99),
        function = const Color(0xFF795E26),
        methodCall = const Color(0xFF795E26),
        variable = const Color(0xFF001080),
        parameter = const Color(0xFF001080),
        property = const Color(0xFF001080),
        constant = const Color(0xFF0070C1),
        annotation = const Color(0xFF795E26),
        thisKeyword = const Color(0xFF0000FF),
        boolLiteral = const Color(0xFF0000FF),
        nullLiteral = const Color(0xFF0000FF);

  SyntaxColors copyWith({
    Color? plain,
    Color? keyword,
    Color? builtInKeyword,
    Color? controlKeyword,
    Color? string,
    Color? number,
    Color? comment,
    Color? operator,
    Color? punctuation,
    Color? type,
    Color? className,
    Color? function,
    Color? methodCall,
    Color? variable,
    Color? parameter,
    Color? property,
    Color? constant,
    Color? annotation,
    Color? thisKeyword,
    Color? boolLiteral,
    Color? nullLiteral,
  }) {
    return SyntaxColors(
      plain: plain ?? this.plain,
      keyword: keyword ?? this.keyword,
      builtInKeyword: builtInKeyword ?? this.builtInKeyword,
      controlKeyword: controlKeyword ?? this.controlKeyword,
      string: string ?? this.string,
      number: number ?? this.number,
      comment: comment ?? this.comment,
      operator: operator ?? this.operator,
      punctuation: punctuation ?? this.punctuation,
      type: type ?? this.type,
      className: className ?? this.className,
      function: function ?? this.function,
      methodCall: methodCall ?? this.methodCall,
      variable: variable ?? this.variable,
      parameter: parameter ?? this.parameter,
      property: property ?? this.property,
      constant: constant ?? this.constant,
      annotation: annotation ?? this.annotation,
      thisKeyword: thisKeyword ?? this.thisKeyword,
      boolLiteral: boolLiteral ?? this.boolLiteral,
      nullLiteral: nullLiteral ?? this.nullLiteral,
    );
  }
}

/// Diagnostic/error colors.
class DiagnosticColors {
  final Color error;
  final Color warning;
  final Color info;
  final Color hint;
  final Color errorBackground;
  final Color warningBackground;
  final Color infoBackground;

  const DiagnosticColors({
    required this.error,
    required this.warning,
    required this.info,
    required this.hint,
    required this.errorBackground,
    required this.warningBackground,
    required this.infoBackground,
  });

  const DiagnosticColors.dark()
      : error = const Color(0xFFF44747),
        warning = const Color(0xFFFF8C00),
        info = const Color(0xFF75BEFF),
        hint = const Color(0xFF6A9955),
        errorBackground = const Color(0x33F44747),
        warningBackground = const Color(0x33FF8C00),
        infoBackground = const Color(0x3375BEFF);

  const DiagnosticColors.light()
      : error = const Color(0xFFD32F2F),
        warning = const Color(0xFFF57C00),
        info = const Color(0xFF1976D2),
        hint = const Color(0xFF388E3C),
        errorBackground = const Color(0x33D32F2F),
        warningBackground = const Color(0x33F57C00),
        infoBackground = const Color(0x331976D2);

  DiagnosticColors copyWith({
    Color? error,
    Color? warning,
    Color? info,
    Color? hint,
    Color? errorBackground,
    Color? warningBackground,
    Color? infoBackground,
  }) {
    return DiagnosticColors(
      error: error ?? this.error,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      hint: hint ?? this.hint,
      errorBackground: errorBackground ?? this.errorBackground,
      warningBackground: warningBackground ?? this.warningBackground,
      infoBackground: infoBackground ?? this.infoBackground,
    );
  }
}

/// Rainbow bracket colors.
class BracketColors {
  final Color bracket0;
  final Color bracket1;
  final Color bracket2;
  final Color bracket3;
  final Color bracket4;
  final Color bracket5;

  const BracketColors({
    required this.bracket0,
    required this.bracket1,
    required this.bracket2,
    required this.bracket3,
    required this.bracket4,
    required this.bracket5,
  });

  const BracketColors.dark()
      : bracket0 = const Color(0xFFFFD700), // Gold
        bracket1 = const Color(0xFFDA70D6), // Orchid
        bracket2 = const Color(0xFF87CEEB), // Sky blue
        bracket3 = const Color(0xFF98FB98), // Pale green
        bracket4 = const Color(0xFFFF6B6B), // Coral
        bracket5 = const Color(0xFFFFB347); // Orange

  const BracketColors.light()
      : bracket0 = const Color(0xFFB8860B), // Dark goldenrod
        bracket1 = const Color(0xFF9932CC), // Dark orchid
        bracket2 = const Color(0xFF4682B4), // Steel blue
        bracket3 = const Color(0xFF228B22), // Forest green
        bracket4 = const Color(0xFFDC143C), // Crimson
        bracket5 = const Color(0xFFFF8C00); // Dark orange

  /// Gets bracket color by depth (cycles through all 6 colors).
  Color colorForDepth(int depth) {
    return switch (depth % 6) {
      0 => bracket0,
      1 => bracket1,
      2 => bracket2,
      3 => bracket3,
      4 => bracket4,
      _ => bracket5,
    };
  }

  BracketColors copyWith({
    Color? bracket0,
    Color? bracket1,
    Color? bracket2,
    Color? bracket3,
    Color? bracket4,
    Color? bracket5,
  }) {
    return BracketColors(
      bracket0: bracket0 ?? this.bracket0,
      bracket1: bracket1 ?? this.bracket1,
      bracket2: bracket2 ?? this.bracket2,
      bracket3: bracket3 ?? this.bracket3,
      bracket4: bracket4 ?? this.bracket4,
      bracket5: bracket5 ?? this.bracket5,
    );
  }
}

/// Tooltip styling for error hovers.
class TooltipStyle {
  final Color background;
  final Color border;
  final Color text;
  final Color codeBackground;
  final double borderRadius;
  final EdgeInsets padding;
  final double maxWidth;
  final BoxShadow? shadow;

  /// Width of the code-completion popup.
  final double completionWidth;

  /// Height of each item in the code-completion popup.
  final double completionItemHeight;

  const TooltipStyle({
    required this.background,
    required this.border,
    required this.text,
    required this.codeBackground,
    this.borderRadius = 6.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.maxWidth = 400.0,
    this.shadow,
    this.completionWidth = 300.0,
    this.completionItemHeight = 28.0,
  });

  const TooltipStyle.dark()
      : background = const Color(0xFF252526),
        border = const Color(0xFF454545),
        text = const Color(0xFFCCCCCC),
        codeBackground = const Color(0xFF1E1E1E),
        borderRadius = 6.0,
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        maxWidth = 400.0,
        completionWidth = 300.0,
        completionItemHeight = 28.0,
        shadow = const BoxShadow(
          color: Color(0x40000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        );

  const TooltipStyle.light()
      : background = const Color(0xFFF3F3F3),
        border = const Color(0xFFD4D4D4),
        text = const Color(0xFF1E1E1E),
        codeBackground = const Color(0xFFE8E8E8),
        borderRadius = 6.0,
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        maxWidth = 400.0,
        completionWidth = 300.0,
        completionItemHeight = 28.0,
        shadow = const BoxShadow(
          color: Color(0x20000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        );

  TooltipStyle copyWith({
    Color? background,
    Color? border,
    Color? text,
    Color? codeBackground,
    double? borderRadius,
    EdgeInsets? padding,
    double? maxWidth,
    BoxShadow? shadow,
    double? completionWidth,
    double? completionItemHeight,
  }) {
    return TooltipStyle(
      background: background ?? this.background,
      border: border ?? this.border,
      text: text ?? this.text,
      codeBackground: codeBackground ?? this.codeBackground,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      maxWidth: maxWidth ?? this.maxWidth,
      shadow: shadow ?? this.shadow,
      completionWidth: completionWidth ?? this.completionWidth,
      completionItemHeight: completionItemHeight ?? this.completionItemHeight,
    );
  }
}

/// Font settings for the editor.
class FontSettings {
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final FontWeight keywordWeight;
  final FontWeight normalWeight;

  /// Ratio of character width to font size used by the error-underline painter
  /// and completion popup positioning (default: 0.6 for monospace fonts).
  final double charWidthRatio;

  const FontSettings({
    this.fontFamily = 'monospace',
    this.fontSize = 14.0,
    this.lineHeight = 1.5,
    this.keywordWeight = FontWeight.w500,
    this.normalWeight = FontWeight.w400,
    this.charWidthRatio = 0.6,
  });

  FontSettings copyWith({
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    FontWeight? keywordWeight,
    FontWeight? normalWeight,
    double? charWidthRatio,
  }) {
    return FontSettings(
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      keywordWeight: keywordWeight ?? this.keywordWeight,
      normalWeight: normalWeight ?? this.normalWeight,
      charWidthRatio: charWidthRatio ?? this.charWidthRatio,
    );
  }

  /// Creates a base TextStyle from these settings.
  TextStyle get baseStyle => TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        height: lineHeight,
        fontWeight: normalWeight,
      );
}
