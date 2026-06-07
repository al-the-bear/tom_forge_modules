# tom_website_editor

Tom Forge module for editing and driving `enterprise_flutter_web` websites. It
wraps the pure-Dart [`tom_website_editor_core`](../tom_website_editor_core)
(config + placeholders + registry) in a [`ForgeModule`] that contributes the
active-website selection / reload config panel to the forge shell.

This package implements **step 2** (§9.2) of the implementation plan in
`tom_website_editor_specification.md`. The preview view (§9.3), control view
(§9.4), and the dedicated `WebsiteConfigEditor` (§6) are added in later steps;
they will build on the shared `WebsiteEditorController` this module exposes.

## What it provides

| API | Purpose |
| --- | --- |
| `WebsiteEditorModule` | `ForgeModule` that loads `tom.website-editor.yaml` from the workspace root on activation and contributes the website config panel. |
| `WebsiteEditorController` | `ChangeNotifier` owning the `WebsiteRegistry`: async load/reload of the config source, the active-website selection, and the loading/issues state for the UI. |
| `WebsiteConfigPanel` | Settings-dialog widget to pick the active website and reload the config; lists validation issues inline. |

## Architecture

The module is intentionally thin — the behaviour lives in two well-tested
layers below it, so the shell-facing glue carries almost no logic:

```
WebsiteEditorModule        (forge wiring: resolve config Uri, read via shell FS)
        │ owns
WebsiteEditorController     (Flutter ChangeNotifier: async read + notify + flags)
        │ owns
WebsiteRegistry            (pure Dart: load / select / reload + last-good)   ← core
```

`WebsiteEditorController` takes a `WebsiteConfigReader` (`Future<String>
Function()`) so it can be exercised in tests without a live shell; the module
wires it to `ForgeShellApi.fileSystem.read(configUri)`.

## Reload contract (§6)

`reload()` re-reads the config source and applies it. On **valid** source the
registry is replaced and the active selection is preserved when its id still
exists (otherwise it resets to the first website). On **invalid** source the
last-good registry is kept, `reload()` returns `false`, and the new issues are
exposed on `controller.issues` for the panel to display.

## Testing

This is a Flutter package, so use `flutter` (not `dart test` / `testkit`):

```bash
flutter analyze
flutter test
```

- `test/website_editor_controller_test.dart` — controller load/select/reload,
  notifications, loading flag, last-good-on-invalid (TWE-CTL-01..08).
- `test/website_config_panel_test.dart` — panel rendering, selection, reload
  button, issue listing (TWE-PANEL-01..04).
