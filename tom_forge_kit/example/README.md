# tom_forge_kit example

One window without editors: it builds a `DefaultKitApi` over a
`ForgeMemoryStateStore` and an in-memory file system, registers a module and
shows the kit's actions as text. Building it for the web, iOS, Android and
macOS shows the kit builds on each:

```sh
flutter build web
flutter build apk --debug
flutter build ios --debug --no-codesign
flutter build macos --debug
```
