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

All **non-UI logic** — the provider/model API, prompt-queue/trail/profile
models, and the placeholder engine — lives in
[`tom_core_agentic`](../../tom_ai/core_extension/tom_core_agentic), which this package
depends on. Widgets here render over those models; they never own transport
specifics (the Agent-SDK transport stays in `tom_vscode_scripting_api`).

## Status

In use by the TomSpecs editor (`tom_specs_editor`). What it exports:

- `AgentChatModule` — the module an agent-enabled tool registers: it owns the
  connection, send, prompt-queue and prompt-trail controllers and offers the
  chat view (connection picker and composer) and the queue and trail editors
  for the application's layout.
- Connection — `AgentConnectionController`, `AgentConnectionPicker`.
- Sending — `AgentSendController`, `AgentSendPanel`, `AgentReconnectBanner`,
  `ChatComposerPanel`, `ChatSendCoordinator`, the placeholder preview.
- Prompt queue and trail — their controllers, editors and views.
- Change log and review — `ChangeEntry`, `ChangeLog`, `ChangeLogPanel`,
  `ChangeReviewPanel`.

It is layer 4 (shell services) of the platform architecture
(`../_copilot_guidelines/platform_architecture.md`): it builds on the shell,
and modules build on it.
