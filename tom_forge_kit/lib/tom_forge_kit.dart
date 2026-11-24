/// Tom Forge Kit — the layout-free part of Forge: what a component sees and
/// what a module contributes, with no widgets and no layout of its own.
///
/// - **Contracts:** components, editors and views ([ForgeComponent],
///   [ForgeEditor], [ForgeView]), editor types an application opens files
///   with by extension ([ForgeKitEditorType]), modules ([ForgeKitModule]
///   with its [ForgeModuleExtra]s), and the views modules contribute with a
///   layout-free placement hint ([ForgeViewPlacementHint],
///   [forgeContributedViews]).
/// - **Data:** actions and their state ([ForgeActionRegistry]), shortcuts
///   ([ForgeShortcutManager]), context-menu entries
///   ([ForgeContextMenuController], [ForgeContextMenuEntry]), status items
///   ([ForgeKitStatusItem]), quick pick items, notifications; what an
///   element draws of them — the state of an action ([ForgeActionState]),
///   an action bar ([ForgeActionBarModel]), a menu ([ForgeMenuModel]), the
///   command list ([ForgeCommandListModel]).
/// - **Routing to the active editor:** the standard editing actions and
///   their keys ([installForgeStandardEditingActions]), the action of a key
///   ([forgeActionIdForKey]), Find ([forgeFindActionId]), the state an editor
///   surface reports to ([ForgeEditorStateSink]).
/// - **The API a component sees:** [ForgeKitApi] over a [ForgeKitState];
///   where editors appear is the application's [ForgeEditorHost]; what is
///   persisted goes through a [ForgeStateStore] ([ForgeMemoryStateStore],
///   [ForgeSharedPreferencesStateStore], [ForgeFileStateStore]), written
///   once per gesture and never before the start's restore
///   ([ForgeCoalescedStateWriter]).
/// - **Files:** the kinds of file a module opens over a [ForgeFileSession]
///   ([ForgeKitFileKind], kept in a [ForgeFileKindRegistry] the application
///   fills) and the binding of an editor's controller to its session
///   ([ForgeSessionFile]).
/// - **Defaults:** [DefaultKitApi] and [DefaultKitState] for a host that is
///   not the panel shell, the default services, [ForgeAutosaveController].
///
/// `tom_forge_shell` builds the panel shell on it and re-exports it.
library;

// ── Actions ──
export 'src/actions/forge_action.dart';
export 'src/actions/forge_shortcut_binding.dart';
export 'src/actions/forge_shortcut_menu.dart';

// ── Components ──
export 'src/components/component_history_manager.dart';
export 'src/components/forge_component.dart';
export 'src/components/forge_editor.dart';
export 'src/components/forge_editor_choice.dart';
export 'src/components/forge_find_target.dart';
export 'src/components/forge_kit_editor_type.dart';
export 'src/components/forge_schema_editor.dart';
export 'src/components/forge_surface_editor.dart';
export 'src/components/forge_text_editor.dart';
export 'src/components/forge_view.dart';
export 'src/components/forge_visual_editor.dart';

// ── Files ──
// The session a file editor reads and saves its file through
// (tom_file_session), the binding of an editor's controller to it, and the
// file kinds a module opens files with.
export 'package:tom_file_session/tom_file_session.dart'
    show
        ForgeFileSaveOutcome,
        ForgeFileSession,
        ForgeFileSessionState,
        forgeReadOnlyAbove;
export 'src/files/forge_file_kind.dart';
// The binding itself is tom_file_session_ui's (one implementation for
// tom_file_editors and Forge); its frame widget is re-exported by
// tom_forge_shared_ui, since the kit has no widgets of its own.
export 'package:tom_file_session_ui/tom_file_session_ui.dart'
    show ForgeSessionFile;

// ── Kit ──
export 'src/kit/default_kit_api.dart';
export 'src/kit/default_kit_state.dart';
export 'src/kit/forge_active_editor.dart';
export 'src/kit/forge_coalesced_state_writer.dart';
export 'src/kit/forge_context_menu_controller.dart';
export 'src/kit/forge_editor_host.dart';
export 'src/kit/forge_editor_routing.dart';
export 'src/kit/forge_file_state_store.dart';
export 'src/kit/forge_host_ports.dart';
export 'src/kit/forge_kit_api.dart';
export 'src/kit/forge_kit_state.dart';
export 'src/kit/forge_memory_state_store.dart';
export 'src/kit/forge_shared_preferences_state_store.dart';
export 'src/kit/forge_state_store.dart';
export 'src/kit/forge_view_state_ports.dart';

// ── Model ──
// Data the kit's models use, from tom_forge_core (pure Dart, also what
// tom_forge_shared_ui draws).
export 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuEntry, ForgeQuickPickItem, StatusBarAlignment;
export 'src/model/forge_action_bar_model.dart';
export 'src/model/forge_action_state.dart';
export 'src/model/forge_command_list_model.dart';
export 'src/model/forge_kit_status_item.dart';
export 'src/model/forge_menu_model.dart';

// ── Module ──
export 'src/module/forge_kit_module.dart';
export 'src/module/forge_kit_module_registry.dart';
export 'src/module/forge_view_placement.dart';

// ── Providers ──
export 'src/providers/modified_file_decoration_provider.dart';

// ── Services ──
export 'src/services/forge_accessibility.dart';
export 'src/services/forge_action_registry.dart';
export 'src/services/forge_clipboard.dart';
export 'src/services/forge_config_manager.dart';
export 'src/services/forge_diagnostic_manager.dart';
export 'src/services/forge_dialog_manager.dart';
export 'src/services/forge_disposable.dart';
export 'src/services/forge_file_decoration_manager.dart';
export 'src/services/forge_file_navigator.dart';
export 'src/services/forge_kit_preferences.dart';
export 'src/services/forge_module_storage.dart';
export 'src/services/forge_navigation_history.dart';
export 'src/services/forge_notification_manager.dart';
export 'src/services/forge_outline_manager.dart';
export 'src/services/forge_output_channel_manager.dart';
export 'src/services/forge_progress_manager.dart';
export 'src/services/forge_revision_restorer.dart';
export 'src/services/forge_search_manager.dart';
export 'src/services/forge_shortcut_manager.dart';
export 'src/services/forge_undo_manager.dart';
export 'src/services/forge_workspace_state_manager.dart';

// ── Defaults ──
export 'src/defaults/default_action_registry.dart';
export 'src/defaults/default_clipboard.dart';
export 'src/defaults/default_config_manager.dart';
export 'src/defaults/default_diagnostic_manager.dart';
export 'src/defaults/default_dialog_manager.dart';
export 'src/defaults/default_module_registry.dart';
export 'src/defaults/default_notification_manager.dart';
export 'src/defaults/default_outline_manager.dart';
export 'src/defaults/default_output_manager.dart';
export 'src/defaults/default_progress_manager.dart';
export 'src/defaults/default_search_manager.dart';
export 'src/defaults/default_undo_manager.dart';
export 'src/defaults/default_workspace_state_manager.dart';
export 'src/defaults/editor_save.dart';
export 'src/defaults/forge_autosave_controller.dart';
export 'src/defaults/persistent_module_storage.dart';
export 'src/defaults/stub_services.dart';

// ── Integrations ──
export 'src/integrations/shell_editor_integration.dart';
