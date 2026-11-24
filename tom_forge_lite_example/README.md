# tom_forge_lite_example

The light panel shell example of Tom Forge's parts: Forge's panel shell
(`tom_forge_shell`) with the file explorer (`tom_forge_file_explorer`) on the
left and the YAML editor (`tom_forge_yaml_editor`) in the middle, and nothing
else: no terminal, webview, analyzer, office or PDF editor, no keychain.

It is assembled from the parts themselves, without `composeForgeSuite`
(`lib/src/lite_shell.dart`): a `DefaultShellApi` over the workspace folder
given the YAML editor type, the shell's own module (the shell actions and the
standard editing actions), the file explorer's kit module, and one panel
application whose left panel is laid out from the contributed views. Every
file that is not YAML opens in the shell's plain-text editor.

## Running it

```bash
flutter run -d macos                                    # the current folder
flutter run -d macos --dart-entrypoint-args ~/notes
```

The workspace folder is the one the command line names, else the current
directory, else (an app started from the Finder runs in `/`) a sample folder
under `~/Library/Application Support/tom_forge_lite_example/` (written the
first time, kept afterwards). A release build:

```bash
flutter build macos --release
build/macos/Build/Products/Release/tom_forge_lite_example.app/Contents/MacOS/tom_forge_lite_example ~/notes
```

### Debug trails

`--trail=yaml` switches on the YAML editor's trail (`kYamlEditorDebug`,
prefix `[YE]`), `--trail=kit` the editor integration's (the action and key
routing between an editor and the shell, `kShellEditorIntegrationDebug`),
`--trail` alone both. A release build prints nothing to stdout; read its
trail with `/usr/bin/log show --predicate 'process == "tom_forge_lite_example"'`.

## Tests

```bash
flutter test                                                   # widget tests
flutter test integration_test/lite_shell_macos_test.dart -d macos
```

Both open a YAML file from the explorer, edit it, undo the edit through the
shell, edit it again and save it through the shell, then check the file's
content.

## License

BSD-3-Clause, see [LICENSE](LICENSE).
