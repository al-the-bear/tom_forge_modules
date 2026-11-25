import 'package:flutter/material.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart'
    show
        TomDescriptionPlacement,
        TomFieldStyle,
        TomFormFieldFamily,
        TomFormStyle;

/// The settings of a configuration tile itself — the same for every tile an
/// application shows, so they all look alike. Colours come from the theme
/// (`ForgeShellTheme` when installed, else the colour scheme).
@immutable
class ForgeConfigurationTileStyle {
  const ForgeConfigurationTileStyle({
    this.padding = const EdgeInsets.all(12),
    this.spacing = 12,
    this.headerSpacing = 8,
    this.dense = false,
    this.borderRadius = 8,
    this.borderWidth = 1,
    this.showHeader = true,
    this.showIcons = true,
    this.fieldFamily = TomFormFieldFamily.material,
    this.formStyle = defaultFormStyle,
    this.stackedBelowWidth = 280,
  });

  /// The form style the tiles give `tom_flutter_ui`'s fields: no reserved
  /// description line under a field (the tile shows help and messages
  /// itself), and hints in the theme's full hint colour, so they stay
  /// readable (WCAG AA) on the tile's surface.
  static const TomFormStyle defaultFormStyle = TomFormStyle(
    defaults: TomFieldStyle(
      descriptionPlacement: TomDescriptionPlacement.tooltip,
      hintOpacity: 1,
    ),
  );

  /// [defaultFormStyle] with less padding inside the fields.
  static const TomFormStyle compactFormStyle = TomFormStyle(
    defaults: TomFieldStyle(
      descriptionPlacement: TomDescriptionPlacement.tooltip,
      hintOpacity: 1,
      labelFieldGap: 2,
      errorFieldGap: 2,
      fieldContentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
  );

  /// The compact preset: less padding and spacing, dense controls.
  static const compact = ForgeConfigurationTileStyle(
    padding: EdgeInsets.all(8),
    spacing: 6,
    headerSpacing: 4,
    dense: true,
    formStyle: compactFormStyle,
  );

  /// The space between the tile's border and its content.
  final EdgeInsets padding;

  /// The space between two settings.
  final double spacing;

  /// The space below the header.
  final double headerSpacing;

  /// Whether the controls are drawn dense.
  final bool dense;

  /// The corner radius of the tile.
  final double borderRadius;

  /// The width of the tile's border (0: none).
  final double borderWidth;

  /// Whether the tile shows its section's title (an application that shows
  /// the title itself, as a side panel's header, turns it off).
  final bool showHeader;

  /// Whether the header shows the section's icon.
  final bool showIcons;

  /// The family of `tom_flutter_ui` fields the editors use (Material or
  /// Cupertino).
  final TomFormFieldFamily fieldFamily;

  /// The `tom_flutter_ui` form style the fields are drawn with (a
  /// `TomFormStyleScope` around each tile's settings).
  final TomFormStyle formStyle;

  /// The width of a setting's row below which an editor drawn beside its
  /// label (a switch, a colour) goes on a line of its own under the label,
  /// with the setting's buttons, so a narrow panel shows every control.
  final double stackedBelowWidth;

  /// A copy with the given values replaced.
  ForgeConfigurationTileStyle copyWith({
    EdgeInsets? padding,
    double? spacing,
    double? headerSpacing,
    bool? dense,
    double? borderRadius,
    double? borderWidth,
    bool? showHeader,
    bool? showIcons,
    TomFormFieldFamily? fieldFamily,
    TomFormStyle? formStyle,
    double? stackedBelowWidth,
  }) => ForgeConfigurationTileStyle(
    padding: padding ?? this.padding,
    spacing: spacing ?? this.spacing,
    headerSpacing: headerSpacing ?? this.headerSpacing,
    dense: dense ?? this.dense,
    borderRadius: borderRadius ?? this.borderRadius,
    borderWidth: borderWidth ?? this.borderWidth,
    showHeader: showHeader ?? this.showHeader,
    showIcons: showIcons ?? this.showIcons,
    fieldFamily: fieldFamily ?? this.fieldFamily,
    formStyle: formStyle ?? this.formStyle,
    stackedBelowWidth: stackedBelowWidth ?? this.stackedBelowWidth,
  );

  @override
  bool operator ==(Object other) =>
      other is ForgeConfigurationTileStyle &&
      other.padding == padding &&
      other.spacing == spacing &&
      other.headerSpacing == headerSpacing &&
      other.dense == dense &&
      other.borderRadius == borderRadius &&
      other.borderWidth == borderWidth &&
      other.showHeader == showHeader &&
      other.showIcons == showIcons &&
      other.fieldFamily.kind == fieldFamily.kind &&
      identical(other.formStyle, formStyle) &&
      other.stackedBelowWidth == stackedBelowWidth;

  @override
  int get hashCode => Object.hash(
    padding,
    spacing,
    headerSpacing,
    dense,
    borderRadius,
    borderWidth,
    showHeader,
    showIcons,
    fieldFamily.kind,
    identityHashCode(formStyle),
    stackedBelowWidth,
  );
}
