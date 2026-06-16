/// Reusable Flutter agent/chat UI for Tom Forge tools.
///
/// This package holds **UI only** (D1/N7). Every agent/chat-enabled Forge
/// tool renders an identical experience by reusing these widgets: the chat
/// composer, prompt queue, prompt trail, agent settings, the
/// navigation/mutation tool surface, and the change-log + three-way review.
///
/// All non-UI logic — the provider/model API, prompt-queue/trail/profile
/// models, and the placeholder engine — lives in `tom_core_agentic`, which
/// this package depends on. Widgets here render over those models; they never
/// own transport specifics.
///
/// The concrete views (composer, queue, trail, settings) are added in Stage C
/// and Stage D of the editor implementation plan; this scaffold establishes
/// the package and its wiring to `tom_core_agentic`.
library;

export 'src/agent_panel_placeholder.dart';
