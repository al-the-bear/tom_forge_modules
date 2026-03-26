import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_editor.dart';
import '../defaults/default_layout_controller.dart';
import '../defaults/default_shell_api.dart';
import '../defaults/default_system_state.dart';
import '../model/forge_application.dart';
import '../services/forge_preferences_service.dart';
import '../shell/forge_layout_controller.dart';
import '../shell/forge_status_bar_controller.dart';
import 'forge_command_palette.dart';
import 'forge_configuration_dialog.dart';
import 'forge_editor_tab_bar.dart';
import 'forge_menu_bar.dart';
import 'forge_notification_overlay.dart';
import 'forge_panel_widget.dart';
import 'forge_status_bar_widget.dart';

/// Animation constants for shell UI.
class ForgeAnimations {
  static const Duration panelTransition = Duration(milliseconds: 200);
  static const Duration tabTransition = Duration(milliseconds: 150);
  static const Duration dropZoneFade = Duration(milliseconds: 100);
  static const Duration shortcutPopupIn = Duration(milliseconds: 150);
  static const Duration shortcutPopupOut = Duration(milliseconds: 100);
  static const Duration notificationIn = Duration(milliseconds: 200);
  static const Duration notificationOut = Duration(milliseconds: 150);

  static const Curve panelCurve = Curves.easeOutCubic;
  static const Curve tabCurve = Curves.easeOut;
  static const Curve popupCurve = Curves.easeOutBack;
}

/// Dimension constants for shell layout.
class ForgeDimensions {
  // Panels
  static const double leftPanelMinWidth = 180;
  static const double leftPanelMaxWidth = 600;
  static const double leftPanelDefaultWidth = 280;
  static const double rightPanelMinWidth = 180;
  static const double rightPanelMaxWidth = 600;
  static const double rightPanelDefaultWidth = 280;
  static const double bottomPanelMinHeight = 100;
  static const double bottomPanelMaxHeight = 500;
  static const double bottomPanelDefaultHeight = 200;
  static const double middlePanelMinWidth = 200;

  // Fixed elements
  static const double titleBarHeight = 48;
  static const double menuBarHeight = 32;
  static const double statusBarHeight = 24;
  static const double tabBarHeight = 36;
  static const double sectionHeaderHeight = 32;
  static const double sideTabBarCollapsed = 48;
  static const double sideTabBarExpanded = 200;

  // Interactive
  static const double dividerHitTarget = 8;
  static const double dividerVisual = 1;

  // Icons
  static const double iconTab = 20;
  static const double iconToolbar = 18;
}

/// Root shell layout widget.
///
/// Layout structure per concept doc §2:
/// ```
/// Column:
///   TitleBar
///   MenuBar (optional)
///   Expanded(
///     Row:
///       LeftPanel (with vertical icon strip)
///       Column:
///         MiddleEditorPanels
///         BottomPanel (between left/right)
///       RightPanel (with vertical icon strip)
///   )
///   StatusBar
/// ```
class ForgeShellScaffold extends StatefulWidget {
  final DefaultShellApi shell;
  final ForgeApplication application;
  final DefaultLayoutController layoutController;
  final DefaultSystemState systemState;
  final ForgeStatusBarController statusBarController;
  final DefaultNotificationManager notificationManager;
  final ForgePreferencesService? preferencesService;

  const ForgeShellScaffold({
    super.key,
    required this.shell,
    required this.application,
    required this.layoutController,
    required this.systemState,
    required this.statusBarController,
    required this.notificationManager,
    this.preferencesService,
  });

  @override
  State<ForgeShellScaffold> createState() => _ForgeShellScaffoldState();
}

class _ForgeShellScaffoldState extends State<ForgeShellScaffold> {
  DefaultLayoutController get _layout => widget.layoutController;
  bool _showCommandPalette = false;

  void _openSettings() {
    final prefs = widget.preferencesService ?? ForgePreferencesService.instance;
    ForgeConfigurationDialog.show(context, prefs);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _buildShortcuts(),
      child: Actions(
        actions: _buildActions(),
        child: Focus(
          autofocus: true,
          child: Material(
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildTitleBar(context),
                    ForgeMenuBar(
                      shellApi: widget.shell,
                      onCommandPalette: _toggleCommandPalette,
                      onSettings: _openSettings,
                    ),
                    Expanded(child: _buildMainArea(context)),
                    ForgeStatusBarWidget(controller: widget.statusBarController),
                  ],
                ),
                ForgeNotificationOverlay(manager: widget.notificationManager),
                if (_showCommandPalette)
                  ForgeCommandPalette(
                    shellApi: widget.shell,
                    onDismiss: _toggleCommandPalette,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, Intent> _buildShortcuts() {
    return {
      // Command Palette: Cmd+P
      const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
          const _CommandPaletteIntent(),
      // Toggle Left Panel: Cmd+L
      const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
          const _ToggleLeftPanelIntent(),
      // Toggle Right Panel: Cmd+R
      const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
          const _ToggleRightPanelIntent(),
      // Focus Explorer: Cmd+1
      const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
          const _FocusLeftPanelIntent(),
      // Focus Editor: Cmd+2
      const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
          const _FocusCenterIntent(),
      // Focus Properties: Cmd+3
      const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
          const _FocusRightPanelIntent(),
      // Focus Bottom Panel: Cmd+4
      const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
          const _FocusBottomPanelIntent(),
      // Save: Cmd+S
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
          const _SaveIntent(),
    };
  }

  Map<Type, Action<Intent>> _buildActions() {
    return {
      _CommandPaletteIntent: CallbackAction<_CommandPaletteIntent>(
        onInvoke: (_) {
          _toggleCommandPalette();
          return null;
        },
      ),
      _ToggleLeftPanelIntent: CallbackAction<_ToggleLeftPanelIntent>(
        onInvoke: (_) {
          widget.shell.layout.togglePanel(ForgePanelLocation.left);
          return null;
        },
      ),
      _ToggleRightPanelIntent: CallbackAction<_ToggleRightPanelIntent>(
        onInvoke: (_) {
          widget.shell.layout.togglePanel(ForgePanelLocation.right);
          return null;
        },
      ),
      _FocusLeftPanelIntent: CallbackAction<_FocusLeftPanelIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.left);
          return null;
        },
      ),
      _FocusCenterIntent: CallbackAction<_FocusCenterIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.middle);
          return null;
        },
      ),
      _FocusRightPanelIntent: CallbackAction<_FocusRightPanelIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.right);
          return null;
        },
      ),
      _FocusBottomPanelIntent: CallbackAction<_FocusBottomPanelIntent>(
        onInvoke: (_) {
          widget.systemState.setFocusedPanelLocation(ForgePanelLocation.bottom);
          return null;
        },
      ),
      _SaveIntent: CallbackAction<_SaveIntent>(
        onInvoke: (_) {
          _executeSave();
          return null;
        },
      ),
    };
  }

  void _toggleCommandPalette() {
    setState(() => _showCommandPalette = !_showCommandPalette);
  }

  void _executeSave() {
    for (final module in widget.shell.modules.allModules) {
      final action = module.actions
          .where((a) => a.id == 'file.save' || a.id == 'file.saveAll')
          .firstOrNull;
      if (action != null) {
        action.execute({});
        return;
      }
    }
  }

  Widget _buildTitleBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: ForgeDimensions.titleBarHeight,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Back/Forward navigation (per concept §2.1)
          IconButton(
            icon: Icon(Icons.arrow_back, size: ForgeDimensions.iconToolbar),
            onPressed: null, // Disabled until component history is implemented
            tooltip: 'Back',
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward, size: ForgeDimensions.iconToolbar),
            onPressed: null,
            tooltip: 'Forward',
          ),
          const SizedBox(width: 16),
          // Application title / search field (per concept §2.1)
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                height: 32,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.search,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.application.title,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Application dropdown (per concept §2.1)
          PopupMenuButton<String>(
            tooltip: 'Switch Application',
            itemBuilder: (context) => [
              PopupMenuItem(
                value: widget.application.title,
                child: Text(widget.application.title),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.application.title, style: theme.textTheme.bodySmall),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        ],
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
                // Left Panel with vertical icon strip on LEFT edge
                if (leftConfig.isVisible)
                  _buildSidePanel(
                    context,
                    width: leftConfig.size,
                    tabs: widget.application.layout.leftPanel.tabs,
                    iconStripPosition: IconStripPosition.left,
                  ),
                if (leftConfig.isVisible) const VerticalDivider(width: 1),

                // Middle area: editor panels + bottom panel
                Expanded(child: _buildCenterColumn(context)),

                // Right Panel with vertical icon strip on RIGHT edge
                if (rightConfig.isVisible) const VerticalDivider(width: 1),
                if (rightConfig.isVisible)
                  _buildSidePanel(
                    context,
                    width: rightConfig.size,
                    tabs: widget.application.layout.rightPanel.tabs,
                    iconStripPosition: IconStripPosition.right,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the center column containing middle panels and bottom panel.
  /// Bottom panel is positioned between left/right panels per concept §2.5.
  Widget _buildCenterColumn(BuildContext context) {
    return ValueListenableBuilder<LayoutPanelConfig>(
      valueListenable: _layout.bottomPanel,
      builder: (context, bottomConfig, _) {
        return Column(
          children: [
            // Middle editor panels
            Expanded(child: _buildMiddleArea(context)),
            // Bottom panel (between left/right, below middle)
            if (bottomConfig.isVisible) _buildBottomPanel(context, bottomConfig),
          ],
        );
      },
    );
  }

  Widget _buildSidePanel(
    BuildContext context, {
    required double width,
    required List<PanelTabConfig> tabs,
    required IconStripPosition iconStripPosition,
  }) {
    if (tabs.isEmpty) {
      return SizedBox(width: width);
    }
    return SizedBox(
      width: width,
      child: ForgeSidePanelWidget(
        tabs: tabs,
        iconStripPosition: iconStripPosition,
      ),
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

  Widget _buildBottomPanel(BuildContext context, LayoutPanelConfig config) {
    final tabs = widget.application.layout.bottomPanel.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: config.size,
      child: Column(
        children: [
          const Divider(height: 1),
          // Bottom panel uses horizontal tabs with icon+text
          Expanded(child: ForgePanelWidget(tabs: tabs)),
        ],
      ),
    );
  }
}

// ── Intents for keyboard shortcuts ──

class _CommandPaletteIntent extends Intent {
  const _CommandPaletteIntent();
}

class _ToggleLeftPanelIntent extends Intent {
  const _ToggleLeftPanelIntent();
}

class _ToggleRightPanelIntent extends Intent {
  const _ToggleRightPanelIntent();
}

class _FocusLeftPanelIntent extends Intent {
  const _FocusLeftPanelIntent();
}

class _FocusCenterIntent extends Intent {
  const _FocusCenterIntent();
}

class _FocusRightPanelIntent extends Intent {
  const _FocusRightPanelIntent();
}

class _FocusBottomPanelIntent extends Intent {
  const _FocusBottomPanelIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
