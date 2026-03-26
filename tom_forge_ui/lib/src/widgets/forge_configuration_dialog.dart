import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
  show ForgeTextSettings;

import '../services/forge_preferences_service.dart';
import '../shell/forge_shell_api.dart';

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

  const ForgeConfigurationDialog({
    super.key,
    required this.preferencesService,
    this.shellApi,
  });

  /// Shows the configuration dialog.
  static Future<void> show(
    BuildContext context,
    ForgePreferencesService preferencesService,
    ForgeShellApi? shellApi,
  ) {
    return showDialog(
      context: context,
      builder: (context) =>
          ForgeConfigurationDialog(
            preferencesService: preferencesService,
            shellApi: shellApi,
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
  bool _isSelectingDirectory = false;
  String? _errorMessage;
  final List<String> _editorTypeIds = ['md', 'dart', 'yaml'];
  late Map<String, ForgeTextSettings> _editorSettings;

  @override
  void initState() {
    super.initState();
    final prefs = widget.preferencesService;
    _configMode = prefs.centralConfigDirectory != null
        ? ForgeConfigMode.centralDirectory
        : ForgeConfigMode.workspaceLocal;
    _centralDirController =
        TextEditingController(text: prefs.centralConfigDirectory ?? '');
    _maxRecentController =
        TextEditingController(text: prefs.maxRecentWorkspaces.toString());
    _editorSettings = {
      for (final typeId in _editorTypeIds)
        typeId: widget.shellApi?.getTextSettings(typeId) ??
            const ForgeTextSettings(),
    };
  }

  @override
  void dispose() {
    _centralDirController.dispose();
    _maxRecentController.dispose();
    super.dispose();
  }

  Future<void> _selectCentralDirectory() async {
    setState(() => _isSelectingDirectory = true);

    try {
      final result = await FilePicker.platform.getDirectoryPath(
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

  void _save() {
    final prefs = widget.preferencesService;

    // Validate and save max recent
    final maxRecent = int.tryParse(_maxRecentController.text.trim());
    if (maxRecent == null || maxRecent < 1 || maxRecent > 50) {
      setState(() => _errorMessage =
          'Max recent workspaces must be a number between 1 and 50');
      return;
    }
    prefs.maxRecentWorkspaces = maxRecent;

    // Save config mode
    if (_configMode == ForgeConfigMode.centralDirectory) {
      final centralDir = _centralDirController.text.trim();
      if (centralDir.isEmpty) {
        setState(
            () => _errorMessage = 'Please specify a central config directory');
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

    prefs.save();

    final shellApi = widget.shellApi;
    if (shellApi != null) {
      for (final entry in _editorSettings.entries) {
        shellApi.setTextSettings(entry.key, entry.value);
      }
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                Text(
                  'Settings',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Recent workspaces setting
            Text(
              'Quick Access',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
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

            // Configuration directory setting
            Text(
              'Configuration Storage',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<ForgeConfigMode>(
              groupValue: _configMode,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _configMode = value);
                }
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
            ),
            if (_configMode == ForgeConfigMode.centralDirectory) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _centralDirController,
                      decoration: InputDecoration(
                        hintText: '/path/to/config',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Editor Text Settings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ..._editorTypeIds.map(_buildEditorSettingsPanel),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorSettingsPanel(String editorTypeId) {
    final settings = _editorSettings[editorTypeId] ?? const ForgeTextSettings();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editorTitle(editorTypeId),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
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
                          fontFamily: value.trim().isEmpty ? settings.fontFamily : value.trim(),
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
                      labelText: 'Font',
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
                  width: 90,
                  child: TextFormField(
                    initialValue: settings.tabSize.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tab',
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
              ],
            ),
          ],
        ),
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
      default:
        return editorTypeId;
    }
  }
}
