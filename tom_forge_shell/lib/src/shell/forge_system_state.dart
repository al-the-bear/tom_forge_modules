import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../model/forge_application.dart';

/// Observable system state for the forge shell: the kit's [ForgeKitState]
/// with the shell's panels, applications, window, explorer, search and
/// layout.
///
/// Provides read-only access to focus, editors, diagnostics,
/// layout, and window state — plus event streams for observation.
abstract class ForgeSystemState extends ForgeKitState {
  // ── Focus ──
  bool get isFocusedComponentMain;
  ForgePanelLocation? get focusedPanelLocation;

  /// Moves focus to the next visible panel in cycle order
  /// (left → middle → right → bottom → left).
  void focusNextPanel();

  /// Moves focus to the previous visible panel in reverse cycle order
  /// (left ← middle ← right ← bottom ← left).
  void focusPreviousPanel();

  // ── Explorer / Selection ──
  List<Uri> get selectedExplorerItems;
  Uri? get hoveredExplorerItem;

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
  Stream<WindowFocusEvent> get onWindowFocusChanged;
  Stream<LayoutChangeEvent> get onLayoutChanged;
  Stream<ApplicationChangeEvent> get onApplicationChanged;
}
