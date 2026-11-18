/// The text and editor-contract types Forge's shell shares with its editors,
/// without the webview.
///
/// A library that only needs these types imports this one rather than
/// `package:tom_editors_shared/tom_editors_shared.dart`, which re-exports
/// everything here together with the tree, text-editor and validation
/// widgets.
///
/// - **Text settings**: [ForgeTextSettings], [ForgeTextDefaults]
/// - **Text context**: [ForgeTextContext], [TextEditingContextImpl]
/// - **Editing actions**: [StandardEditingActions], [ForgeAction],
///   [ForgeMenuLocation], [ForgeShortcutKey]
/// - **Editor contracts**: [EditorActionDescriptor], [ActionContext],
///   [EditorActionProvider], [EditorCapabilities], [EditorStateSnapshot],
///   [ForgeSavedMarker]
library;

export 'src/forge_bridge/editor_action_descriptor.dart';
export 'src/forge_bridge/editor_action_provider.dart';
export 'src/forge_bridge/editor_capabilities.dart';
export 'src/forge_bridge/editor_state_snapshot.dart';
export 'src/forge_bridge/forge_action.dart';
export 'src/forge_bridge/forge_shortcut_key.dart';
export 'src/text_editing/forge_text_context.dart';
export 'src/text_editing/forge_text_settings.dart';
export 'src/text_editing/history/forge_saved_marker.dart';
export 'src/text_editing/standard_editing_actions.dart';
