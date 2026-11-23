/// Test support for Forge's shell and editors.
///
/// - **Undo conformance**: [runForgeUndoConformance], [ForgeUndoSubject] —
///   the history contract every editor's suite runs.
/// - **Shell test doubles**: [ForgeTestDocument], [ForgeTestTextEditor],
///   [ForgeTestModule], [ForgeTestWorkspace].
/// - **File kinds**: [ForgeFileKindTestBed] makes a file kind's editors as
///   a file module of the shell makes them, for the suite of the package
///   that exports the kind.
///
/// It imports `flutter_test`, so it is a package of its own: a suite takes it
/// in `dev_dependencies`, and `tom_forge_ui` itself stays free of the test
/// framework.
library;

export 'src/file_kind_test_bed.dart';
export 'src/test_document.dart';
export 'src/test_module.dart';
export 'src/test_text_editor.dart';
export 'src/test_workspace.dart';
export 'src/undo_conformance.dart';
