import 'package:flutter/material.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

void main() => runApp(const SharedUiExampleApp());

/// A panel and a status bar in Forge's look, following the platform.
class SharedUiExampleApp extends StatelessWidget {
  const SharedUiExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forge shared UI',
      themeMode: ThemeMode.system,
      theme: forgeThemeData(Brightness.light),
      darkTheme: forgeThemeData(Brightness.dark),
      highContrastTheme: forgeThemeData(Brightness.light, highContrast: true),
      highContrastDarkTheme: forgeThemeData(
        Brightness.dark,
        highContrast: true,
      ),
      home: const _Panel(),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = theme.extension<ForgeShellTheme>()!;
    return Scaffold(
      backgroundColor: shell.panelSurface,
      body: Column(
        children: [
          Container(
            height: ForgeDimensions.sectionHeaderHeight,
            color: shell.sectionHeader,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('EXPLORER', style: theme.textTheme.labelMedium),
          ),
          Divider(
            height: ForgeDimensions.dividerVisual,
            thickness: ForgeDimensions.dividerVisual,
            color: shell.panelDivider,
          ),
          const Expanded(child: SizedBox.shrink()),
          Container(
            height: ForgeDimensions.statusBarHeight,
            color: shell.statusBarBackground,
          ),
        ],
      ),
    );
  }
}
