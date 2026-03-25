import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_component.dart';
import '../components/forge_editor.dart';
import '../model/forge_application.dart';

/// Observable system state for the forge shell.
///
/// Provides read-only access to focus, editors, diagnostics,
/// layout, and window state — plus event streams for observation.
abstract class ForgeSystemState {
  // ── Focus ──
  ForgeComponent? get focusedComponent;
  bool get isFocusedComponentMain;
  ForgePanelLocation? get focusedPanelLocation;

  // ── Editors ──
  List<ForgeEditor> get openEditors;
  ForgeEditor? get activeEditor;
  List<ForgeEditor> get dirtyEditors;
  bool get hasUnsavedChanges;

  // ── Component Context ──
  String? get focusedSelectedText;
  bool get hasTextSelection;

  // ── Explorer / Selection ──
  List<Uri> get selectedExplorerItems;
  Uri? get hoveredExplorerItem;

  // ── Problems ──
  DiagnosticSummary get diagnosticSummary;
  List<ForgeDiagnostic> get diagnostics;

  // ── Workspace ──
  String get workspaceRootPath;

  // ── Application ──
  ForgeApplication get activeApplication;
  List<ForgeApplication> get applications;

  // ── Layout ──
  Set<ForgePanelLocation> get visiblePanels;
  int get middlePanelCount;
  int get activeMiddlePanelIndex;

  // ── Window ──
  bool get isWindowFocused;

  // ── Search ──
  String get searchQuery;
  bool get isSearchActive;

  // ── Streams ──
  Stream<FocusChangeEvent> get onFocusChanged;
  Stream<DirtyStateEvent> get onDirtyStateChanged;
  Stream<SelectionChangeEvent> get onSelectionChanged;
  Stream<TextSelectionChangeEvent> get onTextSelectionChanged;
  Stream<DiagnosticChangeEvent> get onDiagnosticsChanged;
  Stream<EditorListChangeEvent> get onEditorsChanged;
  Stream<WindowFocusEvent> get onWindowFocusChanged;
  Stream<LayoutChangeEvent> get onLayoutChanged;
}
