import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'forge_explorer_settings.dart';
import 'forge_explorer_tree_walk.dart';
import 'forge_file_explorer_trail.dart';

/// File explorer tree view.
///
/// Lists files from [TomFileSystem], with collapsible directories
/// and clickable files that open through [openFile].
/// Supports selection, hover, rename, delete, and file decoration rendering.
///
/// A kit component: it reads and changes files through [fileSystem], opens
/// them through [openFile], shares its selection with [selection] when
/// given (the application reveals a file through it) and draws the
/// decorations of [fileDecorationManager] when given, so any application on
/// the kit shows it ([ForgeFileExplorerView.forApi]).
///
/// **Filtering, the hidden count and the root switcher are opt-in** (D36
/// §2–§4 of Webwork's Workspace browser, here for every application on the
/// kit). Without [filter], [filterPresets] and [rootSwitcher] the explorer
/// is Tom Forge's: it lists folders as they are opened and leaves out the
/// entries whose name starts with `.`.
///
/// - **Filter rules** ([filter], [filterPresets]): an ordered rule list of
///   `tom_file_session` ([ForgeFilter]; the last matching rule decides, an
///   entry no rule matches is shown). The header's filter button chooses a
///   preset, edits the rules as text and shows the hidden entries for a
///   while. The tree is then drawn from one **bounded background walk** of
///   the root ([walkLimit] entries; past it the footer says where it
///   stopped and a folder the walk did not finish is listed when opened), so
///   a folder is shown when anything below it is, and every hidden entry is
///   counted.
/// - **The hidden count**: the footer's "*N* hidden" opens the list of the
///   hidden entries with the rule that hid each; a folder whose filter hides
///   something carries its own count.
/// - **The root switcher** ([rootSwitcher]): the header lists [rootUri] and
///   the folders the user registered (*Add folder…* through [pickFolder],
///   else a path prompt; *Remove from list*), and shows the one chosen.
///
/// The registered roots, the root shown and each root's filter choice are
/// kept through [stateStore] under keys starting with [stateKey], when one
/// is given.
class ForgeFileExplorerView extends ForgeView {
  final TomFileSystem fileSystem;

  /// Opens a file the user picks (double tap, Open, a file just created).
  final ForgeOpenFileAt openFile;
  final Uri rootUri;

  /// Where the selection and the hovered row are kept (the application's
  /// state), or null: the explorer keeps its selection to itself.
  final ForgeExplorerSelection? selection;
  final DefaultFileDecorationManager? fileDecorationManager;

  /// Module context-menu contributions for the rows
  /// ([ForgeContextTarget.explorerFileKind],
  /// [ForgeContextTarget.explorerDirectoryKind]), drawn after the explorer's
  /// own entries. Null draws the explorer's entries alone.
  final ForgeContextMenuController? contextMenus;

  /// The editor picker a file row's **Open With ▸** submenu is built from
  /// ([forgeOpenWithMenuEntry]): drawn when the file has more than one
  /// editor. Null draws no submenu.
  final ForgeEditorPicker? editorPicker;

  /// The filter rules in force at the start, or null. When it is one of
  /// [filterPresets]' filters (the same object), that preset is chosen.
  /// With [filter] or [filterPresets] the explorer filters (see the class).
  final ForgeFilter? filter;

  /// The presets the filter button offers; null with a [filter] offers
  /// `tom_file_session`'s built-ins ([ForgeBuiltInPresets.all]). Without
  /// [filter] the first preset is in force at the start.
  final List<ForgeFilterPreset>? filterPresets;

  /// Whether the header offers the root switcher: [rootUri] and the folders
  /// the user registers. Default false: [rootUri] alone, no header.
  final bool rootSwitcher;

  /// The platform's folder picker for the switcher's *Add folder…*; null
  /// asks for the folder's path.
  final Future<Uri?> Function()? pickFolder;

  /// Where the registered roots, the root shown and the filter choices are
  /// kept; null keeps them while the view lives. Read and written only when
  /// filtering or the root switcher is configured.
  final ForgeStateStore? stateStore;

  /// The prefix of this explorer's [stateStore] keys
  /// (`<stateKey>.roots`, `<stateKey>.filters`): one per explorer instance.
  final String stateKey;

  /// How many entries the filtering explorer's walk reads before it stops
  /// and says so (default [forgeExplorerWalkLimit]).
  final int walkLimit;

  /// Whether the explorer filters ([filter] or [filterPresets] given).
  bool get filtering => filter != null || filterPresets != null;

  final _title = ValueNotifier<String>('Explorer');
  final _titleExtension = ValueNotifier<String?>(null);

  ForgeFileExplorerView({
    required this.fileSystem,
    required this.openFile,
    required this.rootUri,
    this.selection,
    this.fileDecorationManager,
    this.contextMenus,
    this.editorPicker,
    this.filter,
    this.filterPresets,
    this.rootSwitcher = false,
    this.pickFolder,
    this.stateStore,
    this.stateKey = forgeExplorerDefaultStateKey,
    this.walkLimit = forgeExplorerWalkLimit,
  });

  /// The view over [api] showing [rootUri]: its file system, opening files
  /// through the application's [ForgeFileNavigator] ([forgeOpenFileAtOf]),
  /// with the modules' context-menu entries ([ForgeKitApi.contextMenus]) and
  /// the **Open With ▸** submenu of its editor picker
  /// ([ForgeKitApi.editorPicker]).
  /// It keeps its selection to itself and draws no decorations, as Tom
  /// Forge's explorer does; give [selection] and [fileDecorationManager] to
  /// the constructor for those.
  ///
  /// [filter], [filterPresets], [rootSwitcher], [pickFolder], [stateKey] and
  /// [walkLimit] are the constructor's; when the explorer filters or offers
  /// the root switcher, its choices are kept in [ForgeKitApi.stateStore].
  factory ForgeFileExplorerView.forApi(
    ForgeKitApi api, {
    required Uri rootUri,
    ForgeFilter? filter,
    List<ForgeFilterPreset>? filterPresets,
    bool rootSwitcher = false,
    Future<Uri?> Function()? pickFolder,
    String stateKey = forgeExplorerDefaultStateKey,
    int walkLimit = forgeExplorerWalkLimit,
  }) => ForgeFileExplorerView(
    fileSystem: api.fileSystem,
    openFile: forgeOpenFileAtOf(api),
    rootUri: rootUri,
    contextMenus: api.contextMenus,
    editorPicker: api.editorPicker,
    filter: filter,
    filterPresets: filterPresets,
    rootSwitcher: rootSwitcher,
    pickFolder: pickFolder,
    // Touched only when configured: a bare kit's default store is the
    // platform's preferences.
    stateStore: (filter != null || filterPresets != null || rootSwitcher)
        ? api.stateStore
        : null,
    stateKey: stateKey,
    walkLimit: walkLimit,
  );

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => Icons.folder_outlined;

  @override
  ForgeComponentSizeHints get sizeHints =>
      const ForgeComponentSizeHints(preferredSize: Size(250, 400));

  @override
  Widget buildMain(BuildContext context) {
    return _FileExplorerContent(
      fileSystem: fileSystem,
      openFile: openFile,
      rootUri: rootUri,
      selection: selection,
      fileDecorationManager: fileDecorationManager,
      contextMenus: contextMenus,
      editorPicker: editorPicker,
      config: this,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

class _FileExplorerContent extends StatefulWidget {
  final TomFileSystem fileSystem;
  final ForgeOpenFileAt openFile;
  final Uri rootUri;
  final ForgeExplorerSelection? selection;
  final DefaultFileDecorationManager? fileDecorationManager;
  final ForgeContextMenuController? contextMenus;
  final ForgeEditorPicker? editorPicker;

  /// The view: its filter, root switcher and state store.
  final ForgeFileExplorerView config;

  const _FileExplorerContent({
    required this.config,
    required this.fileSystem,
    required this.openFile,
    required this.rootUri,
    this.selection,
    this.fileDecorationManager,
    this.contextMenus,
    this.editorPicker,
  });

  @override
  State<_FileExplorerContent> createState() => _FileExplorerContentState();
}

class _FileExplorerContentState extends State<_FileExplorerContent> {
  List<TomFileEntry> _rootEntries = [];
  final Map<String, List<TomFileEntry>> _directoryChildren = {};
  final Set<String> _loadingDirectories = {};
  final Set<String> _expandedDirs = {};
  Uri? _selectedUri;
  Uri? _hoveredUri;
  String? _errorMessage;
  StreamSubscription<Uri?>? _decorationSubscription;

  /// The folder shown: [_FileExplorerContent.rootUri] unless the root
  /// switcher chose another.
  late Uri _root = widget.rootUri;

  /// The folders the user registered (the root switcher), after the host's.
  final List<ForgeExplorerRoot> _registeredRoots = [];

  /// Each root's filter choice, by its folder path.
  final Map<String, ForgeExplorerFilterChoice> _filterChoices = {};

  /// Whether the hidden entries are shown for now, dimmed (not kept).
  bool _showHidden = false;

  /// The filtering explorer's tree, from its last walk.
  ForgeExplorerTreeModel? _model;
  bool _walking = false;
  int _walkGeneration = 0;

  /// Whether the kept choices are still being read.
  bool _restoring = false;

  ForgeFileExplorerView get _config => widget.config;
  bool get _filtering => _config.filtering;
  bool get _hasHeader => _filtering || _config.rootSwitcher;
  String get _rootKey => forgeExplorerFolderPath(_root);

  List<ForgeFilterPreset> get _presets =>
      _config.filterPresets ?? ForgeBuiltInPresets.all;

  ForgeExplorerFilterChoice get _choice =>
      _filterChoices[_rootKey] ?? _initialChoice;

  ForgeExplorerFilterChoice get _initialChoice {
    final given = _config.filter;
    if (given == null) {
      return ForgeExplorerFilterChoice(preset: _presets.firstOrNull?.name);
    }
    final preset = _presets
        .where((p) => identical(p.filter, given))
        .firstOrNull;
    return preset != null
        ? ForgeExplorerFilterChoice(preset: preset.name)
        : ForgeExplorerFilterChoice(rules: given);
  }

  ForgeFilterPreset? get _preset =>
      _presets.where((p) => p.name == _choice.preset).firstOrNull;

  /// The filter in force: the edited rules, else the preset's.
  ForgeFilter get _filter =>
      _choice.rules ?? _preset?.filter ?? const ForgeFilter([]);

  String get _filterLabel {
    final choice = _choice;
    final preset = _preset;
    if (choice.rules == null) return preset?.name ?? 'No filter';
    return preset == null ? 'Custom rules' : '${preset.name}, modified';
  }

  /// The host's root, then the registered ones.
  List<ForgeExplorerRoot> get _roots => [
    ForgeExplorerRoot.of(widget.rootUri),
    ..._registeredRoots,
  ];

  ForgeExplorerRoot get _currentRoot =>
      _roots
          .where((r) => forgeExplorerFolderPath(r.uri) == _rootKey)
          .firstOrNull ??
      ForgeExplorerRoot.of(_root);

  bool get _currentIsRegistered =>
      _registeredRoots.any((r) => forgeExplorerFolderPath(r.uri) == _rootKey);

  ForgeExplorerTreeWalker _walker() => ForgeExplorerTreeWalker(
    fileSystem: widget.fileSystem,
    rootUri: _root,
    filter: _filter,
    limit: _config.walkLimit,
    showHidden: _showHidden,
  );

  @override
  void initState() {
    super.initState();
    if (_hasHeader && _config.stateStore != null) {
      _restoring = true;
      unawaited(
        _restore().whenComplete(() {
          if (!mounted) return;
          setState(() => _restoring = false);
          _loadEntries();
        }),
      );
    } else {
      _loadEntries();
    }
    // Listen for reveal-in-explorer triggers from the shared selection.
    widget.selection?.selectedExplorerItemsListenable.addListener(
      _onSystemStateChanged,
    );
    // Listen for decoration changes to refresh display.
    _decorationSubscription = widget.fileDecorationManager?.onDidChange.listen(
      _onDecorationChanged,
    );
  }

  @override
  void dispose() {
    _decorationSubscription?.cancel();
    widget.selection?.selectedExplorerItemsListenable.removeListener(
      _onSystemStateChanged,
    );
    super.dispose();
  }

  void _onDecorationChanged(Uri? uri) {
    // Rebuild to reflect updated decorations.
    if (mounted) setState(() {});
  }

  void _onSystemStateChanged() {
    final items = widget.selection?.selectedExplorerItems ?? [];
    if (items.isNotEmpty && items.first != _selectedUri) {
      _revealUri(items.first);
    }
  }

  /// Auto-expand directories to reveal [uri] in the tree.
  Future<void> _revealUri(Uri uri) async {
    final rootPath = _root.toFilePath();
    var filePath = uri.toFilePath();
    if (!filePath.startsWith(rootPath)) return;

    // Build list of ancestor directories to expand.
    final segments = <String>[];
    var current = filePath;
    while (current != rootPath && current.contains('/')) {
      current = current.substring(0, current.lastIndexOf('/'));
      if (current.length >= rootPath.length) {
        segments.insert(0, current);
      }
    }

    for (final dirPath in segments) {
      if (!_expandedDirs.contains(dirPath)) {
        _expandedDirs.add(dirPath);
        if (!_directoryChildren.containsKey(dirPath)) {
          await _loadDirectoryChildren(dirPath);
        }
      }
    }

    if (mounted) {
      setState(() => _selectedUri = uri);
    }
  }

  Future<void> _loadEntries() async {
    if (_filtering) return _walk();
    try {
      final entries = await widget.fileSystem.list(_root);
      if (mounted) {
        setState(() {
          _rootEntries = _sortEntries(entries);
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to read workspace files.';
        });
      }
    }
  }

  Future<void> _loadDirectoryChildren(String directoryPath) async {
    if (_loadingDirectories.contains(directoryPath)) {
      return;
    }

    final model = _model;
    if (_filtering &&
        (model == null || model.children.containsKey(directoryPath))) {
      // The walk listed it (or is about to).
      return;
    }

    setState(() => _loadingDirectories.add(directoryPath));
    try {
      final List<TomFileEntry> children;
      if (model != null) {
        // A folder the walk did not reach: its children under the filter.
        await _walker().listDirectory(model, directoryPath);
        if (!identical(model, _model)) return;
        children = model.children[directoryPath] ?? const [];
        forgeExplorerTrail(
          'listed $directoryPath outside the walk: ${children.length} shown',
        );
      } else {
        children = _sortEntries(
          await widget.fileSystem.list(Uri.file(directoryPath)),
        );
      }
      if (mounted) {
        setState(() {
          _directoryChildren[directoryPath] = children;
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _directoryChildren[directoryPath] = const [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingDirectories.remove(directoryPath));
      }
    }
  }

  Future<void> _toggleDirectory(String path, bool isExpanded) async {
    if (isExpanded) {
      setState(() => _expandedDirs.remove(path));
      return;
    }

    setState(() => _expandedDirs.add(path));
    if (!_directoryChildren.containsKey(path)) {
      await _loadDirectoryChildren(path);
    }
  }

  // --- Filtering: the bounded walk ----------------------------------------

  /// Walks the root under the filter in the background, at most
  /// [ForgeFileExplorerView.walkLimit] entries, and draws the tree from it.
  /// A walk started later wins; an earlier one's answer is dropped.
  Future<void> _walk() async {
    final generation = ++_walkGeneration;
    final walker = _walker();
    _walking = true;
    forgeExplorerTrail(
      'walk start: ${walker.rootPath}, filter "$_filterLabel"'
      '${_showHidden ? ', hidden shown' : ''}',
    );
    bool stale() => !mounted || generation != _walkGeneration;
    try {
      final model = await walker.walk(cancelled: stale);
      if (stale()) return;
      setState(() {
        _model = model;
        _rootEntries = model.children[walker.rootPath] ?? const [];
        _directoryChildren
          ..clear()
          ..addAll(model.children)
          ..remove(walker.rootPath);
        _errorMessage = null;
        _walking = false;
      });
      forgeExplorerTrail(
        'walk end: ${model.seen} entries, ${model.hiddenTotal} hidden'
        '${model.truncated ? ', stopped at ${walker.limit}' : ''}',
      );
      // Open folders the walk did not finish are listed as when opened.
      for (final dir in [..._expandedDirs]) {
        if (!_directoryChildren.containsKey(dir)) {
          unawaited(_loadDirectoryChildren(dir));
        }
      }
    } catch (e) {
      if (stale()) return;
      forgeExplorerTrail('walk failed: $e');
      setState(() {
        _model = null;
        _walking = false;
        _errorMessage = 'Failed to read workspace files.';
      });
    }
  }

  void _selectPreset(ForgeFilterPreset preset) {
    forgeExplorerTrail('preset "${preset.name}" for $_rootKey');
    setState(
      () => _filterChoices[_rootKey] = ForgeExplorerFilterChoice(
        preset: preset.name,
      ),
    );
    _persistFilters();
    unawaited(_walk());
  }

  Future<void> _editRules() async {
    final edited = await showDialog<ForgeFilter>(
      context: context,
      builder: (ctx) => _RulesDialog(initial: forgeExplorerRulesText(_filter)),
    );
    if (edited == null || !mounted) return;
    forgeExplorerTrail(
      'rules edited for $_rootKey: ${edited.rules.length} rules',
    );
    setState(
      () => _filterChoices[_rootKey] = ForgeExplorerFilterChoice(
        preset: _choice.preset,
        rules: edited,
      ),
    );
    _persistFilters();
    unawaited(_walk());
  }

  void _toggleShowHidden() {
    forgeExplorerTrail('show hidden: ${!_showHidden}');
    setState(() => _showHidden = !_showHidden);
    unawaited(_walk());
  }

  // --- The root switcher ---------------------------------------------------

  Future<void> _selectRoot(Uri uri) async {
    if (forgeExplorerFolderPath(uri) == _rootKey) return;
    forgeExplorerTrail('root: ${forgeExplorerFolderPath(uri)}');
    setState(() {
      _root = uri;
      _rootEntries = [];
      _directoryChildren.clear();
      _expandedDirs.clear();
      _loadingDirectories.clear();
      _selectedUri = null;
      _model = null;
      _errorMessage = null;
      _showHidden = false;
    });
    _persistRoots();
    await _loadEntries();
  }

  Future<void> _addRoot() async {
    final pick = _config.pickFolder;
    final Uri? picked;
    if (pick != null) {
      picked = await pick();
    } else {
      final path = await showDialog<String>(
        context: context,
        builder: (ctx) => const _TextPromptDialog(
          title: 'Add Folder',
          hintText: '/path/to/folder',
          confirmLabel: 'Add',
        ),
      );
      picked = (path == null || path.trim().isEmpty)
          ? null
          : Uri.directory(path.trim());
    }
    if (picked == null || !mounted) return;
    final path = forgeExplorerFolderPath(picked);
    final uri = Uri.directory(path);
    final known = _roots
        .where((r) => forgeExplorerFolderPath(r.uri) == path)
        .firstOrNull;
    if (known != null) {
      await _selectRoot(known.uri);
      return;
    }
    TomFileEntry? entry;
    try {
      entry = await widget.fileSystem.stat(uri);
    } catch (_) {
      entry = null;
    }
    if (!mounted) return;
    if (entry == null || !entry.isDirectory) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text('No folder at $path')));
      return;
    }
    forgeExplorerTrail('root added: $path');
    setState(() => _registeredRoots.add(ForgeExplorerRoot.of(uri)));
    await _selectRoot(uri);
    _persistRoots();
  }

  Future<void> _removeCurrentRoot() async {
    final key = _rootKey;
    forgeExplorerTrail('root removed: $key');
    setState(() {
      _registeredRoots.removeWhere(
        (r) => forgeExplorerFolderPath(r.uri) == key,
      );
      _filterChoices.remove(key);
    });
    _persistFilters();
    await _selectRoot(widget.rootUri);
    _persistRoots();
  }

  // --- Kept through the state store ---------------------------------------

  String get _rootsKey => '${_config.stateKey}.roots';
  String get _filtersKey => '${_config.stateKey}.filters';

  /// Reads the registered roots, the root shown and the filter choices.
  Future<void> _restore() async {
    final store = _config.stateStore;
    if (store == null) return;
    try {
      if (_config.rootSwitcher) {
        final doc = await store.read(_rootsKey);
        if (doc is Map) {
          final roots = doc['roots'];
          if (roots is List) {
            for (final value in roots) {
              final root = ForgeExplorerRoot.decode(value);
              if (root != null) _registeredRoots.add(root);
            }
          }
          final current = Uri.tryParse('${doc['current']}');
          if (current != null) {
            final path = forgeExplorerFolderPath(current);
            final known = _roots
                .where((r) => forgeExplorerFolderPath(r.uri) == path)
                .firstOrNull;
            if (known != null) _root = known.uri;
          }
        }
      }
      if (_filtering) {
        final doc = await store.read(_filtersKey);
        if (doc is Map) {
          for (final entry in doc.entries) {
            final choice = ForgeExplorerFilterChoice.decode(entry.value);
            if (choice != null) _filterChoices['${entry.key}'] = choice;
          }
        }
      }
      forgeExplorerTrail(
        'restored: ${_registeredRoots.length} roots, root $_rootKey, '
        '${_filterChoices.length} filter choices',
      );
    } catch (e) {
      // A document this build cannot read is left as it is.
      forgeExplorerTrail('restore failed: $e');
    }
  }

  void _persistRoots() {
    final store = _config.stateStore;
    if (store == null || !_config.rootSwitcher) return;
    unawaited(
      store.write(_rootsKey, {
        'roots': [for (final r in _registeredRoots) r.encode()],
        'current': _root.toString(),
      }),
    );
  }

  void _persistFilters() {
    final store = _config.stateStore;
    if (store == null || !_filtering) return;
    unawaited(
      store.write(_filtersKey, {
        for (final e in _filterChoices.entries) e.key: e.value.encode(),
      }),
    );
  }

  // --- Building ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_hasHeader) return _buildTree(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        Expanded(child: _buildTree(context)),
        if (_filtering) _buildFooter(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final current = _currentRoot;
    return Padding(
      key: const ValueKey<String>('forge-explorer-header'),
      padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
      child: Row(
        children: [
          if (_config.rootSwitcher)
            Expanded(
              child: PopupMenuButton<Object>(
                key: const ValueKey<String>('forge-explorer-root-menu'),
                tooltip: 'Choose the folder to show',
                onSelected: (value) => unawaited(_onRootMenu(value)),
                itemBuilder: (ctx) => [
                  for (final root in _roots)
                    CheckedPopupMenuItem<Object>(
                      key: ValueKey<String>(
                        'forge-explorer-root:'
                        '${forgeExplorerFolderPath(root.uri)}',
                      ),
                      value: root,
                      checked: forgeExplorerFolderPath(root.uri) == _rootKey,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(root.name),
                        subtitle: Text(
                          forgeExplorerFolderPath(root.uri),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<Object>(
                    key: ValueKey<String>('forge-explorer-add-root'),
                    value: _RootAction.add,
                    child: Text('Add folder…'),
                  ),
                  if (_currentIsRegistered)
                    const PopupMenuItem<Object>(
                      key: ValueKey<String>('forge-explorer-remove-root'),
                      value: _RootAction.remove,
                      child: Text('Remove from list'),
                    ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree_outlined, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          current.name,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          if (_filtering)
            PopupMenuButton<Object>(
              key: const ValueKey<String>('forge-explorer-filter-menu'),
              tooltip: 'Filter: $_filterLabel',
              onSelected: (value) => unawaited(_onFilterMenu(value)),
              itemBuilder: (ctx) => [
                for (final preset in _presets)
                  CheckedPopupMenuItem<Object>(
                    key: ValueKey<String>(
                      'forge-explorer-preset:${preset.name}',
                    ),
                    value: preset,
                    checked:
                        preset.name == _choice.preset && _choice.rules == null,
                    child: Text(preset.name),
                  ),
                if (_presets.isNotEmpty) const PopupMenuDivider(),
                const PopupMenuItem<Object>(
                  key: ValueKey<String>('forge-explorer-edit-rules'),
                  value: _FilterAction.editRules,
                  child: Text('Edit rules…'),
                ),
                CheckedPopupMenuItem<Object>(
                  key: const ValueKey<String>('forge-explorer-show-hidden'),
                  value: _FilterAction.toggleHidden,
                  checked: _showHidden,
                  child: const Text('Show hidden entries'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list,
                      size: 16,
                      color: _choice.rules != null
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onRootMenu(Object value) async {
    switch (value) {
      case ForgeExplorerRoot(:final uri):
        await _selectRoot(uri);
      case _RootAction.add:
        await _addRoot();
      case _RootAction.remove:
        await _removeCurrentRoot();
    }
  }

  Future<void> _onFilterMenu(Object value) async {
    switch (value) {
      case ForgeFilterPreset():
        _selectPreset(value);
      case _FilterAction.editRules:
        await _editRules();
      case _FilterAction.toggleHidden:
        _toggleShowHidden();
    }
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final model = _model;
    final hidden = model?.hiddenTotal ?? 0;
    final truncated = model?.truncated ?? false;
    if (hidden == 0 && !truncated) return const SizedBox.shrink();
    final small = theme.textTheme.labelSmall;
    return Padding(
      key: const ValueKey<String>('forge-explorer-footer'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (hidden > 0)
            TextButton.icon(
              key: const ValueKey<String>('forge-explorer-hidden-count'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: small,
              ),
              onPressed: () => unawaited(_showHiddenList()),
              icon: Icon(
                _showHidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 14,
              ),
              label: Text(
                _showHidden ? '$hidden hidden, shown' : '$hidden hidden',
              ),
            ),
          if (truncated)
            Tooltip(
              message:
                  'The walk of this folder stopped after '
                  '${_config.walkLimit} entries; a folder it did not finish '
                  'is listed when you open it.',
              child: Text(
                'Stopped after ${_config.walkLimit} entries',
                key: const ValueKey<String>('forge-explorer-walk-stopped'),
                style: small?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  /// The hidden entries with the rule that hid each (D36 §4.2).
  Future<void> _showHiddenList() async {
    final model = _model;
    if (model == null) return;
    final walker = _walker();
    final action = await showDialog<_FilterAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey<String>('forge-explorer-hidden-list'),
        title: Text('${model.hiddenTotal} hidden'),
        content: SizedBox(
          width: 360,
          height: 280,
          child: ListView(
            children: [
              for (final h in model.hidden)
                ListTile(
                  dense: true,
                  title: Text(walker.relative(h.path)),
                  subtitle: Text(h.rule),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_FilterAction.editRules),
            child: const Text('Edit rules…'),
          ),
          TextButton(
            key: const ValueKey<String>('forge-explorer-hidden-toggle'),
            onPressed: () => Navigator.of(ctx).pop(_FilterAction.toggleHidden),
            child: Text(_showHidden ? 'Hide them again' : 'Show them'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (action != null && mounted) await _onFilterMenu(action);
  }

  Widget _buildTree(BuildContext context) {
    if (_restoring || (_filtering && _walking && _model == null)) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_rootEntries.isEmpty) {
      final hidden = _model?.hiddenTotal ?? 0;
      if (_filtering && hidden > 0) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'No entries match this filter ($hidden hidden).',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return const Center(child: Text('No files'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 2),
      children: [
        for (final entry in _rootEntries) _buildEntry(context, entry, 0),
      ],
    );
  }

  Widget _buildEntry(BuildContext context, TomFileEntry entry, int depth) {
    final theme = Theme.of(context);
    final isDirectory = _isDirectoryEntry(entry);
    final path = _absolutePath(entry);
    final name = _nameForPath(path);
    final isExpanded = _expandedDirs.contains(path);
    final childEntries = _directoryChildren[path] ?? const <TomFileEntry>[];
    final isLoading = _loadingDirectories.contains(path);
    final entryUri = Uri.file(path);
    final isSelected = _selectedUri == entryUri;
    final isHovered = _hoveredUri == entryUri;

    // File decorations.
    final decoration = widget.fileDecorationManager?.getDecoration(entryUri);
    // Filtering: a hidden entry shown for now, a folder's hidden count.
    final dimmed = _model?.dimmed.contains(path) ?? false;
    final hiddenInside = isDirectory ? (_model?.hiddenIn[path] ?? 0) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) {
            setState(() => _hoveredUri = entryUri);
            widget.selection?.setHoveredExplorerItem(entryUri);
          },
          onExit: (_) {
            if (_hoveredUri == entryUri) {
              setState(() => _hoveredUri = null);
              widget.selection?.setHoveredExplorerItem(null);
            }
          },
          child: InkWell(
            key: ValueKey<String>('forge-explorer-entry:$path'),
            onTap: () async {
              setState(() => _selectedUri = entryUri);
              widget.selection?.setSelectedExplorerItems([entryUri]);
              if (isDirectory) {
                await _toggleDirectory(path, isExpanded);
              }
            },
            // Only files react to a double tap (open). Leaving [onDoubleTap]
            // null for directories lets their single-tap toggle fire
            // immediately, instead of waiting out the double-tap disambiguation
            // delay — matching the instant expand/collapse users expect.
            onDoubleTap: isDirectory ? null : () => widget.openFile(entryUri),
            onSecondaryTapDown: (details) {
              unawaited(
                _showContextMenu(context, details.globalPosition, entry),
              );
            },
            child: Container(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : isHovered
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                  : null,
              padding: EdgeInsets.only(
                left: 8.0 + depth * 16.0,
                top: 2,
                bottom: 2,
              ),
              child: _dimmedIf(
                dimmed,
                Row(
                  children: [
                    if (isDirectory)
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.chevron_right,
                        size: 16,
                      )
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 2),
                    Icon(
                      isDirectory
                          ? (isExpanded
                                ? Icons.folder_open_outlined
                                : Icons.folder_outlined)
                          : _iconForExtension(name),
                      size: 16,
                      color:
                          decoration?.color ??
                          (isDirectory
                              ? Colors.amber
                              : theme.colorScheme.onSurface),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: decoration?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (decoration?.badge != null)
                      Tooltip(
                        message: decoration!.tooltip ?? '',
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (decoration.color ?? theme.colorScheme.primary)
                                    .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            decoration.badge!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: decoration.color,
                            ),
                          ),
                        ),
                      ),
                    if (hiddenInside > 0)
                      Tooltip(
                        message: '$hiddenInside hidden by the filter',
                        child: Padding(
                          key: ValueKey<String>(
                            'forge-explorer-hidden-in:$path',
                          ),
                          padding: const EdgeInsets.only(right: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_outlined,
                                size: 11,
                                color: theme.hintColor,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$hiddenInside',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isDirectory && isLoading)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isDirectory && isExpanded)
          for (final child in childEntries)
            _buildEntry(context, child, depth + 1),
      ],
    );
  }

  /// [child], faded when [dimmed]: a hidden entry shown for now.
  static Widget _dimmedIf(bool dimmed, Widget child) =>
      dimmed ? Opacity(opacity: 0.5, child: child) : child;

  Future<void> _showContextMenu(
    BuildContext context,
    Offset position,
    TomFileEntry entry,
  ) async {
    final isDirectory = _isDirectoryEntry(entry);
    final entryUri = entry.uri;
    final path = _absolutePath(entry);
    // The row as a context target, for the modules' contributions: drawn
    // after the explorer's own entries, each enabled by its predicate.
    final contributed =
        widget.contextMenus?.entriesFor(
          ForgeContextTarget(
            kind: isDirectory
                ? ForgeContextTarget.explorerDirectoryKind
                : ForgeContextTarget.explorerFileKind,
            data: entryUri,
          ),
        ) ??
        const <ForgeContextMenuEntry>[];
    // Open With ▸ for a file with more than one editor.
    final picker = widget.editorPicker;
    ForgeContextMenuEntry? openWith;
    if (!isDirectory && picker != null) {
      final choices = await picker.choicesFor(ForgeContentItem(entryUri));
      openWith = forgeOpenWithMenuEntry(picker, choices);
      if (!context.mounted) return;
    }
    final value = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        if (!isDirectory)
          const PopupMenuItem(value: 'open', child: Text('Open')),
        if (openWith != null) ...forgeContextMenuItems([openWith]),
        const PopupMenuItem(value: 'rename', child: Text('Rename...')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'newFile', child: Text('New File...')),
        const PopupMenuItem(value: 'newFolder', child: Text('New Folder...')),
        if (contributed.isNotEmpty) ...[
          const PopupMenuDivider(),
          ...forgeContextMenuItems(contributed),
        ],
      ],
    );
    if (value == null || !mounted) return;
    if (value is ForgeContextMenuEntry) {
      if (!value.hasChildren) {
        await value.run();
      } else if (context.mounted) {
        await runForgeContextMenuEntry(
          context,
          value,
          globalPosition: position,
        );
      }
      return;
    }
    switch (value) {
      case 'open':
        widget.openFile(entryUri);
      case 'rename':
        _showRenameDialog(entry);
      case 'delete':
        _showDeleteConfirmation(entry);
      case 'newFile':
        _showNewFileDialog(isDirectory ? path : _parentPath(path));
      case 'newFolder':
        _showNewFolderDialog(isDirectory ? path : _parentPath(path));
    }
  }

  Future<void> _showRenameDialog(TomFileEntry entry) async {
    final name = _nameForPath(_absolutePath(entry));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextPromptDialog(
        title: 'Rename',
        hintText: 'New name',
        confirmLabel: 'Rename',
        initialValue: name,
        selectBaseName: true,
      ),
    );

    if (newName == null || newName.isEmpty || newName == name || !mounted) {
      return;
    }

    try {
      final parentDir = _parentPath(_absolutePath(entry));
      final newPath = '$parentDir/$newName';
      await forgeApplyWorkspaceEdit(
        widget.fileSystem,
        ForgeWorkspaceEdit(
          fileOperations: [
            ForgeRenameFileOperation(
              oldUri: entry.uri,
              newUri: Uri.file(newPath),
            ),
          ],
        ),
      );
      await _loadEntries();
      // Reload affected directory children.
      if (_directoryChildren.containsKey(parentDir)) {
        await _loadDirectoryChildren(parentDir);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
      }
    }
  }

  Future<void> _showDeleteConfirmation(TomFileEntry entry) async {
    final name = _nameForPath(_absolutePath(entry));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.fileSystem.delete(entry.uri);
      final parentDir = _parentPath(_absolutePath(entry));
      await _loadEntries();
      if (_directoryChildren.containsKey(parentDir)) {
        await _loadDirectoryChildren(parentDir);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _showNewFileDialog(String parentDir) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _TextPromptDialog(
        title: 'New File',
        hintText: 'filename.dart',
        confirmLabel: 'Create',
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    try {
      final uri = Uri.file('$parentDir/$name');
      await widget.fileSystem.writeText(uri, '');
      if (!_filtering && _directoryChildren.containsKey(parentDir)) {
        await _loadDirectoryChildren(parentDir);
      } else {
        await _loadEntries();
      }
      widget.openFile(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Create file failed: $e')));
      }
    }
  }

  Future<void> _showNewFolderDialog(String parentDir) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _TextPromptDialog(
        title: 'New Folder',
        hintText: 'folder name',
        confirmLabel: 'Create',
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    try {
      await widget.fileSystem.create(
        Uri.file('$parentDir/$name'),
        directory: true,
      );
      if (!_filtering && _directoryChildren.containsKey(parentDir)) {
        await _loadDirectoryChildren(parentDir);
      } else {
        await _loadEntries();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Create folder failed: $e')));
      }
    }
  }

  String _parentPath(String path) {
    final idx = path.lastIndexOf('/');
    return idx > 0 ? path.substring(0, idx) : path;
  }

  /// The entries the explorer shows: hidden ones (a name starting with `.`)
  /// left out, folders first, then by name.
  List<TomFileEntry> _sortEntries(List<TomFileEntry> entries) {
    final sorted = [
      for (final entry in entries)
        if (!entry.name.startsWith('.')) entry,
    ];
    sorted.sort((a, b) {
      final aIsDir = _isDirectoryEntry(a);
      final bIsDir = _isDirectoryEntry(b);
      if (aIsDir != bIsDir) {
        return aIsDir ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  bool _isDirectoryEntry(TomFileEntry entry) => entry.isDirectory;

  String _absolutePath(TomFileEntry entry) => entry.uri.toFilePath();

  String _nameForPath(String path) {
    final parts = path.split('/').where((segment) => segment.isNotEmpty);
    if (parts.isEmpty) {
      return path;
    }
    return parts.last;
  }

  IconData _iconForExtension(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'dart' => Icons.code,
      'yaml' || 'yml' => Icons.settings,
      'md' || 'markdown' => Icons.description,
      'json' => Icons.data_object,
      'txt' => Icons.text_snippet,
      _ => Icons.insert_drive_file_outlined,
    };
  }
}

/// A small text-input dialog used by the explorer's New File / New Folder /
/// Rename actions.
///
/// It owns its [TextEditingController] and disposes it in [State.dispose], so
/// the controller stays alive for the whole route lifetime — including the
/// dismiss transition. Creating the controller in the caller and disposing it
/// as soon as `showDialog` returns is unsafe: the route is still animating out
/// and rebuilds the field against the (now disposed) controller.
///
/// Pops the entered text on confirm/submit, or `null` on cancel.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hintText,
    required this.confirmLabel,
    this.initialValue = '',
    this.selectBaseName = false,
  });

  final String title;
  final String hintText;
  final String confirmLabel;
  final String initialValue;

  /// When true, preselects the name up to (but excluding) its last `.` so a
  /// rename edits the base name while keeping the extension.
  final bool selectBaseName;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.selectBaseName) {
      final name = widget.initialValue;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: name.lastIndexOf('.').clamp(0, name.length),
      );
    }
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      // A `Focus` wrapper submits on Enter even when the field itself does not
      // deliver an `onSubmitted` action (e.g. under a raw hardware key event),
      // matching the input-box overlay's behaviour.
      content: Focus(
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter) {
            _submit();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(hintText: widget.hintText, isDense: true),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// The root switcher's actions besides choosing a root.
enum _RootAction { add, remove }

/// The filter button's actions besides choosing a preset.
enum _FilterAction { editRules, toggleHidden }

/// The rules dialog: the filter's rules as text, one per line
/// ([forgeExplorerParseRules]); Apply pops the [ForgeFilter], refused while a
/// line cannot be read.
class _RulesDialog extends StatefulWidget {
  const _RulesDialog({required this.initial});

  final String initial;

  @override
  State<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<_RulesDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );
  late var _parsed = forgeExplorerParseRules(widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Filter rules'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'One rule per line; the last matching rule decides, an entry '
              'no rule matches is shown. include: <glob> · exclude: <glob> · '
              'include extensions: md, yaml · hidden: show|hide · '
              'gitignored: show|hide · todo siblings: show|hide',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('forge-explorer-rules-field'),
              controller: _controller,
              autofocus: true,
              minLines: 6,
              maxLines: 12,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (text) =>
                  setState(() => _parsed = forgeExplorerParseRules(text)),
            ),
            for (final problem in _parsed.problems)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  problem,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
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
        TextButton(
          key: const ValueKey<String>('forge-explorer-rules-apply'),
          onPressed: _parsed.filter == null
              ? null
              : () => Navigator.of(context).pop(_parsed.filter),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
