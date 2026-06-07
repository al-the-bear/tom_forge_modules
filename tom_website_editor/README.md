# tom_website_editor

Tom Forge module for editing and driving `enterprise_flutter_web` websites. It
wraps the pure-Dart [`tom_website_editor_core`](../tom_website_editor_core)
(config + placeholders + registry) in a [`ForgeModule`] that contributes the
active-website selection / reload config panel to the forge shell.

This package implements **steps 2 and 3** (§9.2, §9.3) of the implementation
plan in `tom_website_editor_specification.md`. The control view (§9.4), the
dev-server lifecycle / auto-refresh (§9.5), and the dedicated
`WebsiteConfigEditor` (§6) are added in later steps; they build on the shared
`WebsiteEditorController` this module exposes.

## What it provides

| API | Purpose |
| --- | --- |
| `WebsiteEditorModule` | `ForgeModule` that loads `tom.website-editor.yaml` from the workspace root on activation, contributes the website config panel, and registers the preview view. |
| `WebsiteEditorController` | `ChangeNotifier` owning the `WebsiteRegistry`: async load/reload of the config source, the active-website selection, and the loading/issues state for the UI. |
| `WebsiteConfigPanel` | Settings-dialog widget to pick the active website and reload the config; lists validation issues inline. |
| `WebsitePreviewController` | `ChangeNotifier` wrapping the editor controller: resolves the active website's `preview.devUrl` / `preview.builtIndex` via the placeholder resolver, exposes a reload token, a dev/built source toggle, and external-browser open through an injected opener. |
| `WebsitePreviewView` | `ForgeView` embedding the resolved preview URL in a webview, with a toolbar to pick the website, toggle the source, reload, and open in an external browser. |

## Architecture

The module is intentionally thin — the behaviour lives in two well-tested
layers below it, so the shell-facing glue carries almost no logic:

```
WebsiteEditorModule        (forge wiring: resolve config Uri, read via shell FS)
        │ owns
WebsiteEditorController     (Flutter ChangeNotifier: async read + notify + flags)
        │ owns                         ▲ wraps
WebsiteRegistry  ← core      WebsitePreviewController → WebsitePreviewView (ForgeView)
(load/select/reload)         (resolve URL, source toggle, refresh, open-external)
```

`WebsiteEditorController` takes a `WebsiteConfigReader` (`Future<String>
Function()`) so it can be exercised in tests without a live shell; the module
wires it to `ForgeShellApi.fileSystem.read(configUri)`.

`WebsitePreviewView` takes an injectable `PreviewWebViewBuilder` so widget tests
render a stub instead of the platform `InAppWebView`; in production it loads the
URL in a `flutter_inappwebview` view, keyed on `url#reloadToken` so a refresh
recreates the platform view. The external-browser opener is likewise injected
(`ExternalUrlOpener`), defaulting to the host OS launcher (`open` / `xdg-open` /
`start`) — no `url_launcher` dependency. A placeholder-resolution failure is
surfaced as an inline error (with the offending token and location) rather than
a blank preview.

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
- `test/website_preview_controller_test.dart` — URL resolution per source,
  recompute on selection, refresh token, resolve-error surfacing, external open
  (TWE-PREV-CTL-01..10).
- `test/website_preview_view_test.dart` — webview URL rendering, source toggle,
  website picker, refresh, error state, external open, reactive title
  (TWE-PREV-VIEW-01..07).
