/// The look Forge's shell and the applications beside it share, without the
/// shell: the theme tokens ([ForgeShellTheme], installed with
/// [forgeThemeData]), the layout dimensions ([ForgeDimensions]), the
/// animation timings ([ForgeAnimations]), the action bar ([ForgeActionBar]
/// over [ForgeActionGroup]s of [ForgeActionItem]s) and the status bar
/// ([ForgeStatusBar] over [ForgeStatusItem]s), and the shell's overlays and
/// dialogs: [ForgeInputBoxOverlay], [ForgeQuickPickOverlay],
/// [ForgeErrorRecoveryDialog], [ForgeFocusIndicator].
///
/// It depends on Flutter and `tom_ui_support` only, so a package that needs
/// Forge's look — Webwork, a quest application — takes it without the panel
/// shell, the terminal, the editors or a webview. `tom_forge_shell`
/// re-exports it.
library;

export 'src/action_bar/forge_action_bar.dart';
export 'src/action_bar/forge_action_item.dart';
export 'src/forge_animations.dart';
export 'src/forge_dimensions.dart';
export 'src/forge_fixed_listenable.dart';
export 'src/forge_shell_theme.dart';
export 'src/forge_theme_data.dart';
export 'src/overlays/forge_error_recovery_dialog.dart';
export 'src/overlays/forge_focus_indicator.dart';
export 'src/overlays/forge_input_box_overlay.dart';
export 'src/overlays/forge_quick_pick_item.dart';
export 'src/overlays/forge_quick_pick_overlay.dart';
export 'src/status_bar/forge_status_bar.dart';
export 'src/status_bar/forge_status_item.dart';
