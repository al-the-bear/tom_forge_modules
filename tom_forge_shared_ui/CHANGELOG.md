# Changelog

## 0.1.0

- `ForgeActionBar` over `ForgeActionGroup` / `ForgeActionItem`: groups,
  enablement per item, overflow menu. Forge's title-bar action bar uses it.
- `ForgeStatusBar` over `ForgeStatusItem` (visibility listenable, colour,
  emphasis, widget slot), with a rebuild listenable and a progress message.
  `StatusBarAlignment` moved here. Forge's status bar renders through it.
- `ForgeFixedListenable`.
- `ForgeInputBoxOverlay`, `ForgeQuickPickOverlay` with `ForgeQuickPickItem`,
  `ForgeErrorRecoveryDialog` with `ErrorRecoveryAction`, and
  `ForgeFocusIndicator`, taken out of `tom_forge_shell`, which re-exports
  them.

- `ForgeShellTheme` (dark, light, high contrast), `ForgeDimensions` and
  `ForgeAnimations`, taken out of `tom_forge_shell`, which re-exports them.
- `ForgeShellTheme.forMode` follows the platform's brightness for
  `ThemeMode.system`; high contrast is its own flag.
- `forgeThemeData`: the Material theme of a Forge application with the shell
  theme installed.
