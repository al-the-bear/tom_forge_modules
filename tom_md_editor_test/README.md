# tom_md_editor_test

Integration test app for `tom_md_editor`, including Mermaid WebView rendering.

## Run

```bash
flutter pub get
flutter run --debug
```

## Linux WebView Rendering Notes

- The local Linux `flutter_inappwebview` fork now defaults to software rendering.
- You should not need `FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL=1` anymore.
- To explicitly test hardware mode, run with:

```bash
FLUTTER_INAPPWEBVIEW_LINUX_FORCE_GL=1 flutter run --debug
```

## Diagnostics

To confirm selected rendering mode, filter startup logs for plugin mode lines:

```bash
flutter run --debug 2>&1 | grep -E "software rendering|hardware rendering|CustomPlatformView: using (pixel buffer|GL texture)"
```
