/// The look Forge's shell and the applications beside it share, without the
/// shell and without a layout: one rendering of the models of
/// `tom_forge_kit`. Each element takes its data from the kit and acts
/// through its [ForgeKitApi]; an application uses an element, draws the
/// model itself, or leaves it out.
///
/// - **Tokens:** the theme ([ForgeShellTheme], installed with
///   [forgeThemeData]), the layout dimensions ([ForgeDimensions]), the
///   animation timings ([ForgeAnimations]).
/// - **Action bar:** [ForgeKitActionBar] over a [ForgeActionBarModel] (and
///   [ForgeActionBar] over [ForgeActionGroup]s of [ForgeActionItem]s).
/// - **Status bar:** [ForgeKitStatusBar] over [ForgeKitStatusItem]s (and
///   [ForgeStatusBar] over [ForgeStatusItem]s).
/// - **Menus and commands:** [ForgeMenuButton] and [forgeMenuChildren] over a
///   [ForgeMenuModel]; [ForgeCommandList] over a [ForgeCommandListModel].
/// - **Context menu:** [ForgeContextMenuPresenter] and
///   [showForgeKitContextMenu] over the kit's [ForgeContextMenuController]
///   (and [showForgeContextMenuEntries] over [ForgeContextMenuEntry]s).
/// - **Dialogs:** the kit's quick pick and input box (`api.dialogs`) drawn
///   by [ForgeDialogPresenter] / [ForgeDialogLayer] as
///   [ForgeQuickPickOverlay] and [ForgeInputBoxOverlay];
///   [ForgeErrorRecoveryDialog].
/// - **Notifications:** the toasts and the history of the kit's
///   notification manager ([ForgeNotificationOverlay],
///   [ForgeNotificationPopup], both together in [ForgeNotificationLayer]).
/// - **Focus:** [ForgeFocusIndicator] (keyboard focus, or the kit's focused
///   component with [ForgeFocusIndicator.kit]).
/// - **Editors:** [ForgeEditorSurface] shows any [ForgeEditor] connected to
///   the kit: its state, its keys, undo, redo, the clipboard and find.
///
/// It depends on Flutter, `tom_ui_support`, `tom_forge_core` and
/// `tom_forge_kit` only, so a package that needs Forge's look — Webwork, a
/// quest application — takes it without the panel shell, the terminal, the
/// editors or a webview. `tom_forge_shell` re-exports it.
library;

// The manager the notification views read (tom_forge_core), so a caller of
// the views needs no import of its own.
export 'package:tom_forge_core/tom_forge_core.dart'
    show DefaultNotificationManager, NotificationItem, NotificationSeverity;

export 'src/action_bar/forge_action_bar.dart';
export 'src/action_bar/forge_action_item.dart';
export 'src/command_list/forge_command_list.dart';
export 'src/context_menu/forge_context_menu.dart';
export 'src/editor_surface/forge_editor_surface.dart';
export 'src/forge_animations.dart';
export 'src/forge_dimensions.dart';
export 'src/forge_fixed_listenable.dart';
export 'src/forge_shell_theme.dart';
export 'src/forge_theme_data.dart';
export 'src/menus/forge_menu_button.dart';
export 'src/overlays/forge_dialog_presenter.dart';
export 'src/overlays/forge_error_recovery_dialog.dart';
export 'src/overlays/forge_focus_indicator.dart';
export 'src/overlays/forge_input_box_overlay.dart';
export 'src/overlays/forge_notification_layer.dart';
export 'src/overlays/forge_notification_overlay.dart';
export 'src/overlays/forge_notification_popup.dart';
export 'src/overlays/forge_quick_pick_item.dart';
export 'src/overlays/forge_quick_pick_overlay.dart';
export 'src/status_bar/forge_kit_status_bar.dart';
export 'src/status_bar/forge_status_bar.dart';
export 'src/status_bar/forge_status_item.dart';
