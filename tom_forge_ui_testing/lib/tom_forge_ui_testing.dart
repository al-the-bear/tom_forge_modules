/// Test support for Forge's shell and editors.
///
/// - **Undo conformance**: [runForgeUndoConformance], [ForgeUndoSubject] —
///   the history contract every editor's suite runs.
/// - **Shell test doubles**: [ForgeTestDocument], [ForgeTestTextEditor],
///   [ForgeTestModule], [ForgeTestWorkspace].
///
/// It imports `flutter_test`, so it is a package of its own: a suite takes it
/// in `dev_dependencies`, and `tom_forge_ui` itself stays free of the test
/// framework.
library;

export 'src/test_document.dart';
export 'src/test_module.dart';
export 'src/test_text_editor.dart';
export 'src/test_workspace.dart';
export 'src/undo_conformance.dart';
