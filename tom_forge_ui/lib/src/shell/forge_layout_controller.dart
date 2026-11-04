import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_component.dart';
import '../components/forge_editor.dart';

/// Layout control — open/close panels, focus components, open files.
abstract class ForgeLayoutController {
  void openPanel(ForgePanelLocation location);
  void closePanel(ForgePanelLocation location);
  void togglePanel(ForgePanelLocation location);
  void focusComponent(ForgeComponent component);
  void openFile(Uri uri, {int? middlePanelIndex, int? line, int? column});
  void openEditor(ForgeEditor editor, Uri uri, {int? middlePanelIndex});

  /// Closes [editor] in every middle panel and drops it from the open set,
  /// without asking about unsaved work — for a module whose own model has
  /// already closed what the editor showed.
  void closeEditor(ForgeEditor editor);
  Future<void> openFileWith(Uri uri, {int? middlePanelIndex});
  void splitMiddlePanel();

  /// Split and insert a new panel at [position] containing [editor].
  ///
  /// Removes the editor from its current panel, creates a new panel at
  /// the given position index, and places the editor there. Respects
  /// the maximum panel count (4).
  void splitAndInsertPanel(int position, ForgeEditor editor);

  /// Move a component from one panel to another.
  void moveComponent(ForgeComponent component, int targetPanelIndex);

  /// Create a UI copy of a component in the target panel.
  ///
  /// The copy shares data state with the original but has independent
  /// UI state (scroll position, cursor, etc.).
  void copyComponent(ForgeComponent component, int targetPanelIndex);

  LayoutPanelConfig? getPanelConfig(ForgePanelLocation location);
  int get activeMiddlePanelIndex;
  void setActiveMiddlePanelIndex(int index);
  void revealInExplorer(Uri uri);
}

/// Simplified panel config returned from layout queries.
class LayoutPanelConfig {
  final double size;
  final bool isVisible;

  const LayoutPanelConfig({this.size = 250, this.isVisible = true});
}
