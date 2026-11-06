/// Manages workspace-scoped persistent state under the `.forge/` directory.
///
/// Responsibilities:
/// - Initialize and ensure `.forge/` directory structure
/// - Persist and restore the open applications (`state/applications.json`)
///   and each panel application's layout (`state/apps/{id-hash}.json`)
/// - Persist and restore per-editor state (`state/editors/{uri-hash}.json`)
/// - Create revision snapshots on save (`revisions/{uri-hash}/`)
/// - Persist undo history per file (`undo/{uri-hash}.json`)
/// - Keep `.forge/` out of git ([keepForgeStateOutOfGit])
abstract class ForgeWorkspaceStateManager {
  /// Whether the `.forge/` directory has been initialized for the current
  /// workspace.
  bool get isInitialized;

  /// The resolved `.forge/` directory path for the current workspace.
  String get forgeDirectoryPath;

  /// Initialize the `.forge/` directory structure.
  ///
  /// Creates the directory and standard sub-folders if they don't exist.
  /// Returns `true` if the directory was created freshly.
  Future<bool> initialize(String workspaceRootPath);

  /// Check if a `.forge/` directory exists at [path] or any parent.
  ///
  /// Returns the workspace root path if found, or `null`.
  Future<String?> detectWorkspaceRoot(String startPath);

  // ── Per-editor state ──

  /// Save state for a specific editor (cursor position, scroll, etc.).
  Future<void> saveEditorState(Uri editorUri, Map<String, dynamic> state);

  /// Load state for a specific editor.
  Future<Map<String, dynamic>?> loadEditorState(Uri editorUri);

  // ── Revisions ──

  /// Create a revision snapshot of a file's content before saving.
  ///
  /// De-duplicates identical consecutive saves. Returns the revision ID
  /// or `null` if the content matches the last revision.
  Future<String?> createRevision(Uri fileUri, String content);

  /// List all revision IDs for a file, newest first.
  Future<List<String>> listRevisions(Uri fileUri);

  /// Read a specific revision's content.
  Future<String?> readRevision(Uri fileUri, String revisionId);

  /// Delete a single revision.
  Future<void> deleteRevision(Uri fileUri, String revisionId);

  /// Prune old revisions, keeping at most [maxRevisions] per file.
  Future<int> pruneRevisions(Uri fileUri, {int maxRevisions = 50});

  // ── Undo persistence ──

  /// Save serializable undo entries for a file.
  Future<void> saveUndoHistory(
      Uri fileUri, List<Map<String, dynamic>> entries);

  /// Load undo entries for a file.
  Future<List<Map<String, dynamic>>> loadUndoHistory(Uri fileUri);

  // ── Applications ──

  /// Save the open restorable applications and the active one
  /// ([ForgeApplicationRegistry.snapshot]) to `.forge/state/applications.json`.
  Future<void> saveOpenApplications(Map<String, Object?> snapshot);

  /// Load what [saveOpenApplications] wrote, or null when nothing was.
  Future<Map<String, Object?>?> loadOpenApplications();

  /// Save the state of the application [appId] — `{'layout': ...}`, its panel
  /// layout as the shell captures it — to `.forge/state/apps/{hash}.json`.
  Future<void> saveApplicationState(String appId, Map<String, dynamic> state);

  /// Load what [saveApplicationState] wrote for [appId], or null.
  Future<Map<String, dynamic>?> loadApplicationState(String appId);

  /// Delete the saved state of [appId], when the application is removed for
  /// good.
  Future<void> deleteApplicationState(String appId);

  // ── Configuration ──

  /// Save configuration data to `.forge/config.json`.
  Future<void> saveConfig(Map<String, dynamic> configData);

  /// Load configuration data from `.forge/config.json`.
  Future<Map<String, dynamic>?> loadConfig();

  // ── Keeping the state out of git ──

  /// Keeps the workspace's `.forge/` out of git without editing a file the
  /// workspace tracks: when [workspaceRootPath] lies in a git work tree whose
  /// rules do not ignore `.forge/` yet — git itself answers, so every
  /// `.gitignore` up to the repository root, `.git/info/exclude` and the
  /// global excludes count — `.forge/` is added to that clone's
  /// `.git/info/exclude` (the state is per machine). Answers what it found
  /// or did.
  Future<ForgeStateIgnore> keepForgeStateOutOfGit(String workspaceRootPath);

  /// Dispose resources.
  void dispose();
}

/// What [ForgeWorkspaceStateManager.keepForgeStateOutOfGit] found or did.
enum ForgeStateIgnore {
  /// The workspace is not in a git work tree (or git is not installed):
  /// nothing to keep out.
  notInGit,

  /// git already ignores `.forge/`: nothing written.
  alreadyIgnored,

  /// `.forge/` was added to the clone's `.git/info/exclude`.
  addedToLocalExclude,
}
