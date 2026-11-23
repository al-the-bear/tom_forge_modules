import 'package:tom_editors_shared/text_types.dart' show ForgeTextContext;
import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_component.dart';
import '../components/forge_editor.dart';

/// The observable state a component sees, free of any layout: which
/// component has the focus, the open editors and the active one, unsaved
/// work, diagnostics, and the event streams that report their changes.
///
/// A host keeps it current (the panel shell's `ForgeSystemState` extends it
/// with its layout; a host that is not the panel shell feeds a
/// `DefaultKitState`).
abstract class ForgeKitState {
  // ── Focus ──

  /// The component that has the focus, or null.
  ForgeComponent? get focusedComponent;

  // ── Editors ──

  /// Every open editor, in the order they were opened.
  List<ForgeEditor> get openEditors;

  /// The editor the user works in, or null.
  ForgeEditor? get activeEditor;

  /// The open editors with unsaved changes.
  List<ForgeEditor> get dirtyEditors;

  /// Whether any open editor has unsaved changes.
  bool get hasUnsavedChanges;

  // ── Component context ──

  /// The text selected in the focused component, when it has any.
  String? get focusedSelectedText;

  // ── Problems ──

  DiagnosticSummary get diagnosticSummary;
  List<ForgeDiagnostic> get diagnostics;

  // ── Streams ──

  Stream<FocusChangeEvent> get onFocusChanged;
  Stream<DirtyStateEvent> get onDirtyStateChanged;
  Stream<DiagnosticChangeEvent> get onDiagnosticsChanged;
  Stream<EditorListChangeEvent> get onEditorsChanged;

  // ── Editor context bridge ──

  void updateEditorContext(String editorId, ForgeTextContext context);
  ForgeTextContext? getEditorContext(String editorId);
}
