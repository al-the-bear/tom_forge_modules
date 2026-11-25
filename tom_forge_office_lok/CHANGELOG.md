# Changelog

## Unreleased

- The helper is named as looked for: the application's bundle, then
  `$TOM_BINARY_PATH` (`findHelper`), in the module's documentation and in the
  error when neither has it.
- The install runner, checked on bigbeast and legiondary01: executables are
  found through `installExecutableExists` (winget's alias), PATH folders lose
  a trailing backslash, each command's input is closed so a prompt ends
  instead of hanging, and the elevated Chocolatey log is decoded by its
  byte-order mark (`forgeDecodeInstallLog`, UTF-16 from Windows PowerShell);
  a log read error no longer replaces the exit code.
- LibreOffice's install help (`TomLibreOfficeInstallHelp`, DPLD-3) in the
  missing-LibreOffice panel (missing, too old, unusable; *Choose
  LibreOffice…* and the alternative route kept) and in the External Tools row
  (`ForgeLibreOfficeTool.buildHelp`, `helpBuilder`, `lastInstallation`).
- `ForgeLibreOfficeInstaller` runs a confirmed route: Homebrew and winget as
  the user, Chocolatey in an elevated PowerShell, apt/dpkg/rpm through
  `pkexec`, TDF's Linux archive downloaded, checked against its published
  SHA-256, unpacked and installed; `PATH` with Homebrew's folders on macOS
  (`forgeInstallSearchPath`); output streamed, *Stop* kills; detection runs
  again when it ends. Injectable process starter
  (`ForgeInstallProcessStarter`) and HTTP (`ForgeInstallHttp`).
- `ForgeOfficeLokModule`: `installer`, `install(route)`,
  `buildInstallHelp(installation)`; `ForgeOfficePanelActions.installHelp`.
- New dependency: `crypto` (the SHA-256 check).

## 0.1.0

- The LibreOfficeKit office adapter, moved out of `tom_forge_office_editors`
  (split by route, R6): `ForgeOfficeLokModule` (a kit module: `activate(ForgeKitApi)`,
  no shell), `ForgeOfficeEditor`, `ForgeOfficeHost` (over `ForgeKitApi`),
  `ForgeOfficeKind`, `ForgeLibreOfficeTool` (contributed as the kit's
  `ForgeExternalToolsExtra`), `kForgeOfficeDebug`.
- Another route joins as `ForgeOfficeAlternativeRoute` (the missing-LibreOffice
  panel's button, the file-type default, its open editors); what the kit has no
  port for is given: `preferences`, `openExternal`, `filePickers`, `windowFocus`.
