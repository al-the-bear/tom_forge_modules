# Changelog

## 0.1.0

- `ForgeShellTheme` (dark, light, high contrast), `ForgeDimensions` and
  `ForgeAnimations`, taken out of `tom_forge_shell`, which re-exports them.
- `ForgeShellTheme.forMode` follows the platform's brightness for
  `ThemeMode.system`; high contrast is its own flag.
- `forgeThemeData`: the Material theme of a Forge application with the shell
  theme installed.
