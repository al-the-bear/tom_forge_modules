import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

void main() => runApp(const SharedUiExampleApp());

/// An action bar, a panel and a status bar in Forge's look, following the
/// platform.
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
      home: const ExampleWindow(),
    );
  }
}

/// The window: the action bar edits a counter, the status bar shows it.
class ExampleWindow extends StatefulWidget {
  const ExampleWindow({super.key});

  @override
  State<ExampleWindow> createState() => _ExampleWindowState();
}

class _ExampleWindowState extends State<ExampleWindow> {
  final _count = ValueNotifier<int>(0);
  final _countText = ValueNotifier<String>('0 items');
  final _canRemove = ValueNotifier<bool>(false);
  final _busy = ValueNotifier<bool>(false);
  final _busyText = ValueNotifier<String>('Working');
  Timer? _work;

  @override
  void initState() {
    super.initState();
    _count.addListener(() {
      _countText.value = '${_count.value} items';
      _canRemove.value = _count.value > 0;
    });
  }

  @override
  void dispose() {
    _work?.cancel();
    for (final n in [_count, _countText, _canRemove, _busy, _busyText]) {
      n.dispose();
    }
    super.dispose();
  }

  void _startWork() {
    _busy.value = true;
    _work?.cancel();
    _work = Timer(const Duration(seconds: 2), () => _busy.value = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shell = theme.extension<ForgeShellTheme>()!;
    return Scaffold(
      backgroundColor: shell.panelSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: ForgeDimensions.titleBarHeight,
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: ForgeActionBar(
              groups: [
                ForgeActionGroup(
                  id: 'items',
                  items: [
                    ForgeActionItem(
                      id: 'add',
                      icon: Icons.add,
                      label: 'Add item',
                      shortcut: '⌘N',
                      onInvoke: () => _count.value++,
                    ),
                    ForgeActionItem(
                      id: 'remove',
                      icon: Icons.remove,
                      label: 'Remove item',
                      enabled: _canRemove,
                      onInvoke: () => _count.value--,
                    ),
                  ],
                ),
                ForgeActionGroup(
                  id: 'work',
                  items: [
                    ForgeActionItem(
                      id: 'work',
                      icon: Icons.sync,
                      label: 'Do some work',
                      onInvoke: _startWork,
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          ForgeStatusBar(
            items: [
              ForgeStatusItem(text: _countText, icon: Icons.list),
              ForgeStatusItem(
                text: _busyText,
                visible: _busy,
                emphasis: true,
                alignment: StatusBarAlignment.right,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
