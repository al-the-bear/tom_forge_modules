/// Manages workspace-scoped persistent state under the `.forge/` directory.
///
/// Responsibilities:
/// - Initialize and ensure `.forge/` directory structure
/// - Persist and restore layout state (`state/layout.json`)
/// - Persist and restore open editor list (`state/open-editors.json`)
/// - Persist and restore per-editor state (`state/editors/{uri-hash}.json`)
/// - Create revision snapshots on save (`revisions/{uri-hash}/`)
/// - Persist undo history per file (`undo/{uri-hash}.json`)
/// - Suggest `.forge` for `.gitignore`
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

  // ── Layout state ──

  /// Save the current layout state (panel sizes, visibility).
  Future<void> saveLayoutState(Map<String, dynamic> layoutData);

  /// Load persisted layout state. Returns `null` if none saved.
  Future<Map<String, dynamic>?> loadLayoutState();

  // ── Open editors ──

  /// Save the list of currently open editor URIs.
  Future<void> saveOpenEditors(List<String> editorUris);

  /// Load the list of previously open editor URIs.
  Future<List<String>> loadOpenEditors();

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

  // ── Configuration ──

  /// Save configuration data to `.forge/config.json`.
  Future<void> saveConfig(Map<String, dynamic> configData);

  /// Load configuration data from `.forge/config.json`.
  Future<Map<String, dynamic>?> loadConfig();

  // ── Gitignore ──

  /// Check whether `.forge` is listed in the workspace `.gitignore`.
  Future<bool> isForgeInGitignore(String workspaceRootPath);

  /// Suggest adding `.forge` to `.gitignore`. Returns `true` if added.
  Future<bool> suggestGitignore(String workspaceRootPath);

  /// Dispose resources.
  void dispose();
}
