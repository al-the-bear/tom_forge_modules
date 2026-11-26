import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show
        ForgeConfigurationSectionRef,
        ForgeSettingHooks,
        ForgePathKind,
        ForgePathSetting,
        forgeOrderedSections;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../configuration/forge_files_tools_configuration.dart';
import '../configuration/forge_shell_configuration.dart';
import '../configuration/forge_shortcut_configuration.dart';
import '../module/forge_config_panel.dart';
import '../services/forge_preferences_service.dart';
import '../shell/forge_shell_api.dart';
import '../shell/forge_shell_components.dart';
import 'forge_panel_visible_width.dart';

/// In-panel configuration view shown when the config cog is clicked.
///
/// Displays settings sections as an expandable list: first one tile
/// (`tom_configuration_ui`'s [ForgeConfigurationTile]) per section of the
/// configuration descriptions the modules and the editor types contribute
/// ([configurationValues]) — the shell's own *Shell* and *Terminal* sections
/// first ([ForgeShellConfiguration]), then the editor types' (the Dart, YAML
/// and Markdown editors describe their own options), the key bindings
/// ([ForgeShortcutConfiguration]), file types ([ForgeFileTypesConfiguration])
/// and external tools ([ForgeExternalToolsConfiguration]) — then any
/// module-contributed [ForgeConfigPanel]s.
///
/// [expandSection] names a section by the index quick open has always used:
/// 0 *Shell*, 1 *Terminal*, 2 *Dart Editor*, 3 *YAML Editor*, 4 *Markdown
/// Editor*, 5 *Shortcuts*, 6 *Chord Shortcuts*, 7 *File Types*, 8 *External
/// Tools*, then the module panels in order ([sectionIndexShell] ...).
class ForgeConfigurationPanel extends StatefulWidget {
  final ForgePreferencesService preferencesService;
  final ForgeShellApi? shellApi;
  final List<ForgeConfigPanel> modulePanels;

  /// The values of the modules' configuration descriptions (the kit's
  /// values service over the shell's state store, with the shell's storage
  /// bindings); each section of its descriptions is an accordion entry
  /// before the module panels. Null: the panel keeps a values service of
  /// its own over [preferencesService] with the shell's description only
  /// ([forgeShellConfigurationValues]).
  final ForgeConfigurationValues? configurationValues;

  /// The [expandSection] index of the *Shell* section.
  static const sectionIndexShell = 0;

  /// The [expandSection] index of the *Terminal* section.
  static const sectionIndexTerminal = 1;

  /// The [expandSection] index of *Dart Editor*; *YAML Editor*, *Markdown
  /// Editor*, *Shortcuts*, *Chord Shortcuts*, *File Types* and *External
  /// Tools* follow ([describedSectionRefs]), then the module panels in
  /// order.
  static const sectionIndexFirstBuiltIn = 2;

  /// The described sections quick open's indices 2 to 8 name
  /// (`<description>/<section>`): the Dart, YAML and Markdown editors' own
  /// descriptions (`ForgeKitEditorType.configuration`), the shell's key
  /// bindings ([ForgeShortcutConfiguration]), file types
  /// ([ForgeFileTypesConfiguration]) and external tools
  /// ([ForgeExternalToolsConfiguration]).
  static const describedSectionRefs = [
    'forge.editor.dart/editor',
    'forge.editor.yaml/editor',
    'forge.editor.md/editor',
    ForgeShortcutConfiguration.shortcutsSectionRef,
    ForgeShortcutConfiguration.chordsSectionRef,
    ForgeFileTypesConfiguration.sectionRef,
    ForgeExternalToolsConfiguration.sectionRef,
  ];

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
    this.configurationValues,
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
  final Set<int> _expandedSections = {};

  /// Pinned sections remain open when another section is expanded.
  final Set<int> _pinnedSections = {};

  /// Flex factors for expanded sections (for drag-to-resize).
  final Map<int, double> _sectionFlex = {};

  /// The values service of the panel's own, when none is given.
  ForgeConfigurationValues? _ownValues;

  /// The values service the described sections edit: the one given, else
  /// the panel's own over the shell's description.
  ForgeConfigurationValues get _values {
    final given = widget.configurationValues;
    if (given != null) return given;
    return _ownValues ??= _makeOwnValues();
  }

  ForgeConfigurationValues _makeOwnValues() {
    final shell = widget.shellApi;
    final tools = widget.externalTools;
    final values = forgeShellConfigurationValues(
      widget.preferencesService,
      config: shell?.config,
      shell: shell,
      descriptions: [
        if (shell != null) ForgeShortcutConfiguration.description,
        if (shell != null) ForgeFileTypesConfiguration.description,
        if (tools.isNotEmpty)
          ForgeExternalToolsConfiguration.description(tools),
      ],
      hooks: ForgeSettingHooks.merged([
        ForgeShellConfiguration.hooks(),
        if (shell != null) ForgeShortcutConfiguration.hooks(shell),
        if (shell != null) ForgeFileTypesConfiguration.hooks(shell),
        ForgeExternalToolsConfiguration.hooks(tools),
      ]),
    );
    unawaited(values.load());
    return values;
  }

  /// The sections of the configuration descriptions, in their order. They
  /// are shown first but numbered after the module panels;
  /// [ForgeConfigurationPanel.expandSection]'s indices are mapped
  /// ([_sectionForRequest]).
  List<ForgeConfigurationSectionRef> get _describedSections =>
      forgeOrderedSections(_values.descriptions);

  /// The internal index of the described section [refId], or null.
  int? _describedIndexOf(String refId) {
    final described = _describedSections;
    for (var i = 0; i < described.length; i++) {
      if (described[i].id == refId) return _firstDescribedIndex + i;
    }
    return null;
  }

  /// The internal index of the section quick open's index [requested] names
  /// (see [ForgeConfigurationPanel]), or null when it names none.
  int? _sectionForRequest(int requested) {
    if (requested == ForgeConfigurationPanel.sectionIndexShell) {
      return _describedIndexOf(ForgeShellConfiguration.shellSectionRef);
    }
    if (requested == ForgeConfigurationPanel.sectionIndexTerminal) {
      return _describedIndexOf(ForgeShellConfiguration.terminalSectionRef);
    }
    final first = ForgeConfigurationPanel.sectionIndexFirstBuiltIn;
    final editors = ForgeConfigurationPanel.describedSectionRefs;
    if (requested >= first && requested < first + editors.length) {
      return _describedIndexOf(editors[requested - first]);
    }
    final index = requested - first - editors.length;
    return index >= 0 && index < _firstDescribedIndex ? index : null;
  }

  int get _firstDescribedIndex => widget.modulePanels.length;

  int get _totalSections => _firstDescribedIndex + _describedSections.length;

  /// The section indices in the order they are shown.
  List<int> get _displayOrder => [
    for (var i = _firstDescribedIndex; i < _totalSections; i++) i,
    for (var i = 0; i < _firstDescribedIndex; i++) i,
  ];

  @override
  void initState() {
    super.initState();
    // The Shell section is the one open at first, as it always was.
    _expandedSections.add(
      _describedIndexOf(ForgeShellConfiguration.shellSectionRef) ??
          (_totalSections > _firstDescribedIndex ? _firstDescribedIndex : 0),
    );
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
    _ownValues?.dispose();
    super.dispose();
  }

  void _onExpandSectionChanged() {
    final requested = widget.expandSection?.value;
    final target = requested == null ? null : _sectionForRequest(requested);
    if (target != null) {
      _toggleSection(target);
      // Consume the request so it doesn't fire again.
      widget.expandSection?.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build all section entries with their headers and content.
    final children = <Widget>[];
    final described = _describedSections;
    final order = _displayOrder;
    final expandedIndices = order.where(_expandedSections.contains).toList();

    for (final index in order) {
      final String label;
      final IconData icon;
      if (index >= _firstDescribedIndex) {
        final ref = described[index - _firstDescribedIndex];
        final section = ref.section;
        // Under the scope of the module that contributed the description.
        label = _values.textScopeOf(ref.description.id).resolve(section.title);
        icon =
            (section.icon == null
                ? null
                : forgeMaterialIconFor(section.icon!)) ??
            Icons.tune;
      } else {
        final mp = widget.modulePanels[index];
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
            child: _buildSectionContent(index, described),
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
        _expandedSections.removeWhere(
          (i) => !_pinnedSections.contains(i) && i != index,
        );
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

  Widget _buildSectionContent(
    int index,
    List<ForgeConfigurationSectionRef> described,
  ) {
    if (index >= _firstDescribedIndex) {
      return _buildDescribedSection(described[index - _firstDescribedIndex]);
    }
    // Module panel.
    final mp = widget.modulePanels[index];
    return mp.builder(context);
  }

  /// The tile of a described section, its header left to the accordion's.
  Widget _buildDescribedSection(ForgeConfigurationSectionRef ref) {
    final pickers = ForgeShellComponents.of(widget.shellApi).pickers;
    return ForgeConfigurationScope(
      values: _values,
      // The accordion header shows the title; the tile's own header only
      // where the section has help to open.
      style: ForgeConfigurationTileStyle(showHeader: ref.section.help != null),
      pickPath: pickers.available
          ? (setting, current) => _pickPath(pickers, setting, current)
          : null,
      buildHelpPanel: (context, panelId, setting, recheck) =>
          ForgeExternalToolsConfiguration.buildHelpPanel(
            widget.externalTools,
            context,
            panelId,
            recheck,
          ),
      child: _fitToVisibleWidth(
        context,
        SingleChildScrollView(child: ForgeConfigurationTile.of(ref)),
      ),
    );
  }

  /// [child] no wider than the part of the side panel on screen (the panel
  /// lays its content out at least at the shell's content minimum width and
  /// clips the rest); the tiles adapt to that width, so every control of a
  /// row stays visible.
  static Widget _fitToVisibleWidth(BuildContext context, Widget child) {
    final visible = ForgePanelVisibleWidth.maybeOf(context);
    if (visible == null) return child;
    return Align(
      alignment: AlignmentDirectional.topStart,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: visible),
        child: child,
      ),
    );
  }

  static Future<String?> _pickPath(
    ForgeFilePickers pickers,
    ForgePathSetting setting,
    String current,
  ) async {
    final title = ForgeConfigurationLabels.resolve(setting.label);
    if (setting.pathKind == ForgePathKind.folder) {
      return pickers.pickFolder(
        title: title,
        initialDirectory: current.isEmpty ? null : current,
      );
    }
    final files = await pickers.pickFiles(title: title);
    return files.isEmpty ? null : files.first;
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
                    fontWeight: isExpanded
                        ? FontWeight.bold
                        : FontWeight.normal,
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
          child: Center(child: Container(height: 1, color: color)),
        ),
      ),
    );
  }
}
