import 'package:flutter/widgets.dart';

/// A configuration panel contributed by a [ForgeModule].
///
/// Modules register config panels so they appear in the settings dialog
/// alongside the built-in panels (shell, terminal, shortcuts, etc.).
class ForgeConfigPanel {
  /// Unique identifier for this config panel.
  final String id;

  /// Display title shown in the settings sidebar.
  final String title;

  /// Icon shown next to the title in the sidebar.
  final IconData icon;

  /// Sort priority. Lower values appear first.
  /// Built-in panels use 0–99; modules should use 100+.
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
