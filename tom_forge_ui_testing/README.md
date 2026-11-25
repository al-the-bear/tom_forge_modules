# Tom Forge UI Testing

Test support for Forge's shell (`tom_forge_ui`) and its editors:

- **The undo conformance harness** — `runForgeUndoConformance` and
  `ForgeUndoSubject`: the history contract every Forge editor's suite runs
  (`tom_ai/forge_modules/_agent_guidelines/editor_history_contract.md`). An editor's
  suite describes how to drive it with a `ForgeUndoSubject` and calls the
  harness; a check the editor does not meet yet is skipped with its reason.
- **Shell test doubles** — `ForgeTestDocument`, `ForgeTestTextEditor`,
  `ForgeTestModule` and `ForgeTestWorkspace`, which the shell's widget and
  integration suites build on.
- **File kinds** — `ForgeFileKindTestBed`: a file kind's editors
  (`ForgeKitFileKind`) made as a file module of the shell makes them, over a
  `ForgeFileSession` of an in-memory shell, so the package that exports the
  kind (an editor adapter) runs its suites without the file editors module.

It depends on `flutter_test`, so it is a package of its own and is taken only
in `dev_dependencies`:

```yaml
dev_dependencies:
  tom_forge_ui_testing:
    path: ../tom_forge_ui_testing
```

```dart
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';
```

A module's undo subjects, which other packages' suites drive too, are in a
test-support package of their own that takes this one as a dependency
(`tom_forge_file_editors_testing`, `tom_forge_pdf_pdfium_testing`,
`tom_forge_pdf_pdfjs_testing`); the
module itself takes both only as dev_dependencies. So are an editor
adapter's file kind subjects (`tom_forge_md_editor_testing`,
`tom_forge_yaml_editor_testing`).

## License

BSD-3-Clause; see [LICENSE](LICENSE).
