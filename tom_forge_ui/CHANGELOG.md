## Unreleased

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
