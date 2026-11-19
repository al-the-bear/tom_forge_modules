# Tom Forge Shared UI example

A minimal app over `tom_forge_shared_ui`: a panel and a status bar drawn with
the shell theme's tokens and dimensions, following the platform's brightness
and high-contrast setting. Building it for each platform shows the package
builds there:

```sh
flutter build macos
flutter build web
flutter build ios --no-codesign
flutter build apk
```
