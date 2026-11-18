# Tom Forge UI Testing

Test support for Forge's shell (`tom_forge_ui`) and its editors:

- **The undo conformance harness** — `runForgeUndoConformance` and
  `ForgeUndoSubject`: the history contract every Forge editor's suite runs
  (`tom_forge/_copilot_guidelines/editor_history_contract.md`). An editor's
  suite describes how to drive it with a `ForgeUndoSubject` and calls the
  harness; a check the editor does not meet yet is skipped with its reason.
- **Shell test doubles** — `ForgeTestDocument`, `ForgeTestTextEditor`,
  `ForgeTestModule` and `ForgeTestWorkspace`, which the shell's widget and
  integration suites build on.

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

A package whose own library builds undo subjects for others (for example
`tom_forge_file_editors/lib/testing.dart`) takes it in `dependencies`.

## License

BSD-3-Clause; see [LICENSE](LICENSE).
