import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'forge_editor.dart';

/// A visual/canvas-based editor with element selection and viewport control.
abstract class ForgeVisualEditor extends ForgeEditor {
  /// The currently selected elements.
  ValueListenable<List<Object>> get selectedElements;

  /// Whether any element is currently selected.
  bool get hasElementSelection;

  /// Select elements programmatically.
  void selectElements(List<Object> elements);

  /// Clear the current selection.
  void clearSelection();

  /// The current viewport (visible area of the canvas).
  ValueListenable<Rect> get viewport;

  /// Pan/zoom to reveal a specific area.
  void revealArea(Rect area);

  /// Zoom to fit all content in the viewport.
  void zoomToFit();

  /// The current zoom level (1.0 = 100%).
  ValueListenable<double> get zoomLevel;

  /// Set the zoom level.
  void setZoom(double level);
}
