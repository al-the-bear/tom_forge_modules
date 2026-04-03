import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeTextSettings;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../module/forge_config_panel.dart';
import '../services/forge_preferences_service.dart';
import '../shell/forge_shell_api.dart';

/// In-panel configuration view shown when the config cog is clicked.
///
/// Displays settings sections as an expandable list (shell, terminal,
/// editor configs, shortcuts, file types) plus any module-contributed
/// [ForgeConfigPanel]s.
class ForgeConfigurationPanel extends StatefulWidget {
  final ForgePreferencesService preferencesService;
  final ForgeShellApi? shellApi;
  final List<ForgeConfigPanel> modulePanels;
  final VoidCallback? onSettingsChanged;

  const ForgeConfigurationPanel({
    super.key,
    required this.preferencesService,
    this.shellApi,
    this.modulePanels = const [],
    this.onSettingsChanged,
  });

  @override
  State<ForgeConfigurationPanel> createState() =>
      _ForgeConfigurationPanelState();
}

class _ForgeConfigurationPanelState extends State<ForgeConfigurationPanel> {
  /// Tracks which accordion sections are expanded (by index).
  final Set<int> _expandedSections = {0};

  static const _builtInSections = [
    _SectionDef('Shell', Icons.desktop_mac_outlined),
    _SectionDef('Terminal', Icons.terminal),
    _SectionDef('Dart Editor', Icons.code),
    _SectionDef('YAML Editor', Icons.data_object),
    _SectionDef('Markdown Editor', Icons.description_outlined),
    _SectionDef('Shortcuts', Icons.keyboard),
    _SectionDef('Chord Shortcuts', Icons.piano),
    _SectionDef('File Types', Icons.folder_open),
  ];

  int get _totalSections =>
      _builtInSections.length + widget.modulePanels.length;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _totalSections,
      itemBuilder: (context, index) {
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConfigAccordionHeader(
              label: label,
              icon: icon,
              isExpanded: isExpanded,
              onTap: () => setState(() {
                if (isExpanded) {
                  _expandedSections.remove(index);
                } else {
                  _expandedSections.add(index);
                }
              }),
            ),
            if (isExpanded) _buildSectionContent(index),
          ],
        );
      },
    );
  }

  Widget _buildSectionContent(int index) {
    if (index < _builtInSections.length) {
      return switch (index) {
        0 => _ShellSettingsSection(
            preferencesService: widget.preferencesService,
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
  final VoidCallback onTap;

  const _ConfigAccordionHeader({
    required this.label,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
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
            ],
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
  final VoidCallback? onChanged;

  const _ShellSettingsSection({
    required this.preferencesService,
    this.onChanged,
  });

  @override
  State<_ShellSettingsSection> createState() => _ShellSettingsSectionState();
}

class _ShellSettingsSectionState extends State<_ShellSettingsSection> {
  late ThemeMode _selectedThemeMode;
  late TextEditingController _maxRecentController;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.preferencesService.themeMode;
    _maxRecentController = TextEditingController(
      text: widget.preferencesService.maxRecentWorkspaces.toString(),
    );
  }

  @override
  void dispose() {
    _maxRecentController.dispose();
    super.dispose();
  }

  void _save() {
    final prefs = widget.preferencesService;
    prefs.themeMode = _selectedThemeMode;
    final maxRecent = int.tryParse(_maxRecentController.text.trim());
    if (maxRecent != null && maxRecent >= 1 && maxRecent <= 50) {
      prefs.maxRecentWorkspaces = maxRecent;
    }
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
          _sectionHeader(theme, 'Appearance'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Theme:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Flexible(
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light', style: TextStyle(fontSize: 11)),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  selected: {_selectedThemeMode},
                  onSelectionChanged: (values) {
                    setState(() => _selectedThemeMode = values.first);
                    _save();
                  },
                ),
              ),
            ],
          ),
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

  @override
  void initState() {
    super.initState();
    _settings = widget.shellApi?.getTextSettings(widget.editorTypeId) ??
        const ForgeTextSettings();
  }

  void _update(ForgeTextSettings next) {
    setState(() => _settings = next);
    widget.preferencesService.setEditorTextSettings(widget.editorTypeId, next);
    widget.shellApi?.setTextSettings(widget.editorTypeId, next);
    widget.preferencesService.save();
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
        ],
      ),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
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
        if (bindings.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No matches'),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bindings.length,
            itemBuilder: (context, index) {
              final binding = bindings[index];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  binding.action.label,
                  style: const TextStyle(fontSize: 12),
                ),
                subtitle: Text(
                  binding.context ?? 'global',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
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
                          _capturingActionId == binding.action.id
                              ? '...'
                              : 'Edit',
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
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  bool _matchesFilter(ForgeShortcutBinding binding) {
    if (_searchTerm.isEmpty) return true;
    final haystack = [
      binding.action.id,
      binding.action.label,
      binding.displayString,
      binding.context ?? 'global',
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
    final key = event.logicalKey;
    if ({
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
    }.contains(key)) {
      return null;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final useMeta = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    return ForgeShortcutKey(
      key: key,
      primaryModifier: useMeta
          ? pressed.contains(LogicalKeyboardKey.metaLeft) ||
              pressed.contains(LogicalKeyboardKey.metaRight)
          : pressed.contains(LogicalKeyboardKey.controlLeft) ||
              pressed.contains(LogicalKeyboardKey.controlRight),
      shift: pressed.contains(LogicalKeyboardKey.shiftLeft) ||
          pressed.contains(LogicalKeyboardKey.shiftRight),
      alt: pressed.contains(LogicalKeyboardKey.altLeft) ||
          pressed.contains(LogicalKeyboardKey.altRight),
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
    final key = event.logicalKey;
    if ({
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
    }.contains(key)) {
      return null;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final useMeta =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    return ForgeShortcutKey(
      key: key,
      primaryModifier: useMeta
          ? pressed.contains(LogicalKeyboardKey.metaLeft) ||
              pressed.contains(LogicalKeyboardKey.metaRight)
          : pressed.contains(LogicalKeyboardKey.controlLeft) ||
              pressed.contains(LogicalKeyboardKey.controlRight),
      shift: pressed.contains(LogicalKeyboardKey.shiftLeft) ||
          pressed.contains(LogicalKeyboardKey.shiftRight),
      alt: pressed.contains(LogicalKeyboardKey.altLeft) ||
          pressed.contains(LogicalKeyboardKey.altRight),
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
    '.txt': 'md',
  };
  static const _editorTypeIds = ['md', 'dart', 'yaml', 'plaintext'];

  late Map<String, String> _mappings;
  late String _defaultEditor;
  final TextEditingController _newExtController = TextEditingController();

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
  }

  @override
  void dispose() {
    _newExtController.dispose();
    super.dispose();
  }

  void _save() {
    for (final entry in _mappings.entries) {
      widget.preferencesService.setFileTypeDefaultEditor(
          entry.key, entry.value);
      widget.shellApi?.setFileTypeDefault(entry.key, entry.value);
    }
    // Save the default editor for unmapped extensions.
    widget.preferencesService.setFileTypeDefaultEditor('*', _defaultEditor);
    widget.shellApi?.setFileTypeDefault('*', _defaultEditor);
    widget.preferencesService.save();
    widget.onChanged?.call();
  }

  String _editorTitle(String id) {
    return switch (id) {
      'md' => 'Markdown',
      'dart' => 'Dart',
      'yaml' => 'YAML',
      'plaintext' => 'Plain Text',
      _ => id,
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
                    child: DropdownButtonFormField<String>(
                      initialValue: _editorTypeIds.contains(entry.value)
                          ? entry.value
                          : _editorTypeIds.first,
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
                          setState(() => _mappings[entry.key] = value);
                          _save();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
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
