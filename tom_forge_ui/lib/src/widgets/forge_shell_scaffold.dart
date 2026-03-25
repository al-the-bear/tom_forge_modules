import 'package:flutter/material.dart';

import '../components/forge_editor.dart';
import '../defaults/default_layout_controller.dart';
import '../defaults/default_notification_manager.dart';
import '../defaults/default_system_state.dart';
import '../model/forge_application.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_shell_api.dart';
import '../shell/forge_status_bar_controller.dart';
import 'forge_editor_tab_bar.dart';
import 'forge_notification_overlay.dart';
import 'forge_panel_widget.dart';
import 'forge_status_bar_widget.dart';

/// Root shell layout widget.
///
/// Composes title bar, menu bar, side panels, middle editor area,
/// bottom panel, and status bar.
class ForgeShellScaffold extends StatefulWidget {
  final ForgeShellApi shell;
  final ForgeApplication application;
  final DefaultLayoutController layoutController;
  final DefaultSystemState systemState;
  final ForgeStatusBarController statusBarController;
  final DefaultNotificationManager notificationManager;

  const ForgeShellScaffold({
    super.key,
    required this.shell,
    required this.application,
    required this.layoutController,
    required this.systemState,
    required this.statusBarController,
    required this.notificationManager,
  });

  @override
  State<ForgeShellScaffold> createState() => _ForgeShellScaffoldState();
}

class _ForgeShellScaffoldState extends State<ForgeShellScaffold> {
  DefaultLayoutController get _layout => widget.layoutController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildTitleBar(context),
            Expanded(child: _buildMainArea(context)),
            _buildBottomPanel(context),
            ForgeStatusBarWidget(controller: widget.statusBarController),
          ],
        ),
        ForgeNotificationOverlay(manager: widget.notificationManager),
      ],
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Container(
      height: 30,
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      child: Text(
        widget.application.title,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildMainArea(BuildContext context) {
    return ValueListenableBuilder<LayoutPanelConfig>(
      valueListenable: _layout.leftPanel,
      builder: (context, leftConfig, _) {
        return ValueListenableBuilder<LayoutPanelConfig>(
          valueListenable: _layout.rightPanel,
          builder: (context, rightConfig, _) {
            return Row(
              children: [
                if (leftConfig.isVisible)
                  _buildSidePanel(
                    context,
                    width: leftConfig.size,
                    tabs: widget.application.layout.leftPanel.tabs,
                  ),
                if (leftConfig.isVisible) const VerticalDivider(width: 1),
                Expanded(child: _buildMiddleArea(context)),
                if (rightConfig.isVisible) const VerticalDivider(width: 1),
                if (rightConfig.isVisible)
                  _buildSidePanel(
                    context,
                    width: rightConfig.size,
                    tabs: widget.application.layout.rightPanel.tabs,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSidePanel(
    BuildContext context, {
    required double width,
    required List<PanelTabConfig> tabs,
  }) {
    if (tabs.isEmpty) {
      return SizedBox(width: width);
    }
    return SizedBox(
      width: width,
      child: ForgePanelWidget(tabs: tabs),
    );
  }

  Widget _buildMiddleArea(BuildContext context) {
    return ValueListenableBuilder<List<List<ForgeEditor>>>(
      valueListenable: _layout.middlePanels,
      builder: (context, panels, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _layout.activeMiddlePanelIndexNotifier,
          builder: (context, activeIdx, _) {
            if (panels.isEmpty || panels.every((p) => p.isEmpty)) {
              return Center(
                child: Text(
                  'Open a file to get started',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                ),
              );
            }
            return Row(
              children: [
                for (var i = 0; i < panels.length; i++) ...[
                  if (i > 0) const VerticalDivider(width: 1),
                  Expanded(
                    child: _buildEditorPanel(
                      context,
                      editors: panels[i],
                      isActive: i == activeIdx,
                      panelIndex: i,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEditorPanel(
    BuildContext context, {
    required List<ForgeEditor> editors,
    required bool isActive,
    required int panelIndex,
  }) {
    if (editors.isEmpty) {
      return const SizedBox.expand();
    }
    final activeEditor = widget.systemState.activeEditor;
    final currentEditor =
        editors.contains(activeEditor) ? activeEditor : editors.last;

    return Column(
      children: [
        ForgeEditorTabBar(
          editors: editors,
          activeEditor: currentEditor,
          onSelect: (editor) {
            _layout.setActiveMiddlePanelIndex(panelIndex);
            widget.systemState.setActiveEditor(editor);
          },
          onClose: (editor) => _layout.closeEditor(editor),
        ),
        Expanded(
          child: currentEditor?.buildMain(context) ?? const SizedBox.expand(),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return ValueListenableBuilder<LayoutPanelConfig>(
      valueListenable: _layout.bottomPanel,
      builder: (context, config, _) {
        if (!config.isVisible) return const SizedBox.shrink();
        final tabs = widget.application.layout.bottomPanel.tabs;
        if (tabs.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: config.size,
          child: Column(
            children: [
              const Divider(height: 1),
              Expanded(child: ForgePanelWidget(tabs: tabs)),
            ],
          ),
        );
      },
    );
  }
}
