<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->

TODO: Put a short description of the package here that helps potential users
know whether this package might be useful for them.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder. 

```dart
const like = 'sample';
```

## Context-menu contributions

The pure-Dart model behind the shell's context menus
(`src/types/forge_context_menu.dart`):

- `ForgeContextTarget` — what a menu is opened on: a **kind** the producer
  owns (`forge.explorer.file`, `<module>.<unit>`), opaque **data**, and the
  target's own **items** (`ForgeContextMenuItem`: commands only the producer
  can perform, drawn after the contributed entries).
- `ForgeContextMenuContribution` — a module's declaration that one of its
  actions, named by id, is an entry at targets of a kind: `isApplicable`
  (absent when false), `label` and `unavailableReason` (disabled, with the
  reason as tooltip) all read the target. The shell resolves the action from
  its registry and runs it with the target under
  `ForgeContextTarget.parameterKey`.

The drawing lives in `tom_forge_ui` (`ForgeContextMenuController`,
`ForgeContextTargetProvider`). See the repository guideline
`_copilot_guidelines/context_menu_contributions.md`.

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.
