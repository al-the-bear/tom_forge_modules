import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show ForgeTextSettings;

import '../actions/forge_shortcut_binding.dart';
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
      builder: (context) => ForgeConfigurationDialog(
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
  String? _capturingActionId;

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
  }

  @override
  void dispose() {
    _centralDirController.dispose();
    _maxRecentController.dispose();
    _shortcutSearchController.dispose();
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

      for (final entry in _fileTypeDefaults.entries) {
        prefs.setFileTypeDefaultEditor(entry.key, entry.value);
        shellApi?.setFileTypeDefault(entry.key, entry.value);
      }

      await prefs.save();

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
        width: 720,
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
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                            onPressed: _isSelectingDirectory
                                ? null
                                : _selectCentralDirectory,
                            child: _isSelectingDirectory
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
                        style: TextStyle(color: Colors.red[400], fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildShortcutSection(theme),
                    const SizedBox(height: 20),
                    Text(
                      'Editor Text Settings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._editorTypeIds.map(_buildEditorSettingsPanel),
                    const SizedBox(height: 20),
                    _buildFileTypesSection(theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
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
            Radio<ForgeConfigMode>(value: value),
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
                      labelText: 'Font',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          _editorSettings[editorTypeId] = settings.copyWith(
                            fontSize: parsed,
                          );
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
                          _editorSettings[editorTypeId] = settings.copyWith(
                            tabSize: parsed,
                          );
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
                      _editorSettings[editorTypeId] = settings.copyWith(
                        showLineNumbers: value,
                      );
                    });
                  },
                ),
                _buildEditorToggle(
                  label: 'Word wrap',
                  value: settings.wordWrap,
                  onChanged: (value) {
                    setState(() {
                      _editorSettings[editorTypeId] = settings.copyWith(
                        wordWrap: value,
                      );
                    });
                  },
                ),
                _buildEditorToggle(
                  label: 'Highlight current line',
                  value: settings.highlightCurrentLine,
                  onChanged: (value) {
                    setState(() {
                      _editorSettings[editorTypeId] = settings.copyWith(
                        highlightCurrentLine: value,
                      );
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

  Widget _buildShortcutSection(ThemeData theme) {
    final shellApi = widget.shellApi;
    if (shellApi == null) {
      return const SizedBox.shrink();
    }

    final bindings =
        shellApi.shortcuts.allBindings
            .where(_shortcutMatchesFilter)
            .toList(growable: false)
          ..sort((a, b) => a.action.label.compareTo(b.action.label));
    final conflictIds = _collectConflictingActionIds(
      shellApi.shortcuts.allBindings,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Shortcuts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: bindings.isEmpty ? null : _resetAllShortcuts,
              icon: const Icon(Icons.refresh),
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
        if (bindings.isEmpty)
          const Text('No shortcuts match the current filter.')
        else
          Card(
            child: Column(
              children: bindings.map((binding) {
                final isConflicting = conflictIds.contains(binding.action.id);
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
                          onPressed: binding.isChord
                              ? null
                              : () => _rebindShortcut(binding),
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
              }).toList(),
            ),
          ),
      ],
    );
  }

  bool _shortcutMatchesFilter(ForgeShortcutBinding binding) {
    if (_shortcutSearchTerm.isEmpty) {
      return true;
    }
    final haystack = <String>[
      binding.action.id,
      binding.action.label,
      binding.displayString,
      binding.context ?? 'global',
    ].join(' ').toLowerCase();
    return haystack.contains(_shortcutSearchTerm);
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
    if (!mounted) {
      return;
    }

    setState(() {
      _capturingActionId = null;
    });

    if (captured == null) {
      return;
    }

    final shellApi = widget.shellApi;
    if (shellApi == null) {
      return;
    }
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
      if (accepted != true) {
        return;
      }
    }

    shellApi.shortcuts.rebind(binding.action, captured);
    widget.preferencesService.setShortcutOverride(binding.action.id, captured);
    await widget.preferencesService.save();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resetShortcut(ForgeShortcutBinding binding) async {
    final shellApi = widget.shellApi;
    if (shellApi == null) {
      return;
    }
    shellApi.shortcuts.resetToDefault(binding.action);
    widget.preferencesService.removeShortcutOverride(binding.action.id);
    await widget.preferencesService.save();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _resetAllShortcuts() async {
    final shellApi = widget.shellApi;
    if (shellApi == null) {
      return;
    }
    for (final binding in shellApi.shortcuts.allBindings) {
      shellApi.shortcuts.resetToDefault(binding.action);
    }
    widget.preferencesService.clearShortcutOverrides();
    await widget.preferencesService.save();
    if (mounted) {
      setState(() {});
    }
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

  Widget _buildFileTypesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'File Type Associations',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
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
      ],
    );
  }
}
