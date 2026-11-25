# tom_forge_agentic

Reusable Flutter **agent/chat UI** for Tom Forge tools.

This package holds **UI only** (decisions D1/N7 of the TomSpecs Editor
specification). Every agent/chat-enabled Forge tool reuses these widgets so it
renders an identical experience:

- chat composer
- prompt queue
- prompt trail
- agent settings
- navigation / mutation tool surface
- change-log + three-way review

The views and controllers themselves need no shell and live in
[`tom_agentic_ui`](../../modules/tom_agentic_ui) (`tom_ai/modules`),
which this package depends on and re-exports, so a Forge tool imports
`package:tom_forge_agentic/tom_forge_agentic.dart` alone. This package adds
what needs the Forge kit: `AgentChatModule`, the chat view and the queue and
trail editors. It takes the kit only, not the panel shell: `AgentChatModule`
is a `ForgeKitModule`, which any application on the kit registers — the panel
shell's registry included.

All **non-UI logic** — the provider/model API, prompt-queue/trail/profile
models, and the placeholder engine — lives in
[`tom_core_agentic`](../../core_extension/tom_core_agentic), which this package
depends on. Widgets here render over those models; they never own transport
specifics (the Agent-SDK transport stays in `tom_vscode_scripting_api`).

## Status

In use by the TomSpecs editor (`tom_specs_editor`). What it exports:

- `AgentChatModule` — the module an agent-enabled tool registers: it owns the
  connection, send, prompt-queue and prompt-trail controllers and offers the
  chat view (connection picker and composer) and the queue and trail editors
  for the application's layout. The host gives it the workspace's
  `TomFileSystem` (and its process environment): the controllers keep their
  sidecars — bridge choice, session id, queue, trail — there, through
  `tom_core_agentic`'s stores. A controller takes its store; `load()` is
  asynchronous, and `saved` completes when its writes have landed.
- `PromptQueueEditor`, `PromptTrailEditor` — the queue and trail as Forge
  editors.
- Re-exported from `tom_agentic_ui`:
  - Connection — `AgentConnectionController`, `AgentConnectionPicker`.
  - Sending — `AgentSendController`, `AgentSendPanel`, `AgentReconnectBanner`,
    `ChatComposerPanel`, `ChatSendCoordinator`, the placeholder preview.
    Prompt composition is asynchronous (`PromptCompose`): a composer may read
    the files a prompt injects.
  - Prompt queue and trail — their controllers and views.
  - Change log and review — `ChangeEntry`, `ChangeLog`, `ChangeLogPanel`,
    `ChangeReviewPanel`.

It is layer 7 (shell services) of the platform architecture
(`../_agent_guidelines/platform_architecture.md`): it builds on the kit, and
modules build on it.
