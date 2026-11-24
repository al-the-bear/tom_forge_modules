## Unreleased

* The views, quick open and the command palette are packages of their own on
  the kit (`tom_forge_file_explorer`, `tom_forge_search_view`,
  `tom_forge_problems_view`, `tom_forge_outline_view`,
  `tom_forge_output_view`, `tom_forge_revision_view`, `tom_forge_quick_open`,
  `tom_forge_command_palette`), re-exported here; `forgeDesktopViewModules()`
  makes their modules and the terminal's (`forgeTerminalModule()`, which
  places the terminal tab). `ForgeCommandPalette` takes `api:` (a
  `ForgeKitApi`) instead of `shellApi:`.
* The plain-text editor is the adapter package `tom_forge_plain_text_editor`
  (`ForgePlainTextEditor` over `tom_file_editors`' text file editor),
  re-exported here; the shell no longer exports it.
* The code editors are three adapter packages on the kit, re-exported here:
  `tom_forge_md_editor`, `tom_forge_dart_editor` and `tom_forge_yaml_editor`;
  `forgeDesktopComponents` takes their editor types. `tom_forge_code_editors`
  stays re-exported for one release, with the helpers it keeps.
* The native file dialogs and the `dart:io` host pieces moved out of the core
  into `tom_forge_desktop_host` (re-exported here, part of
  `forgeDesktopComponents`): the core reaches them through the
  `ForgeFilePickers` and `ForgeHostEnvironment` ports and builds for the web.
  `ForgeShellScaffold.onOpenFolder` passes the picked folder's path (a
  `String`) instead of a `Directory`.
* The package is the umbrella of Forge's panel shell: the code moved to
  `tom_forge_shell` (the core), `tom_forge_terminal`, `tom_forge_code_editors`
  and `tom_forge_platform_secrets`, all re-exported here. Shells take the
  terminal, the code editors and the keychain from `ForgeShellComponents`:
  `components: forgeDesktopComponents`, or `useForgeDesktopComponents()` once
  at start; without them a shell has the core's (no terminals, secrets in
  memory, files as plain text). `TomForgeShellModule.registerMdEditor` /
  `mdEditors` and their Dart and YAML twins, and
  `DefaultLayoutController.dartSummaryAssets`, are extensions from
  `tom_forge_code_editors`.

## 0.0.1

* TODO: Describe initial release.
