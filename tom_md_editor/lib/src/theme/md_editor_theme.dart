import 'package:flutter/material.dart';

/// Comprehensive basic theme for the markdown editor.
///
/// Provides semantic tokens from which all element styles are derived.
/// Most users only need to customize this — tag overrides are for
/// fine-grained control.
class MdBasicTheme {
  const MdBasicTheme({
    // Colors
    this.background = const Color(0xFF1E1E1E),
    this.surface = const Color(0xFF252526),
    this.surfaceVariant = const Color(0xFF2D2D2D),
    this.text = const Color(0xFFD4D4D4),
    this.textSecondary = const Color(0xFFAAAAAA),
    this.textMuted = const Color(0xFF808080),
    this.accent = const Color(0xFF007ACC),
    this.accentSecondary = const Color(0xFF3794FF),
    this.border = const Color(0xFF3C3C3C),
    this.borderSubtle = const Color(0xFF2D2D2D),
    this.selection = const Color(0x403794FF),
    this.highlight = const Color(0x40FFD700),
    this.error = const Color(0xFFFF5555),
    this.warning = const Color(0xFFFFAA33),
    this.success = const Color(0xFF4EC9B0),
    // Typography
    this.fontFamily = 'Segoe UI',
    this.serifFontFamily = 'Georgia',
    this.monoFontFamily = 'Cascadia Code',
    this.baseFontSize = 14.0,
    this.lineHeight = 1.6,
    this.normalWeight = FontWeight.w400,
    this.boldWeight = FontWeight.w700,
    // Heading scale
    this.h1Scale = 2.0,
    this.h2Scale = 1.5,
    this.h3Scale = 1.25,
    this.h4Scale = 1.1,
    this.h5Scale = 1.0,
    this.h6Scale = 0.9,
    this.headingWeight = FontWeight.w600,
    this.headingLineHeight = 1.3,
    this.headingColor,
    this.headingBorderBottom = true,
    // Spacing
    this.sectionSpacing = 24.0,
    this.paragraphSpacing = 12.0,
    this.headingMarginTop = 24.0,
    this.headingMarginBottom = 8.0,
    this.listIndent = 24.0,
    this.blockPadding = 12.0,
    this.blockMargin = 8.0,
    // Block styling
    this.borderRadius = 6.0,
    this.borderWidth = 1.0,
    this.codeBackground = const Color(0xFF1A1A1A),
    this.codeBorder = const Color(0xFF3C3C3C),
    this.inlineCodeBackground = const Color(0xFF2D2D2D),
    this.blockquoteBackground = const Color(0x10FFFFFF),
    this.blockquoteBorder = const Color(0xFF007ACC),
    this.blockquoteBorderWidth = 3.0,
    this.tableHeaderBackground = const Color(0xFF2D2D2D),
    this.tableRowAlternate = const Color(0x08FFFFFF),
    this.tableBorder = const Color(0xFF3C3C3C),
    // Links
    this.linkColor = const Color(0xFF3794FF),
    this.linkHoverColor = const Color(0xFF58B0FF),
    this.linkDecoration = TextDecoration.underline,
  });

  // Colors
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSecondary;
  final Color border;
  final Color borderSubtle;
  final Color selection;
  final Color highlight;
  final Color error;
  final Color warning;
  final Color success;

  // Typography
  final String fontFamily;
  final String serifFontFamily;
  final String monoFontFamily;
  final double baseFontSize;
  final double lineHeight;
  final FontWeight normalWeight;
  final FontWeight boldWeight;

  // Heading
  final double h1Scale;
  final double h2Scale;
  final double h3Scale;
  final double h4Scale;
  final double h5Scale;
  final double h6Scale;
  final FontWeight headingWeight;
  final double headingLineHeight;
  final Color? headingColor;
  final bool headingBorderBottom;

  // Spacing
  final double sectionSpacing;
  final double paragraphSpacing;
  final double headingMarginTop;
  final double headingMarginBottom;
  final double listIndent;
  final double blockPadding;
  final double blockMargin;

  // Block styling
  final double borderRadius;
  final double borderWidth;
  final Color codeBackground;
  final Color codeBorder;
  final Color inlineCodeBackground;
  final Color blockquoteBackground;
  final Color blockquoteBorder;
  final double blockquoteBorderWidth;
  final Color tableHeaderBackground;
  final Color tableRowAlternate;
  final Color tableBorder;

  // Links
  final Color linkColor;
  final Color linkHoverColor;
  final TextDecoration linkDecoration;

  // ── Derived styles ──

  TextStyle get paragraphStyle => TextStyle(
    inherit: false,
    fontFamily: serifFontFamily,
    fontSize: baseFontSize + 1,
    height: lineHeight,
    color: text,
    fontWeight: boldWeight,
  );

  TextStyle headingStyle(int level) {
    final scale = switch (level) {
      1 => h1Scale,
      2 => h2Scale,
      3 => h3Scale,
      4 => h4Scale,
      5 => h5Scale,
      _ => h6Scale,
    };
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: baseFontSize * scale,
      height: headingLineHeight,
      color: headingColor ?? text,
      fontWeight: headingWeight,
    );
  }

  TextStyle get codeStyle => TextStyle(
    fontFamily: monoFontFamily,
    fontSize: baseFontSize * 0.9,
    height: lineHeight,
    color: text,
  );

  TextStyle get inlineCodeStyle => TextStyle(
    fontFamily: monoFontFamily,
    fontSize: baseFontSize * 0.9,
    color: text,
    backgroundColor: inlineCodeBackground,
  );

  BoxDecoration get codeBlockDecoration => BoxDecoration(
    color: codeBackground,
    border: Border.all(color: codeBorder, width: borderWidth),
    borderRadius: BorderRadius.circular(borderRadius),
  );

  BoxDecoration get blockquoteDecoration => BoxDecoration(
    color: blockquoteBackground,
    border: Border(
      left: BorderSide(
        color: blockquoteBorder,
        width: blockquoteBorderWidth,
      ),
    ),
  );

  MdBasicTheme copyWith({
    Color? background,
    Color? surface,
    Color? text,
    Color? accent,
    double? baseFontSize,
    String? fontFamily,
    String? monoFontFamily,
  }) {
    return MdBasicTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      accent: accent ?? this.accent,
      baseFontSize: baseFontSize ?? this.baseFontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      monoFontFamily: monoFontFamily ?? this.monoFontFamily,
    );
  }
}

/// Hierarchical per-tag style overrides.
///
/// All fields are nullable — `null` means inherit from the parent
/// level or the basic theme.
class MdTagOverrides {
  const MdTagOverrides({
    this.headingBase,
    this.h1,
    this.h2,
    this.h3,
    this.h4,
    this.h5,
    this.h6,
    this.paragraph,
    this.bold,
    this.italic,
    this.inlineCode,
    this.codeBlock,
    this.blockquote,
    this.link,
  });

  final MdHeadingStyleOverride? headingBase;
  final MdHeadingStyleOverride? h1;
  final MdHeadingStyleOverride? h2;
  final MdHeadingStyleOverride? h3;
  final MdHeadingStyleOverride? h4;
  final MdHeadingStyleOverride? h5;
  final MdHeadingStyleOverride? h6;
  final MdTextStyleOverride? paragraph;
  final MdTextStyleOverride? bold;
  final MdTextStyleOverride? italic;
  final MdTextStyleOverride? inlineCode;
  final MdBlockStyleOverride? codeBlock;
  final MdBlockStyleOverride? blockquote;
  final MdLinkStyleOverride? link;

  /// Resolve heading style for a given level, inheriting from base.
  MdHeadingStyleOverride? resolveHeading(int level) {
    final specific = switch (level) {
      1 => h1,
      2 => h2,
      3 => h3,
      4 => h4,
      5 => h5,
      6 => h6,
      _ => null,
    };
    if (headingBase == null) return specific;
    return specific?.merge(headingBase!) ?? headingBase;
  }
}

class MdHeadingStyleOverride {
  const MdHeadingStyleOverride({
    this.color,
    this.fontSize,
    this.fontWeight,
    this.marginTop,
    this.marginBottom,
    this.borderBottomColor,
    this.borderBottomWidth,
    this.letterSpacing,
  });

  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? marginTop;
  final double? marginBottom;
  final Color? borderBottomColor;
  final double? borderBottomWidth;
  final double? letterSpacing;

  MdHeadingStyleOverride merge(MdHeadingStyleOverride parent) {
    return MdHeadingStyleOverride(
      color: color ?? parent.color,
      fontSize: fontSize ?? parent.fontSize,
      fontWeight: fontWeight ?? parent.fontWeight,
      marginTop: marginTop ?? parent.marginTop,
      marginBottom: marginBottom ?? parent.marginBottom,
      borderBottomColor: borderBottomColor ?? parent.borderBottomColor,
      borderBottomWidth: borderBottomWidth ?? parent.borderBottomWidth,
      letterSpacing: letterSpacing ?? parent.letterSpacing,
    );
  }
}

class MdTextStyleOverride {
  const MdTextStyleOverride({
    this.color,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.decoration,
    this.background,
  });

  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final TextDecoration? decoration;
  final Color? background;
}

class MdBlockStyleOverride {
  const MdBlockStyleOverride({
    this.background,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.margin,
  });

  final Color? background;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
}

class MdLinkStyleOverride {
  const MdLinkStyleOverride({
    this.color,
    this.hoverColor,
    this.decoration,
  });

  final Color? color;
  final Color? hoverColor;
  final TextDecoration? decoration;
}

/// Composite editor theme.
class MdEditorTheme {
  const MdEditorTheme({
    required this.basic,
    this.tagOverrides,
  });

  final MdBasicTheme basic;
  final MdTagOverrides? tagOverrides;

  /// Dark theme preset (VS Code inspired).
  factory MdEditorTheme.dark() => const MdEditorTheme(basic: MdBasicTheme());

  /// Light theme preset.
  factory MdEditorTheme.light() => const MdEditorTheme(
    basic: MdBasicTheme(
      background: Color(0xFFFFFFFF),
      surface: Color(0xFFF5F5F5),
      surfaceVariant: Color(0xFFEEEEEE),
      text: Color(0xFF1E1E1E),
      textSecondary: Color(0xFF555555),
      textMuted: Color(0xFF999999),
      accent: Color(0xFF0366D6),
      accentSecondary: Color(0xFF0550AE),
      border: Color(0xFFE0E0E0),
      borderSubtle: Color(0xFFEEEEEE),
      selection: Color(0x400366D6),
      highlight: Color(0x40FFD700),
      error: Color(0xFFCB2431),
      warning: Color(0xFFE36209),
      success: Color(0xFF22863A),
      codeBackground: Color(0xFFF6F8FA),
      codeBorder: Color(0xFFE0E0E0),
      inlineCodeBackground: Color(0xFFEFF1F3),
      blockquoteBackground: Color(0x08000000),
      blockquoteBorder: Color(0xFF0366D6),
      tableHeaderBackground: Color(0xFFF0F0F0),
      tableRowAlternate: Color(0x05000000),
      tableBorder: Color(0xFFE0E0E0),
      linkColor: Color(0xFF0366D6),
      linkHoverColor: Color(0xFF0550AE),
    ),
  );

  /// Build theme from Flutter [ThemeData].
  factory MdEditorTheme.fromThemeData(ThemeData themeData) {
    final isDark = themeData.brightness == Brightness.dark;
    return isDark ? MdEditorTheme.dark() : MdEditorTheme.light();
  }

  MdEditorTheme copyWith({
    MdBasicTheme? basic,
    MdTagOverrides? tagOverrides,
  }) {
    return MdEditorTheme(
      basic: basic ?? this.basic,
      tagOverrides: tagOverrides ?? this.tagOverrides,
    );
  }
}
