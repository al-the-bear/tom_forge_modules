import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/forge_preferences_service.dart';

/// A dialog for selecting a workspace folder.
///
/// Returns the selected [Directory] or null if cancelled.
class WorkspaceFolderSelector extends StatefulWidget {
  final String? initialPath;

  const WorkspaceFolderSelector({
    super.key,
    this.initialPath,
  });

  /// Shows the workspace selector dialog.
  /// Returns the selected directory or null if cancelled.
  static Future<Directory?> show(BuildContext context, {String? initialPath}) {
    return showDialog<Directory>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WorkspaceFolderSelector(initialPath: initialPath),
    );
  }

  @override
  State<WorkspaceFolderSelector> createState() => _WorkspaceFolderSelectorState();
}

class _WorkspaceFolderSelectorState extends State<WorkspaceFolderSelector> {
  final _pathController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pathController.text = widget.initialPath ?? '';
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _browseFolder() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Workspace Folder',
        initialDirectory: _pathController.text.isNotEmpty
            ? _pathController.text
            : null,
      );

      if (result != null) {
        _pathController.text = result;
        setState(() {
          _errorMessage = null;
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmSelection() {
    final path = _pathController.text.trim();

    if (path.isEmpty) {
      setState(() => _errorMessage = 'Please enter a folder path');
      return;
    }

    final dir = Directory(path);
    if (!dir.existsSync()) {
      setState(() => _errorMessage = 'Folder does not exist');
      return;
    }

    Navigator.of(context).pop(dir);
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
                  Icons.folder_open,
                  size: 32,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
                const SizedBox(width: 16),
                Text(
                  'Open Workspace',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Select a folder to open as your workspace:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: InputDecoration(
                      hintText: '/path/to/folder',
                      border: const OutlineInputBorder(),
                      errorText: _errorMessage,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: (_) => _confirmSelection(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _browseFolder,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Browse...'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _confirmSelection,
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A full-screen welcome page for selecting a workspace.
class WorkspaceWelcomePage extends StatefulWidget {
  final void Function(Directory directory) onFolderSelected;
  final ForgePreferencesService? preferencesService;

  const WorkspaceWelcomePage({
    super.key,
    required this.onFolderSelected,
    this.preferencesService,
  });

  @override
  State<WorkspaceWelcomePage> createState() => _WorkspaceWelcomePageState();
}

class _WorkspaceWelcomePageState extends State<WorkspaceWelcomePage> {
  bool _isLoading = false;
  bool _prefsLoaded = false;
  bool _resetUI = false;
  late ForgePreferencesService _prefs;
  List<String> _recentFolders = [];

  @override
  void initState() {
    super.initState();
    _prefs = widget.preferencesService ?? ForgePreferencesService.instance;
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    await _prefs.load();
    if (mounted) {
      setState(() {
        _prefsLoaded = true;
        _recentFolders = _prefs.startupPreferences.recentWorkspaces
            .where((p) => Directory(p).existsSync())
            .toList();
      });
    }
  }

  Future<void> _browseFolder() async {
    setState(() => _isLoading = true);

    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: 'Select Workspace Folder',
      );

      if (result != null && mounted) {
        if (_resetUI) await _clearLayoutPreferences();
        await _prefs.addRecentWorkspace(result);
        widget.onFolderSelected(Directory(result));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectFolder(String path) async {
    if (_resetUI) await _clearLayoutPreferences();
    await _prefs.addRecentWorkspace(path);
    widget.onFolderSelected(Directory(path));
  }

  Future<void> _clearLayoutPreferences() async {
    _prefs.clearLayoutState();
    await _prefs.save();
  }

  Future<void> _removeFromRecent(String path) async {
    await _prefs.removeRecentWorkspace(path);
    setState(() {
      _recentFolders = _prefs.startupPreferences.recentWorkspaces
          .where((p) => Directory(p).existsSync())
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
      body: Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.code,
                    size: 48,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Tom Forge',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Visual IDE Shell',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 48),

              // Start section
              Text(
                'Start',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _ActionButton(
                icon: Icons.folder_open,
                label: 'Open Folder...',
                subtitle: 'Open a folder as your workspace',
                isLoading: _isLoading,
                onTap: _browseFolder,
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Reset UI',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'Start with a fresh layout (discard panel positions)',
                  style: TextStyle(fontSize: 11),
                ),
                value: _resetUI,
                onChanged: (v) => setState(() => _resetUI = v ?? false),
              ),

              // Recent folders
              if (_recentFolders.isNotEmpty) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Quick Access',
                      style: theme.textTheme.titleLarge,
                    ),
                    if (_prefsLoaded)
                      Text(
                        '(max ${_prefs.maxRecentWorkspaces})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._recentFolders.map((path) => _RecentFolderItem(
                      path: path,
                      onTap: () => _selectFolder(path),
                      onRemove: () => _removeFromRecent(path),
                      isDark: isDark,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark
                    ? Colors.grey[800]
                    : Colors.white)
                : (widget.isDark
                    ? Colors.grey[850]
                    : Colors.grey[200]),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      widget.icon,
                      size: 24,
                      color: widget.isDark
                          ? Colors.blue[300]
                          : Colors.blue[700],
                    ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[500],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentFolderItem extends StatefulWidget {
  final String path;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool isDark;

  const _RecentFolderItem({
    required this.path,
    required this.onTap,
    this.onRemove,
    required this.isDark,
  });

  @override
  State<_RecentFolderItem> createState() => _RecentFolderItemState();
}

class _RecentFolderItemState extends State<_RecentFolderItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final folderName = widget.path.split('/').last;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark
                    ? Colors.grey[800]
                    : Colors.grey[200])
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder,
                size: 18,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      widget.path,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isHovered && widget.onRemove != null)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  onPressed: widget.onRemove,
                  tooltip: 'Remove from Quick Access',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
