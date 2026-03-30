import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  static const double dividerHitTarget = 14;
  static const double dividerVisual = 2;

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
  static bool debugEnabled = false;

  static const String _actionFileSave = 'file.save';
  static const String _actionFileSaveAll = 'file.saveAll';

  DefaultLayoutController get _layout => widget.layoutController;
  bool _showCommandPalette = false;
  late final ForgePreferencesService _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = widget.preferencesService ?? ForgePreferencesService.instance;
    _preferences.addListener(_onPreferencesChanged);
    _initializePreferences();
  }

  @override
  void dispose() {
    _preferences.removeListener(_onPreferencesChanged);
    super.dispose();
  }

  Future<void> _initializePreferences() async {
    try {
      if (!_preferences.isLoaded) {
        await _preferences.load();
      }
      _applyPreferenceTextSettings();
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] initialize preferences failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _onPreferencesChanged() {
    try {
      _applyPreferenceTextSettings();
      if (mounted) {
        setState(() {});
      }
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] apply preferences failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _applyPreferenceTextSettings() {
    final settings = _preferences.editorTextSettings;
    for (final entry in settings.entries) {
      widget.shell.setTextSettings(entry.key, entry.value);
    }
    if (debugEnabled) {
      debugPrint('[ForgeShellScaffold] applied persisted settings: ${settings.length}');
    }
  }

  void _openSettings() {
    ForgeConfigurationDialog.show(context, _preferences, widget.shell);
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
    try {
      final useMetaPrimary = defaultTargetPlatform == TargetPlatform.macOS;

      SingleActivator primaryActivator(
        LogicalKeyboardKey key, {
        bool shift = false,
      }) {
        return SingleActivator(
          key,
          meta: useMetaPrimary,
          control: !useMetaPrimary,
          shift: shift,
        );
      }

      final shortcuts = {
        primaryActivator(LogicalKeyboardKey.keyP):
            const _CommandPaletteIntent(),
        primaryActivator(LogicalKeyboardKey.keyL):
            const _ToggleLeftPanelIntent(),
        primaryActivator(LogicalKeyboardKey.keyR):
            const _ToggleRightPanelIntent(),
        primaryActivator(LogicalKeyboardKey.digit1):
            const _FocusLeftPanelIntent(),
        primaryActivator(LogicalKeyboardKey.digit2): const _FocusCenterIntent(),
        primaryActivator(LogicalKeyboardKey.digit3):
            const _FocusRightPanelIntent(),
        primaryActivator(LogicalKeyboardKey.digit4):
            const _FocusBottomPanelIntent(),
        primaryActivator(LogicalKeyboardKey.keyS): const _SaveIntent(),
      };

      if (debugEnabled) {
        debugPrint('[ForgeShellScaffold] shortcut count: ${shortcuts.length}');
      }

      return shortcuts;
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] build shortcuts failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
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
    try {
      if (widget.shell.executeAction(_actionFileSave)) {
        return;
      }

      widget.shell.executeAction(_actionFileSaveAll);
    } catch (error, stackTrace) {
      debugPrint('[ForgeShellScaffold] execute save failed: $error');
      debugPrint('$stackTrace');
      rethrow;
    }
  }

  Widget _buildTitleBar(BuildContext context) {
    const navClusterWidth = 112.0;
    final theme = Theme.of(context);
    return Container(
      height: ForgeDimensions.titleBarHeight,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Back/Forward navigation (per concept §2.1)
          SizedBox(
            width: navClusterWidth,
            child: Row(
              children: [
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
              ],
            ),
          ),
          // Center cluster: search field + application switcher.
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    width: 400,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
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
                  const SizedBox(width: 12),
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
            ),
          ),
          // Keep center cluster visually centered by mirroring nav width.
          const SizedBox(width: navClusterWidth),
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
                    showConfigTab: true,
                    onConfigTap: _openSettings,
                    configurationPanelBuilder: _buildConfigurationPanel,
                  ),
                if (leftConfig.isVisible)
                  _buildVerticalResizeHandle(
                    onDragDelta: _resizeLeftPanel,
                  ),

                // Middle area: editor panels + bottom panel
                Expanded(child: _buildCenterColumn(context)),

                // Right Panel with vertical icon strip on RIGHT edge
                if (rightConfig.isVisible)
                  _buildVerticalResizeHandle(
                    onDragDelta: _resizeRightPanel,
                  ),
                if (rightConfig.isVisible)
                  _buildSidePanel(
                    context,
                    width: rightConfig.size,
                    tabs: widget.application.layout.rightPanel.tabs,
                    iconStripPosition: IconStripPosition.right,
                    showConfigTab: false,
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
            if (bottomConfig.isVisible)
              _buildHorizontalResizeHandle(
                onDragDelta: _resizeBottomPanel,
              ),
            if (bottomConfig.isVisible) _buildBottomPanel(context, bottomConfig),
          ],
        );
      },
    );
  }

  void _resizeLeftPanel(double deltaX) {
    final current = _layout.leftPanel.value;
    final nextSize = (current.size + deltaX).clamp(
      ForgeDimensions.leftPanelMinWidth,
      ForgeDimensions.leftPanelMaxWidth,
    );
    _layout.setPanelSize(ForgePanelLocation.left, nextSize);
  }

  void _resizeRightPanel(double deltaX) {
    final current = _layout.rightPanel.value;
    final nextSize = (current.size - deltaX).clamp(
      ForgeDimensions.rightPanelMinWidth,
      ForgeDimensions.rightPanelMaxWidth,
    );
    _layout.setPanelSize(ForgePanelLocation.right, nextSize);
  }

  void _resizeBottomPanel(double deltaY) {
    final current = _layout.bottomPanel.value;
    final nextSize = (current.size - deltaY).clamp(
      ForgeDimensions.bottomPanelMinHeight,
      ForgeDimensions.bottomPanelMaxHeight,
    );
    _layout.setPanelSize(ForgePanelLocation.bottom, nextSize);
  }

  Widget _buildVerticalResizeHandle({
    required ValueChanged<double> onDragDelta,
  }) {
    return _ResizeHandle(
      axis: Axis.horizontal,
      onDragDelta: onDragDelta,
    );
  }

  Widget _buildHorizontalResizeHandle({
    required ValueChanged<double> onDragDelta,
  }) {
    return _ResizeHandle(
      axis: Axis.vertical,
      onDragDelta: onDragDelta,
    );
  }

  Widget _buildSidePanel(
    BuildContext context, {
    required double width,
    required List<PanelTabConfig> tabs,
    required IconStripPosition iconStripPosition,
    bool showConfigTab = false,
    VoidCallback? onConfigTap,
    WidgetBuilder? configurationPanelBuilder,
  }) {
    if (tabs.isEmpty && !showConfigTab) {
      return SizedBox(width: width);
    }
    return SizedBox(
      width: width,
      child: ForgeSidePanelWidget(
        tabs: tabs,
        iconStripPosition: iconStripPosition,
        showConfigTab: showConfigTab,
        onConfigTap: onConfigTap,
        configurationPanelBuilder: configurationPanelBuilder,
      ),
    );
  }

  Widget _buildConfigurationPanel(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildPanelToggle({
      required String label,
      required ValueListenable<LayoutPanelConfig> config,
      required ForgePanelLocation location,
    }) {
      return ValueListenableBuilder<LayoutPanelConfig>(
        valueListenable: config,
        builder: (context, panelConfig, _) {
          return SwitchListTile(
            title: Text(label),
            value: panelConfig.isVisible,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (nextValue) {
              if (nextValue != panelConfig.isVisible) {
                _layout.togglePanel(location);
              }
            },
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configuration', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Panel visibility and editor settings.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          buildPanelToggle(
            label: 'Show left panel',
            config: _layout.leftPanel,
            location: ForgePanelLocation.left,
          ),
          buildPanelToggle(
            label: 'Show right panel',
            config: _layout.rightPanel,
            location: ForgePanelLocation.right,
          ),
          buildPanelToggle(
            label: 'Show bottom panel',
            config: _layout.bottomPanel,
            location: ForgePanelLocation.bottom,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.tune),
              label: const Text('Open Full Settings'),
            ),
          ),
        ],
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
    return ValueListenableBuilder<ForgeEditor?>(
      valueListenable: widget.systemState.activeEditorListenable,
      builder: (context, activeEditor, _) {
        final currentEditor =
            editors.contains(activeEditor) ? activeEditor : editors.last;

        return Column(
          children: [
            ForgeEditorTabBar(
              editors: editors,
              activeEditor: currentEditor,
              onSelect: (editor) {
                setState(() {
                  _layout.setActiveMiddlePanelIndex(panelIndex);
                  widget.systemState.setActiveEditor(editor);
                });
              },
              onClose: (editor) => _layout.closeEditor(editor),
            ),
            Expanded(
              child: currentEditor?.buildMain(context) ?? const SizedBox.expand(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomPanel(BuildContext context, LayoutPanelConfig config) {
    final tabs = widget.application.layout.bottomPanel.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: config.size,
      // Bottom panel is docked below the editor region; top resize handle
      // is rendered by _buildCenterColumn to keep panel boundaries explicit.
      child: ForgePanelWidget(tabs: tabs),
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

class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.axis,
    required this.onDragDelta,
  });

  final Axis axis;
  final ValueChanged<double> onDragDelta;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerticalDivider = widget.axis == Axis.horizontal;

    final activeColor = theme.colorScheme.primary.withValues(alpha: 0.9);
    final hoverColor = theme.colorScheme.primary.withValues(alpha: 0.45);
    final idleColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.9);

    final gripColor = _isDragging
        ? activeColor
        : (_isHovering ? hoverColor : idleColor);

    final gripThickness = _isDragging
        ? 5.0
        : (_isHovering ? 3.0 : 1.0);

    final grip = isVerticalDivider
        ? AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            margin: EdgeInsets.symmetric(
              horizontal:
                  (ForgeDimensions.dividerHitTarget - gripThickness) / 2,
            ),
            decoration: BoxDecoration(
              color: gripColor,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        : AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            margin: EdgeInsets.symmetric(
              vertical: (ForgeDimensions.dividerHitTarget - gripThickness) / 2,
            ),
            decoration: BoxDecoration(
              color: gripColor,
              borderRadius: BorderRadius.circular(2),
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: isVerticalDivider
          ? (_) => setState(() => _isDragging = true)
          : null,
      onHorizontalDragUpdate: isVerticalDivider
          ? (details) => widget.onDragDelta(details.delta.dx)
          : null,
      onHorizontalDragEnd: isVerticalDivider
          ? (_) => setState(() => _isDragging = false)
          : null,
      onHorizontalDragCancel: isVerticalDivider
          ? () => setState(() => _isDragging = false)
          : null,
      onVerticalDragStart: !isVerticalDivider
          ? (_) => setState(() => _isDragging = true)
          : null,
      onVerticalDragUpdate: !isVerticalDivider
          ? (details) => widget.onDragDelta(details.delta.dy)
          : null,
      onVerticalDragEnd: !isVerticalDivider
          ? (_) => setState(() => _isDragging = false)
          : null,
      onVerticalDragCancel: !isVerticalDivider
          ? () => setState(() => _isDragging = false)
          : null,
      child: MouseRegion(
        cursor: isVerticalDivider
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() {
          _isHovering = false;
          _isDragging = false;
        }),
        child: SizedBox(
          width: isVerticalDivider ? ForgeDimensions.dividerHitTarget : null,
          height: isVerticalDivider ? null : ForgeDimensions.dividerHitTarget,
          child: grip,
        ),
      ),
    );
  }
}
