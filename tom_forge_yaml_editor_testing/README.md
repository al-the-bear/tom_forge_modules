# Tom Forge YAML Editor Testing

Test support for `tom_forge_yaml_editor`: the YAML file kind's editor
(`ForgeYamlFileEditor`) as the undo subject `ForgeYamlFileSubject`. It
describes how to drive the editor for Forge's undo conformance harness
(`tom_forge_ui_testing`), so the adapter's own suite (through the kind,
`ForgeFileKindTestBed`) and an application's suite (e.g. `tom_forge_app`'s,
through the file editors module it composes) run the same checks.

It depends on `flutter_test`, so it is a package of its own and is taken only
in `dev_dependencies`:

```yaml
dev_dependencies:
  tom_forge_yaml_editor_testing:
    path: ../tom_forge_yaml_editor_testing
```

```dart
import 'package:tom_forge_yaml_editor_testing/tom_forge_yaml_editor_testing.dart';
```

## License

BSD-3-Clause; see [LICENSE](LICENSE).
