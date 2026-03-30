import 'package:flutter/material.dart';

/// Shell-level theme extension for Forge visual tokens.
///
/// Provides themed colors for panels, drop zones, and status indicators.
/// Use `Theme.of(context).extension<ForgeShellTheme>()` to access.
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

  const ForgeShellTheme({
    required this.panelSurface,
    required this.panelDivider,
    required this.activeTab,
    required this.dropZoneHighlight,
    required this.dropZoneValid,
    required this.dropZoneInvalid,
    required this.sectionHeader,
    required this.statusBarBackground,
  });

  /// Dark theme variant.
  factory ForgeShellTheme.dark() => const ForgeShellTheme(
        panelSurface: Color(0xFF1E1E1E),
        panelDivider: Color(0xFF3C3C3C),
        activeTab: Color(0xFF007ACC),
        dropZoneHighlight: Color(0x33007ACC),
        dropZoneValid: Color(0x5500CC66),
        dropZoneInvalid: Color(0x55CC3333),
        sectionHeader: Color(0xFF252526),
        statusBarBackground: Color(0xFF007ACC),
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
      );

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
    );
  }

  @override
  ForgeShellTheme lerp(ForgeShellTheme? other, double t) {
    if (other is! ForgeShellTheme) return this;
    return ForgeShellTheme(
      panelSurface: Color.lerp(panelSurface, other.panelSurface, t)!,
      panelDivider: Color.lerp(panelDivider, other.panelDivider, t)!,
      activeTab: Color.lerp(activeTab, other.activeTab, t)!,
      dropZoneHighlight:
          Color.lerp(dropZoneHighlight, other.dropZoneHighlight, t)!,
      dropZoneValid: Color.lerp(dropZoneValid, other.dropZoneValid, t)!,
      dropZoneInvalid: Color.lerp(dropZoneInvalid, other.dropZoneInvalid, t)!,
      sectionHeader: Color.lerp(sectionHeader, other.sectionHeader, t)!,
      statusBarBackground:
          Color.lerp(statusBarBackground, other.statusBarBackground, t)!,
    );
  }
}
