# tom_forge_office_zetaoffice

Forge's ZetaOffice office adapter: ZetaOffice — LibreOffice compiled to
WebAssembly — in a webview (`tom_office_zetaoffice`'s `TomZetaOfficeView`)
as a Forge editor over the kit, without the shell (R9). One kit module,
`ForgeZetaOfficeModule`, offers `ForgeZetaOfficeEditor` under *Open With*:

| Choice id | Editor | What it is |
| --- | --- | --- |
| `office.zetaoffice` | `ForgeZetaOfficeEditor` | ZetaOffice in a webview, the comparison route |

for `.docx .odt .doc .rtf .xlsx .ods .xls .csv .pptx .odp .ppt` with a local
path (any case; `ForgeZetaOfficeKind` picks the tab icon). In Forge the
LibreOfficeKit adapter (`tom_forge_office_lok`) is the default office editor
and ZetaOffice is offered beside it; this module opens an office file itself
(`openUri`) only when the file-type default names `office.zetaoffice` — or,
with `opensByDefault: true`, when no default is set (an application whose only
office route is ZetaOffice). `.csv` stays text either way.

The two adapters are separate packages (R6): an application that takes only
the LibreOfficeKit adapter resolves no webview. Neither depends on the other;
the application wires this module into the LibreOfficeKit module as its
alternative route (`ForgeOfficeAlternativeRoute` from `tom_forge_office_lok`)
with `open`, `editors`, `available`, `checkAvailable` and the label
`openLabel` (*Open with ZetaOffice*), so the missing-LibreOffice panel offers
ZetaOffice and a ZetaOffice tab already open on a file is shown. Usage:
`tom_forge_office_lok`'s README.

License: BSD-3-Clause. Not published (`publish_to: none`). Desktop only: a
webview (the workspace's `flutter_inappwebview` fork, WKWebView on macOS) and
a local content server. ZetaOffice's files are downloaded at run time after
the user confirms and kept in `~/Library/Caches/tom_office_editor/zetaoffice/`
(see `tom_office_zetaoffice`'s `THIRD_PARTY.md`).

## How it fits the application

- **Host.** `ForgeZetaOfficeHost` implements `TomOfficeEditorHost` (the office
  editor's host interface, which the ZetaOffice route runs on): the file's
  path and `TomBinaryFiles` (`TomBinaryFileAccess` on local files), the kit's
  notifications for notices, `openExternal` for links. ZetaOffice starts no
  LibreOffice helper (`helper` refuses) and inserts images in its own
  interface (`pickImage` answers null).
- **Save, undo, redo, dirty.** `getContent()` is null and the editor lists
  the save action: an explicit save runs `store()` and the bytes are posted
  back (a failed save leaves the document dirty); an automatic save leaves
  it alone. Undo and redo go to the controller; `isActionEnabled` follows
  ZetaOffice's undo manager; `isDirty` is ZetaOffice's modified flag.
- **One tab at a time.** ZetaOffice runs in one tab at a time (a second tab
  says so); a closed editor closes its page and content site and frees the
  slot.
- **Views.** A webview page cannot be shown twice: the split copy says
  *This view cannot be split* with a button that shows the document.
- **Outside changes.** `replaceContent` answers false, so the application
  closes and reopens the editor. When the window regains focus
  (`windowFocus`, else the application's lifecycle: resumed), every editor
  checks its file (`checkExternal`).
- **Available.** `available` says whether ZetaOffice can open without an
  installed LibreOffice: its files are cached, or the CDN answers within ten
  seconds (`checkAvailable`; false until checked).

## Undo conformance

The editor runs Forge's undo conformance harness
(`test/undo_conformance_test.dart`, the subject in the test-support package
`tom_forge_office_zetaoffice_testing`) against a scripted ZetaOffice page
(`ScriptedZetaOfficePage`: ZetaOffice's history and modified flag). The fake
checks the routing, not the engine itself. Skips, with their reasons (full
conformance is decided after the comparison, `officeproto31h`):

| Check | `ForgeZetaOfficeEditor` |
| --- | --- |
| `dirtyFollowsSavedState` | **runs** |
| `caretAfterUndoAndRedo` | skipped: the caret is ZetaOffice's, inside the webview |
| `typingUndoneWithinPause` | skipped: ZetaOffice groups typing itself |
| `noRedoAfterTyping` | **runs** |
| `splitCopiesShareHistory` | skipped: a webview page cannot be shown twice |
| `replaceContentClearsHistory` | skipped: `replaceContent` answers false; the reopen is tested by `FZO-REOPEN-1` |

## Debug mode

`kForgeZetaOfficeDebug` in `lib/src/forge_zetaoffice_trail.dart`, prefix
`[FZO]`, off by default and switchable at run time: activation, `openUri`
taken, the choice opened or reused, save (with its outcome), undo, redo,
`checkExternal` on focus, links opened, ZetaOffice not available offline, the
editor closed. Errors in the module's callbacks are reported through
`FlutterError.reportError` with the flag off too. The view's own trail is
`tom_office_zetaoffice`'s `kZetaOfficeDebug` (`[ZO]`).

## Tests

```sh
testkit :test
```

`test/zetaoffice_module_test.dart` (the module in a panel shell over a memory
file system, scripted pages: the choice, the file-type default, save and
undo routing, the split copy, reopening, availability),
`test/office_routes_together_test.dart` (both adapters in one shell as Forge
wires them: Open With offers both, LibreOfficeKit first and the default; a
default naming ZetaOffice; the missing-LibreOffice panel opening ZetaOffice,
and not offline; it takes `tom_forge_office_lok_testing` as test support) and
`test/undo_conformance_test.dart`.

## The routes' evaluation harness

`tool/evaluation/` is the office routes' evaluation (a macOS Flutter app,
`tom_forge_office_route_evaluation`, with its integration test and Python
runner): it drives both components, `tom_office_editor` and
`tom_office_zetaoffice`, the same way and compares them. It is a package of
its own that no adapter depends on; it lives here because this adapter's
dependencies already hold both components, while the LibreOfficeKit adapter
stays free of any webview reference. See its `README.md`.
