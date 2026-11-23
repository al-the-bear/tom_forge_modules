/// Reusable Flutter agent/chat UI for Tom Forge tools.
///
/// This package holds **UI only** (D1/N7). Every agent/chat-enabled Forge
/// tool renders an identical experience by reusing these widgets: the chat
/// composer, prompt queue, prompt trail, agent settings, the
/// navigation/mutation tool surface, and the change-log + three-way review.
/// The views and controllers themselves are `tom_agentic_ui`
/// (`tom_ai/modules`), re-exported here; this package adds what needs the
/// Forge kit: [AgentChatModule] (a `ForgeKitModule`, registered by any
/// application on the kit, the panel shell included), the chat view and the
/// queue and trail editors.
///
/// All non-UI logic — the provider/model API, prompt-queue/trail/profile
/// models, and the placeholder engine — lives in `tom_core_agentic`, which
/// this package depends on. Widgets here render over those models; they never
/// own transport specifics.
///
/// The entry point is [AgentChatModule]: a Forge module that owns the
/// connection, send, prompt-queue and prompt-trail controllers and offers the
/// chat view and the queue and trail editors for an application's layout.
library;

// The views and controllers: tom_agentic_ui (tom_ai/modules), re-exported so
// every Forge tool keeps its imports.
export 'package:tom_agentic_ui/tom_agentic_ui.dart';

export 'src/agent_chat_module.dart';
export 'src/agent_chat_view.dart';
export 'src/queue/prompt_queue_editor.dart';
export 'src/trail/prompt_trail_editor.dart';
