import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';

/// Size hints for shell layout.
class ForgeComponentSizeHints {
  final Size minSize;
  final Size preferredSize;
  final Size maxSize;

  const ForgeComponentSizeHints({
    this.minSize = const Size(120, 80),
    this.preferredSize = const Size(260, 200),
    this.maxSize = const Size(double.infinity, double.infinity),
  });
}

/// Base contract for any component hosted in the forge shell.
///
/// Components are either editors (closable, tied to a URI) or
/// views (persistent panels like explorer or output).
abstract class ForgeComponent {
  /// Display title for tabs and headers.
  ValueListenable<String> get title;

  /// Optional subtitle shown under accordion titles.
  ValueListenable<String?> get titleExtension;

  /// Icon for tab display.
  IconData get icon;

  /// Whether this is an editor (closable) or a view.
  bool get isEditor;

  /// Size hints for accordion layout.
  ForgeComponentSizeHints get sizeHints;

  /// Whether this component supports multi-render (UI copies).
  bool get supportsMultiRender => true;

  /// Whether this component can be dragged to another panel/area.
  ///
  /// Returns `false` for components that must remain in their current
  /// panel (e.g. terminal sections that belong to the terminal manager).
  bool get isDraggable => true;

  /// Create the main Flutter widget for this component.
  Widget buildMain(BuildContext context);

  /// Create a copy widget for multi-render scenarios.
  Widget buildCopy(BuildContext context);

  /// Actions this component contributes to menus/command palette.
  List<ForgeAction> get actions => [];

  /// Actions shown as icon buttons in the accordion section header.
  ///
  /// These appear as small icon buttons next to the pin/close controls
  /// when this component is displayed as an accordion section. Useful
  /// for panel-specific quick actions (e.g. "Clear" or "Kill" for terminals).
  List<ForgeAction> get headerActions => [];

  /// Shortcut bindings when this component is focused.
  List<ForgeShortcutBinding> get shortcuts => [];
}
