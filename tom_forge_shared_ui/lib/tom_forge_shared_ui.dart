/// The look Forge's shell and the applications beside it share, without the
/// shell: the theme tokens ([ForgeShellTheme], installed with
/// [forgeThemeData]), the layout dimensions ([ForgeDimensions]) and the
/// animation timings ([ForgeAnimations]).
///
/// It depends on Flutter and `tom_ui_support` only, so a package that needs
/// Forge's look — Webwork, a quest application — takes it without the panel
/// shell, the terminal, the editors or a webview. `tom_forge_shell`
/// re-exports it.
library;

export 'src/forge_animations.dart';
export 'src/forge_dimensions.dart';
export 'src/forge_shell_theme.dart';
export 'src/forge_theme_data.dart';
