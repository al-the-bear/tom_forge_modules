import 'package:flutter/widgets.dart';

/// A configuration panel contributed by a [ForgeModule]: a widget of the
/// module's own, shown in the configuration side panel after the described
/// sections.
///
/// A module describes its options as a configuration description instead
/// (`ForgeConfigurationDescriptionsExtra`, with its storage bindings and
/// hooks), which the side panel shows as a tile; a panel is for what no
/// setting kind describes yet.
class ForgeConfigPanel {
  /// Unique identifier for this config panel.
  final String id;

  /// Display title shown in the settings sidebar.
  final String title;

  /// Icon shown next to the title in the sidebar.
  final IconData icon;

  /// Sort priority among the module panels. Lower values appear first;
  /// 100+ is recommended.
  final int priority;

  /// Builder for the config panel widget.
  ///
  /// Receives the current [BuildContext] and should return a widget
  /// that can modify its own settings (no save/cancel buttons — the
  /// dialog handles that).
  final Widget Function(BuildContext context) builder;

  /// Optional callback invoked when the dialog's Save button is pressed.
  /// Modules should persist their settings here.
  final Future<void> Function()? onSave;

  const ForgeConfigPanel({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    this.priority = 100,
    this.onSave,
  });
}
