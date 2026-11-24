# tom_forge_office_lok

Forge's LibreOfficeKit office adapter: the native office editor
(`tom_office_editor`'s `TomOfficeEditor`: the installed LibreOffice in a helper
process, `tom_office_host`) as a Forge editor over the kit, without the shell
(R9). One kit module, `ForgeOfficeLokModule`, opens office files itself
(before the application reads them as text) in `ForgeOfficeEditor`, the
default office editor, and offers it under *Open With*:

| Choice id | Editor | What it is |
| --- | --- | --- |
| `office.lok` | `ForgeOfficeEditor` | the LibreOfficeKit editor, the default |

| Extensions (any case) | Kind (`ForgeOfficeKind`) | The choice's label |
| --- | --- | --- |
| `.docx` `.odt` `.doc` `.rtf` | `document` | LibreOffice Writer (native) |
| `.xlsx` `.ods` `.xls` `.csv` | `spreadsheet` | LibreOffice Calc (native) |
| `.pptx` `.odp` `.ppt` | `presentation` | LibreOffice Impress (native) |

`.csv` is text: the module offers its editor for it under *Open With* only,
and `openUri` leaves it to the plain-text editor (`handles` answers false).

The ZetaOffice route is another package, `tom_forge_office_zetaoffice` (R6):
this one has no webview and depends on no other route. An application that
takes both wires ZetaOffice in as the module's `alternative`
(`ForgeOfficeAlternativeRoute`, below).

License: BSD-3-Clause. Not published (`publish_to: none`). Desktop only: a
helper process. LibreOffice is never bundled (see `tom_office_editor`'s
`THIRD_PARTY.md`).

## Usage

```dart
final office = ForgeOfficeLokModule(
  // What the kit has no port for, the application gives (all optional):
  preferences: ForgePreferencesService.instance, // the path setting
  openExternal: shell.environment.openExternal, // links, Open LibreOffice
  filePickers: () => ForgeShellComponents.of(shell).pickers,
);
shell.registerModule(office); // any ForgeKitApi host's registry
```

The module is registered before the file editors; the application keeps
*Plain Text Editor* away from office files with `office.handles(uri)`.

With the ZetaOffice adapter, wired so that neither package depends on the
other:

```dart
final zeta = ForgeZetaOfficeModule(openExternal: shell.environment.openExternal);
final lok = ForgeOfficeLokModule(
  alternative: ForgeOfficeAlternativeRoute(
    choiceId: ForgeZetaOfficeModule.choiceId,
    label: ForgeZetaOfficeModule.openLabel,
    open: zeta.open,
    editors: () => zeta.editors,
    available: zeta.available,
    check: zeta.checkAvailable,
  ),
);
shell
  ..registerModule(lok) // first: the default
  ..registerModule(zeta);
```

## How it fits the application

- **Opening.** `openUri` takes an office file with a local (`file:`) path in
  the application's file system — the helper needs a path, so a file of a
  file system without local paths is declined. It shows an editor already
  open on the file (its own, or the alternative route's), leaves the file to
  the alternative route when the file-type default names its choice
  (`ForgeKitApi.editorPicker`), else opens `ForgeOfficeEditor` through the
  application's editor host. `editorChoicesFor` gives `office.lok`; one
  editor per file.
- **Host.** `ForgeOfficeHost` implements `TomOfficeEditorHost`: the file's
  path and `TomBinaryFiles` (`TomBinaryFileAccess` on local files), the
  helper launcher the module holds for the current LibreOffice, the kit's
  notifications for notices, `openExternal` for links, the file pickers for
  *Insert image*.
- **Detection and the helper.** At activation the module detects LibreOffice
  with `TomLibreOfficeDetector` and the user's path setting
  `forge.tools.libreoffice.path` (from `preferences`, else the key in the
  application's `ForgeKitApi.stateStore`; empty: search), and makes a
  `TomOfficeProcessLauncher` with `tom_office_host` from
  `$TOM_BINARY_PATH/<platform>/`. Without the helper in the binaries layer a
  start fails with that reason. Leftovers of dead helpers are cleaned up once
  (`TomOfficeProcessLauncher.cleanUp`).
- **Save, undo, redo, dirty.** `getContent()` is null and the editor lists
  the save action: an explicit save goes to the controller (temporary
  target, replace over an unchanged file, else the conflict banner); an
  automatic save leaves it alone. Undo and redo go to the controller;
  `isActionEnabled` follows `canUndo` / `canRedo` (`STATE_CHANGED .uno:Undo`
  / `.uno:Redo`); `isDirty` is the controller's (the engine's modified flag).
  History changes fire `onStateChanged`.
- **Clipboard.** Copy, cut and paste (text) are routed to the helper. Find
  is LibreOffice's own (Cmd+F opens its Find & Replace dialog); the
  application's find bar is not offered.
- **Kept view state.** `saveState` keeps the part shown (sheet or slide;
  `{route: lok, part}`) and `restoreState` returns a reopened tab there once
  the document is open. The zoom and the scroll position are the view's own.
- **Outside changes.** `replaceContent` answers false, so the application
  closes and reopens the editor (a new helper, an empty history). When the
  window regains focus (`windowFocus`, else the application's lifecycle:
  resumed), every editor checks its file (`checkExternal`): a clean document
  reopens, a dirty one shows the conflict.
- **Views.** The split copy is a second `TomOfficeEditor` on the same
  controller (one document, one history, its own viewport, no ribbon).
- **Close.** A closed editor ends its helper.

## The tab when LibreOffice is missing

An office file opens a `ForgeOfficeEditor` tab whatever detection found.
Without a `found` result the tab shows, by detection's state:

| State | The panel shows |
| --- | --- |
| `missing`, `tooOld`, `damaged`, a path setting that names nothing usable | the install help (`TomLibreOfficeInstallHelp`, below), *Choose LibreOffice…* |
| `quarantined` | detection's state view (`TomOfficeDetectionView`): *Open LibreOffice*, *Check again* |

- **The alternative route** (*Open with ZetaOffice*) is offered below it
  when one is wired, while its `available` holds (ZetaOffice: not when its
  files are not cached and the CDN does not answer); its `check` runs when
  detection finds no usable LibreOffice.
- **Choose LibreOffice…** stores the picked app as the path setting and runs
  detection again. **Check again** runs detection again; the panel turns into
  the editor in place once it reports `found`.
- **Open With** leaves `office.lok` out while detection reports no usable
  LibreOffice. Opening the file again shows the tab with the panel.

## External Tools

The module contributes `ForgeLibreOfficeTool` as a kit extra
(`ForgeExternalToolsExtra`, its `ownExtras`): the first row of the panel
shell's Configuration panel *External Tools* section (`id` `libreoffice`, the
setting `forge.tools.libreoffice.path`, an app bundle, the download page),
which the shell reads with `forgeModuleExternalTools`. Its `check` runs
`TomLibreOfficeDetector` with the user's path (none: the start-up search),
*Auto-detect* the detector's wider search; detection's states map one to one
onto `ForgeToolState`. While the copy is missing, too old or unusable the row
shows the install help under it (`buildHelp`, the kit's
`ForgeExternalTool.buildHelp`; the module sets the tool's `helpBuilder`); an
install or *Check again* from the row runs the module's detection and then
the row's check.

## Installing LibreOffice (DPLD-3)

The panel and the row show `tom_office_editor`'s `TomLibreOfficeInstallHelp`
(`ForgeOfficeLokModule.buildInstallHelp`): what is wrong, the platform's
install routes (`TomLibreOfficeTool.standard`) with their availability, the
download page (through `openExternal`) and *Check again*. The help asks for
confirmation; the module's `install(route)` then runs the route with
`ForgeLibreOfficeInstaller`:

| Route | How it runs |
| --- | --- |
| macOS Homebrew | `brew install --cask libreoffice` as the user |
| Windows winget | `winget install --id TheDocumentFoundation.LibreOffice -e` as the user; the MSI raises UAC |
| Windows Chocolatey | `choco install libreoffice-fresh -y` in an elevated PowerShell: `powershell -Command "$p = Start-Process -FilePath powershell.exe -ArgumentList '... -EncodedCommand <cmd>' -Verb RunAs -Wait -PassThru; exit $p.ExitCode"` (`forgeElevatedPowerShellArguments`); the elevated window's output is redirected into a log read back when it exits |
| Linux apt (PPA) | its three commands through `pkexec`, in order |
| Linux TDF `.deb` / `.rpm` (managed download) | the archive downloaded (`dart:io` `HttpClient`) into a scratch folder under the system's temporary folder, its SHA-256 (`package:crypto`) compared with the published `<url>.sha256` — a mismatch stops it, nothing is unpacked or run — unpacked with `tar -xzf`, its packages (`packageGlob`) installed with `pkexec dpkg -i` / `pkexec rpm -Uvh`; the scratch folder is removed |

- **PATH.** Every command runs with `PATH` extended by
  `forgeInstallSearchPath`: on macOS `/opt/homebrew/bin` and `/usr/local/bin`
  are added (an app started from Finder gets launchd's short `PATH`), and its
  executable is looked up on it. The routes' availability
  (`installRouteAvailability`) looks on the same `PATH`.
- **Output and Stop.** stdout and stderr stream into the help as they come
  (`TomLibreOfficeInstallRunController`); *Stop* kills the running process
  (an elevated Chocolatey window is the system's and is not stopped).
- **Afterwards.** When the run has ended the module runs detection again
  (`checkAgain`): a waiting tab turns into the editor once LibreOffice is
  found, else the help shows the new state.
- **Tests.** `ForgeLibreOfficeInstaller` takes its process starter
  (`ForgeInstallProcessStarter`), its HTTP (`ForgeInstallHttp`), the
  environment, the platform and the file check; the test support's
  `FakeInstallStarter`, `FakeInstallHttp` and `forgeOfficeTestInstaller` run
  nothing real.

## Undo conformance

The editor runs Forge's undo conformance harness
(`test/undo_conformance_test.dart`, the subject in the test-support package
`tom_forge_office_lok_testing`) against a scripted LibreOffice helper
(`ScriptedOfficeHelper`: text committed by the input method or typed as
keys, one undo step each, a new edit ends the redo, the modified flag false
whenever undo or redo reaches the saved state). The evaluation's engine
checks found LibreOffice 26.8.3.1 behaving that way. The fake checks the
routing, not the engine itself. Skips, with their reasons (full conformance
is decided after the comparison, `officeproto31h`):

| Check | `ForgeOfficeEditor` |
| --- | --- |
| `dirtyFollowsSavedState` | **runs** |
| `caretAfterUndoAndRedo` | skipped: the caret is the engine's, no text offset to compare; LibreOffice restores it |
| `typingUndoneWithinPause` | skipped: LibreOffice groups typing itself; `forgeTypingPause` does not reach it |
| `noRedoAfterTyping` | **runs** |
| `splitCopiesShareHistory` | **runs** |
| `replaceContentClearsHistory` | skipped: `replaceContent` answers false; the reopen is tested by `FOFF-REOPEN-1` |

## Debug mode

`kForgeOfficeDebug` in `lib/src/forge_office_trail.dart`, prefix `[FO]`, off
by default and switchable at run time: activation and detection (state,
version, path setting or search), `openUri` taken, declined or left to the
alternative route, the choice opened or reused, the file-type default
applied, save (with its outcome), undo, redo, copy, cut and paste routed,
`checkExternal` on focus, the state panel shown, *Check again*, *Choose
LibreOffice…*, the tool's checks and help, an install (start, each command,
a SHA-256 mismatch, stop, exit code), the download page opened, the editor
closed. Errors in the module's
callbacks are reported through `FlutterError.reportError` with the flag off
too. The editor's own trail is `tom_office_editor`'s `kOfficeEditorDebug`
(`[OE]`).

## Tests

```sh
testkit :test
```

`test/office_lok_module_test.dart` (the module in a panel shell over a memory
file system, scripted helpers: opening, the choice, the file-type default and
the alternative route, save and undo routing, reopening, focus, the
missing-LibreOffice panel, kept state), `test/libreoffice_tool_test.dart`
(the External Tools descriptor, its extra, its row with the install help, the
path setting), `test/libreoffice_installer_test.dart` (the install help in the
panel and the row, each route's elevation, the managed download's hash check,
Stop, detection after the run; fake processes only) and
`test/undo_conformance_test.dart`. The two routes together are tested in
`tom_forge_office_zetaoffice` (`test/office_routes_together_test.dart`).
