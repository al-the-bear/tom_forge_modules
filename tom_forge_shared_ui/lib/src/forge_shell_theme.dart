import 'package:flutter/material.dart';

/// Shell-level theme extension for Forge visual tokens.
///
/// Provides themed colors for panels, drop zones, and status indicators.
/// Use `Theme.of(context).extension<ForgeShellTheme>()` to access; an app
/// installs it with [forgeThemeData].
class ForgeShellTheme extends ThemeExtension<ForgeShellTheme> {
  /// Panel surface background.
  final Color panelSurface;

  /// Separator line between panels.
  final Color panelDivider;

  /// Active tab indicator color.
  final Color activeTab;

  /// Drop zone highlight on valid drag hover.
  final Color dropZoneHighlight;

  /// Drop zone color for valid drop target.
  final Color dropZoneValid;

  /// Drop zone color for invalid drop target.
  final Color dropZoneInvalid;

  /// Section header background.
  final Color sectionHeader;

  /// Status bar background.
  final Color statusBarBackground;

  /// Chord popup overlay background.
  final Color chordPopupBackground;

  /// Chord popup text/foreground color.
  final Color chordPopupForeground;

  /// Shortcut menu key badge background.
  final Color shortcutKeyBackground;

  /// Focus ring color for keyboard-navigated elements.
  final Color focusRing;

  const ForgeShellTheme({
    required this.panelSurface,
    required this.panelDivider,
    required this.activeTab,
    required this.dropZoneHighlight,
    required this.dropZoneValid,
    required this.dropZoneInvalid,
    required this.sectionHeader,
    required this.statusBarBackground,
    required this.chordPopupBackground,
    required this.chordPopupForeground,
    required this.shortcutKeyBackground,
    required this.focusRing,
  });

  /// Dark theme variant (default).
  factory ForgeShellTheme.dark() => const ForgeShellTheme(
    panelSurface: Color(0xFF1E1E1E),
    panelDivider: Color(0xFF3C3C3C),
    activeTab: Color(0xFF007ACC),
    dropZoneHighlight: Color(0x33007ACC),
    dropZoneValid: Color(0x5500CC66),
    dropZoneInvalid: Color(0x55CC3333),
    sectionHeader: Color(0xFF252526),
    statusBarBackground: Color(0xFF007ACC),
    chordPopupBackground: Color(0xFF252526),
    chordPopupForeground: Color(0xFFCCCCCC),
    shortcutKeyBackground: Color(0xFF616161),
    focusRing: Color(0xFF007ACC),
  );

  /// Light theme variant.
  factory ForgeShellTheme.light() => const ForgeShellTheme(
    panelSurface: Color(0xFFF3F3F3),
    panelDivider: Color(0xFFD4D4D4),
    activeTab: Color(0xFF005FB8),
    dropZoneHighlight: Color(0x33005FB8),
    dropZoneValid: Color(0x5500993D),
    dropZoneInvalid: Color(0x55CC3333),
    sectionHeader: Color(0xFFE7E7E7),
    statusBarBackground: Color(0xFF005FB8),
    chordPopupBackground: Color(0xFFFFFFFF),
    chordPopupForeground: Color(0xFF333333),
    shortcutKeyBackground: Color(0xFFBDBDBD),
    focusRing: Color(0xFF005FB8),
  );

  /// High-contrast theme variant.
  ///
  /// Uses strong borders, saturated colors, and maximum contrast for
  /// accessibility. Intended for users who require enhanced visibility.
  factory ForgeShellTheme.highContrast() => const ForgeShellTheme(
    panelSurface: Color(0xFF000000),
    panelDivider: Color(0xFFFFFFFF),
    activeTab: Color(0xFF00BFFF),
    dropZoneHighlight: Color(0x6600BFFF),
    dropZoneValid: Color(0x6600FF00),
    dropZoneInvalid: Color(0x66FF0000),
    sectionHeader: Color(0xFF1A1A1A),
    statusBarBackground: Color(0xFF00BFFF),
    chordPopupBackground: Color(0xFF1A1A1A),
    chordPopupForeground: Color(0xFFFFFFFF),
    shortcutKeyBackground: Color(0xFF424242),
    focusRing: Color(0xFFFFFFFF),
  );

  /// The shell theme for [mode].
  ///
  /// [ThemeMode.system] follows [platformBrightness] (the platform's
  /// brightness, `MediaQuery.platformBrightnessOf`). [highContrast] — the
  /// user's high-contrast preference or the platform's request for high
  /// contrast (`MediaQuery.highContrastOf`) — gives
  /// [ForgeShellTheme.highContrast] in every mode.
  static ForgeShellTheme forMode(
    ThemeMode mode, {
    Brightness platformBrightness = Brightness.light,
    bool highContrast = false,
  }) {
    if (highContrast) return ForgeShellTheme.highContrast();
    return switch (brightnessFor(mode, platformBrightness)) {
      Brightness.light => ForgeShellTheme.light(),
      Brightness.dark => ForgeShellTheme.dark(),
    };
  }

  /// The brightness [mode] stands for: [ThemeMode.system] follows
  /// [platformBrightness].
  static Brightness brightnessFor(
    ThemeMode mode,
    Brightness platformBrightness,
  ) => switch (mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => platformBrightness,
  };

  @override
  ForgeShellTheme copyWith({
    Color? panelSurface,
    Color? panelDivider,
    Color? activeTab,
    Color? dropZoneHighlight,
    Color? dropZoneValid,
    Color? dropZoneInvalid,
    Color? sectionHeader,
    Color? statusBarBackground,
    Color? chordPopupBackground,
    Color? chordPopupForeground,
    Color? shortcutKeyBackground,
    Color? focusRing,
  }) {
    return ForgeShellTheme(
      panelSurface: panelSurface ?? this.panelSurface,
      panelDivider: panelDivider ?? this.panelDivider,
      activeTab: activeTab ?? this.activeTab,
      dropZoneHighlight: dropZoneHighlight ?? this.dropZoneHighlight,
      dropZoneValid: dropZoneValid ?? this.dropZoneValid,
      dropZoneInvalid: dropZoneInvalid ?? this.dropZoneInvalid,
      sectionHeader: sectionHeader ?? this.sectionHeader,
      statusBarBackground: statusBarBackground ?? this.statusBarBackground,
      chordPopupBackground: chordPopupBackground ?? this.chordPopupBackground,
      chordPopupForeground: chordPopupForeground ?? this.chordPopupForeground,
      shortcutKeyBackground:
          shortcutKeyBackground ?? this.shortcutKeyBackground,
      focusRing: focusRing ?? this.focusRing,
    );
  }

  @override
  ForgeShellTheme lerp(ForgeShellTheme? other, double t) {
    if (other is! ForgeShellTheme) return this;
    return ForgeShellTheme(
      panelSurface: Color.lerp(panelSurface, other.panelSurface, t)!,
      panelDivider: Color.lerp(panelDivider, other.panelDivider, t)!,
      activeTab: Color.lerp(activeTab, other.activeTab, t)!,
      dropZoneHighlight: Color.lerp(
        dropZoneHighlight,
        other.dropZoneHighlight,
        t,
      )!,
      dropZoneValid: Color.lerp(dropZoneValid, other.dropZoneValid, t)!,
      dropZoneInvalid: Color.lerp(dropZoneInvalid, other.dropZoneInvalid, t)!,
      sectionHeader: Color.lerp(sectionHeader, other.sectionHeader, t)!,
      statusBarBackground: Color.lerp(
        statusBarBackground,
        other.statusBarBackground,
        t,
      )!,
      chordPopupBackground: Color.lerp(
        chordPopupBackground,
        other.chordPopupBackground,
        t,
      )!,
      chordPopupForeground: Color.lerp(
        chordPopupForeground,
        other.chordPopupForeground,
        t,
      )!,
      shortcutKeyBackground: Color.lerp(
        shortcutKeyBackground,
        other.shortcutKeyBackground,
        t,
      )!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
    );
  }
}
