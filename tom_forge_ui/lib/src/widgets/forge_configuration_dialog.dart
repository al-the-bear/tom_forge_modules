import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeTextSettings;

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../module/forge_config_panel.dart';
import '../services/forge_preferences_service.dart';
import '../shell/forge_shell_api.dart';

/// Active configuration sub-tab.
enum _ConfigTab {
  shell,
  terminal,
  dartEditor,
  yamlEditor,
  mdEditor,
  shortcuts,
  chordShortcuts,
  fileTypes,
}

/// Configuration mode for forge settings storage.
enum ForgeConfigMode {
  /// Store settings in `{workspace}/.forge/`
  workspaceLocal,

  /// Store settings in a central directory
  centralDirectory,
}

/// Dialog for configuring forge settings.
///
/// Allows changing the configuration directory mode and other global settings.
class ForgeConfigurationDialog extends StatefulWidget {
  final ForgePreferencesService preferencesService;
  final ForgeShellApi? shellApi;
  final List<ForgeConfigPanel> modulePanels;

  const ForgeConfigurationDialog({
    super.key,
    required this.preferencesService,
    this.shellApi,
    this.modulePanels = const [],
  });

  /// Shows the configuration dialog.
  static Future<void> show(
    BuildContext context,
    ForgePreferencesService preferencesService,
    ForgeShellApi? shellApi, {
    List<ForgeConfigPanel> modulePanels = const [],
  }) {
    return showDialog(
      context: context,
      builder: (context) => ForgeConfigurationDialog(
        preferencesService: preferencesService,
        shellApi: shellApi,
        modulePanels: modulePanels,
      ),
    );
  }

  @override
  State<ForgeConfigurationDialog> createState() =>
      _ForgeConfigurationDialogState();
}

class _ForgeConfigurationDialogState extends State<ForgeConfigurationDialog> {
  late ForgeConfigMode _configMode;
  late TextEditingController _centralDirController;
  late TextEditingController _maxRecentController;
  late TextEditingController _shortcutSearchController;
  bool _isSelectingDirectory = false;
  String? _errorMessage;
  final List<String> _editorTypeIds = ['md', 'dart', 'yaml', 'plaintext'];
  late Map<String, ForgeTextSettings> _editorSettings;

  /// File extension to editor type mapping.
  late Map<String, String> _fileTypeDefaults;

  /// Default file type mappings.
  static const _defaultFileTypeMappings = {
    '.md': 'md',
    '.markdown': 'md',
    '.dart': 'dart',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.json': 'yaml', // YAML editor can handle JSON
    '.txt': 'md', // Plain text uses Markdown editor
  };

  String _shortcutSearchTerm = '';
  String _chordSearchTerm = '';
  String? _capturingActionId;

  // Sub-tab selection.
  _ConfigTab _selectedTab = _ConfigTab.shell;

  /// When non-null, a module config panel is selected instead of a built-in tab.
  String? _selectedModulePanelId;

  // Terminal settings controllers.
  late TextEditingController _terminalDefaultShellController;
  late TextEditingController _terminalScrollbackController;
  late TextEditingController _terminalFontFamilyController;
  late TextEditingController _terminalFontSizeController;
  late List<String> _terminalShellPaths;
  late String _terminalStartFolder;

  // Theme mode.
  late ThemeMode _selectedThemeMode;

  @override
  void initState() {
    super.initState();
    final prefs = widget.preferencesService;
    _configMode = prefs.centralConfigDirectory != null
        ? ForgeConfigMode.centralDirectory
        : ForgeConfigMode.workspaceLocal;
    _centralDirController = TextEditingController(
      text: prefs.centralConfigDirectory ?? '',
    );
    _maxRecentController = TextEditingController(
      text: prefs.maxRecentWorkspaces.toString(),
    );
    _shortcutSearchController = TextEditingController();
    _shortcutSearchController.addListener(() {
      setState(() {
        _shortcutSearchTerm = _shortcutSearchController.text
            .trim()
            .toLowerCase();
      });
    });
    _editorSettings = {
      for (final typeId in _editorTypeIds)
        typeId:
            widget.shellApi?.getTextSettings(typeId) ??
            const ForgeTextSettings(),
    };
    _fileTypeDefaults = Map<String, String>.from(_defaultFileTypeMappings)
      ..addAll(prefs.fileTypeDefaultEditors);
    final shellDefaults = widget.shellApi?.getFileTypeDefaults();
    if (shellDefaults != null) {
      _fileTypeDefaults.addAll(shellDefaults);
    }

    // Terminal settings.
    _terminalDefaultShellController =
        TextEditingController(text: prefs.terminalDefaultShell ?? '');
    _terminalScrollbackController =
        TextEditingController(text: prefs.terminalScrollbackLines.toString());
    _terminalFontFamilyController =
        TextEditingController(text: prefs.terminalFontFamily);
    _terminalFontSizeController =
        TextEditingController(text: prefs.terminalFontSize.toStringAsFixed(0));
    _terminalShellPaths = List<String>.from(prefs.terminalShellPaths);
    if (_terminalShellPaths.isEmpty) {
      _terminalShellPaths = _detectAvailableShells();
    }
    _terminalStartFolder = prefs.terminalStartFolder;

    _selectedThemeMode = prefs.themeMode;
  }

  @override
  void dispose() {
    _centralDirController.dispose();
    _maxRecentController.dispose();
    _shortcutSearchController.dispose();
    _terminalDefaultShellController.dispose();
    _terminalScrollbackController.dispose();
    _terminalFontFamilyController.dispose();
    _terminalFontSizeController.dispose();
    super.dispose();
  }

  static List<String> _detectAvailableShells() {
    if (Platform.isWindows) {
      return [
        r'C:\Windows\System32\cmd.exe',
        r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
      ];
    }
    final candidates = [
      '/bin/bash',
      '/bin/zsh',
      '/bin/sh',
      '/bin/fish',
      '/usr/bin/fish',
    ];
    return candidates.where((p) => File(p).existsSync()).toList();
  }

  Future<void> _selectCentralDirectory() async {
    setState(() => _isSelectingDirectory = true);

    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Central Configuration Directory',
        initialDirectory: _centralDirController.text.isNotEmpty
            ? _centralDirController.text
            : null,
      );

      if (result != null) {
        _centralDirController.text = result;
        setState(() => _errorMessage = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isSelectingDirectory = false);
      }
    }
  }

  Future<void> _save() async {
    try {
      final prefs = widget.preferencesService;

      // Validate and save max recent
      final maxRecent = int.tryParse(_maxRecentController.text.trim());
      if (maxRecent == null || maxRecent < 1 || maxRecent > 50) {
        setState(
          () => _errorMessage =
              'Max recent workspaces must be a number between 1 and 50',
        );
        return;
      }
      prefs.maxRecentWorkspaces = maxRecent;

      // Save config mode
      if (_configMode == ForgeConfigMode.centralDirectory) {
        final centralDir = _centralDirController.text.trim();
        if (centralDir.isEmpty) {
          setState(
            () => _errorMessage = 'Please specify a central config directory',
          );
          return;
        }
        final dir = Directory(centralDir);
        if (!dir.existsSync()) {
          // Try to create it
          try {
            dir.createSync(recursive: true);
          } catch (e) {
            setState(() => _errorMessage = 'Cannot create directory: $e');
            return;
          }
        }
        prefs.centralConfigDirectory = centralDir;
      } else {
        prefs.centralConfigDirectory = null;
      }

      final shellApi = widget.shellApi;
      for (final entry in _editorSettings.entries) {
        prefs.setEditorTextSettings(entry.key, entry.value);
        if (shellApi != null) {
          shellApi.setTextSettings(entry.key, entry.value);
        }
      }

      final previousPreferenceKeys = prefs.fileTypeDefaultEditors.keys.toSet();
      final previousShellKeys =
          shellApi?.getFileTypeDefaults().keys.toSet() ?? <String>{};
      final nextKeys = _fileTypeDefaults.keys.toSet();

      for (final entry in _fileTypeDefaults.entries) {
        prefs.setFileTypeDefaultEditor(entry.key, entry.value);
        shellApi?.setFileTypeDefault(entry.key, entry.value);
      }
      for (final key in previousPreferenceKeys.difference(nextKeys)) {
        prefs.clearFileTypeDefaultEditor(key);
      }
      for (final key in previousShellKeys.difference(nextKeys)) {
        shellApi?.clearFileTypeDefault(key);
      }

      // Theme mode.
      prefs.themeMode = _selectedThemeMode;

      // Terminal settings.
      final shellText = _terminalDefaultShellController.text.trim();
      prefs.terminalDefaultShell = shellText.isEmpty ? null : shellText;
      prefs.terminalShellPaths = _terminalShellPaths;
      prefs.terminalStartFolder = _terminalStartFolder;
      final scrollback =
          int.tryParse(_terminalScrollbackController.text.trim());
      if (scrollback != null && scrollback > 0) {
        prefs.terminalScrollbackLines = scrollback;
      }
      final tFontFamily = _terminalFontFamilyController.text.trim();
      if (tFontFamily.isNotEmpty) {
        prefs.terminalFontFamily = tFontFamily;
      }
      final tFontSize =
          double.tryParse(_terminalFontSizeController.text.trim());
      if (tFontSize != null && tFontSize > 0) {
        prefs.terminalFontSize = tFontSize;
      }

      await prefs.save();

      // Invoke module panel save callbacks.
      for (final panel in widget.modulePanels) {
        await panel.onSave?.call();
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to save settings: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 900,
        constraints: const BoxConstraints(maxHeight: 780),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  size: 32,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
                const SizedBox(width: 16),
                Text('Settings', style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSidebar(theme),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTabContent(theme)),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[400], fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Sidebar ──

  Widget _buildSidebar(ThemeData theme) {
    return SizedBox(
      width: 180,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildSidebarItem(
            _ConfigTab.shell,
            Icons.desktop_mac_outlined,
            'Shell',
            theme,
          ),
          _buildSidebarItem(
            _ConfigTab.terminal,
            Icons.terminal,
            'Terminal',
            theme,
          ),
          _buildSidebarItem(
            _ConfigTab.dartEditor,
            Icons.code,
            'Dart Editor',
            theme,
          ),
          _buildSidebarItem(
            _ConfigTab.yamlEditor,
            Icons.data_object,
            'YAML Editor',
            theme,
          ),
          _buildSidebarItem(
            _ConfigTab.mdEditor,
            Icons.description_outlined,
            'Markdown Editor',
            theme,
          ),
          _buildSidebarItem(
            _ConfigTab.shortcuts,
            Icons.keyboard,
            'Shortcuts',
            theme,
          ),
          _buildSidebarItem(
            _ConfigTab.chordShortcuts,
            Icons.piano,
            'Chord Shortcuts',
            theme,
          ),
          _buildSidebarItem(
            _ConfigTab.fileTypes,
            Icons.folder_open,
            'File Types',
            theme,
          ),
          // Module-contributed config panels.
          if (widget.modulePanels.isNotEmpty) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'MODULES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  letterSpacing: 1.2,
                ),
              ),
            ),
            for (final panel in widget.modulePanels)
              _buildModuleSidebarItem(panel, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    _ConfigTab tab,
    IconData icon,
    String label,
    ThemeData theme,
  ) {
    final isSelected = _selectedTab == tab && _selectedModulePanelId == null;
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => setState(() {
          _selectedTab = tab;
          _selectedModulePanelId = null;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color,
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

  Widget _buildModuleSidebarItem(ForgeConfigPanel panel, ThemeData theme) {
    final isSelected = _selectedModulePanelId == panel.id;
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => setState(() {
          _selectedModulePanelId = panel.id;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                panel.icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  panel.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color,
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

  // ── Tab content router ──

  Widget _buildTabContent(ThemeData theme) {
    // Show module panel if one is selected.
    if (_selectedModulePanelId != null) {
      final panel = widget.modulePanels
          .where((p) => p.id == _selectedModulePanelId)
          .firstOrNull;
      if (panel != null) {
        return panel.builder(context);
      }
    }
    return switch (_selectedTab) {
      _ConfigTab.shell => _buildShellTab(theme),
      _ConfigTab.terminal => _buildTerminalTab(theme),
      _ConfigTab.dartEditor => _buildEditorTab(theme, 'dart', 'Dart'),
      _ConfigTab.yamlEditor => _buildEditorTab(theme, 'yaml', 'YAML'),
      _ConfigTab.mdEditor => _buildEditorTab(theme, 'md', 'Markdown'),
      _ConfigTab.shortcuts => _buildShortcutsTab(theme),
      _ConfigTab.chordShortcuts => _buildChordShortcutsTab(theme),
      _ConfigTab.fileTypes => _buildFileTypesTab(theme),
    };
  }

  // ── Shell tab ──

  Widget _buildShellTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(theme, 'Appearance'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Theme:'),
              const SizedBox(width: 12),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_brightness, size: 16),
                  ),
                ],
                selected: {_selectedThemeMode},
                onSelectionChanged: (values) {
                  setState(() => _selectedThemeMode = values.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Quick Access'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Max recent workspaces:'),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _maxRecentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Configuration Storage'),
          const SizedBox(height: 12),
          _buildConfigModeRadios(),
          if (_configMode == ForgeConfigMode.centralDirectory) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _centralDirController,
                    decoration: const InputDecoration(
                      hintText: '/path/to/config',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      _isSelectingDirectory ? null : _selectCentralDirectory,
                  child: _isSelectingDirectory
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Browse...'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigModeRadios() {
    return RadioGroup<ForgeConfigMode>(
      groupValue: _configMode,
      onChanged: (value) {
        if (value != null) setState(() => _configMode = value);
      },
      child: Column(
        children: [
          _buildConfigModeOption(
            value: ForgeConfigMode.workspaceLocal,
            title: 'Workspace-local',
            subtitle: 'Store settings in {workspace}/.forge/',
          ),
          const SizedBox(height: 8),
          _buildConfigModeOption(
            value: ForgeConfigMode.centralDirectory,
            title: 'Central directory',
          subtitle: 'Store settings in a shared location',
        ),
        ],
      ),
    );
  }

  Widget _buildConfigModeOption({
    required ForgeConfigMode value,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () => setState(() => _configMode = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Radio<ForgeConfigMode>(
              value: value,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Terminal tab ──

  Widget _buildTerminalTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(theme, 'Shell'),
          const SizedBox(height: 12),
          TextFormField(
            controller: _terminalDefaultShellController,
            decoration: InputDecoration(
              labelText: 'Default Shell',
              hintText: Platform.isWindows ? 'cmd.exe' : '/bin/zsh',
              border: const OutlineInputBorder(),
              helperText: 'Leave empty to use platform default',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Available Shells',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._terminalShellPaths.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    onPressed: () {
                      setState(() {
                        _terminalShellPaths.removeAt(entry.key);
                      });
                    },
                    tooltip: 'Remove',
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: _addShellPath,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add shell path'),
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Start Folder'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _terminalStartFolder,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'workspace',
                child: Text('Workspace root'),
              ),
              DropdownMenuItem(value: 'home', child: Text('Home directory')),
              DropdownMenuItem(
                value: 'lastUsed',
                child: Text('Last used directory'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _terminalStartFolder = value);
            },
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Font & Display'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _terminalFontFamilyController,
                  decoration: const InputDecoration(
                    labelText: 'Font Family',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextFormField(
                  controller: _terminalFontSizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Font Size',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Scrollback lines:'),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _terminalScrollbackController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addShellPath() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Shell'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: Platform.isWindows ? r'C:\path\to\shell.exe' : '/bin/fish',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        if (!_terminalShellPaths.contains(result)) {
          _terminalShellPaths.add(result);
        }
      });
    }
  }

  // ── Editor tab (shared for Dart, YAML, Markdown) ──

  Widget _buildEditorTab(ThemeData theme, String editorTypeId, String title) {
    final settings =
        _editorSettings[editorTypeId] ?? const ForgeTextSettings();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(theme, '$title Editor — Font'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: settings.fontFamily,
                  decoration: const InputDecoration(
                    labelText: 'Font Family',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _editorSettings[editorTypeId] = settings.copyWith(
                        fontFamily: value.trim().isEmpty
                            ? settings.fontFamily
                            : value.trim(),
                      );
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextFormField(
                  initialValue: settings.fontSize.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Font Size',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value.trim());
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        _editorSettings[editorTypeId] =
                            settings.copyWith(fontSize: parsed);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextFormField(
                  initialValue: settings.lineHeight.toStringAsFixed(1),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Line Height',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value.trim());
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        _editorSettings[editorTypeId] =
                            settings.copyWith(lineHeight: parsed);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Indentation'),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextFormField(
                  initialValue: settings.tabSize.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tab Size',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed != null && parsed > 0) {
                      setState(() {
                        _editorSettings[editorTypeId] =
                            settings.copyWith(tabSize: parsed);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              _buildEditorToggle(
                label: 'Insert spaces',
                value: settings.insertSpaces,
                onChanged: (value) {
                  setState(() {
                    _editorSettings[editorTypeId] =
                        settings.copyWith(insertSpaces: value);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Display'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildEditorToggle(
                label: 'Line numbers',
                value: settings.showLineNumbers,
                onChanged: (value) {
                  setState(() {
                    _editorSettings[editorTypeId] =
                        settings.copyWith(showLineNumbers: value);
                  });
                },
              ),
              _buildEditorToggle(
                label: 'Word wrap',
                value: settings.wordWrap,
                onChanged: (value) {
                  setState(() {
                    _editorSettings[editorTypeId] =
                        settings.copyWith(wordWrap: value);
                  });
                },
              ),
              _buildEditorToggle(
                label: 'Highlight current line',
                value: settings.highlightCurrentLine,
                onChanged: (value) {
                  setState(() {
                    _editorSettings[editorTypeId] =
                        settings.copyWith(highlightCurrentLine: value);
                  });
                },
              ),
              _buildEditorToggle(
                label: 'Show whitespace',
                value: settings.showWhitespace,
                onChanged: (value) {
                  setState(() {
                    _editorSettings[editorTypeId] =
                        settings.copyWith(showWhitespace: value);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Undo'),
          const SizedBox(height: 12),
          SizedBox(
            width: 140,
            child: TextFormField(
              initialValue: settings.maxUndoHistory.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max undo steps',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null && parsed > 0) {
                  setState(() {
                    _editorSettings[editorTypeId] =
                        settings.copyWith(maxUndoHistory: parsed);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(label, style: const TextStyle(fontSize: 13)),
        value: value,
        onChanged: (next) {
          onChanged(next ?? false);
        },
      ),
    );
  }

  // ── Shortcuts tab (one-key) ──

  Widget _buildShortcutsTab(ThemeData theme) {
    final shellApi = widget.shellApi;
    if (shellApi == null) {
      return const Center(child: Text('Shell not available'));
    }

    final bindings = shellApi.shortcuts.allBindings
        .where((b) => !b.isChord)
        .where(_shortcutMatchesFilter)
        .toList(growable: false)
      ..sort((a, b) => a.action.label.compareTo(b.action.label));
    final conflictIds = _collectConflictingActionIds(
      shellApi.shortcuts.allBindings.where((b) => !b.isChord).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader(theme, 'System Shortcuts'),
            const Spacer(),
            TextButton.icon(
              onPressed: bindings.isEmpty ? null : _resetAllShortcuts,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _shortcutSearchController,
          decoration: const InputDecoration(
            labelText: 'Search shortcuts',
            hintText: 'Filter by action, key, or context',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: bindings.isEmpty
              ? const Center(
                  child: Text('No shortcuts match the current filter.'),
                )
              : ListView.builder(
                  itemCount: bindings.length,
                  itemBuilder: (context, index) {
                    final binding = bindings[index];
                    final isConflicting =
                        conflictIds.contains(binding.action.id);
                    return _buildShortcutRow(theme, binding, isConflicting);
                  },
                ),
        ),
      ],
    );
  }

  // ── Chord shortcuts tab (two-key) ──

  Widget _buildChordShortcutsTab(ThemeData theme) {
    final shellApi = widget.shellApi;
    if (shellApi == null) {
      return const Center(child: Text('Shell not available'));
    }

    final bindings = shellApi.shortcuts.allBindings
        .where((b) => b.isChord)
        .where(_chordMatchesFilter)
        .toList(growable: false)
      ..sort((a, b) => a.action.label.compareTo(b.action.label));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Chord Shortcuts (Two-Key)'),
        const SizedBox(height: 8),
        TextField(
          onChanged: (value) =>
              setState(() => _chordSearchTerm = value.trim().toLowerCase()),
          decoration: const InputDecoration(
            labelText: 'Search chords',
            hintText: 'Filter by action or key sequence',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: bindings.isEmpty
              ? const Center(
                  child: Text('No chord shortcuts match the current filter.'),
                )
              : ListView.builder(
                  itemCount: bindings.length,
                  itemBuilder: (context, index) {
                    final binding = bindings[index];
                    return _buildChordRow(theme, binding);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildShortcutRow(
    ThemeData theme,
    ForgeShortcutBinding binding,
    bool isConflicting,
  ) {
    return Container(
      color: isConflicting
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: ListTile(
        dense: true,
        title: Text(binding.action.label),
        subtitle: Text(
          'Context: ${binding.context ?? 'global'}',
          style: TextStyle(
            color: isConflicting ? theme.colorScheme.error : null,
          ),
        ),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              binding.displayString,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (isConflicting)
              Icon(
                Icons.warning_amber,
                color: theme.colorScheme.error,
                size: 18,
              ),
            TextButton(
              onPressed: () => _rebindShortcut(binding),
              child: _capturingActionId == binding.action.id
                  ? const Text('Press keys...')
                  : const Text('Rebind'),
            ),
            TextButton(
              onPressed: () => _resetShortcut(binding),
              child: const Text('Reset'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChordRow(ThemeData theme, ForgeShortcutBinding binding) {
    return ListTile(
      dense: true,
      title: Text(binding.action.label),
      subtitle: Text('Context: ${binding.context ?? 'global'}'),
      trailing: Text(
        binding.displayString,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  bool _shortcutMatchesFilter(ForgeShortcutBinding binding) {
    if (_shortcutSearchTerm.isEmpty) return true;
    final haystack = <String>[
      binding.action.id,
      binding.action.label,
      binding.displayString,
      binding.context ?? 'global',
    ].join(' ').toLowerCase();
    return haystack.contains(_shortcutSearchTerm);
  }

  bool _chordMatchesFilter(ForgeShortcutBinding binding) {
    if (_chordSearchTerm.isEmpty) return true;
    final haystack = <String>[
      binding.action.id,
      binding.action.label,
      binding.displayString,
      binding.context ?? 'global',
    ].join(' ').toLowerCase();
    return haystack.contains(_chordSearchTerm);
  }

  Set<String> _collectConflictingActionIds(
    List<ForgeShortcutBinding> bindings,
  ) {
    final byKey = <ForgeShortcutKey, List<ForgeShortcutBinding>>{};
    for (final binding in bindings.where((b) => !b.isChord)) {
      byKey
          .putIfAbsent(binding.key, () => <ForgeShortcutBinding>[])
          .add(binding);
    }
    final conflicting = <String>{};
    for (final entry in byKey.entries) {
      if (entry.value.length > 1) {
        conflicting.addAll(entry.value.map((b) => b.action.id));
      }
    }
    return conflicting;
  }

  Future<void> _rebindShortcut(ForgeShortcutBinding binding) async {
    setState(() {
      _capturingActionId = binding.action.id;
    });

    final captured = await _captureShortcutKey();
    if (!mounted) return;

    setState(() {
      _capturingActionId = null;
    });

    if (captured == null) return;

    final shellApi = widget.shellApi;
    if (shellApi == null) return;

    final conflict = shellApi.shortcuts.conflictsWith(captured);
    if (conflict != null && conflict.action.id != binding.action.id) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Shortcut Conflict'),
          content: Text(
            '"${captured.toDisplayString()}" is currently bound to '
            '"${conflict.action.label}". Replace it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
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
          // Create a wildcard action that delegates to the active editor.
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

  Future<void> _resetShortcut(ForgeShortcutBinding binding) async {
    final shellApi = widget.shellApi;
    if (shellApi == null) return;
    shellApi.shortcuts.resetToDefault(binding.action);
    widget.preferencesService.removeShortcutOverride(binding.action.id);
    await widget.preferencesService.save();
    if (mounted) setState(() {});
  }

  Future<void> _resetAllShortcuts() async {
    final shellApi = widget.shellApi;
    if (shellApi == null) return;
    for (final binding in shellApi.shortcuts.allBindings) {
      shellApi.shortcuts.resetToDefault(binding.action);
    }
    widget.preferencesService.clearShortcutOverrides();
    await widget.preferencesService.save();
    if (mounted) setState(() {});
  }

  Future<ForgeShortcutKey?> _captureShortcutKey() {
    return showDialog<ForgeShortcutKey>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Press new shortcut'),
          content: SizedBox(
            width: 420,
            child: Focus(
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(context).pop();
                  return KeyEventResult.handled;
                }
                final captured = _eventToShortcutKey(event);
                if (captured != null) {
                  Navigator.of(context).pop(captured);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: const Text(
                'Press a key combination. Press Esc to cancel.',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  ForgeShortcutKey? _eventToShortcutKey(KeyDownEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      return null;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final useMeta = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final hasPrimary = useMeta
        ? pressed.contains(LogicalKeyboardKey.metaLeft) ||
              pressed.contains(LogicalKeyboardKey.metaRight)
        : pressed.contains(LogicalKeyboardKey.controlLeft) ||
              pressed.contains(LogicalKeyboardKey.controlRight);
    final hasShift =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    final hasAlt =
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);

    return ForgeShortcutKey(
      key: key,
      primaryModifier: hasPrimary,
      shift: hasShift,
      alt: hasAlt,
    );
  }

  // ── File types tab ──

  Widget _buildFileTypesTab(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(theme, 'File Type Associations'),
          const SizedBox(height: 8),
          Text(
            'Configure which editor opens each file type by default.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _fileTypeDefaults.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, size: 16),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: entry.value,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              isDense: true,
                            ),
                            items: _editorTypeIds.map((id) {
                              return DropdownMenuItem(
                                value: id,
                                child: Text(_editorTitle(id)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _fileTypeDefaults[entry.key] = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Plain Text Editor'),
          const SizedBox(height: 8),
          _buildPlainTextEditorSettings(),
        ],
      ),
    );
  }

  Widget _buildPlainTextEditorSettings() {
    final settings =
        _editorSettings['plaintext'] ?? const ForgeTextSettings();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: settings.fontFamily,
                    decoration: const InputDecoration(
                      labelText: 'Font Family',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _editorSettings['plaintext'] = settings.copyWith(
                          fontFamily: value.trim().isEmpty
                              ? settings.fontFamily
                              : value.trim(),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    initialValue: settings.fontSize.toStringAsFixed(0),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Font Size',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          _editorSettings['plaintext'] =
                              settings.copyWith(fontSize: parsed);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildEditorToggle(
                  label: 'Line numbers',
                  value: settings.showLineNumbers,
                  onChanged: (value) {
                    setState(() {
                      _editorSettings['plaintext'] =
                          settings.copyWith(showLineNumbers: value);
                    });
                  },
                ),
                _buildEditorToggle(
                  label: 'Word wrap',
                  value: settings.wordWrap,
                  onChanged: (value) {
                    setState(() {
                      _editorSettings['plaintext'] =
                          settings.copyWith(wordWrap: value);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ──

  Widget _sectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _editorTitle(String editorTypeId) {
    switch (editorTypeId) {
      case 'md':
        return 'Markdown';
      case 'dart':
        return 'Dart';
      case 'yaml':
        return 'YAML';
      case 'plaintext':
        return 'Plain Text';
      default:
        return editorTypeId;
    }
  }
}
