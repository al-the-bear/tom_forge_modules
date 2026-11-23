import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// Draws the context menu for [target] at [globalPosition] and runs the
/// chosen entry: the entries [controller] resolves at the target, drawn by
/// the shared [showForgeKitContextMenu]. Nothing is drawn when nothing
/// applies at the target.
Future<void> showForgeContextMenu(
  BuildContext context, {
  required ForgeContextMenuController controller,
  required ForgeContextTarget target,
  required Offset globalPosition,
}) => showForgeKitContextMenu(
  context,
  controller: controller,
  target: target,
  globalPosition: globalPosition,
);
