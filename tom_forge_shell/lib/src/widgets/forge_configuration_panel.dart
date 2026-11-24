import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/text_types.dart'
    show ForgeTextSettings;
import 'package:tom_forge_core/tom_forge_core.dart'
  show AutoSaveConfig, DefaultConfigManager, ForgeConfig, ForgeSearchConfig;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../module/forge_config_panel.dart';
import '../services/forge_preferences_service.dart';
import '../shell/forge_shell_api.dart';
import '../shell/forge_shell_components.dart';
import '../tools/forge_external_tool.dart';
import '../tools/forge_external_tools_section.dart';

/// In-panel configuration view shown when the config cog is clicked.
///
/// Displays settings sections as an expandable list (shell, terminal,
/// editor configs, shortcuts, file types) plus any module-contributed
/// [ForgeConfigPanel]s.
class ForgeConfigurationPanel extends StatefulWidget {
  final ForgePreferencesService preferencesService;
  final ForgeShellApi? shellApi;
  final List<ForgeConfigPanel> modulePanels;

  /// The external tools the modules registered (the *External Tools*
  /// section's rows).
  final List<ForgeExternalTool> externalTools;
  final VoidCallback? onSettingsChanged;

  /// When set to a non-null section index, the accordion expands that section.
  final ValueNotifier<int?>? expandSection;

  const ForgeConfigurationPanel({
    super.key,
    required this.preferencesService,
    this.shellApi,
    this.modulePanels = const [],
    this.externalTools = const [],
    this.onSettingsChanged,
    this.expandSection,
  });

  @override
  State<ForgeConfigurationPanel> createState() =>
      _ForgeConfigurationPanelState();
}

class _ForgeConfigurationPanelState extends State<ForgeConfigurationPanel> {
  /// Tracks which accordion sections are expanded (by index).
  final Set<int> _expandedSections = {0};
  /// Pinned sections remain open when another section is expanded.
  final Set<int> _pinnedSections = {};
  /// Flex factors for expanded sections (for drag-to-resize).
  final Map<int, double> _sectionFlex = {};

  static const _builtInSections = [
    _SectionDef('Shell', Icons.desktop_mac_outlined),
    _SectionDef('Terminal', Icons.terminal),
    _SectionDef('Dart Editor', Icons.code),
    _SectionDef('YAML Editor', Icons.data_object),
    _SectionDef('Markdown Editor', Icons.description_outlined),
    _SectionDef('Shortcuts', Icons.keyboard),
    _SectionDef('Chord Shortcuts', Icons.piano),
    _SectionDef('File Types', Icons.folder_open),
    _SectionDef('External Tools', Icons.build_outlined),
  ];

  int get _totalSections =>
      _builtInSections.length + widget.modulePanels.length;

  @override
  void initState() {
    super.initState();
    widget.expandSection?.addListener(_onExpandSectionChanged);
    // Apply an already-requested section target when the panel is first built.
    // Quick-open may set the target before this widget is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onExpandSectionChanged();
    });
  }

  @override
  void didUpdateWidget(covariant ForgeConfigurationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expandSection != widget.expandSection) {
      oldWidget.expandSection?.removeListener(_onExpandSectionChanged);
      widget.expandSection?.addListener(_onExpandSectionChanged);
    }
  }

  @override
  void dispose() {
    widget.expandSection?.removeListener(_onExpandSectionChanged);
    super.dispose();
  }

  void _onExpandSectionChanged() {
    final target = widget.expandSection?.value;
    if (target != null && target >= 0 && target < _totalSections) {
      _toggleSection(target);
      // Consume the request so it doesn't fire again.
      widget.expandSection?.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build all section entries with their headers and content.
    final children = <Widget>[];
    final expandedIndices = List.generate(_totalSections, (i) => i)
        .where(_expandedSections.contains)
        .toList();

    for (var index = 0; index < _totalSections; index++) {
      final String label;
      final IconData icon;
      if (index < _builtInSections.length) {
        label = _builtInSections[index].label;
        icon = _builtInSections[index].icon;
      } else {
        final mp = widget.modulePanels[index - _builtInSections.length];
        label = mp.title;
        icon = mp.icon;
      }
      final isExpanded = _expandedSections.contains(index);
      final isPinned = _pinnedSections.contains(index);

      children.add(
        _ConfigAccordionHeader(
          label: label,
          icon: icon,
          isExpanded: isExpanded,
          isPinned: isPinned,
          onTap: () => _toggleSection(index),
          onTogglePin: () => _togglePin(index),
        ),
      );
      if (isExpanded) {
        children.add(
          Flexible(
            flex: ((_sectionFlex[index] ?? 1.0) * 1000).round(),
            child: _buildSectionContent(index),
          ),
        );
        // Add drag divider between adjacent expanded sections.
        if (_hasNextExpanded(index, expandedIndices)) {
          children.add(
            _ConfigDivider(
              onDragDelta: (delta) {
                final nextIdx = _nextExpanded(index, expandedIndices);
                if (nextIdx != null) _resizeSections(index, nextIdx, delta);
              },
              onDoubleTap: () => setState(() => _sectionFlex.clear()),
            ),
          );
        }
      }
    }

    return Column(children: children);
  }

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        if (_expandedSections.length > 1) {
          _expandedSections.remove(index);
        }
      } else {
        // Mutual exclusivity: collapse unpinned sections.
        _expandedSections
            .removeWhere((i) => !_pinnedSections.contains(i) && i != index);
        _expandedSections.add(index);
      }
    });
  }

  void _togglePin(int index) {
    setState(() {
      if (_pinnedSections.contains(index)) {
        _pinnedSections.remove(index);
      } else {
        _pinnedSections.add(index);
        _expandedSections.add(index);
      }
    });
  }

  bool _hasNextExpanded(int current, List<int> expandedIndices) {
    final pos = expandedIndices.indexOf(current);
    return pos >= 0 && pos < expandedIndices.length - 1;
  }

  int? _nextExpanded(int current, List<int> expandedIndices) {
    final pos = expandedIndices.indexOf(current);
    if (pos >= 0 && pos < expandedIndices.length - 1) {
      return expandedIndices[pos + 1];
    }
    return null;
  }

  void _resizeSections(int topIdx, int bottomIdx, double delta) {
    const minFlex = 0.15;
    final topFlex = _sectionFlex[topIdx] ?? 1.0;
    final bottomFlex = _sectionFlex[bottomIdx] ?? 1.0;
    final totalFlex = topFlex + bottomFlex;
    final flexDelta = delta / 200.0;
    final newTop = (topFlex + flexDelta).clamp(minFlex, totalFlex - minFlex);
    setState(() {
      _sectionFlex[topIdx] = newTop;
      _sectionFlex[bottomIdx] = totalFlex - newTop;
    });
  }

  Widget _buildSectionContent(int index) {
    if (index < _builtInSections.length) {
      return switch (index) {
        0 => _ShellSettingsSection(
            preferencesService: widget.preferencesService,
            shellApi: widget.shellApi,
            onChanged: widget.onSettingsChanged,
          ),
        1 => _TerminalSettingsSection(
            preferencesService: widget.preferencesService,
            onChanged: widget.onSettingsChanged,
          ),
        2 => _EditorSettingsSection(
            editorTypeId: 'dart',
            title: 'Dart',
            preferencesService: widget.preferencesService,
            shellApi: widget.shellApi,
            onChanged: widget.onSettingsChanged,
          ),
        3 => _EditorSettingsSection(
            editorTypeId: 'yaml',
            title: 'YAML',
            preferencesService: widget.preferencesService,
            shellApi: widget.shellApi,
            onChanged: widget.onSettingsChanged,
          ),
        4 => _EditorSettingsSection(
            editorTypeId: 'md',
            title: 'Markdown',
            preferencesService: widget.preferencesService,
            shellApi: widget.shellApi,
            onChanged: widget.onSettingsChanged,
          ),
        5 => _ShortcutsSettingsSection(
            shellApi: widget.shellApi,
            preferencesService: widget.preferencesService,
            isChord: false,
          ),
        6 => _ShortcutsSettingsSection(
            shellApi: widget.shellApi,
            preferencesService: widget.preferencesService,
            isChord: true,
          ),
        7 => _FileTypesSettingsSection(
            preferencesService: widget.preferencesService,
            shellApi: widget.shellApi,
            onChanged: widget.onSettingsChanged,
          ),
        8 => ForgeExternalToolsSection(
            tools: widget.externalTools,
            preferencesService: widget.preferencesService,
            onChanged: widget.onSettingsChanged,
            filePickers: ForgeShellComponents.of(widget.shellApi).pickers,
          ),
        _ => const SizedBox.shrink(),
      };
    }
    // Module panel.
    final mp = widget.modulePanels[index - _builtInSections.length];
    return mp.builder(context);
  }
}

/// Accordion section header for the configuration panel.
class _ConfigAccordionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isExpanded;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _ConfigAccordionHeader({
    required this.label,
    required this.icon,
    required this.isExpanded,
    this.isPinned = false,
    required this.onTap,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isExpanded
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Row(
            children: [
              Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Icon(
                icon,
                size: 14,
                color: isExpanded
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight:
                        isExpanded ? FontWeight.bold : FontWeight.normal,
                    color: isExpanded
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Pin button
              GestureDetector(
                key: Key('config-pin-$label'),
                onTap: onTogglePin,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 12,
                    color: isPinned
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draggable divider between expanded config accordion sections.
class _ConfigDivider extends StatefulWidget {
  final ValueChanged<double> onDragDelta;
  final VoidCallback? onDoubleTap;

  const _ConfigDivider({required this.onDragDelta, this.onDoubleTap});

  @override
  State<_ConfigDivider> createState() => _ConfigDividerState();
}

class _ConfigDividerState extends State<_ConfigDivider> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _dragging
        ? theme.colorScheme.primary
        : _hovering
            ? theme.colorScheme.primary.withValues(alpha: 0.5)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onVerticalDragStart: (_) => setState(() => _dragging = true),
        onVerticalDragUpdate: (d) => widget.onDragDelta(d.delta.dy),
        onVerticalDragEnd: (_) => setState(() => _dragging = false),
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          height: 5,
          color: Colors.transparent,
          child: Center(
            child: Container(height: 1, color: color),
          ),
        ),
      ),
    );
  }
}

class _SectionDef {
  final String label;
  final IconData icon;
  const _SectionDef(this.label, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell settings
// ─────────────────────────────────────────────────────────────────────────────

class _ShellSettingsSection extends StatefulWidget {
  final ForgePreferencesService preferencesService;
  final ForgeShellApi? shellApi;
  final VoidCallback? onChanged;

  const _ShellSettingsSection({
    required this.preferencesService,
    this.shellApi,
    this.onChanged,
  });

  @override
  State<_ShellSettingsSection> createState() => _ShellSettingsSectionState();
}

class _ShellSettingsSectionState extends State<_ShellSettingsSection> {
  late ThemeMode _selectedThemeMode;
  late TextEditingController _maxRecentController;
  late bool _autoSaveEnabled;
  late TextEditingController _autoSaveDelayController;
  late bool _autoSaveFocusLoss;
  late ForgeSearchConfig _searchConfig;
  late TextEditingController _excludedExtController;
  late TextEditingController _excludedDirsController;
  late TextEditingController _fileSizeLimitController;
  late TextEditingController _maxFileResultsController;
  // Layout dimensions
  late TextEditingController _panelMinWidthController;
  late TextEditingController _leftPanelWidthController;
  late TextEditingController _rightPanelWidthController;
  late TextEditingController _bottomPanelHeightController;
  late TextEditingController _dividerHitTargetController;
  late bool _reduceMotion;
  late bool _highContrast;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.preferencesService.themeMode;
    _maxRecentController = TextEditingController(
      text: widget.preferencesService.maxRecentWorkspaces.toString(),
    );
    final autoSave = widget.shellApi?.config.current.autoSave ??
        const AutoSaveConfig();
    _autoSaveEnabled = autoSave.enabled;
    _autoSaveDelayController = TextEditingController(
      text: autoSave.idleDelay.inSeconds.toString(),
    );
    _autoSaveFocusLoss = autoSave.saveOnFocusLoss;
    _searchConfig = widget.preferencesService.searchConfig;
    _excludedExtController = TextEditingController(
      text: _searchConfig.excludedExtensions.join(', '),
    );
    _excludedDirsController = TextEditingController(
      text: _searchConfig.excludedDirectories.join(', '),
    );
    _fileSizeLimitController = TextEditingController(
      text: (_searchConfig.fileSizeLimit ~/ (1024 * 1024)).toString(),
    );
    _maxFileResultsController = TextEditingController(
      text: _searchConfig.maxFileResults.toString(),
    );
    // Layout dimensions
    _panelMinWidthController = TextEditingController(
      text: widget.preferencesService.panelContentMinWidth.toInt().toString(),
    );
    _leftPanelWidthController = TextEditingController(
      text: widget.preferencesService.leftPanelDefaultWidth.toInt().toString(),
    );
    _rightPanelWidthController = TextEditingController(
      text: widget.preferencesService.rightPanelDefaultWidth.toInt().toString(),
    );
    _bottomPanelHeightController = TextEditingController(
      text: widget.preferencesService.bottomPanelDefaultHeight.toInt().toString(),
    );
    _dividerHitTargetController = TextEditingController(
      text: widget.preferencesService.dividerHitTarget.toInt().toString(),
    );
    _reduceMotion = widget.preferencesService.reduceMotion;
    _highContrast = widget.preferencesService.highContrast;
  }

  @override
  void dispose() {
    _maxRecentController.dispose();
    _autoSaveDelayController.dispose();
    _excludedExtController.dispose();
    _excludedDirsController.dispose();
    _fileSizeLimitController.dispose();
    _maxFileResultsController.dispose();
    _panelMinWidthController.dispose();
    _leftPanelWidthController.dispose();
    _rightPanelWidthController.dispose();
    _bottomPanelHeightController.dispose();
    _dividerHitTargetController.dispose();
    super.dispose();
  }

  void _save() {
    final prefs = widget.preferencesService;
    prefs.themeMode = _selectedThemeMode;
    final maxRecent = int.tryParse(_maxRecentController.text.trim());
    if (maxRecent != null && maxRecent >= 1 && maxRecent <= 50) {
      prefs.maxRecentWorkspaces = maxRecent;
    }

    final shellApi = widget.shellApi;
    if (shellApi != null) {
      final delaySeconds = int.tryParse(_autoSaveDelayController.text.trim());
      final effectiveDelaySeconds =
          delaySeconds != null && delaySeconds > 0 ? delaySeconds : 2;
      final nextAutoSave = AutoSaveConfig(
        enabled: _autoSaveEnabled,
        idleDelay: Duration(seconds: effectiveDelaySeconds),
        saveOnFocusLoss: _autoSaveFocusLoss,
      );
      final currentConfig = shellApi.config.current;
      final nextConfig = ForgeConfig(
        autoSave: nextAutoSave,
        performance: currentConfig.performance,
      );

      final configManager = shellApi.config;
      if (configManager is DefaultConfigManager) {
        configManager.setCurrent(nextConfig, key: 'autoSave');
      }
    }

    prefs.save();
    widget.onChanged?.call();
  }

  void _saveSearchConfig() {
    final excludedExt = _excludedExtController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final excludedDirs = _excludedDirsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final fileSizeMB =
        int.tryParse(_fileSizeLimitController.text.trim()) ?? 10;
    final maxFiles =
        int.tryParse(_maxFileResultsController.text.trim()) ?? 50;
    _searchConfig = _searchConfig.copyWith(
      excludedExtensions: excludedExt,
      excludedDirectories: excludedDirs,
      fileSizeLimit: fileSizeMB * 1024 * 1024,
      excludeHiddenDirectories: _searchConfig.excludeHiddenDirectories,
      excludeGitIgnored: _searchConfig.excludeGitIgnored,
      maxFileResults: maxFiles.clamp(1, 1000),
    );
    widget.preferencesService.searchConfig = _searchConfig;
    widget.preferencesService.save();
    widget.onChanged?.call();
  }

  void _saveLayoutDimensions() {
    final prefs = widget.preferencesService;
    final minW = double.tryParse(_panelMinWidthController.text.trim());
    if (minW != null) prefs.panelContentMinWidth = minW;
    final leftW = double.tryParse(_leftPanelWidthController.text.trim());
    if (leftW != null) prefs.leftPanelDefaultWidth = leftW;
    final rightW = double.tryParse(_rightPanelWidthController.text.trim());
    if (rightW != null) prefs.rightPanelDefaultWidth = rightW;
    final bottomH = double.tryParse(_bottomPanelHeightController.text.trim());
    if (bottomH != null) prefs.bottomPanelDefaultHeight = bottomH;
    final hitT = double.tryParse(_dividerHitTargetController.text.trim());
    if (hitT != null) prefs.dividerHitTarget = hitT;
    prefs.reduceMotion = _reduceMotion;
    prefs.highContrast = _highContrast;
    prefs.save();
    widget.onChanged?.call();
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 180,
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _themeModeButton(
    BuildContext context,
    ThemeMode mode,
    String label,
  ) {
    final selected = _selectedThemeMode == mode;
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () {
        setState(() => _selectedThemeMode = mode);
        _save();
      },
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: selected ? scheme.primaryContainer : null,
        foregroundColor: selected ? scheme.onPrimaryContainer : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(theme, 'Appearance'),
          const SizedBox(height: 8),
          const Text('Theme:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _themeModeButton(context, ThemeMode.dark, 'Dark'),
              _themeModeButton(context, ThemeMode.light, 'Light'),
              _themeModeButton(context, ThemeMode.system, 'System'),
            ],
          ),
          const SizedBox(height: 8),
          _toggle('High contrast', _highContrast, (v) {
            setState(() => _highContrast = v);
            widget.preferencesService.highContrast = v;
          }),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Quick Access'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Max recent:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _maxRecentController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Auto Save'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _toggle('Enabled', _autoSaveEnabled, (v) {
                setState(() => _autoSaveEnabled = v);
                _save();
              }),
              _toggle('Save on focus loss', _autoSaveFocusLoss, (v) {
                setState(() => _autoSaveFocusLoss = v);
                _save();
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Idle delay (s):', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _autoSaveDelayController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Search'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _toggle('Hide hidden dirs', _searchConfig.excludeHiddenDirectories,
                  (v) {
                setState(() {
                  _searchConfig = _searchConfig.copyWith(
                    excludeHiddenDirectories: v,
                  );
                });
                _saveSearchConfig();
              }),
              _toggle('Use .gitignore', _searchConfig.excludeGitIgnored, (v) {
                setState(() {
                  _searchConfig = _searchConfig.copyWith(
                    excludeGitIgnored: v,
                  );
                });
                _saveSearchConfig();
              }),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _excludedExtController,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'Excluded extensions',
              hintText: 'png, jpg, exe, lock',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            maxLines: 2,
            onChanged: (_) => _saveSearchConfig(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _excludedDirsController,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              labelText: 'Excluded directories',
              hintText: 'node_modules, build, .dart_tool',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            maxLines: 2,
            onChanged: (_) => _saveSearchConfig(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _fileSizeLimitController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Size (MB)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveSearchConfig(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _maxFileResultsController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Max results',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveSearchConfig(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Layout'),
          const SizedBox(height: 8),
          _toggle('Reduce motion', _reduceMotion, (v) {
            setState(() => _reduceMotion = v);
            _saveLayoutDimensions();
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Panel min width:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _panelMinWidthController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLayoutDimensions(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _leftPanelWidthController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Left panel',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLayoutDimensions(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _rightPanelWidthController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Right panel',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLayoutDimensions(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _bottomPanelHeightController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Bottom panel',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLayoutDimensions(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _dividerHitTargetController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Divider hit',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => _saveLayoutDimensions(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Terminal settings
// ─────────────────────────────────────────────────────────────────────────────

class _TerminalSettingsSection extends StatefulWidget {
  final ForgePreferencesService preferencesService;
  final VoidCallback? onChanged;

  const _TerminalSettingsSection({
    required this.preferencesService,
    this.onChanged,
  });

  @override
  State<_TerminalSettingsSection> createState() =>
      _TerminalSettingsSectionState();
}

class _TerminalSettingsSectionState extends State<_TerminalSettingsSection> {
  late TextEditingController _defaultShellController;
  late TextEditingController _scrollbackController;
  late TextEditingController _fontFamilyController;
  late TextEditingController _fontSizeController;
  late String _startFolder;

  @override
  void initState() {
    super.initState();
    final prefs = widget.preferencesService;
    _defaultShellController =
        TextEditingController(text: prefs.terminalDefaultShell ?? '');
    _scrollbackController =
        TextEditingController(text: prefs.terminalScrollbackLines.toString());
    _fontFamilyController =
        TextEditingController(text: prefs.terminalFontFamily);
    _fontSizeController =
        TextEditingController(text: prefs.terminalFontSize.toStringAsFixed(0));
    _startFolder = prefs.terminalStartFolder;
  }

  @override
  void dispose() {
    _defaultShellController.dispose();
    _scrollbackController.dispose();
    _fontFamilyController.dispose();
    _fontSizeController.dispose();
    super.dispose();
  }

  void _save() {
    final prefs = widget.preferencesService;
    final shell = _defaultShellController.text.trim();
    prefs.terminalDefaultShell = shell.isEmpty ? null : shell;
    prefs.terminalStartFolder = _startFolder;
    final scrollback = int.tryParse(_scrollbackController.text.trim());
    if (scrollback != null && scrollback > 0) {
      prefs.terminalScrollbackLines = scrollback;
    }
    final fontFamily = _fontFamilyController.text.trim();
    if (fontFamily.isNotEmpty) prefs.terminalFontFamily = fontFamily;
    final fontSize = double.tryParse(_fontSizeController.text.trim());
    if (fontSize != null && fontSize > 0) prefs.terminalFontSize = fontSize;
    prefs.save();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(theme, 'Default Shell'),
          const SizedBox(height: 8),
          TextField(
            controller: _defaultShellController,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: '/bin/bash',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            onChanged: (_) => _save(),
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Start Folder'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _startFolder,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
            items: const [
              DropdownMenuItem(
                  value: 'workspace', child: Text('Workspace root')),
              DropdownMenuItem(value: 'home', child: Text('Home directory')),
              DropdownMenuItem(
                  value: 'lastUsed', child: Text('Last used directory')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _startFolder = value);
                _save();
              }
            },
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Font & Display'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fontFamilyController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Font',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => _save(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: _fontSizeController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Size',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Scrollback:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _scrollbackController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => _save(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor settings (shared for Dart, YAML, Markdown)
// ─────────────────────────────────────────────────────────────────────────────

class _EditorSettingsSection extends StatefulWidget {
  final String editorTypeId;
  final String title;
  final ForgePreferencesService preferencesService;
  final ForgeShellApi? shellApi;
  final VoidCallback? onChanged;

  const _EditorSettingsSection({
    required this.editorTypeId,
    required this.title,
    required this.preferencesService,
    this.shellApi,
    this.onChanged,
  });

  @override
  State<_EditorSettingsSection> createState() => _EditorSettingsSectionState();
}

class _EditorSettingsSectionState extends State<_EditorSettingsSection> {
  late ForgeTextSettings _settings;
  late Map<String, dynamic> _editorConfig;

  @override
  void initState() {
    super.initState();
    _settings = widget.shellApi?.getTextSettings(widget.editorTypeId) ??
        const ForgeTextSettings();
    _editorConfig =
        widget.shellApi?.getEditorSpecificConfig(widget.editorTypeId) ??
            <String, dynamic>{};
  }

  void _update(ForgeTextSettings next) {
    setState(() => _settings = next);
    widget.preferencesService.setEditorTextSettings(widget.editorTypeId, next);
    widget.shellApi?.setTextSettings(widget.editorTypeId, next);
    widget.preferencesService.save();
    widget.onChanged?.call();
  }

  void _updateConfig(String key, dynamic value) {
    setState(() => _editorConfig[key] = value);
    widget.preferencesService
        .setEditorSpecificConfig(widget.editorTypeId, _editorConfig);
    widget.shellApi
        ?.setEditorSpecificConfig(widget.editorTypeId, _editorConfig);
    widget.preferencesService.save();
    widget.onChanged?.call();
  }

  bool _configBool(String key, {bool defaultValue = true}) =>
      (_editorConfig[key] as bool?) ?? defaultValue;

  int _configInt(String key, {int defaultValue = 0}) =>
      (_editorConfig[key] as int?) ??
      ((_editorConfig[key] as num?)?.toInt()) ??
      defaultValue;

  String _configString(String key, {String defaultValue = ''}) =>
      (_editorConfig[key] as String?) ?? defaultValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(theme, '${widget.title} — Font'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _settings.fontFamily,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Font Family',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    if (v.trim().isNotEmpty) {
                      _update(_settings.copyWith(fontFamily: v.trim()));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 65,
                child: TextFormField(
                  initialValue: _settings.fontSize.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Size',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final p = double.tryParse(v.trim());
                    if (p != null && p > 0) {
                      _update(_settings.copyWith(fontSize: p));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 65,
                child: TextFormField(
                  initialValue: _settings.lineHeight.toStringAsFixed(1),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final p = double.tryParse(v.trim());
                    if (p != null && p > 0) {
                      _update(_settings.copyWith(lineHeight: p));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Indentation'),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 65,
                child: TextFormField(
                  initialValue: _settings.tabSize.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Tab',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final p = int.tryParse(v.trim());
                    if (p != null && p > 0) {
                      _update(_settings.copyWith(tabSize: p));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              _toggle(
                'Spaces',
                _settings.insertSpaces,
                (v) => _update(_settings.copyWith(insertSpaces: v)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Display'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _toggle(
                'Line numbers',
                _settings.showLineNumbers,
                (v) => _update(_settings.copyWith(showLineNumbers: v)),
              ),
              _toggle(
                'Word wrap',
                _settings.wordWrap,
                (v) => _update(_settings.copyWith(wordWrap: v)),
              ),
              _toggle(
                'Highlight line',
                _settings.highlightCurrentLine,
                (v) => _update(_settings.copyWith(highlightCurrentLine: v)),
              ),
              _toggle(
                'Whitespace',
                _settings.showWhitespace,
                (v) => _update(_settings.copyWith(showWhitespace: v)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'Undo'),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: _settings.maxUndoHistory.toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Max undo',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) {
                final p = int.tryParse(v.trim());
                if (p != null && p > 0) {
                  _update(_settings.copyWith(maxUndoHistory: p));
                }
              },
            ),
          ),
          // ── Editor-specific settings ──
          ..._buildEditorSpecificSettings(theme),
        ],
      ),
    );
  }

  List<Widget> _buildEditorSpecificSettings(ThemeData theme) {
    return switch (widget.editorTypeId) {
      'dart' => _buildDartSettings(theme),
      'yaml' => _buildYamlSettings(theme),
      'md' => _buildMdSettings(theme),
      _ => const <Widget>[],
    };
  }

  // ── Dart editor-specific settings ──

  List<Widget> _buildDartSettings(ThemeData theme) {
    return [
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Toolbar'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Show toolbar', _configBool('showToolbar'),
              (v) => _updateConfig('showToolbar', v)),
          _toggle('Line numbers', _configBool('showLineNumbers'),
              (v) => _updateConfig('showLineNumbers', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Autocompletion'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Enabled', _configBool('autoCompleteEnabled'),
              (v) => _updateConfig('autoCompleteEnabled', v)),
          _toggle('Popup below', _configBool('popupPreferBelow'),
              (v) => _updateConfig('popupPreferBelow', v)),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: 100,
        child: TextFormField(
          initialValue: _configInt('maxCompletionItems', defaultValue: 8)
              .toString(),
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Max items',
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
          ),
          onChanged: (v) {
            final p = int.tryParse(v.trim());
            if (p != null && p > 0) _updateConfig('maxCompletionItems', p);
          },
        ),
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Diagnostics — Errors'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Tooltips', _configBool('showErrorTooltips'),
              (v) => _updateConfig('showErrorTooltips', v)),
          _toggle('Markers', _configBool('showErrorMarkers'),
              (v) => _updateConfig('showErrorMarkers', v)),
        ],
      ),
      const SizedBox(height: 8),
      _sectionHeader(theme, 'Diagnostics — Warnings'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Tooltips', _configBool('showWarningTooltips'),
              (v) => _updateConfig('showWarningTooltips', v)),
          _toggle('Markers', _configBool('showWarningMarkers'),
              (v) => _updateConfig('showWarningMarkers', v)),
        ],
      ),
      const SizedBox(height: 8),
      _sectionHeader(theme, 'Diagnostics — Info'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle(
              'Tooltips',
              _configBool('showInfoTooltips', defaultValue: false),
              (v) => _updateConfig('showInfoTooltips', v)),
          _toggle(
              'Markers',
              _configBool('showInfoMarkers', defaultValue: false),
              (v) => _updateConfig('showInfoMarkers', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Toolbar Buttons'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Autocomplete toggle',
              _configBool('showAutoCompleteToggle'),
              (v) => _updateConfig('showAutoCompleteToggle', v)),
          _toggle('Error toggles', _configBool('showErrorToggles'),
              (v) => _updateConfig('showErrorToggles', v)),
          _toggle('Warning toggles', _configBool('showWarningToggles'),
              (v) => _updateConfig('showWarningToggles', v)),
          _toggle('Info toggles', _configBool('showInfoToggles'),
              (v) => _updateConfig('showInfoToggles', v)),
          _toggle('Popup position', _configBool('showPopupPositionToggle'),
              (v) => _updateConfig('showPopupPositionToggle', v)),
          _toggle('Open reference', _configBool('showOpenReferenceButton'),
              (v) => _updateConfig('showOpenReferenceButton', v)),
        ],
      ),
    ];
  }

  // ── YAML editor-specific settings ──

  List<Widget> _buildYamlSettings(ThemeData theme) {
    return [
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Tree & Structure'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Tree lines', _configBool('showTreeLines'),
              (v) => _updateConfig('showTreeLines', v)),
          _toggle('Collapse toggles', _configBool('showCollapseToggles'),
              (v) => _updateConfig('showCollapseToggles', v)),
          _toggle('Add buttons', _configBool('showAddButtons'),
              (v) => _updateConfig('showAddButtons', v)),
          _toggle('Remove buttons', _configBool('showRemoveButtons'),
              (v) => _updateConfig('showRemoveButtons', v)),
          _toggle('Inline validation', _configBool('showInlineValidation'),
              (v) => _updateConfig('showInlineValidation', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Schema'),
      const SizedBox(height: 8),
      _buildDirectoryField(
        configKey: 'yamlSchemasPath',
        labelText: 'JSON Schema directory',
        hintText: '.tom/json-schema/',
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Layout'),
      const SizedBox(height: 8),
      Row(
        children: [
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue:
                  _configInt('indentWidth', defaultValue: 24).toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Indent',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) {
                final p = int.tryParse(v.trim());
                if (p != null && p > 0) _updateConfig('indentWidth', p);
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextFormField(
              initialValue: _configInt('collapsedPreviewLines',
                      defaultValue: 2)
                  .toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Preview lines',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) {
                final p = int.tryParse(v.trim());
                if (p != null && p >= 0) {
                  _updateConfig('collapsedPreviewLines', p);
                }
              },
            ),
          ),
        ],
      ),
    ];
  }

  // ── Markdown editor-specific settings ──

  List<Widget> _buildMdSettings(ThemeData theme) {
    return [
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Layout'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Show tree', _configBool('showTree'),
              (v) => _updateConfig('showTree', v)),
          _toggle(
              'Show toolbar',
              _configBool('showToolbar', defaultValue: false),
              (v) => _updateConfig('showToolbar', v)),
          _toggle('Show status bar', _configBool('showStatusBar'),
              (v) => _updateConfig('showStatusBar', v)),
          _toggle('Show search box', _configBool('showSearchBox'),
              (v) => _updateConfig('showSearchBox', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Raw Editor'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Auto-hide editor', _configBool('autoHideEditor'),
              (v) => _updateConfig('autoHideEditor', v)),
          _toggle('Live preview', _configBool('livePreview'),
              (v) => _updateConfig('livePreview', v)),
          _toggle('Allow position change',
              _configBool('allowEditorPositionChange'),
              (v) => _updateConfig('allowEditorPositionChange', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Main Panel'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle(
              'Line numbers',
              _configBool('showLineNumbers', defaultValue: false),
              (v) => _updateConfig('showLineNumbers', v)),
          _toggle('Section borders', _configBool('showSectionBorders'),
              (v) => _updateConfig('showSectionBorders', v)),
          _toggle('Highlight section',
              _configBool('highlightCurrentSection'),
              (v) => _updateConfig('highlightCurrentSection', v)),
          _toggle('Smooth scrolling', _configBool('enableSmoothScrolling'),
              (v) => _updateConfig('enableSmoothScrolling', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Tree'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Expand all', _configBool('expandAllByDefault'),
              (v) => _updateConfig('expandAllByDefault', v)),
          _toggle('Validation markers',
              _configBool('showValidationMarkers'),
              (v) => _updateConfig('showValidationMarkers', v)),
          _toggle('Drag and drop', _configBool('enableDragAndDrop'),
              (v) => _updateConfig('enableDragAndDrop', v)),
          _toggle(
              'Section icons',
              _configBool('showSectionIcons', defaultValue: false),
              (v) => _updateConfig('showSectionIcons', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Markdown Features'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Mermaid diagrams', _configBool('enableMermaid'),
              (v) => _updateConfig('enableMermaid', v)),
          _toggle('Math (KaTeX)', _configBool('enableMath'),
              (v) => _updateConfig('enableMath', v)),
          _toggle('Footnotes', _configBool('enableFootnotes'),
              (v) => _updateConfig('enableFootnotes', v)),
          _toggle('Task lists', _configBool('enableTaskLists'),
              (v) => _updateConfig('enableTaskLists', v)),
          _toggle('Interactive tasks',
              _configBool('enableInteractiveTaskLists'),
              (v) => _updateConfig('enableInteractiveTaskLists', v)),
          _toggle('Tables', _configBool('enableTables'),
              (v) => _updateConfig('enableTables', v)),
          _toggle('Syntax highlighting',
              _configBool('enableSyntaxHighlighting'),
              (v) => _updateConfig('enableSyntaxHighlighting', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Code Blocks'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Show language', _configBool('showCodeBlockLanguage'),
              (v) => _updateConfig('showCodeBlockLanguage', v)),
          _toggle('Copy button', _configBool('showCopyCodeButton'),
              (v) => _updateConfig('showCopyCodeButton', v)),
          _toggle('Edit button', _configBool('showCodeEditButton'),
              (v) => _updateConfig('showCodeEditButton', v)),
          _toggle('Enable editing', _configBool('enableCodeEditing'),
              (v) => _updateConfig('enableCodeEditing', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Tables'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Edit button', _configBool('showTableEditButton'),
              (v) => _updateConfig('showTableEditButton', v)),
          _toggle('Enable editing', _configBool('enableTableEditing'),
              (v) => _updateConfig('enableTableEditing', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Search'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle('Search', _configBool('enableSearch'),
              (v) => _updateConfig('enableSearch', v)),
          _toggle('Replace', _configBool('enableReplace'),
              (v) => _updateConfig('enableReplace', v)),
          _toggle(
              'Regex',
              _configBool('enableRegexSearch', defaultValue: false),
              (v) => _updateConfig('enableRegexSearch', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Behavior'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _toggle(
              'Read only',
              _configBool('readOnly', defaultValue: false),
              (v) => _updateConfig('readOnly', v)),
          _toggle('Confirm delete', _configBool('confirmDelete'),
              (v) => _updateConfig('confirmDelete', v)),
          _toggle(
              'Auto save',
              _configBool('autoSave', defaultValue: false),
              (v) => _updateConfig('autoSave', v)),
        ],
      ),
      const SizedBox(height: 16),
      _sectionHeader(theme, 'Schema'),
      const SizedBox(height: 8),
      _buildDirectoryField(
        configKey: 'docspecSchemasPath',
        labelText: 'DocSpec schema directory',
        hintText: '.tom/docspecs-schema/',
      ),
    ];
  }

  Widget _buildDirectoryField({
    required String configKey,
    required String labelText,
    required String hintText,
  }) {
    return TextFormField(
      initialValue: _configString(configKey),
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.folder_open, size: 18),
          tooltip: 'Browse\u2026',
          onPressed: () async {
            final path = await ForgeShellComponents.of(
              widget.shellApi,
            ).pickers.pickFolder();
            if (path != null) {
              _updateConfig(configKey, path);
            }
          },
        ),
      ),
      onChanged: (v) => _updateConfig(configKey, v.trim()),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SizedBox(
      width: 150,
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shortcuts settings
// ─────────────────────────────────────────────────────────────────────────────

class _ShortcutsSettingsSection extends StatefulWidget {
  final ForgeShellApi? shellApi;
  final ForgePreferencesService preferencesService;
  final bool isChord;

  const _ShortcutsSettingsSection({
    required this.shellApi,
    required this.preferencesService,
    required this.isChord,
  });

  @override
  State<_ShortcutsSettingsSection> createState() =>
      _ShortcutsSettingsSectionState();
}

class _ShortcutsSettingsSectionState extends State<_ShortcutsSettingsSection> {
  String _searchTerm = '';
  String? _capturingActionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shellApi = widget.shellApi;
    if (shellApi == null) {
      return const Center(child: Text('Shell not available'));
    }

    final bindings = shellApi.shortcuts.allBindings
        .where((b) => widget.isChord ? b.isChord : !b.isChord)
        .where(_matchesFilter)
        .toList(growable: false)
      ..sort((a, b) => a.action.label.compareTo(b.action.label));

    // Group bindings by key for multi-action detection.
    final keyGroups = <String, List<ForgeShortcutBinding>>{};
    for (final b in bindings) {
      keyGroups.putIfAbsent(b.displayString, () => []).add(b);
    }
    final groupEntries = keyGroups.entries.toList()
      ..sort((a, b) => a.value.first.action.label
          .compareTo(b.value.first.action.label));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _searchTerm = v.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: widget.isChord
                        ? 'Search chords...'
                        : 'Search shortcuts...',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 16),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: widget.isChord ? 'Add Chord' : 'Add Shortcut',
                onPressed: () => _addBinding(shellApi),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              if (!widget.isChord) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: bindings.isEmpty ? null : _resetAll,
                  child:
                      const Text('Reset', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        if (groupEntries.isEmpty)
          const Expanded(
            child: Center(child: Text('No matches')),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: groupEntries.length,
              itemBuilder: (context, index) {
                final entry = groupEntries[index];
                final group = entry.value;
                if (group.length == 1) {
                  return _buildSingleActionTile(theme, group.first);
                }
                return _buildMultiActionTile(theme, entry.key, group);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSingleActionTile(
    ThemeData theme,
    ForgeShortcutBinding binding,
  ) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(
        binding.action.label,
        style: const TextStyle(fontSize: 12),
      ),
      subtitle: Text(
        binding.context ?? 'Global',
        style: TextStyle(
          fontSize: 10,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            binding.displayString,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => widget.isChord
                ? _rebindChord(binding)
                : _rebind(binding),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                _capturingActionId == binding.action.id ? '...' : 'Edit',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: () => _removeBinding(binding),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 12,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiActionTile(
    ThemeData theme,
    String keyDisplay,
    List<ForgeShortcutBinding> group,
  ) {
    final warningColor = theme.colorScheme.error.withValues(alpha: 0.8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: key + conflict indicator + edit button.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                Text(
                  keyDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.warning_amber_rounded,
                    size: 12, color: warningColor),
                const SizedBox(width: 2),
                Text(
                  '${group.length} actions',
                  style: TextStyle(fontSize: 10, color: warningColor),
                ),
              ],
            ),
          ),
          // Per-action rows.
          for (final binding in group)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: binding.action.label,
                            style: const TextStyle(fontSize: 11),
                          ),
                          TextSpan(
                            text: '  (${binding.context ?? "Global"})',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _removeBinding(binding),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  bool _matchesFilter(ForgeShortcutBinding binding) {
    if (_searchTerm.isEmpty) return true;
    final haystack = [
      binding.action.id,
      binding.action.label,
      binding.displayString,
      binding.context ?? 'Global',
    ].join(' ').toLowerCase();
    return haystack.contains(_searchTerm);
  }

  Future<void> _rebind(ForgeShortcutBinding binding) async {
    setState(() => _capturingActionId = binding.action.id);
    final captured = await _captureKey();
    if (!mounted) return;
    setState(() => _capturingActionId = null);
    if (captured == null) return;

    final shellApi = widget.shellApi;
    if (shellApi == null) return;

    final conflict = shellApi.shortcuts.conflictsWith(captured);
    if (conflict != null && conflict.action.id != binding.action.id) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Conflict'),
          content: Text(
            '"${captured.toDisplayString()}" is bound to '
            '"${conflict.action.label}". Replace?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Replace')),
          ],
        ),
      );
      if (accepted != true) return;
    }

    shellApi.shortcuts.rebind(binding.action, captured);
    widget.preferencesService.setShortcutOverride(binding.action.id, captured);
    await widget.preferencesService.save();

    // If the action has a <prefix>.<suffix> pattern, offer to create
    // a wildcard binding (*.<suffix>) so the shortcut works across all
    // editors that support the same action suffix.
    final actionId = binding.action.id;
    final dotIdx = actionId.indexOf('.');
    if (dotIdx > 0 && mounted) {
      final prefix = actionId.substring(0, dotIdx);
      final suffix = actionId.substring(dotIdx + 1);
      // Only offer wildcard for editor-specific prefixes.
      final editorPrefixes = {'md', 'dart', 'yaml', 'plaintext'};
      if (editorPrefixes.contains(prefix)) {
        final wildcardChoice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Shortcut Scope'),
            content: Text(
              'Bind "${captured.toDisplayString()}" as:\n\n'
              '• Specific: $prefix.$suffix (only for $prefix editor)\n'
              '• All editors: *.$suffix (any editor supporting this action)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Specific ($prefix)'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('All editors (*)'),
              ),
            ],
          ),
        );
        if (wildcardChoice == true && mounted) {
          final wildcardId = '*.$suffix';
          final wildcardAction = ForgeAction(
            id: wildcardId,
            label: '${binding.action.label} (all editors)',
            icon: binding.action.icon,
            menu: ForgeMenuLocation.commandPalette,
            execute: (_) async => null,
            isEnabled: () => true,
            isVisible: () => true,
          );
          shellApi.actionRegistry.registerAction(wildcardAction);
          shellApi.shortcuts.rebind(wildcardAction, captured);
          widget.preferencesService
              .setShortcutOverride(wildcardId, captured);
          // Remove the specific binding to avoid conflicts.
          shellApi.shortcuts.removeBinding(actionId);
          widget.preferencesService.removeShortcutOverride(actionId);
          await widget.preferencesService.save();
        }
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _resetAll() async {
    final shellApi = widget.shellApi;
    if (shellApi == null) return;
    for (final b in shellApi.shortcuts.allBindings.where((b) => !b.isChord)) {
      shellApi.shortcuts.resetToDefault(b.action);
    }
    widget.preferencesService.clearShortcutOverrides();
    await widget.preferencesService.save();
    if (mounted) setState(() {});
  }

  Future<void> _addBinding(ForgeShellApi shellApi) async {
    // Show a picker with all registered actions.
    final allActions = shellApi.actionRegistry.allActions;
    final boundIds = shellApi.shortcuts.allBindings
        .where((b) => widget.isChord ? b.isChord : !b.isChord)
        .map((b) => b.action.id)
        .toSet();
    // Show both bound and unbound actions, sorted by label.
    final sortedActions = allActions.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    final chosen = await showDialog<ForgeAction>(
      context: context,
      builder: (ctx) => _ActionPickerDialog(
        actions: sortedActions,
        boundIds: boundIds,
      ),
    );
    if (chosen == null || !mounted) return;

    if (widget.isChord) {
      final chord = await _captureChord();
      if (chord == null || !mounted) return;
      shellApi.shortcuts.rebindChord(chosen, chord);
      widget.preferencesService.setChordOverride(chosen.id, chord);
    } else {
      final key = await _captureKey();
      if (key == null || !mounted) return;
      final conflict = shellApi.shortcuts.conflictsWith(key);
      if (conflict != null && conflict.action.id != chosen.id) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Conflict'),
            content: Text(
              '"${key.toDisplayString()}" is bound to '
              '"${conflict.action.label}". Replace?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Replace')),
            ],
          ),
        );
        if (accepted != true) return;
      }
      shellApi.shortcuts.rebind(chosen, key);
      widget.preferencesService.setShortcutOverride(chosen.id, key);
    }
    await widget.preferencesService.save();
    if (mounted) setState(() {});
  }

  Future<void> _removeBinding(ForgeShortcutBinding binding) async {
    final shellApi = widget.shellApi;
    if (shellApi == null) return;
    shellApi.shortcuts.removeBinding(binding.action.id);
    widget.preferencesService.removeShortcutOverride(binding.action.id);
    widget.preferencesService.removeChordOverride(binding.action.id);
    widget.preferencesService.addDeletedBinding(binding.action.id);
    await widget.preferencesService.save();
    if (mounted) setState(() {});
  }

  Future<void> _rebindChord(ForgeShortcutBinding binding) async {
    setState(() => _capturingActionId = binding.action.id);
    final chord = await _captureChord();
    if (!mounted) return;
    setState(() => _capturingActionId = null);
    if (chord == null) return;

    final shellApi = widget.shellApi;
    if (shellApi == null) return;

    shellApi.shortcuts.rebindChord(binding.action, chord);
    widget.preferencesService.setChordOverride(binding.action.id, chord);
    await widget.preferencesService.save();
    if (mounted) setState(() {});
  }

  Future<ForgeChordKey?> _captureChord() {
    return showDialog<ForgeChordKey>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChordCaptureDialog(),
    );
  }

  Future<ForgeShortcutKey?> _captureKey() {
    return showDialog<ForgeShortcutKey>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Press new shortcut'),
        content: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              Navigator.of(ctx).pop();
              return KeyEventResult.handled;
            }
            final key = _toShortcutKey(event);
            if (key != null) {
              Navigator.of(ctx).pop(key);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: const Text('Press a key combination.\nEsc to cancel.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
        ],
      ),
    );
  }

  ForgeShortcutKey? _toShortcutKey(KeyDownEvent event) {
    return ForgeShortcutKey.fromPressed(
      event.logicalKey,
      HardwareKeyboard.instance.logicalKeysPressed,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action picker dialog (for adding new shortcuts/chords)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionPickerDialog extends StatefulWidget {
  final List<ForgeAction> actions;
  final Set<String> boundIds;

  const _ActionPickerDialog({
    required this.actions,
    required this.boundIds,
  });

  @override
  State<_ActionPickerDialog> createState() => _ActionPickerDialogState();
}

class _ActionPickerDialogState extends State<_ActionPickerDialog> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.actions.where((a) {
      if (_filter.isEmpty) return true;
      return a.label.toLowerCase().contains(_filter) ||
          a.id.toLowerCase().contains(_filter);
    }).toList();

    return AlertDialog(
      title: const Text('Select Action'),
      content: SizedBox(
        width: 360,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) =>
                  setState(() => _filter = v.trim().toLowerCase()),
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Filter actions...',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 16),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final action = filtered[index];
                  final isBound = widget.boundIds.contains(action.id);
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: action.icon != null
                        ? Icon(action.icon, size: 16)
                        : null,
                    title: Text(
                      action.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      action.id,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: isBound
                        ? Icon(Icons.check, size: 14,
                            color: theme.colorScheme.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(action),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chord capture dialog (captures two key combinations)
// ─────────────────────────────────────────────────────────────────────────────

class _ChordCaptureDialog extends StatefulWidget {
  @override
  State<_ChordCaptureDialog> createState() => _ChordCaptureDialogState();
}

class _ChordCaptureDialogState extends State<_ChordCaptureDialog> {
  ForgeShortcutKey? _firstKey;

  ForgeShortcutKey? _toShortcutKey(KeyDownEvent event) {
    return ForgeShortcutKey.fromPressed(
      event.logicalKey,
      HardwareKeyboard.instance.logicalKeysPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_firstKey == null
          ? 'Press first key combination'
          : 'Press second key combination'),
      content: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          final key = _toShortcutKey(event);
          if (key == null) return KeyEventResult.ignored;
          if (_firstKey == null) {
            setState(() => _firstKey = key);
            return KeyEventResult.handled;
          }
          Navigator.of(context).pop(
            ForgeChordKey(firstKey: _firstKey!, secondKey: key),
          );
          return KeyEventResult.handled;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_firstKey != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'First: ${_firstKey!.toDisplayString()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            Text(_firstKey == null
                ? 'Press a key combination for the first key.\nEsc to cancel.'
                : 'Now press the second key combination.\nEsc to cancel.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File types settings
// ─────────────────────────────────────────────────────────────────────────────

class _FileTypesSettingsSection extends StatefulWidget {
  final ForgePreferencesService preferencesService;
  final ForgeShellApi? shellApi;
  final VoidCallback? onChanged;

  const _FileTypesSettingsSection({
    required this.preferencesService,
    this.shellApi,
    this.onChanged,
  });

  @override
  State<_FileTypesSettingsSection> createState() =>
      _FileTypesSettingsSectionState();
}

class _FileTypesSettingsSectionState extends State<_FileTypesSettingsSection> {
  static const _defaultMappings = {
    '.md': 'md',
    '.markdown': 'md',
    '.dart': 'dart',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.json': 'yaml',
  };
  static const _editorTypeIds = ['md', 'dart', 'yaml', 'plaintext'];

  late Map<String, String> _mappings;
  late String _defaultEditor;
  final TextEditingController _newExtController = TextEditingController();

  /// The names of the editors the shell's editor picker offers beyond
  /// [_editorTypeIds] (a module's editor, e.g. one made the default from
  /// **Open With ▸**).
  final Map<String, String> _editorLabels = {};

  /// The editors the shell's editor picker offers per extension, in the
  /// picker's order.
  final Map<String, List<String>> _pickerChoices = {};

  /// Set while [_save] writes, so its own changes are not read back.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mappings = Map<String, String>.from(_defaultMappings)
      ..addAll(widget.preferencesService.fileTypeDefaultEditors);
    final shellDefaults = widget.shellApi?.getFileTypeDefaults();
    if (shellDefaults != null) _mappings.addAll(shellDefaults);
    // Extract the wildcard/default mapping or fall back to 'plaintext'.
    _defaultEditor = _mappings.remove('*') ??
        widget.preferencesService.fileTypeDefaultEditors['*'] ??
        'plaintext';
    widget.preferencesService.addListener(_onPreferencesChanged);
    _loadEditorLabels();
  }

  @override
  void dispose() {
    widget.preferencesService.removeListener(_onPreferencesChanged);
    _newExtController.dispose();
    super.dispose();
  }

  /// A default set elsewhere while the section is shown (the checkmark of
  /// **Open With ▸ Set default for**) shows here at once.
  void _onPreferencesChanged() {
    if (_saving || !mounted) return;
    final stored = widget.preferencesService.fileTypeDefaultEditors;
    final next = Map<String, String>.from(_mappings);
    var defaultEditor = _defaultEditor;
    for (final entry in stored.entries) {
      if (entry.key == '*') {
        defaultEditor = entry.value;
      } else {
        next[entry.key] = entry.value;
      }
    }
    final unchanged = next.length == _mappings.length &&
        next.entries.every((e) => _mappings[e.key] == e.value);
    if (defaultEditor == _defaultEditor && unchanged) return;
    setState(() {
      _mappings = next;
      _defaultEditor = defaultEditor;
    });
    _loadEditorLabels();
  }

  /// Asks the shell's editor picker which editors each mapped extension
  /// has (a sample file of that extension), for the rows' choices and the
  /// names of the editors the section does not know.
  Future<void> _loadEditorLabels() async {
    final picker = widget.shellApi?.editorPicker;
    if (picker == null) return;
    final missing = [
      for (final extension in _mappings.keys)
        if (!_pickerChoices.containsKey(extension)) extension,
    ];
    if (missing.isEmpty) return;
    final foundChoices = <String, List<String>>{};
    final foundLabels = <String, String>{};
    for (final extension in missing) {
      final choices = await picker.choicesFor(
        ForgeContentItem(Uri.file('/forge-file-type$extension')),
      );
      foundChoices[extension] = [
        for (final choice in choices.choices) choice.id,
      ];
      for (final choice in choices.choices) {
        foundLabels[choice.id] = choice.label;
      }
    }
    if (!mounted) return;
    setState(() {
      _pickerChoices.addAll(foundChoices);
      _editorLabels.addAll(foundLabels);
    });
  }

  /// The editors the row of [extension] offers: the ones the editor picker
  /// knows for it, the section's own, and the one the row names when it is
  /// none of them.
  List<String> _editorIdsFor(String extension, String id) {
    final ids = <String>[
      ...?_pickerChoices[extension],
      for (final own in _editorTypeIds)
        if (!(_pickerChoices[extension]?.contains(own) ?? false)) own,
    ];
    if (!ids.contains(id)) ids.add(id);
    return ids;
  }

  void _save() {
    _saving = true;
    try {
      _write();
    } finally {
      _saving = false;
    }
    widget.onChanged?.call();
  }

  void _write() {
    final previousPreferenceKeys =
        widget.preferencesService.fileTypeDefaultEditors.keys.toSet();
    final previousShellKeys =
        widget.shellApi?.getFileTypeDefaults().keys.toSet() ?? <String>{};
    final nextKeys = <String>{..._mappings.keys, '*'};

    for (final key in previousPreferenceKeys.difference(nextKeys)) {
      widget.preferencesService.clearFileTypeDefaultEditor(key);
    }
    for (final key in previousShellKeys.difference(nextKeys)) {
      widget.shellApi?.clearFileTypeDefault(key);
    }

    for (final entry in _mappings.entries) {
      widget.preferencesService.setFileTypeDefaultEditor(
          entry.key, entry.value);
      widget.shellApi?.setFileTypeDefault(entry.key, entry.value);
    }
    // Save the default editor for unmapped extensions.
    widget.preferencesService.setFileTypeDefaultEditor('*', _defaultEditor);
    widget.shellApi?.setFileTypeDefault('*', _defaultEditor);
    widget.preferencesService.save();
  }

  String _editorTitle(String id) {
    return switch (id) {
      'md' => 'Markdown',
      'dart' => 'Dart',
      'yaml' => 'YAML',
      'plaintext' => 'Plain Text',
      _ => _editorLabels[id] ?? id,
    };
  }

  void _addExtension() {
    var ext = _newExtController.text.trim().toLowerCase();
    if (ext.isEmpty) return;
    if (!ext.startsWith('.')) ext = '.$ext';
    if (_mappings.containsKey(ext)) return;
    setState(() {
      _mappings[ext] = _defaultEditor;
      _newExtController.clear();
    });
    _save();
    _loadEditorLabels();
  }

  void _removeExtension(String ext) {
    setState(() => _mappings.remove(ext));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedEntries = _mappings.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(theme, 'Default Editor (unmapped extensions)'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('file-type-default-editor'),
            initialValue: _defaultEditor,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            items: _editorTypeIds
                .map((id) => DropdownMenuItem(
                    value: id, child: Text(_editorTitle(id))))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _defaultEditor = value);
                _save();
              }
            },
          ),
          const SizedBox(height: 16),
          _sectionHeader(theme, 'File Type Associations'),
          const SizedBox(height: 8),
          for (final entry in sortedEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                key: Key('file-type-row-${entry.key}'),
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    // Keyed by the value too: a default set elsewhere
                    // rebuilds the choice showing it.
                    child: KeyedSubtree(
                      key: ValueKey(
                        'file-type-value-${entry.key}=${entry.value}',
                      ),
                      child: DropdownButtonFormField<String>(
                        key: Key('file-type-editor-${entry.key}'),
                        initialValue: entry.value,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 12),
                        items: _editorIdsFor(entry.key, entry.value)
                            .map((id) => DropdownMenuItem(
                                value: id, child: Text(_editorTitle(id))))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _mappings[entry.key] = value);
                            _save();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    key: Key('file-type-remove-${entry.key}'),
                    onTap: () => _removeExtension(entry.key),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  key: const Key('file-type-new-extension'),
                  controller: _newExtController,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  decoration: const InputDecoration(
                    hintText: '.ext',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addExtension(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                tooltip: 'Add Extension',
                onPressed: _addExtension,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _sectionHeader(ThemeData theme, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    ),
  );
}
