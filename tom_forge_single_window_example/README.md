# tom_forge_single_window_example

The single-window example of Tom Forge's parts: one YAML editor in a window
of its own, without the panel shell. It shows what an application built on
the Forge kit alone looks like.

- **Its own layout.** One window: a bar with the File and Edit menus and the
  toolbar, the editor below it, a status line with the file and whether it
  has unsaved changes (`lib/src/kit_yaml_window.dart`).
- **Its own toolbar and menus from the kit's models.** The menus are
  `ForgeMenuModel`s of the actions the example's module places in File
  (Save) and Edit (Undo, Redo; Cut, Copy, Paste), drawn by
  `ForgeMenuButton`; the toolbar is a `ForgeActionBarModel` drawn by
  `ForgeKitActionBar` (`lib/src/kit_yaml_tool.dart`).
- **Its own `ForgeEditorHost`.** `SingleWindowEditorHost` gives the window
  one editor at a time, opens a file with the YAML editor type, and keeps an
  editor with unsaved changes open (`lib/src/single_window_host.dart`).
- **Undo, redo, the clipboard, keys.** `ForgeEditorSurface` connects the
  editor to the kit: the standard editing actions reach the editor by key,
  by menu and by toolbar alike.

It depends on `tom_forge_kit`, `tom_forge_shared_ui` and the YAML adapter
`tom_forge_yaml_editor` (with `tom_yaml_editor`, `tom_editors_shared` and
`tom_file_system`, which they bring anyway): no `tom_forge_shell`, terminal,
webview, analyzer, office or PDF editor.

## Running it

```bash
flutter run -d macos                                   # the sample file
flutter run -d macos --dart-entrypoint-args ~/notes/config.yaml
```

Without a file on the command line it opens `settings.yaml` under
`~/Library/Application Support/tom_forge_single_window_example/` (written the first
time, kept afterwards). A release build:

```bash
flutter build macos --release
build/macos/Build/Products/Release/tom_forge_single_window_example.app/Contents/MacOS/tom_forge_single_window_example ~/notes/config.yaml
```

### Debug trails

`--trail=yaml` switches on the YAML editor's trail (`kYamlEditorDebug`,
prefix `[YE]`), `--trail=kit` the editor integration's (the action and key
routing between the editor and the kit, `kShellEditorIntegrationDebug`),
`--trail` alone both. A release build prints nothing to stdout; read its
trail with `/usr/bin/log show --predicate 'process == "tom_forge_single_window_example"'`.

## Tests

```bash
flutter test                                                  # widget tests
flutter test integration_test/kit_yaml_macos_test.dart -d macos
```

Both open a YAML file, edit it, undo the edit with Edit > Undo, edit it again
and save it with the toolbar, then check the file's content.

## License

BSD-3-Clause, see [LICENSE](LICENSE).
