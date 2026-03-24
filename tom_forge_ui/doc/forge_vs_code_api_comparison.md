# Tom Forge vs VS Code — API Comparison

**Project:** tom_forge_ui  
**Date:** 2026-03-24  
**Purpose:** Comprehensive mapping between the VS Code Extension API and the Tom Forge Shell API. Used to identify coverage gaps and Forge-specific additions.

---

## Part 1 — VS Code Extension API → Tom Forge

This section lists **every major VS Code API namespace and capability** and shows the Forge equivalent (or notes the gap). The goal is to ensure nothing important is missed.

### Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Covered in Forge concept |
| 🔶 | Partially covered or different approach |
| ❌ | Not covered — gap to evaluate |
| ➖ | Not applicable to Forge's architecture |

---

### 1. Extension Activation and Lifecycle

**What VS Code exposes to extensions:**

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `activate(context: ExtensionContext)` | Called when extension activates; receives context with subscriptions, storage, secrets | `ForgeExtension.activate(ForgeShellApi shell)` — shell reference provides full API access | ✅ |
| `deactivate()` | Called on extension shutdown | `ForgeExtension.deactivate()` | ✅ |
| `ExtensionContext.subscriptions` | Disposable list — auto-disposed on deactivate | No equivalent — extensions manage own cleanup in `deactivate()` | 🔶 |
| `ExtensionContext.extensionPath` | Filesystem path to the extension | Not applicable — extensions are compiled into the app | ➖ |
| `ExtensionContext.extensionUri` | URI of extension directory | Not applicable | ➖ |
| `ExtensionContext.globalState` | Persistent key-value store (across workspaces) | `ForgeConfigManager` — config persisted in `.forge/` | 🔶 |
| `ExtensionContext.workspaceState` | Per-workspace key-value store | `ForgeConfigManager` — config persisted in workspace `.forge/` | 🔶 |
| `ExtensionContext.secrets` | Secure storage for tokens/passwords | ❌ No secret storage API | ❌ |
| `ExtensionContext.storageUri` | Extension-specific storage directory | No per-extension storage directory | ❌ |
| `ExtensionContext.globalStorageUri` | Global extension storage | No equivalent | ❌ |
| `ExtensionContext.logUri` | Extension log file location | Extensions use `ForgeOutputChannelManager` for logging | 🔶 |
| `ExtensionContext.extensionMode` | Development / Production / Test | No equivalent | ❌ |
| `extensions.getExtension(id)` | Get another extension by ID | `ForgeExtensionRegistry.get<T>()` — cross-references | ✅ |
| `extensions.all` | List of all installed extensions | `ForgeExtensionRegistry` — iterable | ✅ |
| `extensions.onDidChange` | Extension install/uninstall events | Not applicable — extensions are compile-time | ➖ |

**What VS Code extensions expose back to VS Code:**

| VS Code Mechanism | Description | Forge Equivalent | Status |
|-------------------|-------------|-------------------|--------|
| `package.json: activationEvents` | Declares when extension activates (onLanguage, onCommand, workspaceContains, etc.) | Extensions always activate at startup, in dependency order | 🔶 |
| `package.json: contributes.commands` | Declares commands the extension provides | `ForgeExtension.actions` — list of `ForgeAction` | ✅ |
| `package.json: contributes.menus` | Declares menu contributions (editor/title, context, etc.) | Actions declare `ForgeMenuLocation`; context menus via `ForgeContextMenuContribution` | ✅ |
| `package.json: contributes.keybindings` | Declares keyboard shortcuts | `ForgeExtension.shortcuts` — list of `ForgeShortcutBinding` | ✅ |
| `package.json: contributes.languages` | Declares language support (ID, aliases, extensions, config) | `ForgeFileAssociationRegistry` — pattern → editor mapping | 🔶 |
| `package.json: contributes.grammars` | TextMate grammars for syntax highlighting | ❌ No grammar/syntax highlighting system | ❌ |
| `package.json: contributes.themes` | Color themes | `ForgeConfig.theme` — but no theme contribution from extensions | 🔶 |
| `package.json: contributes.iconThemes` | File icon themes | ❌ No icon theme system | ❌ |
| `package.json: contributes.productIconThemes` | Product icon overrides | ❌ | ❌ |
| `package.json: contributes.snippets` | Code snippets | ❌ No snippet system | ❌ |
| `package.json: contributes.jsonValidation` | JSON schema associations | ❌ No built-in JSON schema integration | ❌ |
| `package.json: contributes.views` | Declares views for side bar containers | Components declared via `ForgeExtension.components` | ✅ |
| `package.json: contributes.viewsContainers` | Custom sidebar containers | Custom tabs in left/right panels via `PanelTabConfig` | ✅ |
| `package.json: contributes.viewsWelcome` | Welcome content for empty views | ❌ No welcome content system | ❌ |
| `package.json: contributes.configuration` | Extension settings (shown in Settings UI) | Extension configuration views in Configuration tab | ✅ |
| `package.json: contributes.configurationDefaults` | Default settings values | `ForgeConfig` code-configured defaults | ✅ |
| `package.json: contributes.taskDefinitions` | Task types for the task system | ❌ No task system | ❌ |
| `package.json: contributes.problemMatchers` | Regex matchers for build output | ❌ No problem matcher system | ❌ |
| `package.json: contributes.problemPatterns` | Reusable problem patterns | ❌ | ❌ |
| `package.json: contributes.debuggers` | Debug adapter contributions | ❌ No debug adapter protocol | ❌ |
| `package.json: contributes.breakpoints` | Breakpoint types | ❌ | ❌ |
| `package.json: contributes.terminal.profiles` | Terminal profile contributions | ❌ No terminal profile system | ❌ |
| `package.json: contributes.walkthroughs` | Getting Started walkthroughs | ❌ No walkthrough system | ❌ |
| `package.json: contributes.customEditors` | Custom editor types for specific file types | `ForgeComponentRegistry.registerEditor()` + `ForgeFileAssociationRegistry` | ✅ |
| `package.json: contributes.notebooks` | Notebook types | ❌ No notebook system | ❌ |
| `package.json: contributes.notebookRenderer` | Custom notebook cell renderers | ❌ | ❌ |
| Extension API export | Extensions export an API object for other extensions | `ForgeExtensionRegistry.get<T>()` — direct Dart type access (stronger than VS Code) | ✅ |

---

### 2. Window and Layout (`vscode.window`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `window.activeTextEditor` | Currently active text editor | `ForgeSystemState.focusedComponent` + `activeEditorUri` | ✅ |
| `window.visibleTextEditors` | All visible text editors | `ForgeSystemState.openEditorUris` (open, not just visible) | 🔶 |
| `window.onDidChangeActiveTextEditor` | Active editor changed | `ForgeSystemState.onFocusChanged` | ✅ |
| `window.onDidChangeVisibleTextEditors` | Visible editors changed | `ForgeSystemState.onEditorsChanged` | ✅ |
| `window.onDidChangeTextEditorSelection` | Selection changed in editor | `ForgeSystemState.onSelectionChanged` | ✅ |
| `window.onDidChangeTextEditorVisibleRanges` | Visible range changed (scroll) | ❌ No scroll/visible-range tracking in system state | ❌ |
| `window.onDidChangeTextEditorOptions` | Editor options changed (tab size, insert spaces) | ❌ No per-editor options change event | ❌ |
| `window.onDidChangeTextEditorViewColumn` | Editor moved to different column | Tracked via layout changes, but no specific event | 🔶 |
| `window.showTextDocument(uri, options)` | Open a document in an editor | `ForgeLayoutController` — open/focus components | ✅ |
| `window.showNotebookDocument` | Open a notebook | Not applicable | ➖ |
| `window.createTextEditorDecorationType` | Decorations (highlights, gutters, rulers) | ❌ No decoration API | ❌ |
| `window.showInformationMessage` | Info notification with optional actions | ❌ No notification/message API | ❌ |
| `window.showWarningMessage` | Warning notification | ❌ | ❌ |
| `window.showErrorMessage` | Error notification | ❌ | ❌ |
| `window.showQuickPick` | Quick pick dropdown | Command palette (search bar) — but no programmatic quick pick API | 🔶 |
| `window.showInputBox` | Text input dialog | ❌ No programmatic input box | ❌ |
| `window.showOpenDialog` | File open dialog | ❌ No programmatic file dialog | ❌ |
| `window.showSaveDialog` | File save dialog | ❌ | ❌ |
| `window.showWorkspaceFolderPick` | Workspace folder picker | Not applicable (single workspace) | ➖ |
| `window.createOutputChannel` | Create output channel | `ForgeOutputChannelManager` | ✅ |
| `window.createWebviewPanel` | Create a webview panel | Not applicable — use native Flutter widgets | ➖ |
| `window.registerWebviewPanelSerializer` | Webview state restoration | Not applicable | ➖ |
| `window.createTreeView` | Create tree view in sidebar | Extensions create view components directly as Flutter widgets | 🔶 |
| `window.registerTreeDataProvider` | Register tree data for a view | Extensions build tree widgets directly | 🔶 |
| `window.registerFileDecorationProvider` | File decorations in explorer (badges, colors) | ❌ No file decoration API | ❌ |
| `window.registerUriHandler` | Handle custom URI schemes | ❌ No URI handler system | ❌ |
| `window.registerCustomEditorProvider` | Register custom editor | `ForgeComponentRegistry.registerEditor()` | ✅ |
| `window.registerTerminalProfileProvider` | Terminal profile provider | ❌ | ❌ |
| `window.registerTerminalLinkProvider` | Clickable links in terminal output | ❌ | ❌ |
| `window.createTerminal` | Create a terminal instance | ❌ No programmatic terminal creation API | ❌ |
| `window.activeTerminal` | Currently active terminal | ❌ No terminal state in system state | ❌ |
| `window.terminals` | All open terminals | ❌ | ❌ |
| `window.onDidOpenTerminal` | Terminal opened event | ❌ | ❌ |
| `window.onDidCloseTerminal` | Terminal closed event | ❌ | ❌ |
| `window.onDidChangeActiveTerminal` | Active terminal changed | ❌ | ❌ |
| `window.onDidChangeTerminalState` | Terminal state changed | ❌ | ❌ |
| `window.state.focused` | Whether VS Code window has focus | ❌ No window-level focus tracking | ❌ |
| `window.onDidChangeWindowState` | Window focus changed | ❌ | ❌ |
| `window.tabGroups` | Tab groups (editor columns) | Middle panels (1–4) | ✅ |
| `window.tabGroups.onDidChangeTabGroups` | Tab group layout changed | Layout change events in `ForgeShellController` | 🔶 |
| `window.tabGroups.onDidChangeTabs` | Tabs changed | Editor change events | 🔶 |
| `window.registerColorTheme` | Register color theme | ❌ No theme contribution API | ❌ |

---

### 3. Commands (`vscode.commands`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `commands.registerCommand(id, handler)` | Register a command | `ForgeActionRegistry` — register `ForgeAction` | ✅ |
| `commands.registerTextEditorCommand` | Command with guaranteed text editor | Action + `isEnabled` check via system state | ✅ |
| `commands.executeCommand(id, ...args)` | Execute a command by ID | `ForgeActionRegistry.execute(id)` | ✅ |
| `commands.getCommands(filter?)` | List all registered commands | `ForgeActionRegistry` — iterable | ✅ |

---

### 4. Workspace (`vscode.workspace`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `workspace.workspaceFolders` | Open workspace folders | `ForgeSystemState.workspaceRoot` (single root) | 🔶 |
| `workspace.name` | Workspace name | `ForgeApplication.title` | ✅ |
| `workspace.workspaceFile` | Multi-root workspace file URI | Not applicable — single workspace | ➖ |
| `workspace.onDidChangeWorkspaceFolders` | Workspace folders changed | Not applicable — single workspace, static | ➖ |
| `workspace.getWorkspaceFolder(uri)` | Get workspace folder for a URI | Not applicable | ➖ |
| `workspace.asRelativePath(uri)` | Convert to workspace-relative path | ❌ No path utility API | ❌ |
| `workspace.findFiles(include, exclude)` | Glob-based file search | ❌ No programmatic file search API | ❌ |
| `workspace.openTextDocument(uri)` | Open a text document (model, not UI) | `ForgeFileSystem.read(uri)` | 🔶 |
| `workspace.registerTextDocumentContentProvider` | Virtual document content | ❌ No virtual document provider | ❌ |
| `workspace.onDidOpenTextDocument` | Document opened | `ForgeSystemState.onEditorsChanged` | 🔶 |
| `workspace.onDidCloseTextDocument` | Document closed | `ForgeSystemState.onEditorsChanged` | 🔶 |
| `workspace.onDidChangeTextDocument` | Document content changed | ❌ No document change event stream | ❌ |
| `workspace.onDidSaveTextDocument` | Document saved | ❌ No document save event | ❌ |
| `workspace.onWillSaveTextDocument` | Before document save (allows edits) | ❌ No pre-save hook | ❌ |
| `workspace.onDidCreateFiles` | Files created in workspace | ❌ No file system event watching | ❌ |
| `workspace.onDidDeleteFiles` | Files deleted | ❌ | ❌ |
| `workspace.onDidRenameFiles` | Files renamed | ❌ | ❌ |
| `workspace.onWillCreateFiles` | Before file creation | ❌ | ❌ |
| `workspace.onWillDeleteFiles` | Before file deletion | ❌ | ❌ |
| `workspace.onWillRenameFiles` | Before file rename | ❌ | ❌ |
| `workspace.applyEdit(workspaceEdit)` | Apply multi-file edit atomically | ❌ No workspace edit API | ❌ |
| `workspace.createFileSystemWatcher` | Watch file changes | ❌ No file watcher API | ❌ |
| `workspace.getConfiguration(section)` | Read configuration values | `ForgeConfigManager` | ✅ |
| `workspace.onDidChangeConfiguration` | Configuration changed | ❌ No configuration change event | ❌ |
| `workspace.registerTaskProvider` | Register task provider | ❌ No task system | ❌ |
| `workspace.registerFileSystemProvider` | Virtual file system | ❌ No virtual FS provider | ❌ |
| `workspace.fs` | File system access (read, write, stat, delete) | `ForgeFileSystem` (read, write, save — routed through revisioning) | 🔶 |
| `workspace.isTrusted` | Workspace trust state | ❌ No workspace trust model | ❌ |
| `workspace.onDidGrantWorkspaceTrust` | Trust granted | ❌ | ❌ |
| `workspace.notebookDocuments` | Open notebook documents | Not applicable | ➖ |
| `workspace.onDidOpenNotebookDocument` | Notebook opened | Not applicable | ➖ |
| `workspace.onDidCloseNotebookDocument` | Notebook closed | Not applicable | ➖ |

---

### 5. Languages (`vscode.languages`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `languages.registerCompletionItemProvider` | Autocomplete | ❌ No language service API | ❌ |
| `languages.registerHoverProvider` | Tooltip on hover | ❌ | ❌ |
| `languages.registerSignatureHelpProvider` | Function signature help | ❌ | ❌ |
| `languages.registerDefinitionProvider` | Go-to-definition | ❌ | ❌ |
| `languages.registerTypeDefinitionProvider` | Go-to-type-definition | ❌ | ❌ |
| `languages.registerImplementationProvider` | Go-to-implementation | ❌ | ❌ |
| `languages.registerReferenceProvider` | Find all references | ❌ | ❌ |
| `languages.registerDocumentHighlightProvider` | Highlight occurrences | ❌ | ❌ |
| `languages.registerDocumentSymbolProvider` | Document outline symbols | ❌ (Outline view exists but symbol provider is internal) | 🔶 |
| `languages.registerWorkspaceSymbolProvider` | Workspace-wide symbol search | ❌ | ❌ |
| `languages.registerCodeActionsProvider` | Quick fixes, refactorings | ❌ | ❌ |
| `languages.registerCodeLensProvider` | Inline code actions above code | ❌ | ❌ |
| `languages.registerDocumentLinkProvider` | Clickable links in documents | ❌ | ❌ |
| `languages.registerColorProvider` | Color picker in documents | ❌ | ❌ |
| `languages.registerFoldingRangeProvider` | Code folding | ❌ | ❌ |
| `languages.registerSelectionRangeProvider` | Smart selection expansion | ❌ | ❌ |
| `languages.registerDocumentFormattingEditProvider` | Format document | ❌ | ❌ |
| `languages.registerDocumentRangeFormattingEditProvider` | Format selection | ❌ | ❌ |
| `languages.registerOnTypeFormattingEditProvider` | Format on type | ❌ | ❌ |
| `languages.registerRenameProvider` | Rename symbol | ❌ | ❌ |
| `languages.registerDocumentSemanticTokensProvider` | Semantic syntax highlighting | ❌ | ❌ |
| `languages.registerDocumentRangeSemanticTokensProvider` | Range-based semantic tokens | ❌ | ❌ |
| `languages.registerInlayHintsProvider` | Inline type hints, parameter names | ❌ | ❌ |
| `languages.registerCallHierarchyProvider` | Call hierarchy (incoming/outgoing) | ❌ | ❌ |
| `languages.registerTypeHierarchyProvider` | Type hierarchy | ❌ | ❌ |
| `languages.registerLinkedEditingRangeProvider` | Linked editing (rename HTML tags) | ❌ | ❌ |
| `languages.registerEvaluatableExpressionProvider` | Debug expression evaluation | ❌ | ❌ |
| `languages.registerInlineValuesProvider` | Inline values during debug | ❌ | ❌ |
| `languages.getDiagnostics(uri)` | Get diagnostics for a file | `ForgeDiagnosticManager` — diagnostics by URI | ✅ |
| `languages.createDiagnosticCollection` | Register diagnostic source | `ForgeDiagnosticManager` | ✅ |
| `languages.onDidChangeDiagnostics` | Diagnostics changed | `ForgeSystemState.onDiagnosticsChanged` | ✅ |
| `languages.getLanguages()` | List of known language IDs | ❌ No language ID registry | ❌ |
| `languages.setLanguageConfiguration` | Bracket, comment, indentation rules | ❌ | ❌ |
| `languages.setTextDocumentLanguage` | Change a file's language | ❌ | ❌ |
| `languages.match(selector, document)` | Match document against selector | File association matching via `ForgeFileAssociationRegistry` | 🔶 |
| `languages.registerDocumentDropEditProvider` | Handle file/data drop into editor | ❌ No in-editor drop API | ❌ |

**Note:** The entire `vscode.languages` namespace is VS Code's language server protocol integration layer. Tom Forge is not a code editor IDE — it's a visual tooling shell. Language services would be provided by individual editor extensions (e.g., a D4rt editor extension that includes completion, hover, etc.) rather than as shell-level APIs. The shell could optionally provide a `ForgeLanguageServiceRegistry` for extensions that want consistent language feature integration.

---

### 6. Debug (`vscode.debug`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `debug.activeDebugSession` | Active debug session | ❌ No debug system | ❌ |
| `debug.activeDebugConsole` | Active debug console | ❌ | ❌ |
| `debug.breakpoints` | All breakpoints | ❌ | ❌ |
| `debug.onDidChangeActiveDebugSession` | Debug session changed | ❌ | ❌ |
| `debug.onDidStartDebugSession` | Debug started | ❌ | ❌ |
| `debug.onDidTerminateDebugSession` | Debug ended | ❌ | ❌ |
| `debug.onDidReceiveDebugSessionCustomEvent` | Custom debug event | ❌ | ❌ |
| `debug.onDidChangeBreakpoints` | Breakpoints changed | ❌ | ❌ |
| `debug.registerDebugConfigurationProvider` | Debug launch config | ❌ | ❌ |
| `debug.registerDebugAdapterDescriptorFactory` | Custom debug adapter | ❌ | ❌ |
| `debug.registerDebugAdapterTrackerFactory` | Debug adapter logging | ❌ | ❌ |
| `debug.startDebugging` | Start debug session | ❌ | ❌ |
| `debug.stopDebugging` | Stop debug session | ❌ | ❌ |
| `debug.addBreakpoints` | Add breakpoints programmatically | ❌ | ❌ |
| `debug.removeBreakpoints` | Remove breakpoints | ❌ | ❌ |
| `debug.asDebugSourceUri` | Convert debug source to URI | ❌ | ❌ |

**Note:** Debug support is listed as a future addition (§14.2 — Debug Console view). A full debug API would be needed when D4rt integration lands. This can be modeled as a `ForgeDebugManager` on the shell API.

---

### 7. Source Control (`vscode.scm`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `scm.createSourceControl` | Register SCM provider | ❌ No SCM API | ❌ |
| `scm.inputBox` | SCM input box (commit message) | ❌ | ❌ |
| `SourceControl.rootUri` | SCM root | ❌ | ❌ |
| `SourceControl.inputBox` | Input for commit messages | ❌ | ❌ |
| `SourceControl.createResourceGroup` | File groups (staged, modified) | ❌ | ❌ |
| `SourceControl.quickDiffProvider` | Inline diff | ❌ | ❌ |

**Note:** SCM is listed as a future view (§14.2). If added, a `ForgeScmManager` could wrap git operations.

---

### 8. Tasks (`vscode.tasks`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `tasks.registerTaskProvider` | Provide tasks (build, test, etc.) | ❌ No task system | ❌ |
| `tasks.fetchTasks` | Get all available tasks | ❌ | ❌ |
| `tasks.executeTask` | Run a task | ❌ | ❌ |
| `tasks.taskExecutions` | Currently running tasks | ❌ | ❌ |
| `tasks.onDidStartTask` | Task started | ❌ | ❌ |
| `tasks.onDidStartTaskProcess` | Task process started | ❌ | ❌ |
| `tasks.onDidEndTask` | Task ended | ❌ | ❌ |
| `tasks.onDidEndTaskProcess` | Task process ended | ❌ | ❌ |

**Note:** Tom Forge could introduce a simple task/process runner API without the full complexity of VS Code's task system.

---

### 9. Tests (`vscode.tests`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `tests.createTestController` | Register test provider | ❌ No test API | ❌ |
| `TestController.createRunProfile` | Run/debug/coverage profiles | ❌ | ❌ |
| `TestController.createTestRun` | Start a test run | ❌ | ❌ |
| `TestController.items` | Test item tree | ❌ | ❌ |
| `TestRunProfile.runHandler` | Handler for running tests | ❌ | ❌ |

---

### 10. Comments (`vscode.comments`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `comments.createCommentController` | Inline comment threads | ❌ No comment/annotation API | ❌ |
| `CommentController.commentingRangeProvider` | Where comments can be placed | ❌ | ❌ |

---

### 11. Authentication (`vscode.authentication`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `authentication.getSession` | Get auth session (GitHub, MS) | ❌ No authentication API | ❌ |
| `authentication.onDidChangeSessions` | Auth session changed | ❌ | ❌ |
| `authentication.registerAuthenticationProvider` | Custom auth provider | ❌ | ❌ |

---

### 12. Environment and Context (`vscode.env`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `env.appName` | Application name ("Visual Studio Code") | Shell configuration | ✅ |
| `env.appRoot` | Installation directory | Not applicable | ➖ |
| `env.appHost` | App host (desktop, web, codespaces) | Not applicable (desktop only initially) | ➖ |
| `env.uriScheme` | Custom URI scheme ("vscode") | ❌ No custom URI scheme | ❌ |
| `env.language` | UI language | ❌ No i18n API | ❌ |
| `env.clipboard.readText` | Read clipboard | ❌ No clipboard API | ❌ |
| `env.clipboard.writeText` | Write clipboard | ❌ | ❌ |
| `env.machineId` | Unique machine ID | ❌ | ❌ |
| `env.sessionId` | Current session ID | ❌ | ❌ |
| `env.remoteName` | Remote name (SSH, WSL) | Not applicable | ➖ |
| `env.shell` | Default shell path | ❌ No shell path API | ❌ |
| `env.isTelemetryEnabled` | Telemetry consent | ❌ | ❌ |
| `env.onDidChangeTelemetryEnabled` | Telemetry consent changed | ❌ | ❌ |
| `env.createTelemetryLogger` | Create telemetry sender | ❌ No telemetry API | ❌ |
| `env.openExternal(uri)` | Open URI in default browser/app | ❌ No external opener API | ❌ |
| `env.asExternalUri(uri)` | Convert to externally reachable URI | ❌ | ❌ |
| `env.logLevel` | Current log level | ❌ No log level API | ❌ |
| `env.onDidChangeLogLevel` | Log level changed | ❌ | ❌ |

---

### 13. Text Documents and Editors (Data Model)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `TextDocument.uri` | Document URI | `ForgeComponent.uri` | ✅ |
| `TextDocument.fileName` | File path | Derivable from URI | ✅ |
| `TextDocument.languageId` | Language identifier | ❌ No language ID concept | ❌ |
| `TextDocument.version` | Document version counter | ❌ No document version tracking | ❌ |
| `TextDocument.isDirty` | Has unsaved changes | `ForgeSystemState.dirtyEditorUris` | ✅ |
| `TextDocument.isUntitled` | Untitled (never saved) | ❌ No untitled document tracking | ❌ |
| `TextDocument.isClosed` | Document closed | Derivable from `openEditorUris` | ✅ |
| `TextDocument.save()` | Save the document | `ForgeFileSystem.save(uri)` | ✅ |
| `TextDocument.eol` | End-of-line character | ❌ Not exposed | ❌ |
| `TextDocument.lineCount` | Number of lines | ❌ Not exposed at shell level | ❌ |
| `TextDocument.lineAt(line)` | Get line text | ❌ | ❌ |
| `TextDocument.getText(range?)` | Get text content | `ForgeFileSystem.read(uri)` | 🔶 |
| `TextDocument.getWordRangeAtPosition` | Word at position | ❌ | ❌ |
| `TextDocument.offsetAt(position)` | Position to offset | ❌ | ❌ |
| `TextDocument.positionAt(offset)` | Offset to position | ❌ | ❌ |
| `TextDocument.validateRange` | Clamp range to document | ❌ | ❌ |
| `TextDocument.validatePosition` | Clamp position to document | ❌ | ❌ |
| `TextEditor.document` | The editor's document | Component data state (editor-internal) | 🔶 |
| `TextEditor.selection` | Current selection | UI state per copy (editor-internal) | 🔶 |
| `TextEditor.selections` | Multiple selections | ❌ No multi-cursor at shell level | ❌ |
| `TextEditor.visibleRanges` | Visible text ranges | UI state per copy (editor-internal) | 🔶 |
| `TextEditor.options` | Tab size, insert spaces, etc. | ❌ No per-editor options API | ❌ |
| `TextEditor.viewColumn` | Which editor column | Panel location via layout | ✅ |
| `TextEditor.edit(callback)` | Apply edits to document | ❌ No programmatic edit API at shell level | ❌ |
| `TextEditor.insertSnippet` | Insert snippet at cursor | ❌ | ❌ |
| `TextEditor.setDecorations` | Apply decorations | ❌ | ❌ |
| `TextEditor.revealRange` | Scroll to make range visible | ❌ No programmatic scroll API | ❌ |
| `TextEditorEdit.insert` | Insert text at position | ❌ (editor-internal) | ❌ |
| `TextEditorEdit.delete` | Delete range | ❌ | ❌ |
| `TextEditorEdit.replace` | Replace range with text | ❌ | ❌ |

**Note:** Tom Forge intentionally does not expose text-level APIs at the shell level. Each editor extension manages its own document model internally. The shell tracks document-level metadata (URI, dirty state, open/close) but not text content or positions. This is a deliberate architectural difference — the shell is a layout/coordination framework, not a text editing framework.

---

### 14. Progress and Notifications

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `window.withProgress(options, task)` | Progress indicator (notification, status bar, or editor) | ❌ No progress API | ❌ |
| `Progress.report({ increment, message })` | Update progress | ❌ | ❌ |
| `CancellationToken` | Cancellation support | ❌ No cancellation token pattern | ❌ |
| `window.showInformationMessage` | Info toast/dialog | ❌ No notification API | ❌ |
| `window.showWarningMessage` | Warning toast/dialog | ❌ | ❌ |
| `window.showErrorMessage` | Error toast/dialog | ❌ | ❌ |

---

### 15. Theming

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `window.activeColorTheme` | Current color theme | `ForgeConfig.theme` | 🔶 |
| `window.onDidChangeActiveColorTheme` | Theme changed | ❌ No theme change event | ❌ |
| `ColorTheme.kind` | Light / Dark / HighContrast | Derivable from Flutter theme | 🔶 |
| `ThemeColor` | Reference theme colors by name | Flutter `ThemeData` colors | 🔶 |
| `ThemeIcon` | Reference theme icons by name | Flutter `IconData` | 🔶 |

---

### 16. Chat and Language Models (VS Code 1.90+)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `lm.selectChatModels` | Access language models | ❌ No LM/AI API | ❌ |
| `chat.createChatParticipant` | Register chat participant | ❌ | ❌ |
| `ChatParticipant.requestHandler` | Handle chat requests | ❌ | ❌ |
| `LanguageModelChat.sendRequest` | Send prompt to LM | ❌ | ❌ |
| `lm.registerTool` | Register a tool for AI | ❌ | ❌ |

**Note:** AI integration is a potential future direction for Tom Forge (it lives in the Tom AI ecosystem already), but is not in the current shell scope.

---

## Part 2 — Tom Forge API → VS Code

This section lists every Forge API surface and shows whether VS Code has an equivalent.

### Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | VS Code has equivalent |
| 🆕 | Forge-only — no VS Code equivalent |
| 🔶 | Similar but different in VS Code |

---

### 1. ForgeShellApi (§8.5)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `registry` | Component registration | `contributes.views`, `registerCustomEditorProvider`, `registerTreeDataProvider` | 🔶 |
| `systemState` | Real-time system state (focus, editors, selection, diagnostics) | Spread across `window.*`, `workspace.*`, `languages.getDiagnostics` | 🆕 (unified) |
| `actions` | Action registry (menu items, commands) | `commands.registerCommand` + `contributes.menus` | 🔶 |
| `shortcuts` | Shortcut registration and management | `contributes.keybindings` | 🔶 |
| `fileSystem` | Revisioned file access | `workspace.fs` (no revisioning) | 🆕 (revisioning) |
| `layout` | Programmatic layout control (panels, focus) | `window.showTextDocument`, `commands.executeCommand('workbench.*')` | 🆕 (direct) |
| `statusBar` | Status bar item registration | `window.createStatusBarItem` | ✅ |
| `fileAssociations` | File pattern → editor mapping | `contributes.customEditors` + `contributes.languages` | 🔶 |
| `extensions` | Extension cross-references | `extensions.getExtension(id)` | ✅ |
| `output` | Output channel management | `window.createOutputChannel` | ✅ |
| `diagnostics` | Problem/diagnostic registration | `languages.createDiagnosticCollection` | ✅ |
| `config` | Configuration access | `workspace.getConfiguration` | ✅ |

### 2. ForgeSystemState (§10)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `focusedComponentTypeId` | Type ID of focused component | `window.activeTextEditor` (editors only) | 🆕 (any component) |
| `focusedComponent` | The focused component instance | `window.activeTextEditor` | 🆕 (direct access) |
| `isFocusedComponentMain` | Main vs UI copy distinction | No equivalent (no multi-render) | 🆕 |
| `focusedPanelLocation` | Which panel has focus | No direct equivalent | 🆕 |
| `openEditorUris` | All open editor URIs | `window.tabGroups` → tabs → input URIs | 🔶 |
| `activeEditorUri` | Active editor URI | `window.activeTextEditor.document.uri` | ✅ |
| `dirtyEditorUris` | Editors with unsaved changes | No aggregate — check per document | 🆕 (aggregate) |
| `hasUnsavedChanges` | Any unsaved changes | No direct equivalent | 🆕 |
| `selectedExplorerItems` | Selected files in explorer | No direct API (internal to explorer) | 🆕 |
| `hoveredExplorerItem` | Hovered file in explorer | No equivalent | 🆕 |
| `diagnosticSummary` | Error/warn/info counts | Derivable from `languages.getDiagnostics` | 🆕 (pre-computed) |
| `diagnostics` | All diagnostics | `languages.getDiagnostics` | ✅ |
| `workspaceRoot` | Workspace directory | `workspace.workspaceFolders[0]` | ✅ |
| `isForgeFolderInitialized` | .forge folder status | No equivalent | 🆕 |
| `activeApplication` | Current application | No equivalent (single "workspace" state) | 🆕 |
| `applications` | All applications | No equivalent | 🆕 |
| `onFocusChanged` | Focus change stream | `window.onDidChangeActiveTextEditor` | 🔶 |
| `onDirtyStateChanged` | Dirty state stream | No aggregate event | 🆕 |
| `onSelectionChanged` | Selection change stream | `window.onDidChangeTextEditorSelection` | 🔶 |
| `onDiagnosticsChanged` | Diagnostics change stream | `languages.onDidChangeDiagnostics` | ✅ |
| `onEditorsChanged` | Editor list change stream | `window.tabGroups.onDidChangeTabs` | 🔶 |

### 3. Multi-Application Model (§6)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `ForgeApplication` | Named panel layout kept alive in memory | No equivalent — VS Code has one layout | 🆕 |
| Application switching (all stay alive) | Switch without closing | `workbench.action.openRecent` (closes current) | 🆕 |
| Shared components across applications | Same URI/type shares data state | No equivalent | 🆕 |

### 4. Multi-Render Components (§4.2)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| UI copies (SHIFT+drag) | Same component in multiple locations with independent UI state | Split editor — but same view, not configurable | 🆕 |
| Data state sharing | All copies share one data model | Split editors share document model | ✅ |
| Independent UI state per copy | Each copy has own scroll, cursor, selection | Split editors have independent scroll/cursor | ✅ |
| Main component vs copies | Lifecycle tracking, oldest copy promotion | No concept — all splits are equal | 🆕 |

### 5. Extension System (§8)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| No sandboxing — same Dart isolate | Deep shell access, modify anything | Sandboxed extension host process | 🆕 |
| `ForgeExtension.components` | Declarative component list | `package.json` contributions | 🔶 |
| `ForgeExtension.actions` | Declarative action list | `package.json: contributes.commands` | 🔶 |
| `ForgeExtension.shortcuts` | Declarative shortcut list | `package.json: contributes.keybindings` | 🔶 |
| Extension dependency order activation | Activate in dependency order | `extensionDependencies` in package.json | ✅ |
| `ForgeExtensionRegistry.get<T>()` | Type-safe cross-reference | `extensions.getExtension(id).exports` (untyped) | 🆕 (type-safe) |

### 6. Menu System (§7)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Fixed top-level menu structure | File, Edit, View, Go, Extensions, Help | VS Code has similar menus (not extensible top-level) | ✅ |
| Action-based population | Actions declare menu + group + priority | `contributes.menus` with `group` and `order` | ✅ |
| Menu configurability (user can reorder/hide) | Runtime menu editor in Configuration tab | No equivalent — menus are fixed | 🆕 |
| Dynamic `isVisible` / `isEnabled` | Per-action computed visibility | `when` clauses in package.json (declarative) | 🆕 (imperative) |
| Context menus from system state | `ForgeContextMenuContribution.isApplicable` | `contributes.menus` with `when` context keys | 🔶 |

### 7. Two-Key Shortcut System (§11)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Trigger key popup | Press trigger key → popup → second key | No equivalent (all shortcuts are direct) | 🆕 |
| Shortcut editor with conflict detection | Built-in configuration view | VS Code Keyboard Shortcuts editor | ✅ |
| Shortcut rebinding at runtime | Config tab allows rebinding | Settings-based keybinding overrides | ✅ |

### 8. Auto-Save and File Revisioning (§12)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Auto-save on focus loss / idle | Configurable auto-save | `files.autoSave` setting | ✅ |
| `.forge/` folder for revisions | File history with snapshots | No equivalent — relies on git | 🆕 |
| Shell-routed file access (`ForgeFileSystem`) | All file ops go through revisioning | workspace.fs (direct, no versioning) | 🆕 |
| Undo persistence across sessions | `.forge/undo/` stores undo stack | No equivalent — undo lost on close | 🆕 |
| File History view | Browse/diff/restore revisions | Timeline view (git-based, not built-in) | 🆕 |

### 9. Configuration System (§9)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Built-in Configuration tab (⚙, pinned) | Always-present settings panel | Settings UI (Cmd+,) | 🔶 |
| Code-based defaults + runtime overrides | `ForgeConfig` → `.forge/config.json` | `defaultSettings` → `settings.json` | ✅ |
| Configuration views (Menu, Shortcuts, Extensions, Layout, File Types) | Dedicated editors for each area | Mixed — Settings UI, Keyboard Shortcuts, Extensions view | 🆕 (integrated) |

### 10. Startup Dialog (§13)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Workspace picker at startup | Choose workspace + config directory | Welcome tab + `File > Open Folder` | 🆕 |
| Configuration directory selection (global/project/custom) | Where .forge data lives | No equivalent | 🆕 |
| Remembered preferences (`SharedPreferences`) | Remember last workspace | Recent files/folders list | 🔶 |
| CLI override (`--workspace`, `--config`) | Command-line bypass | `code /path/to/folder` | ✅ |

### 11. Layout Control

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `ForgeLayoutController` | Programmatic panel open/close/focus | `commands.executeCommand('workbench.action.*')` | 🔶 |
| Accordeon layout in side/bottom panels | Sections with mutual exclusion, pinning | VS Code views in sidebar (simpler, no accordeon) | 🆕 |
| Up to 4 middle panels | Configurable column count | Editor groups (unlimited, but complex API) | 🔶 |
| Configuration tab pinned at bottom | Built-in, non-removable | No equivalent | 🆕 |

### 12. Status Bar (§15)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `ForgeStatusBarController` | Register status bar items | `window.createStatusBarItem` | ✅ |
| Global + component items | Items from shell and focused component | Same — extensions contribute items | ✅ |
| Reactive updates via `ValueNotifier` | Auto-update on state change | `StatusBarItem.text` + `command` (manual update) | 🆕 (reactive) |

---

## Part 3 — Gap Analysis and Recommendations

### Critical Gaps (should add to Forge)

These are capabilities that visual tooling extensions will commonly need:

| # | Gap | VS Code API | Recommendation for Forge |
|---|-----|-------------|--------------------------|
| 1 | **Notification/message API** | `window.showInformationMessage/Warning/Error` | Add `ForgeNotificationManager` to `ForgeShellApi` — show toast notifications with optional action buttons. Feed into Notifications view (§14.2). |
| 2 | **Progress API** | `window.withProgress` | Add `ForgeProgressManager` — show progress in status bar or as overlay. Support cancellation tokens. |
| 3 | **Quick pick / input box** | `window.showQuickPick`, `window.showInputBox` | Add `ForgeDialogManager` — programmatic quick pick (reuse command palette UI) and input box dialogs. |
| 4 | **File dialog** | `window.showOpenDialog`, `window.showSaveDialog` | Add `ForgeDialogManager.showOpenDialog()`, `showSaveDialog()` — thin wrapper over Flutter file picker. |
| 5 | **Clipboard API** | `env.clipboard` | Add `ForgeClipboard` — read/write text clipboard. |
| 6 | **External URI opener** | `env.openExternal` | Add `ForgeEnvironment.openExternal(uri)` — open URL in browser, file in OS default app. |
| 7 | **File system events** | `workspace.createFileSystemWatcher`, `onDidCreate/Delete/Rename` | Add `ForgeFileSystem.watch(pattern)` — file system watcher with events. Critical for explorer auto-refresh and extension reactivity. |
| 8 | **Document change events** | `workspace.onDidChangeTextDocument`, save/pre-save events | Add `ForgeFileSystem.onDidChange`, `onDidSave`, `onWillSave` events. Extensions need to react to file edits. |
| 9 | **Text editor decorations** | `createTextEditorDecorationType`, `setDecorations` | Add `ForgeDecorationProvider` — extensions can contribute decorations (highlights, margin icons, underlines) to editors that support it. Editor-specific, not shell-level. |
| 10 | **File decorations (explorer)** | `registerFileDecorationProvider` | Add `ForgeFileDecorationProvider` — badges, colors on files in explorer. Useful for SCM status, build errors. |
| 11 | **Per-extension storage** | `ExtensionContext.globalState`, `workspaceState`, `storageUri` | Add `ForgeExtensionStorage` — key-value store per extension in `.forge/extensions/<id>/`. |
| 12 | **Terminal API** | `window.createTerminal`, `terminals`, `activeTerminal`, events | Add `ForgeTerminalManager` to `ForgeShellApi` — create terminals, list them, write to them, listen to events. |
| 13 | **Configuration change event** | `workspace.onDidChangeConfiguration` | Add `ForgeConfigManager.onDidChange` stream. |

### Lower Priority Gaps (evaluate later)

| # | Gap | Notes |
|---|-----|-------|
| 14 | Secret storage | Add when authentication features are needed |
| 15 | Language services (completion, hover, etc.) | Individual editor extensions implement this internally; shell-level API optional |
| 16 | Debug adapter protocol | Add with D4rt debugger integration |
| 17 | Task system | Could add simple process runner API |
| 18 | Test API | Could add when test runner integration is needed |
| 19 | SCM API | Could add with Git view |
| 20 | Comment/annotation API | Could add for code review features |
| 21 | AI/LM API | Could add for Tom AI integration |
| 22 | Telemetry | Add if usage tracking is desired |
| 23 | i18n / localization | Add when internationalization is needed |
| 24 | Workspace edit (multi-file atomic edits) | Useful for refactoring tools |
| 25 | Virtual document content provider | Useful for showing computed/generated content as documents |
| 26 | Snippet system | Add if code editors need snippet support |

### Forge-Only Features (advantages over VS Code)

| # | Feature | Value |
|---|---------|-------|
| 1 | **Unified system state API** | Single `ForgeSystemState` vs VS Code's scattered events across namespaces |
| 2 | **Multi-application model** | Multiple layouts alive simultaneously — VS Code only has one |
| 3 | **No extension sandboxing** | Type-safe, same-process extensions — zero IPC overhead, full API access |
| 4 | **Built-in file revisioning** | `.forge/` folder tracking revisions without requiring git |
| 5 | **Persistent undo across sessions** | Undo history survives app restart |
| 6 | **Two-key shortcut system** | Avoids OS/host app shortcut conflicts |
| 7 | **Menu configurability** | Users can reorder/hide menu items at runtime |
| 8 | **Accordeon with pinning** | More flexible panel layout than VS Code sidebar |
| 9 | **Multi-render with independent UI state** | SHIFT+drag creates copies with their own scroll/cursor |
| 10 | **Startup workspace/config picker** | User chooses both workspace and config storage location |
| 11 | **Imperative action visibility** | `isEnabled()`/`isVisible()` callbacks vs VS Code's declarative `when` strings |
| 12 | **Type-safe extension cross-references** | `get<T>()` vs untyped `exports` object |
| 13 | **Reactive status bar items** | `ValueNotifier`-based auto-update vs manual text assignment |
| 14 | **Configuration tab always visible** | Pinned ⚙ in left panel vs separate settings editor |

---

## Part 4 — Concept Document API Completeness Audit

This section verifies that every component, state element, service, and model mentioned in `forge_panel_shell_concept.md` is properly exposed through the `ForgeShellApi` or other API surfaces.

### Components and Models

| Item in Concept Doc | Exposed via API? | Notes |
|---------------------|------------------|-------|
| `ForgeComponent` | ✅ `ForgeComponentRegistry` | Register/retrieve |
| `ForgeComponentSizeHints` | ✅ Component contract | Component provides via `sizeHints` |
| `ForgeComponentDescriptor` | ✅ `ForgeComponentRegistry.viewTypes`, `editorTypes` | Listed |
| `ForgeApplication` | ✅ `ForgeSystemState.applications`, `activeApplication` | Read access |
| `ApplicationLayout` | 🔶 In model, but not programmatically modifiable at runtime | Need `ForgeLayoutController` API expansion |
| `PanelConfig`, `PanelTabConfig`, `AccordeonSectionConfig` | 🔶 Construction-time config, not runtime-accessible | Need `ForgeLayoutController.getPanelConfig()` |
| `MiddlePanelConfig`, `MiddleTabConfig` | 🔶 Same as above | |
| `StatusBarItem` | ✅ `ForgeStatusBarController` | Register/update |
| `ForgeAction` | ✅ `ForgeActionRegistry` | Register/execute/list |
| `ForgeContextMenuContribution` | ✅ Declared in §7.4 | Register via `ForgeActionRegistry` |
| `ForgeShortcutBinding` | ✅ `ForgeShortcutManager` | Register/rebind/list |
| `ForgeExtension` | ✅ `ForgeExtensionRegistry` | Lifecycle, cross-refs |
| `ForgeConfig` / `AutoSaveConfig` | ✅ `ForgeConfigManager` | Read/write |
| `ForgeStartupPreferences` | ✅ Via `SharedPreferences` | Pre-shell startup |
| `TomForgeShell` | ✅ Top-level configuration | Construction-time |

### Services on ForgeShellApi

| Service | Declared in §8.5? | All operations exposed? | Gaps |
|---------|-------------------|------------------------|------|
| `ForgeComponentRegistry` | ✅ `registry` | ✅ Register, list | — |
| `ForgeSystemState` | ✅ `systemState` | ✅ All state + streams | — |
| `ForgeActionRegistry` | ✅ `actions` | 🔶 Register, execute, but `list` not explicitly declared | Add `List<ForgeAction> get allActions` |
| `ForgeShortcutManager` | ✅ `shortcuts` | 🔶 Register, but no `list` / `rebind` / `remove` declared | Add `list`, `rebind(id, newBinding)`, `remove(id)` |
| `ForgeFileSystem` | ✅ `fileSystem` | 🔶 `read`, `save` mentioned, but no `write`, `delete`, `stat`, `exists`, `list`, `watch` | Add missing file operations |
| `ForgeLayoutController` | ✅ `layout` | ❌ Mentioned but no methods declared | Add `openPanel`, `closePanel`, `focusComponent`, `openEditor`, `splitMiddlePanel`, `getActiveMiddlePanel` |
| `ForgeStatusBarController` | ✅ `statusBar` | 🔶 Registration implied but not detailed | Add `register(StatusBarItem)`, `remove(id)`, `update(id, updates)` |
| `ForgeFileAssociationRegistry` | ✅ `fileAssociations` | 🔶 `register` shown in example | Add `list`, `getEditorForUri`, `remove` |
| `ForgeExtensionRegistry` | ✅ `extensions` | 🔶 `get<T>()` shown | Add `list`, `isActive(id)` |
| `ForgeOutputChannelManager` | ✅ `output` | ❌ Not detailed | Add `create(name)`, `get(name)`, `list`, `ForgeOutputChannel.append/appendLine/clear/show/hide/dispose` |
| `ForgeDiagnosticManager` | ✅ `diagnostics` | 🔶 Referenced but not detailed | Add `createCollection(name)`, `ForgeDiagnosticCollection.set/delete/clear/dispose` |
| `ForgeConfigManager` | ✅ `config` | 🔶 Read implied | Add `get<T>(key)`, `set(key, value)`, `onDidChange`, `getSection(extension)` |

### State Elements in ForgeSystemState

| State Property | In §10.2? | Accessible? | Gaps |
|----------------|-----------|-------------|------|
| Focus (component, type, panel, main/copy) | ✅ | ✅ | — |
| Open editors | ✅ | ✅ | — |
| Active editor | ✅ | ✅ | — |
| Dirty editors | ✅ | ✅ | — |
| Explorer selection/hover | ✅ | ✅ | — |
| Diagnostics | ✅ | ✅ | — |
| Workspace root | ✅ | ✅ | — |
| .forge initialized | ✅ | ✅ | — |
| Active application | ✅ | ✅ | — |
| All applications | ✅ | ✅ | — |
| **Visible panels** (which panels are open) | ❌ | ❌ | Add `visiblePanels` (left, right, bottom — open/closed) |
| **Panel sizes** | ❌ | ❌ | Add `panelSizes` (left width, right width, bottom height) |
| **Middle panel count** | ❌ | ❌ | Add `middlePanelCount` |
| **Active middle panel index** | ❌ | ❌ | Add `activeMiddlePanelIndex` |
| **Component render locations** | ❌ | ❌ | Add `getComponentLocations(typeId)` — where a component and its copies are rendered |
| **Open output channels** | ❌ | ❌ | Add `openOutputChannels` |
| **Active terminal** | ❌ | ❌ | Add `activeTerminal`, `terminals` (if terminal API is added) |
| **Window focus** | ❌ | ❌ | Add `isWindowFocused` + `onWindowFocusChanged` |
| **Search state** (is search active, query) | ❌ | ❌ | Add `searchQuery`, `isSearchActive` |
| **Command palette state** | ❌ | ❌ | Add `isCommandPaletteOpen` |

### Built-In Views

| View | Mentioned in §14? | Accessible via API? | Gaps |
|------|-------------------|---------------------|------|
| Terminal | ✅ | ❌ No terminal management API | Add `ForgeTerminalManager` |
| Output | ✅ | ✅ via `ForgeOutputChannelManager` | Detail the API |
| Problems | ✅ | ✅ via `ForgeDiagnosticManager` | Detail the API |
| Explorer | ✅ | 🔶 Selection exposed, but no control API | Add `reveal(uri)`, `refresh()` |
| Search | ✅ | ❌ No search API | Add `ForgeSearchManager.search(query)`, `results` |
| Outline | ✅ | ❌ No outline data API | Consider `ForgeOutlineProvider` registration |
| File History | ✅ | ❌ No revision browsing API | Managed by `ForgeFileSystem` revisions, but no view-control API |

---

## Summary Statistics

| Category | Count |
|----------|-------|
| VS Code API items reviewed | ~210 |
| Covered in Forge (✅) | ~45 |
| Partially covered (🔶) | ~30 |
| Not covered — gap (❌) | ~105 |
| Not applicable (➖) | ~30 |
| Forge-only features (🆕) | 14 |
| Critical gaps to add | 13 |
| Lower priority gaps | 13 |
