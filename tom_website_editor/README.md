# tom_website_editor

Tom Forge module for editing and driving `enterprise_flutter_web` websites. It
wraps the pure-Dart [`tom_website_editor_core`](../tom_website_editor_core)
(config + placeholders + registry) in a [`ForgeModule`] that contributes the
active-website selection / reload config panel to the forge shell.

This package implements **steps 2, 3, 4, 5 and 6** (§9.2, §9.3, §9.4, §9.5,
§9.6 / §6a) of the implementation plan in `tom_website_editor_specification.md`.
The dedicated `WebsiteConfigEditor` (§6) is added in a later step; it builds on
the shared `WebsiteEditorController` this module exposes.

## What it provides

| API | Purpose |
| --- | --- |
| `WebsiteEditorModule` | `ForgeModule` that loads `tom.website-editor.yaml` from the workspace root on activation, contributes the website config panel, and registers the preview view. |
| `WebsiteEditorController` | `ChangeNotifier` owning the `WebsiteRegistry`: async load/reload of the config source, the active-website selection, and the loading/issues state for the UI. |
| `WebsiteConfigPanel` | Settings-dialog widget to pick the active website and reload the config; lists validation issues inline. |
| `WebsitePreviewController` | `ChangeNotifier` wrapping the editor controller: resolves the active website's `preview.devUrl` / `preview.builtIndex` via the placeholder resolver, exposes a reload token, a dev/built source toggle, and external-browser open through an injected opener. |
| `WebsitePreviewView` | `ForgeView` embedding the resolved preview URL in a webview, with a toolbar to pick the website, toggle the source, reload, and open in an external browser. |
| `WebsiteControlController` | `ChangeNotifier` wrapping the editor controller: renders one action button per configured command (§7), expands the command + `cwd` via the placeholder resolver, spawns the external process through an injected `WebsiteProcessRunner`, streams stdout→info / stderr→warning into a levelled log, and maps the exit code via the §7 taxonomy. |
| `WebsiteControlView` | `ForgeView` (the control panel, §5) rendering the command buttons, a filterable message log with pinned errors, a website picker, and a status line (active website, error/warning counts, last-run time). |
| `WebsiteProcessRunner` | Injectable seam (`WebsiteCommandSpec` → `WebsiteProcessHandle`) for spawning commands. The `DartIoWebsiteProcessRunner` default uses `Process.start`; tests inject a fake that replays output + an exit code. |
| `WebsiteContentController` | `ChangeNotifier` wrapping the editor controller: builds the §6a content catalog (component → module → optional submodule, plus `site.yaml` and `pages/`) from the active website's `content:` block through the injectable `WebsiteContentFs` seam, classifies each field managed vs editable, writes `# @manual` pins back to disk, and disables itself for websites without a `content:` block. |
| `WebsiteContentBrowser` | `ForgeView` (the content browser, §6a): the catalog tree on the left and a field/page detail pane on the right. Managed fields are read-only/badged with a pin affordance; curated / pinned fields route to the inline editor named by their typed suffix (`-md` → Markdown, `-json` → JSON, else plain string). |
| `WebsiteContentFs` / `ForgeContentFs` | Narrow file-system seam (list/read/write/exists, plus typed `listEntries` for the structure tree) for the content layer; `ForgeContentFs` adapts the shell's `ForgeFileSystem`, while tests inject an in-memory fake. |
| `WebsiteStructureController` | `ChangeNotifier` wrapping the editor controller: scans the active website's `content/` tree through the `WebsiteContentFs` seam and builds the §6b structure tree (`site.yaml`, `areas/`, `components/`, `copy/` [grouped by the §16 naming convention], `pages/`, recursive `diagrams/`). Each file node routes to an editor by extension (`.yaml` → YAML, `.md` → Markdown). Creates new copy files at the §16 convention path, and disables itself / surfaces placeholder errors like the content controller. |
| `WebsiteStructureExplorer` | `ForgeView` (the structure explorer, §6b): the filesystem-driven `content/` tree on the left and a detail pane on the right naming the editor a selected file opens in. |
| `StructureNode` / `groupCopyFiles` / `copyFileName` | Pure-Dart structure-tree model and §16 copy-file naming helpers (parse/encode/group) used by the controller; no Flutter dependency, fully unit-tested. |

## Architecture

The module is intentionally thin — the behaviour lives in two well-tested
layers below it, so the shell-facing glue carries almost no logic:

```
WebsiteEditorModule        (forge wiring: resolve config Uri, read via shell FS)
        │ owns
WebsiteEditorController     (Flutter ChangeNotifier: async read + notify + flags)
        │ owns                         ▲ wraps
WebsiteRegistry  ← core      WebsitePreviewController → WebsitePreviewView (ForgeView)
(load/select/reload)         (resolve URL, source toggle, refresh, open-external)
```

`WebsiteEditorController` takes a `WebsiteConfigReader` (`Future<String>
Function()`) so it can be exercised in tests without a live shell; the module
wires it to `ForgeShellApi.fileSystem.read(configUri)`.

`WebsitePreviewView` takes an injectable `PreviewWebViewBuilder` so widget tests
render a stub instead of the platform `InAppWebView`; in production it loads the
URL in a `flutter_inappwebview` view, keyed on `url#reloadToken` so a refresh
recreates the platform view. The external-browser opener is likewise injected
(`ExternalUrlOpener`), defaulting to the host OS launcher (`open` / `xdg-open` /
`start`) — no `url_launcher` dependency. A placeholder-resolution failure is
surfaced as an inline error (with the offending token and location) rather than
a blank preview.

`WebsiteControlController` reuses the same injection discipline: it takes a
`WebsiteProcessRunner` (default `DartIoWebsiteProcessRunner`) so widget/unit
tests drive a fake that replays predetermined output and an exit code — no real
process is spawned. It exposes the message log as an immutable `List<WebsiteLogEntry>`
on a `ChangeNotifier`. The §5 specification suggests a `tom_core_kernel`
`TomObservable`; this package keeps the log on `ChangeNotifier` for **consistency**
with the editor/preview controllers (and because `tom_core_kernel` is not a
dependency of `tom_forge_ui`). The levelled/filterable/pinned semantics §5 asks
for are delivered identically.

## Control panel + command contract (§5, §7)

`WebsiteControlView` renders one **action button per command** in the §7
canonical order — *Generate content*, *Extract design*, *Generate all*, *Status
report*, *Smoke test*, *Start dev server*, *Build*, *Open in browser* — followed
by any extra (non-canonical) commands the website configures. A button whose
command is **absent** from the active website's `commands:` is shown **disabled**;
a button whose process is in flight shows a spinner and is disabled.

On tap, `WebsiteControlController.runCommand(name)`:

1. expands the command template and `cwd` via `PlaceholderResolver.forWebsite`
   (a resolution failure is logged as a **pinned error** and nothing is spawned);
2. builds the argv from `defaults.shell` (e.g. `["bash","-lc"]` → `bash -lc
   "<expanded command>"`), with `workingDirectory` = the expanded `cwd`;
3. logs the **expanded command + cwd** as an info entry *before* running, so what
   executes is always visible (§3);
4. spawns the process via the injected `WebsiteProcessRunner` and streams
   **stdout → info / stderr → warning** into the log;
5. maps the **exit code** via the §7 taxonomy: `0` → info "completed", `1` →
   pinned error "failed (exit 1)", `2` → pinned error "usage/config error (exit
   2)" (a template/config bug, distinct from a real failure).

`--dry-run` is offered by appending the flag to the resolved command (the §2/§7
safe-probe contract). The status line surfaces the active website, the dev-server
state, error/warning counts, and the last-run time; the log is filterable by
level, and pinned errors stay visible even when their level is filtered out. **No
website code is imported** — every action is a process (§1).

## Dev-server lifecycle + auto-refresh (§9.5)

`serveStart` is **not** a one-shot command: it is a long-lived child the
controller owns. So it is driven by a dedicated lifecycle rather than
`runCommand` (which awaits the exit code and would block on a server that never
returns):

- `startServer()` expands `serveStart` (same placeholder/shell/cwd path as
  `runCommand`), spawns the child, and returns **without** awaiting its exit. The
  handle is tracked (`isServerRunning`, `serverWebsiteId`), its stdout→info /
  stderr→warning streamed into the log. Starting while a server is already
  running, or when `serveStart` is unconfigured/unresolvable, logs and returns
  `false` (single spawn).
- `stopServer()` kills the child and waits for the supervisor to settle, clearing
  the tracked state. The controller's `dispose()` also kills any orphaned server.
- `restartServer()` stops the current child then starts a fresh one for the
  active website.
- When the server exits on its own, the supervisor clears the state and logs the
  exit code (info on `0`, warning otherwise).

**Auto-refresh.** Each dev-server **stdout** line is matched against a
`ServerOutputMatcher`; a match fires the injected `onRebuildComplete` callback,
which the module wires to `WebsitePreviewController.refresh` so the embedded
preview reloads on every rebuild. The matcher is injectable; the default
(`WebsiteControlController.isRebuildCompleteLine`) is a **best-effort** regex over
common reload cues (`reload`, `recompiled`, `serving at`, …). Confirming the
exact `jaspr serve` rebuild marker against the live website is deferred to the
§9.7 e2e step (gated on `enterprise_flutter_web`); tracked in
`completion_steps.tom_forge.md`.

In the view, `serveStart` renders as a **start/stop toggle** (plus a restart
button while running) instead of the generic command button.

### Deferred (gated on enterprise_flutter_web)

- **Structured drift-report parsing.** §5 asks the control view to parse the
  generator's *drift report* from `generateAll` output. The authoritative grammar
  lives in `enterprise_flutter_web/website/doc/command_contract.md`, which is not
  present in this checkout, so a faithful parser cannot be authored yet. Until
  then the raw generator output is surfaced verbatim in the log (the §7 exit-code
  taxonomy is honoured). Tracked in `completion_steps.tom_forge.md`.
- **Real forge spawn service.** The forge shell exposes no process-spawn API
  (`ForgeExecutionMonitor` only *tracks* executions). The control controller uses
  the `dart:io`-backed `DartIoWebsiteProcessRunner` for now; wiring it to a shared
  forge spawn service (so the shell's execution monitor reflects website runs) is
  deferred. Tracked in `completion_steps.tom_forge.md`.

## Content browser + manual-copy editors (§6a)

The content browser surfaces the website's **data model** — its catalog of
component records and standalone pages — so hand-owned copy can be edited
without touching the generator's output. Reading and writing these YAML/MD data
files is plain file I/O (allowed by §1's process-only rule, which only forbids
linking the website's *Dart code*).

A website opts in with a `content:` block in `tom.website-editor.yaml`:

```yaml
content:
  dir:            "{websiteRoot}/content"   # placeholder-expanded root
  components:     "components/*.yaml"        # glob, relative to dir
  site:           "site.yaml"               # relative to dir
  pages:          "pages/*.md"              # glob, relative to dir
  editableFields: [tagline, summary-md, overview-md, enables]
  manualPin:      "# @manual"
```

When the block is **absent** the browser is **disabled** for that website
(`WebsiteContentController.isEnabled == false`) and the view shows a disabled
state.

**Catalog tree.** Each `components/*.yaml` file is parsed into a record tree —
component → `modules:` → optional `submodules:` — rendered on the left alongside
`site.yaml` and each page. `WebsiteContentController.refresh()` rebuilds the
tree from disk; the module also refreshes it when the active website changes.
The `dir` template is placeholder-expanded via `PlaceholderResolver`; a
resolution failure surfaces as an inline error (with the offending token), never
a silent blank tree.

**Managed vs editable fields.** A field is **editable** when its name is one of
the website's curated `editableFields` (`tagline` / `summary-md` / `overview-md`
/ `enables`) **or** it carries the `# @manual` pin; every other field is
**generator-managed** and shown read-only with a badge. Editable fields route to
the inline editor named by their **typed suffix** (enterprise spec §4.1): a
`-md` field opens the Markdown editor, a `-json` field the JSON editor, anything
else a plain string field.

**Pinning.** Editing a managed field is opt-in: the detail pane offers a **Pin**
action that appends the configured `manualPin` comment to the field's source
line (`pinFieldLine`) and writes the file back. Because the pin is a real YAML
trailing comment, the manual edit **survives the next `generateContent`** — on
the next refresh the field is re-classified as editable. Pin detection is
**span-precise**: each key's source line is read from the raw YAML, so the pin
is recognised even on block scalars and nested module fields.

**Pages.** Standalone `pages/*.md` use `@tom:override` / `@tom:managed`
insert-marker regions: `ContentPage.parse` splits a page into regions, exposes
the editable (override) bodies, and `serialize()` reproduces the source exactly,
so generated regions and the markers themselves are never disturbed when an
override region is edited.

### Deferred (gated on enterprise_flutter_web)

- **Live component field set.** The authoritative curated-field list and the
  exact component-YAML shape live in the website's
  `module_and_component_web_information.md`, which is not present in this
  checkout. The browser is built generically against the §2 defaults and
  fixtures; reconciling the precise field set is deferred to §9.7. Tracked in
  `completion_steps.tom_forge.md`.
- **Exact page-region grammar.** The precise `@tom:override` / `@tom:managed`
  marker grammar lives in the website's spec (enterprise §6.2), absent here. The
  region classifier is injectable (`PageMarkerClassifier`) so the exact form can
  be supplied without touching the region model; confirming it is deferred to
  §9.7. Tracked in `completion_steps.tom_forge.md`.
- **Rich inline-editor embedding + value write-back.** Editable fields render in
  the correct inline editor *by kind* now; binding `tom_yaml_editor`'s
  `YamlSchemaEditor` (record editing, against the live component JSON Schema) and
  `tom_md_editor` (page override regions) for two-way value persistence is
  reconciled in §9.7, where the live schema lands. Tracked in
  `completion_steps.tom_forge.md`.

## Structure explorer (§6b)

Where the content browser (§6a) presents the website's **parsed catalog**, the
structure explorer presents the **filesystem layout** of the same `content/`
tree, so contributors can navigate and open files by their on-disk shape. It is
driven by `WebsiteStructureController` over the same `WebsiteContentFs` seam (now
extended with a typed `listEntries` so it can distinguish files from
directories) and reuses the `content:` block — no extra configuration.

`WebsiteStructureController.refresh()` builds the top-level sections in order:

- **`site.yaml`** — the site-level file (when present).
- **`areas/`**, **`components/`**, **`pages/`** — directory sections listing the
  files matched by each config glob.
- **`copy/`** — grouped by the **§16 naming convention** rather than shown flat:
  `home.md`, `<A>_area.md`, `<C>_component.md`, `<C>_<M>_module.md`,
  `<C>_<M>_<S>_submodule.md` fold into a `component → module → submodule` tree
  plus an `areas` group and the `home` file. Files that don't follow the
  convention are surfaced verbatim, never dropped (`groupCopyFiles`).
- **`diagrams/`** — listed recursively (e.g. `diagrams/<feature>/flow.svg`).

**Editor routing.** Each file node carries a `FileEditorKind` derived from its
extension: `.yaml` / `.yml` → the YAML editor (`tom_yaml_editor`), `.md` /
`.markdown` → the Markdown editor (`tom_md_editor`), everything else → a
read-only viewer. The explorer's detail pane names the routed editor on
selection; embedding the rich editor widgets is deferred (see below).

**New-file creation.** `createCopyFile(kind, parts: …)` encodes the §16 file name
(`copyFileName`) and writes it at the convention path under `copy/` (e.g.
`createCopyFile(CopyFileKind.component, parts: ['billing'])` →
`copy/billing_component.md`), then refreshes so the new group appears. Arity is
validated — a malformed request throws rather than writing a bad path.

Like the content browser, the explorer is **disabled** for websites without a
`content:` block, and a placeholder-resolution failure on `dir` surfaces as an
inline error rather than a silent blank tree.

### Deferred (gated on enterprise_flutter_web)

- **Rich editor embedding.** File nodes route to the correct editor *by kind*
  now; binding the live `tom_yaml_editor` / `tom_md_editor` widgets into the
  detail pane for in-place editing is reconciled in §9.7 alongside the content
  browser's editor embedding. Tracked in `completion_steps.tom_forge.md`.

## Reload contract (§6)

`reload()` re-reads the config source and applies it. On **valid** source the
registry is replaced and the active selection is preserved when its id still
exists (otherwise it resets to the first website). On **invalid** source the
last-good registry is kept, `reload()` returns `false`, and the new issues are
exposed on `controller.issues` for the panel to display.

## Testing

This is a Flutter package, so use `flutter` (not `dart test` / `testkit`):

```bash
flutter analyze
flutter test
```

- `test/website_editor_controller_test.dart` — controller load/select/reload,
  notifications, loading flag, last-good-on-invalid (TWE-CTL-01..08).
- `test/website_config_panel_test.dart` — panel rendering, selection, reload
  button, issue listing (TWE-PANEL-01..04).
- `test/website_preview_controller_test.dart` — URL resolution per source,
  recompute on selection, refresh token, resolve-error surfacing, external open
  (TWE-PREV-CTL-01..10).
- `test/website_preview_view_test.dart` — webview URL rendering, source toggle,
  website picker, refresh, error state, external open, reactive title
  (TWE-PREV-VIEW-01..07).
- `test/website_control_controller_test.dart` — button availability, shell-argv
  + cwd expansion, log-before-run echo, stdout/stderr log levels, the 0/1/2
  exit-code mapping, `--dry-run`, unconfigured-command + resolve-error handling,
  running/stop lifecycle (TWE-CTRL-01..15).
- `test/website_control_view_test.dart` — command buttons (enabled/disabled),
  tap-spawns-process, log echo + completion, website picker, status line, reactive
  title, level filtering, dev-server start/stop toggle (TWE-CTRLV-01..08).
- `test/website_dev_server_test.dart` — dev-server lifecycle: non-blocking start,
  no-serveStart error, stop/kill, single-spawn, restart, self-exit clearing,
  auto-refresh on matching stdout, output→log levels, default matcher
  (TWE-SRV-01..11).
- `test/content/content_model_test.dart` — typed-suffix editor routing, record
  tree parsing, field classification (managed/editable/pinned), span-precise
  `# @manual` read + `pinFieldLine` write, and the override/managed page-region
  round-trip (TWE-MODEL-01..05).
- `test/content/website_content_controller_test.dart` — catalog build (component
  → module → submodule, incl. a module with and without submodules), site/pages
  discovery, pin-writes-to-disk + re-parse, disabled-without-content, refresh
  reload, placeholder-failure surfacing (TWE-CTRL-01..05).
- `test/content/website_content_browser_test.dart` — disabled state, tree
  render, managed pin button vs editable field, pin writes the pin, typed
  inline-editor routing (TWE-BROWSE-01..05).
- `test/structure/copy_naming_test.dart` — §16 copy-file naming: parse/encode
  round-trip per kind, arity validation, non-convention files preserved, and the
  `component → module → submodule` grouping (CN-01..11).
- `test/structure/website_structure_controller_test.dart` — disabled state, tree
  mirroring `content/`, §16 copy grouping, editor-kind routing, convention-path
  file creation, placeholder-failure surfacing (WSC-01..07).
- `test/structure/website_structure_explorer_test.dart` — disabled state, tree
  render with grouped copy, and yaml/md editor-routing on selection
  (TWE-STRUCT-01..04).
