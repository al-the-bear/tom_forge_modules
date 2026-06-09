# tom_website_editor

Tom Forge module for editing and driving `enterprise_flutter_web` websites. It
wraps the pure-Dart [`tom_website_editor_core`](../tom_website_editor_core)
(config + placeholders + registry) in a [`ForgeModule`] that contributes the
active-website selection / reload config panel to the forge shell.

This package implements **steps 2, 3, 4, 5 and 6** (§9.2, §9.3, §9.4, §9.5,
§9.6 / §6a) of the implementation plan in `tom_website_editor_specification.md`,
including the dedicated `WebsiteConfigEditor` (§6) that edits
`tom.website-editor.yaml` itself and reloads the registry on save.

## What it provides

| API | Purpose |
| --- | --- |
| `WebsiteEditorModule` | `ForgeModule` that loads `tom.website-editor.yaml` from the workspace root on activation, contributes the website config panel, and registers the preview view. |
| `WebsiteEditorController` | `ChangeNotifier` owning the `WebsiteRegistry`: async load/reload of the config source, the active-website selection, and the loading/issues state for the UI. |
| `WebsiteConfigPanel` | Settings-dialog widget to pick the active website, reload the config, and open the config editor (the *Edit configuration* action); lists validation issues inline. |
| `WebsiteConfigEditor` | `ForgeYamlEditor` subclass (§6) that handles `tom.website-editor.yaml` itself: self-loads the on-disk text, recomputes schema + placeholder diagnostics on every edit, and on save reloads the registry (an invalid save is rejected, last-good kept). |
| `websiteConfigDiagnostics` | Pure function turning config text into `ForgeDiagnostic`s — reuses the runtime loader/validator/resolver so editor and registry agree on validity (single source of truth). |
| `WebsitePreviewController` | `ChangeNotifier` wrapping the editor controller: resolves the active website's `preview.devUrl` / `preview.builtIndex` via the placeholder resolver, exposes a reload token, a dev/built source toggle, and external-browser open through an injected opener. |
| `WebsitePreviewView` | `ForgeView` embedding the resolved preview URL in a webview, with a toolbar to pick the website, toggle the source, reload, and open in an external browser. |
| `WebsiteControlController` | `ChangeNotifier` wrapping the editor controller: renders one action button per configured command (§7), expands the command + `cwd` via the placeholder resolver, spawns the external process through an injected `WebsiteProcessRunner`, streams stdout→info / stderr→warning into a levelled log, and maps the exit code via the §7 taxonomy. |
| `WebsiteControlView` | `ForgeView` (the control panel, §5) rendering the command buttons, a filterable message log with pinned errors, a website picker, and a status line (active website, error/warning counts, last-run time). |
| `WebsiteProcessRunner` | Injectable seam (`WebsiteCommandSpec` → `WebsiteProcessHandle`) for spawning commands. The `DartIoWebsiteProcessRunner` default uses `Process.start`; tests inject a fake that replays output + an exit code. |
| `WebsiteContentController` | `ChangeNotifier` wrapping the editor controller: builds the §6a content catalog (component → module → optional submodule, plus `site.yaml`, `pages/`, and the external `copy/*.md` files) from the active website's `content:` block through the injectable `WebsiteContentFs` seam, classifies each field managed vs editable, writes `# @manual` pins and copy-file edits back to disk, and disables itself for websites without a `content:` block. |
| `ContentCopyFile` / `ContentCopyDocument` | Pure-Dart model for an external editorial copy file (§16): YAML front-matter + a region-aware Markdown body. Parses, round-trips byte-for-byte, edits a front-matter field or a body override region in place, and preserves the §6.2 managed regions + markers so a hand edit survives `generateContent`. No Flutter dependency. |
| `WebsiteContentBrowser` | `ForgeView` (the content browser, §6a): the catalog tree on the left and a field/page detail pane on the right. Managed fields are read-only/badged with a pin affordance; curated / pinned fields route to the inline editor named by their typed suffix (`-md` → Markdown, `-json` → JSON, else plain string). Tapping a leaf opens its backing file through the injected `onOpenFile` seam (a record → its `components/<c>.yaml`, a page → `pages/<p>.md`, `site.yaml` → itself). |
| `WebsiteContentFs` / `ForgeContentFs` | Narrow file-system seam (list/read/write/exists, plus typed `listEntries` for the structure tree) for the content layer; `ForgeContentFs` adapts the shell's `ForgeFileSystem`, while tests inject an in-memory fake. |
| `WebsiteStructureController` | `ChangeNotifier` wrapping the editor controller: scans the active website's `content/` tree through the `WebsiteContentFs` seam and builds the §6b structure tree (`site.yaml`, `areas/`, `components/`, `copy/` [grouped by the §16 naming convention], `pages/`, recursive `diagrams/`). Each file node routes to an editor by extension (`.yaml` → YAML, `.md` → Markdown). Creates new copy files at the §16 convention path, and disables itself / surfaces placeholder errors like the content controller. |
| `WebsiteStructureExplorer` | `ForgeView` (the structure explorer, §6b): the filesystem-driven `content/` tree on the left and a detail pane on the right. Tapping a file node opens its backing file through the `onOpenFile` seam (wired by the module to `ForgeLayoutController.openFile`); the detail pane names the routed editor and offers an **Open in editor** button. |
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

**Refresh after a generate run.** A real (non dry-run) `generateContent` /
`generateAll` run from the control panel rewrites content on disk, so on
completion the controller fires an injected `onContentRegenerated` callback. The
module wires this to refresh **both** the §6a content tree and the §6b structure
explorer from disk — the user sees the regenerated catalog without a manual
reload. The callback fires regardless of exit code (a partial/failed run still
mutates disk, and the trees should reflect reality), and is skipped for
dry-runs (which never touch disk). The generator's drift report is part of the
run's stdout, so it is already surfaced verbatim in the message log (structured
drift parsing remains deferred — see below).

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
  editableFields: [tagline, summary, enables]   # unsuffixed §16 copy-file front-matter; overview is the body
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
the website's curated `editableFields` (`tagline` / `summary` / `enables` — the
unsuffixed §16 copy-file front-matter keys) **or** it carries the `# @manual`
pin; every other field is **generator-managed** and shown read-only (no inline
editor, only the **Pin** affordance).

**Inline editing + save.** The inline/full-editor boundary follows each field's
**typed suffix** (enterprise spec §4.1):

- A **plain string** field binds a persistent `TextEditingController` and writes
  on submit through `WebsiteContentController.setFieldValue` →
  `setFieldLineValue`, which rewrites only that key's source line (preserving
  indentation, a trailing `# @manual` pin, and quoting only when a bare scalar
  would be misread) and re-parses the document. The edit persists to disk and
  survives a reload.
- A `-md` or `-json` field is **not** edited inline — its rich body belongs in
  the full editor. The detail pane shows a read-only preview plus an **Open in
  editor** button that routes the backing file through the same `onOpenFile`
  seam as catalog navigation (below), so the typed editor opens via `canHandle`.

This keeps the short-scalar inline path and the rich-body full-editor path from
fighting: inline for simple values, full editor for Markdown / JSON / page
bodies.

**Pinning.** Editing a managed field is opt-in: the detail pane offers a **Pin**
action that appends the configured `manualPin` comment to the field's source
line (`pinFieldLine`) and writes the file back. Because the pin is a real YAML
trailing comment, the manual edit **survives the next `generateContent`** — on
the next refresh the field is re-classified as editable. Pin detection is
**span-precise**: each key's source line is read from the raw YAML, so the pin
is recognised even on block scalars and nested module fields.

**Provenance + lifecycle hints.** Every field row carries a classification badge
(**managed** / **editable** / **pinned**) whose tooltip spells out its
regeneration lifecycle (a managed field is replaced on the next regenerate; a
pinned field is protected; an editable field is hand-curated). When the
component's YAML has a `_generated` block, the parser captures it as the
record's `provenance` (one line, `key: value · key: value` in document order)
— it is **never** rendered as an ordinary field — and each managed field shows a
**generated** badge whose tooltip names what produced the value. Any field whose
value contains a §3 `{placeholder}` is visually distinguished with a
*"Placeholder — resolves at generate time"* hint, since the literal is only
computed when the generator runs. `valueHasPlaceholder` matches a bare `{name}`
token (a leading letter, then word chars plus `:` `.` `-`), so built-ins like
`{env:HOME}` and `{date}` count while a YAML flow map (`{ a: 1 }`) does not.

**Pages.** Standalone `pages/*.md` use `@tom:override` / `@tom:managed`
insert-marker regions: `ContentPage.parse` splits a page into regions, exposes
the editable (override) bodies, and `serialize()` reproduces the source exactly,
so generated regions and the markers themselves are never disturbed when an
override region is edited.

**External copy files (§16, front-matter + body).** Editorial copy now lives as
one Markdown file per component/module/submodule/area/home under `content/copy/`
(website §16) — YAML front-matter (`tagline`, `summary`, `enables` — the
canonical unsuffixed `editableFields`) plus a Markdown body that is the overview
— rather than inline `-md` fields on a record. `ContentCopyFile.parse` splits the
two halves: `frontMatter` exposes the editable fields (a typed `-md`/`-json`
suffix still routes to the matching editor, but the live copy files use plain
scalars), and `body` is a region-aware
`ContentPage`, so the §6.2 `@tom:override` / `@tom:managed` markers and the
managed regions they protect round-trip untouched. `withFrontMatterValue(name,
value)` edits one front-matter field line-precisely; `withBody(page)` (paired with
`ContentPage.withRegionBody`) edits a body override region; `serialize()`
reproduces the source byte-for-byte, so a hand edit survives the next
`generateContent`. The controller loads these from the `content.copy` glob into
`copyFiles` (`ContentCopyDocument`), and `setCopyFrontMatterValue` /
`setCopyBody` write the edit back through the `WebsiteContentFs` seam and
re-parse in place. Both browsers open the same files: the §6a browser by node,
the §6b explorer by path (grouped via `groupCopyFiles`).

**Navigation (open the backing file).** Tapping any leaf in the catalog routes
its backing file to the host editor through the injected
`WebsiteContentBrowser.onOpenFile` seam — the module wires it to
`ForgeShellApi.layout.openFile`, so routing to the matching editor is automatic
via each editor's `canHandle` (no per-extension branching here). A component
record opens its `components/<c>.yaml`, a page opens `pages/<p>.md`, and
`site.yaml` opens itself. The `site.yaml` / page detail pane shows the resolved
path plus an **Open in editor** button (the same seam); the record pane keeps the
field / pin affordances. When `onOpenFile` is `null` (the view rendered in
isolation) taps only update the detail pane.

**Filtering.** A search box above the catalog narrows the visible tree to nodes
whose label matches (case-insensitive): a component is kept when its record — or
any descendant module/submodule — matches, and `site.yaml` / pages are kept when
their file name matches. Clearing the box restores the full catalog.

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

**Editor routing + opening.** Each file node carries a `FileEditorKind` derived
from its extension: `.yaml` / `.yml` → the YAML editor (`tom_yaml_editor`),
`.md` / `.markdown` → the Markdown editor (`tom_md_editor`), everything else → a
read-only viewer. **Tapping a file node opens its backing file** through the
`void Function(Uri)? onOpenFile` ctor seam — the module wires it to
`ForgeLayoutController.openFile`, and editor routing is then automatic via each
editor's `canHandle`, so no per-extension branching lives in the view. The
detail pane names the routed editor, shows the resolved on-disk path, and offers
an **Open in editor** button that re-opens the selected file through the same
seam. When `onOpenFile` is `null` (e.g. the view rendered in isolation) taps only
update the detail pane. Embedding the rich editor widgets *inline* (vs. routing
to the shell's editor area) is deferred (see below).

**New-file creation.** `createCopyFile(kind, parts: …)` encodes the §16 file name
(`copyFileName`) and writes it at the convention path under `copy/` (e.g.
`createCopyFile(CopyFileKind.component, parts: ['billing'])` →
`copy/billing_component.md`), then refreshes so the new group appears. Arity is
validated — a malformed request throws rather than writing a bad path.

**File CRUD affordances.** The explorer owns the file-management actions (the
content browser stays read-navigation only — single responsibility). Each
directory/group section header carries a **＋** button that prompts for a name and
calls `createFile(uri)`; each file row carries a **⋮** menu with **Rename** and
**Delete**. The controller exposes the three operations through the
`WebsiteContentFs` seam (extended with `delete` / `rename`; `ForgeContentFs` maps
`rename` onto a `ForgeWorkspaceEdit` file operation, the only supported path):

- `createFile(uri, {content})` — writes the file if absent, then refreshes.
- `renameFile(from, newName)` — moves the file to a sibling of `from`;
  `newName` must be a bare file name (a blank name or one containing `/` throws
  `ArgumentError`).
- `deleteFile(uri)` — deletes through the seam, after a confirmation dialog.

**Filtering.** A search box above the tree narrows the view via the pure
`filterStructureNodes(nodes, query)` helper: a leaf is kept when its label
matches (case-insensitive), a directory is kept whole when its own label matches
or pruned to just its matching descendants otherwise. An empty query is a no-op.

Like the content browser, the explorer is **disabled** for websites without a
`content:` block, and a placeholder-resolution failure on `dir` surfaces as an
inline error rather than a silent blank tree.

### Deferred (gated on enterprise_flutter_web)

- **Rich editor embedding.** File nodes route to the correct editor *by kind*
  now; binding the live `tom_yaml_editor` / `tom_md_editor` widgets into the
  detail pane for in-place editing is reconciled in §9.7 alongside the content
  browser's editor embedding. Tracked in `completion_steps.tom_forge.md`.

## Config editor (§6)

`WebsiteConfigEditor` is the first-class editor for `tom.website-editor.yaml`
itself. It **extends `tom_yaml_editor`'s `ForgeYamlEditor`** — YAML syntax,
folding, dirty-state, undo/redo, and the save lifecycle all come from that
component — and layers website-config semantics on top:

- **Routing (self-registration, §2/§6).** The module contributes this editor
  through the standard `ForgeModule.editors` getter, so the Forge layout
  resolves it by `canHandle` like any other editor — no filename hand-wiring in
  the host app. `canHandle` **accepts only** the workspace file whose name
  matches `configFileName` (default `tom.website-editor.yaml`, the §2 naming
  convention) and **rejects everything else**. Rejecting (rather than
  `inspect`-ing) matters: this is a single instance bound to the on-disk config,
  and `ForgeYamlEditor`'s inherited `canHandleContent` accepts *any* `.yaml`, so
  an `inspect` result would let the config editor hijack every content `.yaml`
  opened from the browser. With `reject`, the config file routes here while the
  website's content files (`components/*.yaml`, `pages/*.md`, `site.yaml`) route
  to the standard YAML / Markdown editors via the layout's extension fallback.
- **Self-load.** Module-contributed editors are not handed file content by the
  shell, so the editor reads the on-disk text once via an injected
  `configReader` and marks the loaded document clean. A read failure leaves an
  empty document whose structural diagnostics tell the author the config is
  missing.
- **Schema + placeholder diagnostics.** On every edit it recomputes
  `configDiagnostics` via `websiteConfigDiagnostics` — the *same* runtime
  loader/validator and placeholder resolver the registry uses, so editor and
  runtime agree on validity (single source of truth). Unresolvable
  `{placeholder}` templates are flagged as warnings carrying the token and its
  location. The owning module forwards these to the shell diagnostic manager.
- **Save → reload.** The shell writes `getContent()` to disk and then calls
  `markClean()`; that triggers `onSaveReload`, wired to
  `WebsiteEditorController.reload`, which rebuilds the registry. An invalid
  document is rejected by the registry, which keeps the last-good config.

**Design decision (§7): YAML editor + schema, not a bespoke form.** The §6
spec asks for editing `tom.website-editor.yaml` (commands, content paths,
`editableFields`) "with validation against the sample/contract". Rather than a
hand-built form per field, the surface is the full `ForgeYamlEditor` plus the
runtime-shared `websiteConfigDiagnostics` — the author edits the YAML directly
and the *same* loader/resolver the runtime uses tells them, live, what is
invalid. This keeps one source of truth (no form schema that can drift from the
loader), and any structure the loader understands (new commands, new websites)
is editable the day the loader supports it, with no editor change. The
config-specific value `WebsiteConfigEditor` adds over a plain YAML editor is
exactly the three layers above: filename routing, the schema/placeholder
diagnostics, and the save→reload hook.

**Invalid edits surface as shell issues (§7 "done when").** The module creates a
`website-editor-config` diagnostic collection and forwards the editor's
`configDiagnostics` into it on every edit (`WebsiteEditorModule`), so an invalid
edit — e.g. a malformed `commands:` value — appears in the shell's diagnostic
manager keyed to the config URI, not just inside the editor. `deactivate()`
retracts them. This module→shell forwarding is pinned by `TWE-MOD-01..04`.

The config panel's **Edit configuration** action opens the file in this editor
via `ForgeShellApi.layout.openFile`.

> Diagnostics are currently anchored at line 0 — `tom_website_editor_core`'s
> `ConfigIssue` carries no source line/column, so the offending path travels in
> the diagnostic `code`. Precise line mapping is a deferred refinement (an
> owning-package change in `tom_website_editor_core`); tracked in
> `completion_steps.tom_forge.md`.

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
- `test/config/website_config_diagnostics_test.dart` — schema agreement with the
  runtime loader (valid → none, missing version / malformed commands / malformed
  paths → errors) and placeholder awareness (unknown → warning, resolvable /
  built-in → none, no placeholder noise on invalid config) (TWE-CFGDIAG-01..08).
- `test/website_config_editor_test.dart` — routing (`canHandle` accepts the
  config, rejects other YAML/Markdown/unrelated files so content routes to the
  standard editors), the one-time self-load (loaded clean, read-failure → empty
  clean), diagnostics recompute on edit, and the save → reload hook (markClean
  triggers reload, self-load does not) (TWE-CFGED-01..10).
- `test/website_editor_module_test.dart` — the §7 in-shell surface: the module
  forwards the config editor's diagnostics into the shell diagnostic manager, so
  editing the open config to an invalid command surfaces a shell issue, fixing it
  clears the issue, and `deactivate()` retracts it (TWE-MOD-01..04); plus the §5
  refresh-after-generate wiring — a control-panel `generateAll` run refreshes
  both the content tree and the structure explorer from disk and logs the drift
  output (TWE-MOD-05).
- `test/website_preview_controller_test.dart` — URL resolution per source,
  recompute on selection, refresh token, resolve-error surfacing, external open
  (TWE-PREV-CTL-01..10).
- `test/website_preview_view_test.dart` — webview URL rendering, source toggle,
  website picker, refresh, error state, external open, reactive title
  (TWE-PREV-VIEW-01..07).
- `test/website_control_controller_test.dart` — button availability, shell-argv
  + cwd expansion, log-before-run echo, stdout/stderr log levels, the 0/1/2
  exit-code mapping, `--dry-run`, unconfigured-command + resolve-error handling,
  running/stop lifecycle (TWE-CTRL-01..15), and the content-regeneration refresh
  callback (`generateContent`/`generateAll` fire `onContentRegenerated`, `build`
  does not, dry-runs do not) (TWE-CTRL-16..18).
- `test/website_control_view_test.dart` — command buttons (enabled/disabled),
  tap-spawns-process, log echo + completion, website picker, status line, reactive
  title, level filtering, dev-server start/stop toggle (TWE-CTRLV-01..08).
- `test/website_dev_server_test.dart` — dev-server lifecycle: non-blocking start,
  no-serveStart error, stop/kill, single-spawn, restart, self-exit clearing,
  auto-refresh on matching stdout, output→log levels, default matcher
  (TWE-SRV-01..11).
- `test/content/content_model_test.dart` — typed-suffix editor routing, record
  tree parsing, field classification (managed/editable/pinned), span-precise
  `# @manual` read + `pinFieldLine` write, `setFieldLineValue` scalar rewrite
  (quote/indent/pin-preserve), the override/managed page-region round-trip, the
  `_generated`-block→record-provenance capture, and `valueHasPlaceholder` token
  detection (TWE-MODEL-01..08).
- `test/content/website_content_controller_test.dart` — catalog build (component
  → module → submodule, incl. a module with and without submodules), site/pages
  discovery, pin-writes-to-disk + re-parse, editable-field save + re-parse
  (managed/unchanged no-op, pinned keeps marker), disabled-without-content,
  refresh reload, placeholder-failure surfacing (TWE-CTRL-01..06), and copy-file
  load + front-matter/body save surviving generate (TWE-CTRL-07).
- `test/content/content_copy_file_test.dart` — the §16 copy-file model: parse
  front-matter + body, editor-kind routing, byte-for-byte round-trip (with and
  without front-matter), front-matter-field edit (unknown-field no-op), and a
  body override-region edit preserving the managed region + markers
  (TWE-COPY-01..04).
- `test/content/website_content_browser_test.dart` — disabled state, tree
  render, managed pin button vs editable field, pin writes the pin, typed
  inline-editor routing, tap-opens-backing-file navigation, detail-pane open
  button, inline scalar save, managed has no inline editor, `-md` routes to the
  full editor, the search box narrowing the catalog, the managed-field
  provenance badge + tooltip, the placeholder-value generate-time hint, and the
  pinned-field pin-state tooltip (TWE-BROWSE-01..14).
- `test/structure/copy_naming_test.dart` — §16 copy-file naming: parse/encode
  round-trip per kind, arity validation, non-convention files preserved, and the
  `component → module → submodule` grouping (CN-01..11).
- `test/structure/website_structure_controller_test.dart` — disabled state, tree
  mirroring `content/`, §16 copy grouping, editor-kind routing, convention-path
  file creation, placeholder-failure surfacing (WSC-01..07), free-form
  create/delete/rename + rename validation (WSC-08..11), and the pure
  `filterStructureNodes` helper (WSC-FILTER-01..04).
- `test/structure/website_structure_explorer_test.dart` — disabled state, tree
  render with grouped copy, yaml/md editor-routing on selection
  (TWE-STRUCT-01..04), the search box narrowing the tree, the new-file /
  rename / delete affordances (TWE-STRUCT-05..08), and the open-file seam —
  tapping a yaml / page-md / grouped copy-md node and the detail-pane
  **Open in editor** button both fire `onOpenFile` with the resolved uri
  (TWE-STRUCT-09..10).
