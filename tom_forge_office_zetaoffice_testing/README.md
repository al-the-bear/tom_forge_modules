# Tom Forge Office ZetaOffice Testing

Test support for `tom_forge_office_zetaoffice`: the ZetaOffice editor as an
undo subject (`ForgeZetaOfficeEditorSubject`), with the checks it skips
(`forgeZetaOfficeEditorSkips`) and a scripted ZetaOffice page
(`ScriptedZetaOfficePage`), for Forge's undo conformance harness
(`tom_forge_ui_testing`); and the adapter's test bed: the module in a panel
shell over a memory file system (`ForgeZetaOfficeWorkspace`, which can
register modules before it — the LibreOfficeKit module, as Forge composes
them). The adapter's own suite and an application's suite run the same
checks.

It depends on `flutter_test` and the panel shell, so it is a package of its
own and is taken only in `dev_dependencies`; the shell reaches the suites,
never the adapter:

```yaml
dev_dependencies:
  tom_forge_office_zetaoffice_testing:
    path: ../tom_forge_office_zetaoffice_testing
```

```dart
import 'package:tom_forge_office_zetaoffice_testing/tom_forge_office_zetaoffice_testing.dart';
```

## License

BSD-3-Clause; see [LICENSE](LICENSE).
