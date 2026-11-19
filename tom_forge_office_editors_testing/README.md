# Tom Forge Office Editors Testing

Test support for `tom_forge_office_editors`: the office editors (LibreOfficeKit, ZetaOffice) as undo subjects, with the checks each skips, a scripted LibreOffice helper, a scripted ZetaOffice page and a tile decoder that needs no real time. They describe how to drive each editor
for Forge's undo conformance harness (`tom_forge_ui_testing`), so the module's
own suite and an application's suite (e.g. `tom_forge_app`'s, through the
module it composes) run the same checks.

It depends on `flutter_test`, so it is a package of its own and is taken only
in `dev_dependencies`:

```yaml
dev_dependencies:
  tom_forge_office_editors_testing:
    path: ../tom_forge_office_editors_testing
```

```dart
import 'package:tom_forge_office_editors_testing/tom_forge_office_editors_testing.dart';
```

## License

BSD-3-Clause; see [LICENSE](LICENSE).
