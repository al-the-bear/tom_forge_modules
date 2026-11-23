import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart' as xterm;

/// The colours of a [TomTerminalView]: the text, the background, the cursor,
/// the selection and the 16 ANSI colours.
@immutable
class TomTerminalColors {
  const TomTerminalColors({
    required this.foreground,
    required this.background,
    required this.cursor,
    required this.selection,
    required this.ansi,
  }) : assert(ansi.length == 16);

  /// xterm's default colours (light text on black).
  static final TomTerminalColors standard = TomTerminalColors.fromXterm(
    xterm.TerminalThemes.defaultTheme,
  );

  /// The colours of an xterm theme.
  factory TomTerminalColors.fromXterm(xterm.TerminalTheme theme) =>
      TomTerminalColors(
        foreground: theme.foreground,
        background: theme.background,
        cursor: theme.cursor,
        selection: theme.selection,
        ansi: [
          theme.black,
          theme.red,
          theme.green,
          theme.yellow,
          theme.blue,
          theme.magenta,
          theme.cyan,
          theme.white,
          theme.brightBlack,
          theme.brightRed,
          theme.brightGreen,
          theme.brightYellow,
          theme.brightBlue,
          theme.brightMagenta,
          theme.brightCyan,
          theme.brightWhite,
        ],
      );

  final Color foreground;
  final Color background;
  final Color cursor;
  final Color selection;

  /// Black, red, green, yellow, blue, magenta, cyan, white, then their
  /// bright variants.
  final List<Color> ansi;

  /// These colours with the ones given replaced.
  TomTerminalColors copyWith({
    Color? foreground,
    Color? background,
    Color? cursor,
    Color? selection,
    List<Color>? ansi,
  }) => TomTerminalColors(
    foreground: foreground ?? this.foreground,
    background: background ?? this.background,
    cursor: cursor ?? this.cursor,
    selection: selection ?? this.selection,
    ansi: ansi ?? this.ansi,
  );

  /// The xterm theme of these colours (search highlights from xterm's
  /// default theme).
  xterm.TerminalTheme toXterm() {
    const base = xterm.TerminalThemes.defaultTheme;
    return xterm.TerminalTheme(
      cursor: cursor,
      selection: selection,
      foreground: foreground,
      background: background,
      black: ansi[0],
      red: ansi[1],
      green: ansi[2],
      yellow: ansi[3],
      blue: ansi[4],
      magenta: ansi[5],
      cyan: ansi[6],
      white: ansi[7],
      brightBlack: ansi[8],
      brightRed: ansi[9],
      brightGreen: ansi[10],
      brightYellow: ansi[11],
      brightBlue: ansi[12],
      brightMagenta: ansi[13],
      brightCyan: ansi[14],
      brightWhite: ansi[15],
      searchHitBackground: base.searchHitBackground,
      searchHitBackgroundCurrent: base.searchHitBackgroundCurrent,
      searchHitForeground: base.searchHitForeground,
    );
  }
}

/// How a [TomTerminalView] draws its text: the font and the colours.
@immutable
class TomTerminalStyle {
  const TomTerminalStyle({
    this.fontFamily = 'monospace',
    this.fontSize = 13,
    this.colors,
  });

  /// The font family; a monospaced font.
  final String fontFamily;

  /// The font size in logical pixels.
  final double fontSize;

  /// The colours; null: [TomTerminalColors.standard].
  final TomTerminalColors? colors;

  /// The xterm text style of this style.
  xterm.TerminalStyle toXtermTextStyle() =>
      xterm.TerminalStyle(fontSize: fontSize, fontFamily: fontFamily);

  /// The xterm theme of this style.
  xterm.TerminalTheme toXtermTheme() =>
      (colors ?? TomTerminalColors.standard).toXterm();
}
