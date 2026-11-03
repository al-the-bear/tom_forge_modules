import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
  show ForgeTextContext;

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

  /// Moves focus to the next visible panel in cycle order
  /// (left → middle → right → bottom → left).
  void focusNextPanel();

  /// Moves focus to the previous visible panel in reverse cycle order
  /// (left ← middle ← right ← bottom ← left).
  void focusPreviousPanel();

  // ── Editors ──
  List<ForgeEditor> get openEditors;
  ForgeEditor? get activeEditor;
  List<ForgeEditor> get dirtyEditors;
  bool get hasUnsavedChanges;

  // ── Component Context ──
  String? get focusedSelectedText;

  // ── Explorer / Selection ──
  List<Uri> get selectedExplorerItems;
  Uri? get hoveredExplorerItem;

  // ── Problems ──
  DiagnosticSummary get diagnosticSummary;
  List<ForgeDiagnostic> get diagnostics;

  // ── Workspace ──
  String get workspaceRootPath;

  // ── Application ──
  ForgeApplication? get activeApplication;
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
  Stream<DiagnosticChangeEvent> get onDiagnosticsChanged;
  Stream<EditorListChangeEvent> get onEditorsChanged;
  Stream<WindowFocusEvent> get onWindowFocusChanged;
  Stream<LayoutChangeEvent> get onLayoutChanged;
  Stream<ApplicationChangeEvent> get onApplicationChanged;

  // ── Editor Context Bridge ──
  void updateEditorContext(String editorId, ForgeTextContext context);
  ForgeTextContext? getEditorContext(String editorId);
}
