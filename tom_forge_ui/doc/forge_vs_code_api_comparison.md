# Tom Forge vs VS Code — API Comparison

**Project:** tom_forge_ui  
**Date:** 2026-03-24  
**Based on:** Concept v5 (OO/type-safe redesign + editor hierarchy + two-phase resolution)  
**Purpose:** Comprehensive mapping between the VS Code Extension API and the Tom Forge Shell API. Used to identify coverage gaps and ensure functional equivalence where Forge covers the same domain.

---

## Part 1 — VS Code Extension API → Tom Forge

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
| `activate(context: ExtensionContext)` | Called when extension activates; receives context | `ForgeModule.activate(ForgeShellApi shell)` — shell reference provides full typed API access | ✅ |
| `deactivate()` | Called on extension shutdown | `ForgeModule.deactivate()` | ✅ |
| `ExtensionContext.subscriptions` | Disposable list — auto-disposed on deactivate | No equivalent — modules manage own cleanup in `deactivate()` | 🔶 |
| `ExtensionContext.extensionPath` | Filesystem path to the extension | Not applicable — modules are compiled into the app | ➖ |
| `ExtensionContext.extensionUri` | URI of extension directory | Not applicable | ➖ |
| `ExtensionContext.globalState` | Persistent key-value store (across workspaces) | `ForgeModuleStorage.forModule(module)` — per-module key-value store in `.forge/` | ✅ |
| `ExtensionContext.workspaceState` | Per-workspace key-value store | `ForgeModuleStorage.forModule(module)` — stored in workspace `.forge/modules/<type>/` | ✅ |
| `ExtensionContext.secrets` | Secure storage for tokens/passwords | ❌ No secret storage API | ❌ |
| `ExtensionContext.storageUri` | Extension-specific storage directory | `ForgeModuleStorage.forModule(module)` — directory is `.forge/modules/<type>/` | ✅ |
| `ExtensionContext.globalStorageUri` | Global extension storage | Not applicable — all storage is workspace-scoped | ➖ |
| `ExtensionContext.logUri` | Extension log file location | Modules use `ForgeOutputChannelManager` for logging | 🔶 |
| `ExtensionContext.extensionMode` | Development / Production / Test | ❌ No mode API | ❌ |
| `extensions.getExtension(id)` | Get another extension by ID | `ForgeModuleRegistry.get<T>()` — type-safe, no string IDs (stronger than VS Code) | ✅ |
| `extensions.all` | List of all installed extensions | `ForgeModuleRegistry.allModules` | ✅ |
| `extensions.onDidChange` | Extension install/uninstall events | Not applicable — modules are compile-time | ➖ |

**What VS Code extensions expose back to VS Code:**

| VS Code Mechanism | Description | Forge Equivalent | Status |
|-------------------|-------------|-------------------|--------|
| `package.json: activationEvents` | Declares when extension activates | Modules always activate at startup, in declaration order | 🔶 |
| `package.json: contributes.commands` | Declares commands | `ForgeModule.actions` — list of `ForgeAction` objects (no string IDs) | ✅ |
| `package.json: contributes.menus` | Declares menu contributions | Actions declare `ForgeMenuLocation` + `group` + `priority`; context menus via `isApplicable` callbacks | ✅ |
| `package.json: contributes.keybindings` | Declares keyboard shortcuts | `ForgeModule.shortcuts` — list of `ForgeShortcutBinding` | ✅ |
| `package.json: contributes.languages` | Declares language support | `ForgeDocument.languageId` per editor; two-phase `canHandle`/`canHandleContent` for file resolution | 🔶 |
| `package.json: contributes.grammars` | TextMate grammars for syntax highlighting | ❌ No grammar/syntax highlighting system | ❌ |
| `package.json: contributes.themes` | Color themes | `ForgeConfig.theme` — but no theme contribution from modules | 🔶 |
| `package.json: contributes.iconThemes` | File icon themes | ❌ No icon theme system | ❌ |
| `package.json: contributes.productIconThemes` | Product icon overrides | ❌ | ❌ |
| `package.json: contributes.snippets` | Code snippets | ❌ No snippet system | ❌ |
| `package.json: contributes.jsonValidation` | JSON schema associations | ❌ No built-in JSON schema integration | ❌ |
| `package.json: contributes.views` | Declares views for side bar | Components declared as direct `late final` members on `ForgeModule` | ✅ |
| `package.json: contributes.viewsContainers` | Custom sidebar containers | Custom tabs in left/right panels via `PanelTabConfig` | ✅ |
| `package.json: contributes.viewsWelcome` | Welcome content for empty views | ❌ No welcome content system | ❌ |
| `package.json: contributes.configuration` | Extension settings | Module configuration views in Configuration tab (§9) | ✅ |
| `package.json: contributes.configurationDefaults` | Default settings values | `ForgeConfig` code-configured defaults | ✅ |
| `package.json: contributes.taskDefinitions` | Task types | ❌ No task system | ❌ |
| `package.json: contributes.problemMatchers` | Regex matchers for build output | ❌ No problem matcher system | ❌ |
| `package.json: contributes.problemPatterns` | Reusable problem patterns | ❌ | ❌ |
| `package.json: contributes.debuggers` | Debug adapter contributions | ❌ No debug adapter protocol | ❌ |
| `package.json: contributes.breakpoints` | Breakpoint types | ❌ | ❌ |
| `package.json: contributes.terminal.profiles` | Terminal profile contributions | ❌ No terminal profile system | ❌ |
| `package.json: contributes.walkthroughs` | Getting Started walkthroughs | ❌ No walkthrough system | ❌ |
| `package.json: contributes.customEditors` | Custom editor types | `ForgeEditor` subclasses (`ForgeTextEditor`, `ForgeVisualEditor`, `ForgeSchemaEditor`) with `canHandle(uri)` and `canHandleContent(uri, bytes)` | ✅ |
| `package.json: contributes.notebooks` | Notebook types | ❌ No notebook system | ❌ |
| `package.json: contributes.notebookRenderer` | Custom notebook cell renderers | ❌ | ❌ |
| Extension API export | Extensions export an API object | `ForgeModuleRegistry.get<T>()` — direct Dart type access with full API (stronger than VS Code's untyped exports) | ✅ |

---

### 2. Window and Layout (`vscode.window`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `window.activeTextEditor` | Currently active text editor | `ForgeSystemState.focusedComponent` (use `is ForgeTextEditor`) + `activeEditor` | ✅ |
| `window.visibleTextEditors` | All visible text editors | `ForgeSystemState.openEditors` (all open editors as direct references) | ✅ |
| `window.onDidChangeActiveTextEditor` | Active editor changed | `ForgeSystemState.onFocusChanged` | ✅ |
| `window.onDidChangeVisibleTextEditors` | Visible editors changed | `ForgeSystemState.onEditorsChanged` | ✅ |
| `window.onDidChangeTextEditorSelection` | Selection changed | `ForgeSystemState.onTextSelectionChanged` | ✅ |
| `window.onDidChangeTextEditorVisibleRanges` | Visible range changed (scroll) | ❌ No visible-range tracking at shell level | ❌ |
| `window.onDidChangeTextEditorOptions` | Editor options changed | ❌ No per-editor options change event | ❌ |
| `window.onDidChangeTextEditorViewColumn` | Editor moved to different column | `ForgeSystemState.onLayoutChanged` | ✅ |
| `window.showTextDocument(uri, options)` | Open a document in an editor | `ForgeLayoutController.openFile(uri)` — triggers two-phase resolution | ✅ |
| `window.showNotebookDocument` | Open a notebook | Not applicable | ➖ |
| `window.createTextEditorDecorationType` | Decorations (highlights, gutters, rulers) | ❌ No decoration API | ❌ |
| `window.showInformationMessage` | Info notification with actions | `ForgeNotificationManager.showInformation(message, actions)` | ✅ |
| `window.showWarningMessage` | Warning notification | `ForgeNotificationManager.showWarning(message, actions)` | ✅ |
| `window.showErrorMessage` | Error notification | `ForgeNotificationManager.showError(message, actions)` | ✅ |
| `window.showQuickPick` | Quick pick dropdown | `ForgeDialogManager.showQuickPick(items)` | ✅ |
| `window.showInputBox` | Text input dialog | `ForgeDialogManager.showInputBox(prompt)` | ✅ |
| `window.showOpenDialog` | File open dialog | `ForgeDialogManager.showOpenDialog()` | ✅ |
| `window.showSaveDialog` | File save dialog | `ForgeDialogManager.showSaveDialog()` | ✅ |
| `window.showWorkspaceFolderPick` | Workspace folder picker | Not applicable (single workspace) | ➖ |
| `window.createOutputChannel` | Create output channel | `ForgeOutputChannelManager.create(name)` | ✅ |
| `window.createWebviewPanel` | Create a webview panel | Not applicable — use native Flutter widgets | ➖ |
| `window.registerWebviewPanelSerializer` | Webview state restoration | Not applicable | ➖ |
| `window.createTreeView` | Create tree view in sidebar | Modules create view components directly as Flutter widgets | 🔶 |
| `window.registerTreeDataProvider` | Register tree data for a view | Modules build tree widgets directly — more flexible | 🔶 |
| `window.registerFileDecorationProvider` | File decorations in explorer (badges, colors) | ❌ No file decoration API | ❌ |
| `window.registerUriHandler` | Handle custom URI schemes | ❌ No URI handler system | ❌ |
| `window.registerCustomEditorProvider` | Register custom editor | `ForgeEditor` subclasses declared as module members with `canHandle(uri)` | ✅ |
| `window.registerTerminalProfileProvider` | Terminal profile provider | ❌ No terminal profile system | ❌ |
| `window.registerTerminalLinkProvider` | Clickable links in terminal output | ❌ No terminal link provider | ❌ |
| `window.createTerminal` | Create a terminal instance | `ForgeTerminalManager.create(name, shellPath, cwd)` | ✅ |
| `window.activeTerminal` | Currently active terminal | `ForgeTerminalManager.activeTerminal` | ✅ |
| `window.terminals` | All open terminals | `ForgeTerminalManager.terminals` | ✅ |
| `window.onDidOpenTerminal` | Terminal opened event | `ForgeTerminalManager.onDidOpen` | ✅ |
| `window.onDidCloseTerminal` | Terminal closed event | `ForgeTerminalManager.onDidClose` | ✅ |
| `window.onDidChangeActiveTerminal` | Active terminal changed | `ForgeTerminalManager.onDidChangeActive` | ✅ |
| `window.onDidChangeTerminalState` | Terminal state changed | ❌ No terminal state change event | ❌ |
| `window.state.focused` | Whether window has focus | `ForgeSystemState.isWindowFocused` | ✅ |
| `window.onDidChangeWindowState` | Window focus changed | `ForgeSystemState.onWindowFocusChanged` | ✅ |
| `window.tabGroups` | Tab groups (editor columns) | Middle panels (1–4) via `ForgeSystemState.middlePanelCount` | ✅ |
| `window.tabGroups.onDidChangeTabGroups` | Tab group layout changed | `ForgeSystemState.onLayoutChanged` | ✅ |
| `window.tabGroups.onDidChangeTabs` | Tabs changed | `ForgeSystemState.onEditorsChanged` | ✅ |
| `window.registerColorTheme` | Register color theme | ❌ No theme contribution API | ❌ |

---

### 3. Commands (`vscode.commands`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `commands.registerCommand(id, handler)` | Register a command | `ForgeAction` objects declared on modules — no string IDs, direct references | ✅ |
| `commands.registerTextEditorCommand` | Command with guaranteed text editor | `ForgeAction` with `isEnabled: () => state.focusedComponent is ForgeTextEditor` | ✅ |
| `commands.executeCommand(id, ...args)` | Execute a command by ID | Call `action.execute()` directly — action is a typed object reference | ✅ |
| `commands.getCommands(filter?)` | List all registered commands | Collect `module.actions` across all modules | ✅ |

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
| `workspace.findFiles(include, exclude)` | Glob-based file search | ❌ No glob-based file search API | ❌ |
| `workspace.openTextDocument(uri)` | Open a text document (model, not UI) | `ForgeFileSystem.read(uri)` for content; `ForgeTextEditor.document` for model | ✅ |
| `workspace.registerTextDocumentContentProvider` | Virtual document content | ❌ No virtual document provider | ❌ |
| `workspace.onDidOpenTextDocument` | Document opened | `ForgeSystemState.onEditorsChanged` | ✅ |
| `workspace.onDidCloseTextDocument` | Document closed | `ForgeSystemState.onEditorsChanged` | ✅ |
| `workspace.onDidChangeTextDocument` | Document content changed | `ForgeDocument.onDidChange` (per-editor) | ✅ |
| `workspace.onDidSaveTextDocument` | Document saved | `ForgeFileSystem.onDidSave` | ✅ |
| `workspace.onWillSaveTextDocument` | Before document save (allows edits) | `ForgeFileSystem.onWillSave` | ✅ |
| `workspace.onDidCreateFiles` | Files created in workspace | `ForgeFileSystem.onDidChange` (FileChangeEvent) | ✅ |
| `workspace.onDidDeleteFiles` | Files deleted | `ForgeFileSystem.onDidChange` (FileChangeEvent) | ✅ |
| `workspace.onDidRenameFiles` | Files renamed | `ForgeFileSystem.onDidChange` (FileChangeEvent) | ✅ |
| `workspace.onWillCreateFiles` | Before file creation | ❌ No pre-creation hook | ❌ |
| `workspace.onWillDeleteFiles` | Before file deletion | ❌ No pre-deletion hook | ❌ |
| `workspace.onWillRenameFiles` | Before file rename | ❌ No pre-rename hook | ❌ |
| `workspace.applyEdit(workspaceEdit)` | Apply multi-file edit atomically | ❌ No workspace edit API | ❌ |
| `workspace.createFileSystemWatcher` | Watch file changes | `ForgeFileSystem.watch(uri, recursive)` | ✅ |
| `workspace.getConfiguration(section)` | Read configuration values | `ForgeConfigManager.current` | ✅ |
| `workspace.onDidChangeConfiguration` | Configuration changed | `ForgeConfigManager.onDidChange` | ✅ |
| `workspace.registerTaskProvider` | Register task provider | ❌ No task system | ❌ |
| `workspace.registerFileSystemProvider` | Virtual file system | ❌ No virtual FS provider | ❌ |
| `workspace.fs` | File system access | `ForgeFileSystem` (read, write, save, delete, exists, stat, list, watch — routed through revisioning) | ✅ |
| `workspace.isTrusted` | Workspace trust state | ❌ No workspace trust model | ❌ |
| `workspace.onDidGrantWorkspaceTrust` | Trust granted | ❌ | ❌ |
| `workspace.notebookDocuments` | Open notebook documents | Not applicable | ➖ |
| `workspace.onDidOpenNotebookDocument` | Notebook opened | Not applicable | ➖ |
| `workspace.onDidCloseNotebookDocument` | Notebook closed | Not applicable | ➖ |

---

### 5. Languages (`vscode.languages`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `languages.registerCompletionItemProvider` | Autocomplete | ❌ No language service API (editor-internal) | ❌ |
| `languages.registerHoverProvider` | Tooltip on hover | ❌ | ❌ |
| `languages.registerSignatureHelpProvider` | Function signature help | ❌ | ❌ |
| `languages.registerDefinitionProvider` | Go-to-definition | ❌ | ❌ |
| `languages.registerTypeDefinitionProvider` | Go-to-type-definition | ❌ | ❌ |
| `languages.registerImplementationProvider` | Go-to-implementation | ❌ | ❌ |
| `languages.registerReferenceProvider` | Find all references | ❌ | ❌ |
| `languages.registerDocumentHighlightProvider` | Highlight occurrences | ❌ | ❌ |
| `languages.registerDocumentSymbolProvider` | Document outline symbols | ❌ (Outline view exists but no provider registration API) | 🔶 |
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
| `languages.registerCallHierarchyProvider` | Call hierarchy | ❌ | ❌ |
| `languages.registerTypeHierarchyProvider` | Type hierarchy | ❌ | ❌ |
| `languages.registerLinkedEditingRangeProvider` | Linked editing (rename HTML tags) | ❌ | ❌ |
| `languages.registerEvaluatableExpressionProvider` | Debug expression evaluation | ❌ | ❌ |
| `languages.registerInlineValuesProvider` | Inline values during debug | ❌ | ❌ |
| `languages.getDiagnostics(uri)` | Get diagnostics for a file | `ForgeDiagnosticManager.forUri(uri)` | ✅ |
| `languages.createDiagnosticCollection` | Register diagnostic source | `ForgeDiagnosticManager.createCollection(name)` | ✅ |
| `languages.onDidChangeDiagnostics` | Diagnostics changed | `ForgeSystemState.onDiagnosticsChanged` | ✅ |
| `languages.getLanguages()` | List of known language IDs | ❌ No language ID registry | ❌ |
| `languages.setLanguageConfiguration` | Bracket, comment, indentation rules | ❌ | ❌ |
| `languages.setTextDocumentLanguage` | Change a file's language | ❌ | ❌ |
| `languages.match(selector, document)` | Match document against selector | Two-phase file resolution via `canHandle(uri)` + `canHandleContent(uri, bytes)` | 🔶 |
| `languages.registerDocumentDropEditProvider` | Handle file/data drop into editor | ❌ No in-editor drop API | ❌ |

**Note:** The entire `vscode.languages` namespace is VS Code's language server protocol integration layer. Tom Forge is not a code editor IDE — it's a visual tooling shell. Language services are provided by individual editor modules internally (e.g., a D4rt editor module) via the `ForgeTextEditor` API rather than as shell-level registration points. The shell provides the editor contracts (`ForgeTextEditor`, `ForgeDocument`) — language-specific intelligence lives inside the modules.

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

**Note:** Debug support is a future addition. A full `ForgeDebugManager` would be needed when D4rt integration lands.

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

**Note:** SCM is a future view. If added, a `ForgeScmManager` could wrap git operations.

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

**Note:** Tom Forge could introduce a simple task/process runner API without the full complexity of VS Code's task system. The terminal manager provides some of this functionality already.

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
| `authentication.getSession` | Get auth session | ❌ No authentication API | ❌ |
| `authentication.onDidChangeSessions` | Auth session changed | ❌ | ❌ |
| `authentication.registerAuthenticationProvider` | Custom auth provider | ❌ | ❌ |

---

### 12. Environment and Context (`vscode.env`)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `env.appName` | Application name | `ForgeEnvironment.appName` | ✅ |
| `env.appRoot` | Installation directory | Not applicable | ➖ |
| `env.appHost` | App host (desktop, web, codespaces) | Not applicable (desktop only initially) | ➖ |
| `env.uriScheme` | Custom URI scheme ("vscode") | ❌ No custom URI scheme | ❌ |
| `env.language` | UI language | ❌ No i18n API | ❌ |
| `env.clipboard.readText` | Read clipboard | `ForgeClipboard.readText()` | ✅ |
| `env.clipboard.writeText` | Write clipboard | `ForgeClipboard.writeText(text)` | ✅ |
| `env.machineId` | Unique machine ID | ❌ | ❌ |
| `env.sessionId` | Current session ID | ❌ | ❌ |
| `env.remoteName` | Remote name (SSH, WSL) | Not applicable | ➖ |
| `env.shell` | Default shell path | ❌ No shell path API | ❌ |
| `env.isTelemetryEnabled` | Telemetry consent | ❌ | ❌ |
| `env.onDidChangeTelemetryEnabled` | Telemetry consent changed | ❌ | ❌ |
| `env.createTelemetryLogger` | Create telemetry sender | ❌ No telemetry API | ❌ |
| `env.openExternal(uri)` | Open URI in default browser/app | `ForgeEnvironment.openExternal(uri)` | ✅ |
| `env.asExternalUri(uri)` | Convert to externally reachable URI | ❌ | ❌ |
| `env.logLevel` | Current log level | ❌ No log level API | ❌ |
| `env.onDidChangeLogLevel` | Log level changed | ❌ | ❌ |

---

### 13. Text Documents and Editors (Data Model)

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `TextDocument.uri` | Document URI | `ForgeDocument.uri` / `ForgeEditor.uri` | ✅ |
| `TextDocument.fileName` | File path | Derivable from URI | ✅ |
| `TextDocument.languageId` | Language identifier | `ForgeDocument.languageId` | ✅ |
| `TextDocument.version` | Document version counter | ❌ No document version tracking | ❌ |
| `TextDocument.isDirty` | Has unsaved changes | `ForgeDocument.isDirty` / `ForgeEditor.isDirty` | ✅ |
| `TextDocument.isUntitled` | Untitled (never saved) | ❌ No untitled document concept | ❌ |
| `TextDocument.isClosed` | Document closed | Derivable from `ForgeSystemState.openEditors` | ✅ |
| `TextDocument.save()` | Save the document | `ForgeFileSystem.save(uri)` | ✅ |
| `TextDocument.eol` | End-of-line character | ❌ Not exposed | ❌ |
| `TextDocument.lineCount` | Number of lines | `ForgeDocument.lineCount` | ✅ |
| `TextDocument.lineAt(line)` | Get line text | `ForgeDocument.lineAt(line)` | ✅ |
| `TextDocument.getText(range?)` | Get text content | `ForgeDocument.text` / `ForgeDocument.textInRange(range)` | ✅ |
| `TextDocument.getWordRangeAtPosition` | Word at position | ❌ Not exposed | ❌ |
| `TextDocument.offsetAt(position)` | Position to offset | ❌ Not exposed | ❌ |
| `TextDocument.positionAt(offset)` | Offset to position | ❌ Not exposed | ❌ |
| `TextDocument.validateRange` | Clamp range to document | ❌ Not exposed | ❌ |
| `TextDocument.validatePosition` | Clamp position to document | ❌ Not exposed | ❌ |
| `TextEditor.document` | The editor's document | `ForgeTextEditor.document` | ✅ |
| `TextEditor.selection` | Current selection | `ForgeTextEditor.selection` | ✅ |
| `TextEditor.selections` | Multiple selections (multi-cursor) | ❌ Single selection only | ❌ |
| `TextEditor.visibleRanges` | Visible text ranges | ❌ Not exposed at editor level | ❌ |
| `TextEditor.options` | Tab size, insert spaces, etc. | ❌ No per-editor options API | ❌ |
| `TextEditor.viewColumn` | Which editor column | Panel location via layout | ✅ |
| `TextEditor.edit(callback)` | Apply edits to document | `ForgeTextEditor.insertText()`, `replaceRange()`, `deleteRange()` | ✅ |
| `TextEditor.insertSnippet` | Insert snippet at cursor | ❌ No snippet support | ❌ |
| `TextEditor.setDecorations` | Apply decorations | ❌ No decoration API | ❌ |
| `TextEditor.revealRange` | Scroll to make range visible | `ForgeTextEditor.revealPosition(position)` | ✅ |
| `TextEditorEdit.insert` | Insert text at position | `ForgeTextEditor.insertText(text)` | ✅ |
| `TextEditorEdit.delete` | Delete range | `ForgeTextEditor.deleteRange(range)` | ✅ |
| `TextEditorEdit.replace` | Replace range with text | `ForgeTextEditor.replaceRange(range, replacement)` | ✅ |

**Note:** With the `ForgeTextEditor` and `ForgeDocument` APIs, Tom Forge now provides rich text-level access comparable to VS Code. The key architectural difference is that text APIs are on the editor type hierarchy (`ForgeTextEditor`) rather than a global namespace — making them type-safe and available only when a text editor is focused.

---

### 14. Progress and Notifications

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `window.withProgress(options, task)` | Progress indicator | `ForgeProgressManager.withProgress(title, location, task)` | ✅ |
| `Progress.report({ increment, message })` | Update progress | `ForgeProgressReporter.report(increment, message)` | ✅ |
| `CancellationToken` | Cancellation support | `ForgeProgressManager.withProgress(cancellable: true)` — cancellation is built in | ✅ |
| `window.showInformationMessage` | Info toast/dialog | `ForgeNotificationManager.showInformation(message, actions)` | ✅ |
| `window.showWarningMessage` | Warning toast/dialog | `ForgeNotificationManager.showWarning(message, actions)` | ✅ |
| `window.showErrorMessage` | Error toast/dialog | `ForgeNotificationManager.showError(message, actions)` | ✅ |

---

### 15. Theming

| VS Code API | Description | Forge Equivalent | Status |
|-------------|-------------|-------------------|--------|
| `window.activeColorTheme` | Current color theme | `ForgeConfig.theme` | 🔶 |
| `window.onDidChangeActiveColorTheme` | Theme changed | `ForgeConfigManager.onDidChange` (includes theme changes) | ✅ |
| `ColorTheme.kind` | Light / Dark / HighContrast | Derivable from Flutter `ThemeData` | 🔶 |
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
| `systemState` | Real-time system state (focus, editors, selection, diagnostics, layout) | Spread across `window.*`, `workspace.*`, `languages.getDiagnostics` | 🆕 (unified) |
| `layout` | Programmatic layout control (panels, focus, open file, open with) | `window.showTextDocument`, `commands.executeCommand('workbench.*')` | 🆕 (direct API) |
| `statusBar` | Status bar item management | `window.createStatusBarItem` | ✅ |
| `fileSystem` | Revisioned file access (read, write, save, delete, stat, watch, events) | `workspace.fs` (no revisioning, fewer events) | 🆕 (revisioning) |
| `modules` | Module cross-references (type-safe) | `extensions.getExtension(id)` (untyped) | ✅ |
| `output` | Output channel creation and management | `window.createOutputChannel` | ✅ |
| `diagnostics` | Problem/diagnostic registration | `languages.createDiagnosticCollection` | ✅ |
| `config` | Configuration access with change events | `workspace.getConfiguration` | ✅ |
| `notifications` | Toast notifications with action buttons | `window.showInformationMessage` etc. | ✅ |
| `progress` | Progress indicators (status bar / overlay) | `window.withProgress` | ✅ |
| `dialogs` | Quick pick, input box, file dialogs | `window.showQuickPick`, `showInputBox`, `showOpenDialog`, `showSaveDialog` | ✅ |
| `terminals` | Terminal instance management | `window.createTerminal`, `terminals`, events | ✅ |
| `clipboard` | Clipboard read/write | `env.clipboard` | ✅ |
| `environment` | App info, open external URI | `env.appName`, `env.openExternal` | ✅ |
| `storage` | Per-module persistent key-value storage | `ExtensionContext.workspaceState`, `globalState` | ✅ |
| `undoManager` | Action-level undo/redo stack | Partial — VS Code has per-editor undo, no action-level undo | 🆕 (action-level) |

### 2. ForgeSystemState (§10)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `focusedComponent` | The focused component instance (any type) | `window.activeTextEditor` (editors only) | 🆕 (any component) |
| `isFocusedComponentMain` | Main vs UI copy distinction | No equivalent (no multi-render) | 🆕 |
| `focusedPanelLocation` | Which panel has focus | No direct equivalent | 🆕 |
| `openEditors` | All open editors (direct typed references) | `window.tabGroups` → tabs → input URIs (indirect) | 🆕 (typed refs) |
| `activeEditor` | Active editor (direct reference) | `window.activeTextEditor` | ✅ |
| `dirtyEditors` | Editors with unsaved changes (list) | No aggregate — check per document | 🆕 (aggregate) |
| `hasUnsavedChanges` | Any unsaved changes | No direct equivalent | 🆕 |
| `focusedTextSelection` | Text selection from focused TextEditor | `window.activeTextEditor.selection` | ✅ |
| `focusedSelectedText` | Selected text content | `window.activeTextEditor.document.getText(selection)` | ✅ |
| `hasTextSelection` | Non-empty text or element selection | Check `selection.isEmpty` | 🔶 |
| `focusedSelectedElements` | Selected elements from focused VisualEditor | No equivalent | 🆕 |
| `selectedExplorerItems` | Selected files in explorer | No direct API | 🆕 |
| `hoveredExplorerItem` | Hovered file in explorer | No equivalent | 🆕 |
| `diagnosticSummary` | Error/warn/info counts | Derivable from `languages.getDiagnostics` | 🆕 (pre-computed) |
| `diagnostics` | All diagnostics | `languages.getDiagnostics` | ✅ |
| `workspaceRoot` | Workspace directory | `workspace.workspaceFolders[0]` | ✅ |
| `isForgeFolderInitialized` | .forge folder status | No equivalent | 🆕 |
| `activeApplication` | Current application | No equivalent (single layout) | 🆕 |
| `applications` | All applications | No equivalent | 🆕 |
| `visiblePanels` | Which panels are open | No direct API | 🆕 |
| `middlePanelCount` | Number of editor columns | `window.tabGroups.all.length` | 🔶 |
| `activeMiddlePanelIndex` | Active editor column | `window.tabGroups.activeTabGroup` | 🔶 |
| `isWindowFocused` | Window has OS focus | `window.state.focused` | ✅ |
| `searchQuery` / `isSearchActive` | Search state | No direct API | 🆕 |
| `onFocusChanged` | Focus change stream | `window.onDidChangeActiveTextEditor` | 🔶 |
| `onDirtyStateChanged` | Dirty state stream | No aggregate event | 🆕 |
| `onSelectionChanged` | Selection change stream | `window.onDidChangeTextEditorSelection` | 🔶 |
| `onTextSelectionChanged` | Text selection change stream | `window.onDidChangeTextEditorSelection` | ✅ |
| `onDiagnosticsChanged` | Diagnostics change stream | `languages.onDidChangeDiagnostics` | ✅ |
| `onEditorsChanged` | Editor list change stream | `window.tabGroups.onDidChangeTabs` | 🔶 |
| `onWindowFocusChanged` | Window focus stream | `window.onDidChangeWindowState` | ✅ |
| `onLayoutChanged` | Layout change stream | Partial via tab group events | 🆕 |

### 3. Editor Type Hierarchy (§4.3)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `ForgeEditor` | Base editor — URI, `canHandle`, dirty, history | `CustomEditorProvider` | 🔶 |
| `ForgeTextEditor` | Text editor — document, selection, cursor, modification, find/replace | `TextEditor` + `TextDocument` | ✅ |
| `ForgeVisualEditor` | Canvas editor — element selection, viewport, zoom | Custom webview editor (no typed API) | 🆕 (typed API) |
| `ForgeSchemaEditor` | Content-based schema detection; "Open with" additional options | No equivalent | 🆕 |
| `ForgeDocument` | Structured text buffer (lineCount, lineAt, text, languageId, encoding) | `TextDocument` | ✅ |
| `TextPosition` / `TextRange` | Position and range types | `Position` / `Range` | ✅ |
| `DocumentChangeEvent` | Document content change event | `TextDocumentChangeEvent` | ✅ |
| `ForgeTextEditor.insertText()` | Insert text at cursor/selection | `TextEditor.edit()` callback | ✅ |
| `ForgeTextEditor.replaceRange()` | Replace text in range | `TextEditorEdit.replace()` | ✅ |
| `ForgeTextEditor.deleteRange()` | Delete text in range | `TextEditorEdit.delete()` | ✅ |
| `ForgeTextEditor.findAll()` | Find pattern occurrences in document | No direct API — internal to find widget | 🆕 |
| `ForgeTextEditor.replaceAll()` | Replace all pattern occurrences | No direct API | 🆕 |
| `ForgeVisualEditor.selectedElements` | Canvas element selection | No typed API | 🆕 |
| `ForgeVisualEditor.viewport` / `zoomLevel` | Viewport and zoom control | No typed API | 🆕 |
| `ForgeVisualEditor.zoomToFit()` | Zoom to fit all content | No typed API | 🆕 |

### 4. Two-Phase File Resolution (§10.4)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `canHandle(Uri uri)` → `FileHandlingResult` | Phase 1: URI-based matching (accept/reject/inspect) | `CustomEditorSelector` file globs | 🆕 (richer) |
| `canHandleContent(Uri uri, Uint8List bytes)` | Phase 2: Content-based inspection | No equivalent | 🆕 |
| `FileHandlingResult.inspect` | Request content inspection before deciding | No equivalent | 🆕 |
| "Open with" dialog (primary + additional options) | Multi-editor file opening with schema editors | "Open With" in VS Code (simpler, no schema concept) | 🆕 (schema-aware) |
| `ForgeSchemaEditor.schemaLabel` | Schema display in "Open with" dialog | No equivalent | 🆕 |

### 5. Multi-Application Model (§6)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `ForgeApplication` | Named panel layout kept alive in memory | No equivalent — VS Code has one layout | 🆕 |
| Application switching (all stay alive) | Switch without closing | `workbench.action.openRecent` (closes current) | 🆕 |
| Shared components across applications | Same URI/type shares data state | No equivalent | 🆕 |

### 6. Multi-Render Components (§4.2)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| UI copies (SHIFT+drag) | Same component in multiple locations | Split editor — but same view, not configurable | 🆕 |
| Data state sharing | All copies share one data model | Split editors share document model | ✅ |
| Independent UI state per copy | Each copy has own scroll, cursor, selection | Split editors have independent scroll/cursor | ✅ |
| Main component vs copies | Lifecycle tracking, oldest copy promotion | No concept — all splits are equal | 🆕 |

### 7. Module System (§8)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| No sandboxing — same Dart isolate | Deep shell access, zero IPC overhead | Sandboxed extension host process | 🆕 |
| `ForgeModule` with typed members | Editors/views as `late final` class members | `package.json` contributions (declarative, not typed) | 🆕 |
| `ForgeModule.actions` | Action objects with imperative visibility | `contributes.commands` + `contributes.menus` (declarative when clauses) | 🆕 (imperative) |
| `ForgeModule.shortcuts` | Shortcut binding objects | `contributes.keybindings` | 🔶 |
| Module dependency order activation | Activate in dependency order | `extensionDependencies` in package.json | ✅ |
| `ForgeModuleRegistry.get<T>()` | Type-safe cross-reference | `extensions.getExtension(id).exports` (untyped) | 🆕 (type-safe) |

### 8. Menu System (§7)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Fixed top-level menu structure | File, Edit, View, Go, Modules, Help | VS Code has similar menus | ✅ |
| Action-based menu population | Actions declare menu + group + priority | `contributes.menus` with `group` and `order` | ✅ |
| Menu configurability (user can reorder/hide) | Runtime menu editor in Configuration tab | No equivalent — menus are fixed | 🆕 |
| Dynamic `isVisible` / `isEnabled` | Per-action computed visibility (imperative Dart) | `when` clauses (declarative strings) | 🆕 (imperative) |

### 9. Two-Key Shortcut System (§11)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Trigger key popup | Press trigger → popup → second key | No equivalent | 🆕 |
| Shortcut editor with conflict detection | Built-in configuration view | Keyboard Shortcuts editor | ✅ |
| Shortcut rebinding at runtime | Config tab allows rebinding | Keybinding overrides | ✅ |

### 10. Auto-Save and File Revisioning (§12)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Auto-save on focus loss / idle | Configurable auto-save | `files.autoSave` setting | ✅ |
| `.forge/` folder for revisions | File history with snapshots | No equivalent — relies on git | 🆕 |
| Shell-routed file access (`ForgeFileSystem`) | All file ops through revisioning with events | `workspace.fs` (direct, no versioning) | 🆕 |
| Undo persistence across sessions | `.forge/undo/` stores undo stack | No equivalent — undo lost on close | 🆕 |
| File History view | Browse/diff/restore revisions | Timeline view (git-based) | 🆕 |

### 11. Configuration System (§9)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Built-in Configuration tab (⚙, pinned) | Always-present settings panel | Settings UI (Cmd+,) | 🔶 |
| Code-based defaults + runtime overrides | `ForgeConfig` → `.forge/config.json` | `defaultSettings` → `settings.json` | ✅ |
| Configuration views (Menu, Shortcuts, Modules, Layout, File Types) | Dedicated editors for each area | Mixed — Settings UI, Keyboard Shortcuts, Extensions view | 🆕 (integrated) |
| `ForgeConfigManager.onDidChange` | Configuration change stream | `workspace.onDidChangeConfiguration` | ✅ |

### 12. Startup Dialog (§13)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| Workspace picker at startup | Choose workspace + config directory | Welcome tab + `File > Open Folder` | 🆕 |
| Configuration directory selection | Where .forge data lives | No equivalent | 🆕 |
| Remembered preferences | Remember last workspace | Recent files/folders list | 🔶 |
| CLI override | Command-line bypass | `code /path/to/folder` | ✅ |

### 13. Layout Control

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `ForgeLayoutController` | Typed API: open/close/toggle panels, focus, openFile, openFileWith, split, reveal | `commands.executeCommand('workbench.action.*')` (string-based) | 🆕 (typed API) |
| Accordeon layout in side/bottom panels | Sections with mutual exclusion, pinning | VS Code views in sidebar (simpler) | 🆕 |
| Up to 4 middle panels | Configurable column count | Editor groups (unlimited, complex API) | 🔶 |
| Configuration tab pinned at bottom | Built-in, non-removable | No equivalent | 🆕 |
| `openFileWith(uri)` | "Open with" dialog with two-phase resolution | "Open With" command (simpler) | 🆕 |

### 14. Status Bar (§15)

| Forge API | Description | VS Code Equivalent | Status |
|-----------|-------------|--------------------|--------|
| `ForgeStatusBarController` | Status bar item management | `window.createStatusBarItem` | ✅ |
| `StatusBarItem.isActive(state)` | Context-sensitive activation | `StatusBarItem.alignment` + manual show/hide | 🆕 (reactive) |
| Reactive updates via `ValueNotifier` | Auto-update on state change | Manual `text` assignment | 🆕 (reactive) |

---

## Part 3 — Gap Analysis and Recommendations

### Remaining Critical Gaps (should add to Forge)

These are capabilities where Forge covers the same domain as VS Code but our API is thinner, or capabilities that visual tooling modules will commonly need:

| # | Gap | VS Code API | Recommendation for Forge | Priority |
|---|-----|-------------|--------------------------|----------|
| 1 | **Text editor decorations** | `createTextEditorDecorationType`, `setDecorations` | Add decoration support to `ForgeTextEditor` — modules contribute decorations (highlights, margin icons, underlines, error squiggles). Critical for any rich text editor experience. | High |
| 2 | **File decorations (explorer)** | `registerFileDecorationProvider` | Add `ForgeFileDecorationProvider` on `ForgeShellApi` — badges, colors on files in explorer (SCM status, build errors, ignored files). | High |
| 3 | **readBytes for binary files** | `workspace.fs.readFile` returns `Uint8Array` | Add `Future<Uint8List> readBytes(Uri uri)` to `ForgeFileSystem`. Currently `read()` returns `String` only, but `canHandleContent` takes `Uint8List`. Needed for binary file support and for the two-phase resolution flow. | High |
| 4 | **Multi-cursor / multi-selection** | `TextEditor.selections` (array) | Add `List<TextRange> get selections` and `void setSelections(List<TextRange>)` to `ForgeTextEditor`. Current single selection is limiting for any serious text editor. | Medium |
| 5 | **Visible ranges** | `TextEditor.visibleRanges`, `onDidChangeVisibleRanges` | Add `ValueListenable<TextRange> get visibleRange` to `ForgeTextEditor`. Needed for scroll-aware features: minimap, virtual rendering, lazy decoration. | Medium |
| 6 | **Editor options** | `TextEditor.options` (tabSize, insertSpaces, wordWrap) | Add `ForgeTextEditorOptions` to `ForgeTextEditor` — per-editor configurable options that override global defaults. | Medium |
| 7 | **Workspace edit (atomic multi-file)** | `workspace.applyEdit(WorkspaceEdit)` | Add `ForgeFileSystem.applyWorkspaceEdit(ForgeWorkspaceEdit)` — atomic multi-file edits for refactoring tools. Without this, a rename/refactor across files cannot be treated as one undo step. | Medium |
| 8 | **Virtual document provider** | `registerTextDocumentContentProvider` | Add `ForgeVirtualDocumentProvider` registration — modules provide content for custom URI schemes (computed/generated documents, diffs, previews). | Medium |
| 9 | **Outline / symbol provider** | `registerDocumentSymbolProvider` | Add `ForgeOutlineProvider` registration so `ForgeTextEditor` subclasses can feed structured outline data to the built-in Outline view. Without this the Outline view cannot show content from module editors. | Medium |
| 10 | **Document version** | `TextDocument.version` | Add `int get version` to `ForgeDocument` — increments on each edit. Useful for detecting stale references and concurrent modifications. | Low |
| 11 | **Untitled documents** | `TextDocument.isUntitled` | Add `bool get isUntitled` to `ForgeDocument` — tracks "new file" documents not yet saved to disk. | Low |
| 12 | **Secret storage** | `ExtensionContext.secrets` | Add `ForgeSecretStorage` on `ForgeShellApi` — secure storage for tokens, API keys. Needed for any module with authentication features. | Low |
| 13 | **Programmatic search** | Custom (no direct VS Code API either) | Add `ForgeSearchManager` on `ForgeShellApi` — programmatic text search with results stream. Needed for modules that want to search workspace files. | Low |

### Previously Identified Gaps — Now Resolved ✅

These gaps existed in the prior comparison (concept ≤v3) and have been addressed in v4/v5:

| # | Gap | Resolution |
|---|-----|------------|
| 1 | Notification/message API | `ForgeNotificationManager` — showInformation/Warning/Error with action buttons |
| 2 | Progress API | `ForgeProgressManager` — progress in status bar or overlay, with cancellation |
| 3 | Quick pick / input box | `ForgeDialogManager` — showQuickPick, showInputBox |
| 4 | File dialog | `ForgeDialogManager` — showOpenDialog, showSaveDialog |
| 5 | Clipboard API | `ForgeClipboard` — readText, writeText |
| 6 | External URI opener | `ForgeEnvironment.openExternal(uri)` |
| 7 | File system events | `ForgeFileSystem` — onDidChange, onDidSave, onWillSave, watch() |
| 8 | Document change events | `ForgeDocument.onDidChange` per text editor |
| 9 | Text editor APIs (document, selection, modification) | `ForgeTextEditor` / `ForgeDocument` — full text editor hierarchy |
| 10 | Per-module storage | `ForgeModuleStorage` — key-value store in `.forge/modules/<type>/` |
| 11 | Terminal API | `ForgeTerminalManager` — create, list, active, events |
| 12 | Configuration change event | `ForgeConfigManager.onDidChange` |
| 13 | Window focus state | `ForgeSystemState.isWindowFocused` + `onWindowFocusChanged` |
| 14 | Layout state (panels, middle panel count) | `ForgeSystemState.visiblePanels`, `middlePanelCount`, `activeMiddlePanelIndex` |
| 15 | File-to-editor sophistication | Two-phase resolution with content inspection + "Open with" dialog |
| 16 | Selection delegation | `ForgeSystemState` delegates to `ForgeTextEditor.selection` / `ForgeVisualEditor.selectedElements` |

### Lower Priority Gaps (evaluate later)

| # | Gap | Notes |
|---|-----|-------|
| 14 | Language services (completion, hover, go-to-definition, etc.) | Individual editor modules implement internally; optional shell-level `ForgeLanguageServiceRegistry` |
| 15 | Debug adapter protocol | Add with D4rt debugger integration |
| 16 | Task system | Could add simple process runner API (terminal mgr partially covers this) |
| 17 | Test API | Could add when test runner integration is needed |
| 18 | SCM API | Could add with Git view |
| 19 | Comment/annotation API | Could add for code review features |
| 20 | AI/LM API | Could add for Tom AI integration |
| 21 | Telemetry | Add if usage tracking is desired |
| 22 | i18n / localization | Add when internationalization is needed |
| 23 | Snippet system | Add if code editors need snippet support |
| 24 | Terminal link provider | Clickable links in terminal output |
| 25 | Terminal profile system | Shell selection, working dir presets |

### Forge-Only Features (advantages over VS Code)

| # | Feature | Value |
|---|---------|-------|
| 1 | **Unified system state API** | Single `ForgeSystemState` vs VS Code's scattered events across namespaces |
| 2 | **Multi-application model** | Multiple layouts alive simultaneously — VS Code only has one |
| 3 | **No module sandboxing** | Type-safe, same-process modules — zero IPC overhead, full API access |
| 4 | **Built-in file revisioning** | `.forge/` folder tracking revisions without requiring git |
| 5 | **Persistent undo across sessions** | Undo history survives app restart |
| 6 | **Two-key shortcut system** | Avoids OS/host app shortcut conflicts |
| 7 | **Menu configurability** | Users can reorder/hide menu items at runtime |
| 8 | **Accordeon with pinning** | More flexible panel layout than VS Code sidebar |
| 9 | **Multi-render with independent UI state** | SHIFT+drag creates copies with their own scroll/cursor |
| 10 | **Startup workspace/config picker** | User chooses both workspace and config storage location |
| 11 | **Imperative action visibility** | `isEnabled()`/`isVisible()` callbacks vs VS Code's declarative `when` strings |
| 12 | **Type-safe module cross-references** | `get<T>()` vs untyped `exports` object |
| 13 | **Reactive status bar items** | `ValueNotifier`-based auto-update vs manual text assignment |
| 14 | **Configuration tab always visible** | Pinned ⚙ in left panel vs separate settings editor |
| 15 | **Editor type hierarchy** | `ForgeTextEditor` / `ForgeVisualEditor` / `ForgeSchemaEditor` — typed editor APIs instead of VS Code's flat `TextEditor` + untyped custom editors |
| 16 | **Two-phase file resolution** | Content-aware editor matching vs VS Code's glob-only file association |
| 17 | **Schema editors** | Content-based detection with "Open with" additional options — no VS Code equivalent |
| 18 | **Action-level undo/redo** | `ForgeUndoManager` tracks action-level undo across the shell, not just per-editor |
| 19 | **Visual editor typed API** | `ForgeVisualEditor` with viewport, zoom, element selection — VS Code has no typed canvas editor API |
| 20 | **Programmatic find/replace** | `ForgeTextEditor.findAll()` / `replaceAll()` — VS Code has no programmatic find API |

---

## Part 4 — Concept Document API Completeness Audit

### Services on ForgeShellApi

| Service | Declared? | API Detailed? | Notes |
|---------|-----------|---------------|-------|
| `ForgeSystemState` | ✅ §10 | ✅ Full — all state + streams | — |
| `ForgeLayoutController` | ✅ §10.4 | ✅ Full — open/close/toggle panels, openFile, openFileWith, split, reveal | — |
| `ForgeStatusBarController` | ✅ §10.4 | 🔶 Minimal — just `List<StatusBarItem> get items` | Add register/remove methods |
| `ForgeFileSystem` | ✅ §10.4 | ✅ Full — read, write, save, delete, exists, stat, list, watch, events | Add `readBytes()` for binary |
| `ForgeModuleRegistry` | ✅ §10.4 | ✅ `get<T>()`, `allModules` | — |
| `ForgeOutputChannelManager` | ✅ §10.4 | ✅ Full — create, get, channels, ForgeOutputChannel methods | — |
| `ForgeDiagnosticManager` | ✅ §10.4 | ✅ Full — createCollection, all, forUri, Collection methods | — |
| `ForgeConfigManager` | ✅ §10.4 | ✅ Full — current, update, getModuleConfig, onDidChange, resetToDefaults | — |
| `ForgeNotificationManager` | ✅ §10.4 | ✅ Full — showInformation/Warning/Error with actions | — |
| `ForgeProgressManager` | ✅ §10.4 | ✅ Full — withProgress, reporter, cancellation | — |
| `ForgeDialogManager` | ✅ §10.4 | ✅ Full — quickPick, inputBox, openDialog, saveDialog | — |
| `ForgeTerminalManager` | ✅ §10.4 | ✅ Full — create, terminals, activeTerminal, events, ForgeTerminal methods | — |
| `ForgeClipboard` | ✅ §10.4 | ✅ Full — readText, writeText | — |
| `ForgeEnvironment` | ✅ §10.4 | ✅ Full — appName, openExternal | — |
| `ForgeModuleStorage` | ✅ §10.4 | ✅ Full — forModule, ForgeKeyValueStore methods | — |
| `ForgeUndoManager` | ✅ §10.4 | ✅ Full — undo, redo, canUndo, canRedo | — |
| `ForgeShortcutManager` | ✅ §10.4 | ✅ Full — allBindings, rebind, resetToDefault, conflictsWith | — |

### Component Contracts

| Component | Declared? | API Detailed? | Notes |
|-----------|-----------|---------------|-------|
| `ForgeComponent` | ✅ §4.3 | ✅ Full | Base contract |
| `ForgeEditor` | ✅ §4.3 | ✅ Full — canHandle/canHandleContent, isDirty, historyManager | Two-phase resolution |
| `ForgeTextEditor` | ✅ §4.3 | ✅ Full — document, cursor, selection, insert/delete/replace, find | v5 |
| `ForgeVisualEditor` | ✅ §4.3 | ✅ Full — elements, viewport, zoom | v5 |
| `ForgeSchemaEditor` | ✅ §4.3 | ✅ Full — canHandleContent, schemaLabel | v5 |
| `ForgeView` | ✅ §4.3 | ✅ Full | Minimal by design |
| `ForgeDocument` | ✅ §4.3 | ✅ Full — uri, text, lineCount, lineAt, languageId, encoding, isDirty, onDidChange | v5 |
| `ComponentHistoryManager` | ✅ §4.3 | ✅ Full | — |
| `ForgeModule` | ✅ §8 | ✅ Full | — |
| `ForgeAction` | ✅ §7 | ✅ Full | — |
| `ForgeShortcutBinding` | ✅ §11 | ✅ Full | — |
| `StatusBarItem` | ✅ §15 | ✅ Full | — |

### Built-In Views

| View | Mentioned? | API Access? | Notes |
|------|-----------|-------------|-------|
| Terminal | ✅ §14 | ✅ `ForgeTerminalManager` | Full API |
| Output | ✅ §14 | ✅ `ForgeOutputChannelManager` | Full API |
| Problems | ✅ §14 | ✅ `ForgeDiagnosticManager` | Full API |
| Explorer | ✅ §14 | 🔶 Selection exposed + `revealInExplorer` | No refresh API, no file decoration provider |
| Search | ✅ §14 | 🔶 `searchQuery`, `isSearchActive` in state | No programmatic search API |
| Outline | ✅ §14 | ❌ No outline data provider API | Needs `ForgeOutlineProvider` registration |
| File History | ✅ §14 | ❌ No revision browsing API | Managed by `ForgeFileSystem` revisions |

---

## Summary Statistics

| Category | v3 Count | v5 Count | Change |
|----------|----------|----------|--------|
| VS Code API items reviewed | ~210 | ~210 | — |
| Covered in Forge (✅) | ~45 | ~95 | **+50** |
| Partially covered (🔶) | ~30 | ~20 | -10 |
| Not covered — gap (❌) | ~105 | ~65 | **-40** |
| Not applicable (➖) | ~30 | ~30 | — |
| Forge-only features (🆕) | 14 | 20 | **+6** |
| Critical gaps remaining | 13 | 13 | different items |
| Previously critical, now resolved | — | 16 | **+16** |
