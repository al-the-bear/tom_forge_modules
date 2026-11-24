# Tom Forge Office LibreOfficeKit Testing

Test support for `tom_forge_office_lok`: the LibreOfficeKit editor as an undo
subject (`ForgeOfficeEditorSubject`), with the checks it skips
(`forgeOfficeEditorSkips`), a scripted LibreOffice helper
(`ScriptedOfficeHelper`) and a tile decoder that needs no real time
(`forgeOfficeTestDecoder`), for Forge's undo conformance harness
(`tom_forge_ui_testing`); and the adapter's test bed: the module in a panel
shell over a memory file system (`ForgeOfficeLokWorkspace`) and the panel
shell's External Tools section (`pumpForgeExternalToolsSection`,
`forgeShellExternalToolsOf`). `package:tom_forge_office_lok_testing/adapter.dart`
re-exports the adapter, for another package's suite that composes it with its
own (the ZetaOffice adapter's). The adapter's own suite and an
application's suite (e.g. `tom_forge_app`'s, through the module it composes)
run the same checks.

It depends on `flutter_test` and the panel shell, so it is a package of its
own and is taken only in `dev_dependencies`; the shell reaches the suites,
never the adapter:

```yaml
dev_dependencies:
  tom_forge_office_lok_testing:
    path: ../tom_forge_office_lok_testing
```

```dart
import 'package:tom_forge_office_lok_testing/tom_forge_office_lok_testing.dart';
```

## License

BSD-3-Clause; see [LICENSE](LICENSE).
