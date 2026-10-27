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

Scaffold (Stage B, step 8 of the editor implementation plan). The only export
today is `AgentPanelPlaceholder`, a stand-in panel that also exercises the
`tom_core_agentic` wiring. The concrete views (composer, queue, trail,
settings) are added in Stage C and Stage D.
