# Tom Markdown Editor Specification

## Overview

Tom Markdown Editor (`tom_md_editor`) is a Flutter widget for editing structured markdown documents with a graphical preview, section-based navigation, schema validation, and comprehensive theming support.

The editor displays formatted markdown in the main panel without showing raw markdown syntax. Users edit content in a text editor section below the preview, with real-time updates as they type. A collapsible tree view shows the document's section hierarchy, enabling drag-and-drop reorganization.

Integration with `tom_doc_scanner` and `tom_doc_specs` provides document structure parsing and schema-based validation, including automatic generation of required section structures from schemas.

---

## Terminology

The following terms align with `tom_doc_scanner` and `tom_doc_specs`:

| Term | Definition |
|------|------------|
| **Section** | A headline with its text content (until the next headline of equal or higher level). Sections can have nested subsections. |
| **Document** | The root section containing all content, with metadata (path, timestamp, schema). |
| **Schema** | A DocSpecs definition describing expected document structure, section types, and validation rules. |
| **Section ID** | Unique identifier from `[id]` or `<!--[id]-->` syntax in headlines. |
| **Section Name** | The headline text without ID markers. |
| **Section Text** | Content between the section's headline and the next headline. |
| **Subsections** | Child sections nested within a parent section. |
| **Validation Error** | A diagnostic indicating the document does not conform to its schema. |

---

## Core Concepts

### Section-Based Editing

The editor treats the document as a tree of sections, not raw text:

1. **Main Panel**: Displays rendered markdown (HTML-like presentation)
2. **Tree View**: Shows section hierarchy with expand/collapse and drag-drop
3. **Text Editor**: Appears when clicking on content in the main panel

When clicking:
- On a **headline**: Opens the headline text in the editor
- On **body text**: Opens the text between that headline and the next

### Schema Integration

Documents can declare a schema in the first headline field:

```markdown
# <!-- schema=quest-overview-1.0 --> My Document Title
```

When a schema is declared:
- Validation errors appear as markers in the tree and main panel
- Missing required sections are highlighted
- Auto-generation can scaffold required structure

---

## Component Architecture

### Widget Hierarchy

```
MdEditorWidget
├── MdEditorToolbar               # Optional: formatting buttons
├── Row/Column (responsive)
│   ├── MdTreeView                # Optional: section tree
│   │   └── MdTreeNode            # Recursive tree nodes
│   └── MdMainPanel               # Rendered markdown view
│       └── MdSectionView         # Individual section rendering
└── MdTextEditor                  # Plain text editing area
    └── DartCodeEditor (optional) # For code blocks
```

### State Management

```dart
class MdEditorController {
  Document document;              // Parsed document from doc_scanner
  SpecDoc? specDoc;               // Validated document (if schema present)
  String? schemaId;               // Declared schema identifier
  Section? selectedSection;       // Currently selected section
  List<ValidationError> errors;   // Schema validation errors
  
  // Edit operations
  void updateSectionText(Section section, String newText);
  void updateSectionHeadline(Section section, String newHeadline);
  void insertSection(Section? parent, int index, int level, String headline);
  void moveSection(Section section, Section? newParent, int newIndex);
  void deleteSection(Section section);
  
  // Schema operations
  void scaffoldFromSchema(DocSpecSchema schema);
  void validateDocument();
}
```

---

## Feature Specifications

### 1. Main Panel — Rendered Markdown View

The main panel displays formatted markdown as rendered HTML-like content:

**Rendering Requirements:**

| Element | Rendering |
|---------|-----------|
| Headlines (`#`-`######`) | Styled heading levels with clickable regions |
| Paragraphs | Normal text with proper spacing |
| Lists (ordered, unordered) | Bullet/number lists with indentation |
| Code blocks | Syntax-highlighted with language detection |
| Inline code | Monospace with background highlight |
| Bold, italic, strikethrough | Appropriate text styling |
| Links | Clickable with hover styling |
| Images | Rendered inline with alt text fallback |
| Tables | Proper table layout with edit icon on hover |
| Blockquotes | Indented with quote styling |
| Horizontal rules | Visual separator |
| **Mermaid diagrams** | Rendered as interactive diagrams |
| Task lists | Interactive checkboxes |
| Footnotes | Superscript links with hover preview |
| Math (KaTeX/LaTeX) | Rendered equations |

**Click Behaviors in Preview:**

| Element | Left-Click | Right-Click |
|---------|------------|-------------|
| Headline | Scroll to section, select in tree | Open context menu (edit, delete, add sibling/child) |
| Body text | Open text in raw text editor | Insert content menu (Table, Math, Mermaid, Code, custom plugins) |
| Code block | Navigate to source (if link) | Open code editor overlay |
| Link | Navigate to URL/anchor | Open context menu (edit link, copy URL) |
| Image | Open full size | Open context menu (edit, replace, properties) |
| Table | (hover shows edit icon) | Open table editor overlay |
| Mermaid diagram | Pan/zoom | Open source in editor overlay |
| Task checkbox | Toggle checked state | Open context menu |
| Math block | - | Open LaTeX editor overlay |
| Empty area | - | Insert content menu (Table, Math, Mermaid, Code, custom plugins) |

**Hover Behaviors:**

- Tables show an edit icon button; clicking opens table editor overlay
- Code blocks show a copy button and edit icon
- Links show tooltip with URL
- Images show alt text tooltip

### 2. Tree View — Section Navigator

The tree view shows document structure on the **left side** of the preview:

```
Document Title
├── Section 1
│   ├── Subsection 1.1
│   └── Subsection 1.2
├── Section 2
└── Section 3
    └── Subsection 3.1
```

**Features:**

| Feature | Description |
|---------|-------------|
| Expand/collapse | Toggle visibility of subsections |
| Selection | Click to select, highlight in main panel |
| Drag-and-drop | Reorder sections via drag |
| Context menu | Right-click for section operations |
| Validation markers | Error/warning icons on invalid sections |
| Search box | Below tree for document-wide search |

**Click Behaviors in Tree (distinct from preview):**

| Action | Left-Click | Right-Click |
|--------|------------|-------------|
| Section node | Select and scroll preview to section | Open full context menu |
| Expand icon | Toggle expand/collapse | - |
| Validation icon | Show error details | Quick-fix menu |
| Search result | Navigate to location, open in raw editor | - |

**Context Menu Operations:**

| Action | Description |
|--------|-------------|
| Add Section Above | Insert same-level section above |
| Add Section Below | Insert same-level section below |
| Add Subsection (Top) | Insert child section at top |
| Add Subsection (Bottom) | Insert child section at bottom |
| Rename Section | Edit headline text |
| Delete Section | Remove section and all subsections |
| Move Up | Swap with previous sibling |
| Move Down | Swap with next sibling |
| Promote | Decrease heading level (e.g., `###` → `##`) |
| Demote | Increase heading level (e.g., `##` → `###`) |

**Drag-and-Drop Rules:**

1. Sections can be dropped as siblings (before/after another section)
2. Sections can be dropped as children (inside another section)
3. Drop indicators show target position
4. Heading levels adjust automatically based on new parent
5. All subsections move with their parent

### 3. Search and Replace

A search box appears **below the navigation tree**. Results display as a clickable list.

**Search Features:**

| Feature | Description |
|---------|-------------|
| Search box | Text input with search/replace toggle |
| Results list | Clickable list below search box showing matches |
| Result navigation | Click result → scroll preview + open raw editor at location |
| Next/Previous | Keyboard shortcuts (F3, Shift+F3) or buttons |
| Replace | Replace current or replace all |
| Regex support | Optional regex mode |
| Case sensitivity | Toggle case-sensitive search |
| Scope | Search entire document or current section |

**Search Result Item:**

```
┌─────────────────────────────────┐
│ Section Name                    │
│ ...matched text with context... │
│ Line 42                         │
└─────────────────────────────────┘
```

Clicking a result:
1. Scrolls preview to the match location
2. Highlights the match in preview
3. Opens the containing section in raw text editor
4. Positions cursor at match location

### 4. Raw Text Editor

The raw text editor appears when content is selected. Position is configurable:
- **Below** the preview (default for wide screens)
- **Right** of the preview (better for tall/narrow screens)

User can **interactively switch** position via a toggle button or drag.

**Capabilities:**

| Feature | Description |
|---------|-------------|
| Plain text editing | Standard text input with markdown source |
| Live preview | Main panel updates as user types |
| Multiple cursors | Support for selection and multiple edit points |
| Undo/redo | Full edit history |
| Search/replace | Find and replace in current section |
| Syntax highlighting | Markdown syntax highlighting in raw view |

**Headline Marker Handling:**

If the user types headline markers (`#`, `##`, etc.) in the text:

1. Show warning marker in the editor
2. Display tooltip explaining the issue
3. Offer popup menu with options:
   - "Insert as Same-Level Section" — Split text and create new sibling
   - "Insert as Subsection" — Split text and create new child
   - "Keep as Text" — Escape the markers as literal text

### 5. Code Block Support

#### Supported Languages (Built-in Syntax Highlighting)

| Language | Alias(es) |
|----------|-----------|
| Dart | `dart` |
| JavaScript | `js`, `javascript` |
| TypeScript | `ts`, `typescript` |
| Python | `py`, `python` |
| Java | `java` |
| Kotlin | `kt`, `kotlin` |
| Swift | `swift` |
| C | `c` |
| C++ | `cpp`, `c++` |
| C# | `cs`, `csharp` |
| Go | `go`, `golang` |
| Rust | `rs`, `rust` |
| Ruby | `rb`, `ruby` |
| PHP | `php` |
| SQL | `sql` |
| HTML | `html` |
| CSS | `css` |
| SCSS | `scss`, `sass` |
| JSON | `json` |
| YAML | `yaml`, `yml` |
| XML | `xml` |
| Markdown | `md`, `markdown` |
| Shell | `sh`, `bash`, `zsh`, `shell` |
| PowerShell | `ps`, `powershell` |
| Dockerfile | `dockerfile` |
| Plain text | `text`, `plaintext` |

#### Syntax Highlighting Implementation

Syntax highlighting is provided by two packages:

| Package | Usage |
|---------|-------|
| `flutter_highlight` | Preview panel code block rendering |
| `code_text_field` | Inline editor with live syntax highlighting |
| `highlight` | Language mode definitions (shared by both) |

The `MdCodeHighlighting` utility class provides shared functionality:

```dart
class MdCodeHighlighting {
  /// Normalize language alias to canonical form.
  static String normalizeLanguage(String? language);

  /// Build syntax highlighting theme from editor theme.
  static Map<String, TextStyle> buildTheme(MdBasicTheme theme);
}
```

#### Code Editor Overlays

Code blocks can be edited in **overlay editors** with **inline syntax highlighting**. The editor uses `code_text_field` to provide real-time syntax coloring as the user types.

**Default Code Block Overlay:**

The built-in `MdCodeBlockOverlay` provides:

- **Language label** — Shows the code block language
- **Inline syntax highlighting** — Real-time coloring using `CodeController` and `CodeField`
- **Save/Cancel buttons** — Commit or discard changes
- **Theme-aware styling** — Colors match the editor's dark/light theme

```dart
// Internal implementation using code_text_field
CodeController(
  text: initialCode,
  language: highlight.getMode(language),
)

// Wrapped in CodeTheme for proper token styling
CodeTheme(
  data: CodeThemeData(styles: MdCodeHighlighting.buildTheme(theme)),
  child: CodeField(
    controller: controller,
    expands: false,
    // ...
  ),
)
```

**Registering Custom Code Editors:**

```dart
MdEditor(
  markdown: content,
  codeEditorRegistry: MdCodeEditorRegistry([
    // Use our Dart editor for Dart code
    MdCodeEditorRegistration(
      languages: ['dart'],
      editorBuilder: (code, onChanged) => DartCodeEditor(
        controller: DartCodeController(userCode: code),
        onChanged: onChanged,
      ),
    ),
    // Custom Python editor
    MdCodeEditorRegistration(
      languages: ['python', 'py'],
      editorBuilder: (code, onChanged) => PythonEditor(
        code: code,
        onChanged: onChanged,
      ),
    ),
  ]),
)
```

**MdCodeEditorRegistry API:**

```dart
class MdCodeEditorRegistry {
  MdCodeEditorRegistry(List<MdCodeEditorRegistration> registrations);
  
  /// Register an editor for languages
  void register(MdCodeEditorRegistration registration);
  
  /// Get editor for a language (returns default if not registered)
  Widget buildEditor(String language, String code, ValueChanged<String> onChanged);
  
  /// Check if custom editor exists for language
  bool hasCustomEditor(String language);
}

class MdCodeEditorRegistration {
  final List<String> languages;
  final Widget Function(String code, ValueChanged<String> onChanged) editorBuilder;
  final String? displayName;  // e.g., "Dart Editor"
  final IconData? icon;
}
```

#### Custom Language Renderers

For languages without built-in syntax highlighting, register custom renderers:

```dart
MdEditor(
  markdown: content,
  languageRenderers: MdLanguageRendererRegistry([
    // Custom renderer for a DSL
    MdLanguageRenderer(
      languages: ['mydsl'],
      renderer: (code, theme) => MyDslHighlighter(
        code: code,
        colors: theme.syntaxColors,
      ),
    ),
    // Render as diagram instead of code
    MdLanguageRenderer(
      languages: ['plantuml'],
      renderer: (code, theme) => PlantUmlDiagram(source: code),
    ),
  ]),
)
```

**MdLanguageRenderer API:**

```dart
class MdLanguageRendererRegistry {
  MdLanguageRendererRegistry(List<MdLanguageRenderer> renderers);
  
  void register(MdLanguageRenderer renderer);
  Widget? buildRenderer(String language, String code, MdBasicTheme theme);
}

class MdLanguageRenderer {
  final List<String> languages;
  final Widget Function(String code, MdBasicTheme theme) renderer;
}
```

### 6. Table Editor

Tables have a dedicated overlay editor for structured manipulation.

**Opening the Table Editor:**
- Hover over table in preview → Edit icon appears
- Click edit icon → Table editor overlay opens
- Right-click table → "Edit Table" in context menu

**Table Editor Features:**

| Feature | Description |
|---------|-------------|
| Cell editing | Click cell to edit inline |
| Add row | Button or keyboard shortcut (Ctrl+Enter) |
| Delete row | Select row, delete key or button |
| Add column | Button or context menu |
| Delete column | Select column header, delete |
| Move row up/down | Drag or arrow buttons |
| Move column left/right | Drag header or buttons |
| Header row toggle | Convert first row to/from header |
| Alignment | Set column alignment (left/center/right) |
| Sort | Sort by column (temporary preview) |

**Table Editor Overlay:**

```
┌─────────────────────────────────────────────┐
│ Table Editor                           [X]  │
├─────────────────────────────────────────────┤
│ [+ Row] [+ Col] [Alignment ▼] [Done]        │
├─────────────────────────────────────────────┤
│   │ Header 1    │ Header 2    │ Header 3   │
│ ≡ │ Cell A1     │ Cell B1     │ Cell C1    │
│ ≡ │ Cell A2     │ Cell B2     │ Cell C2    │
│ ≡ │ Cell A3     │ Cell B3     │ Cell C3    │
└─────────────────────────────────────────────┘
  ↑ drag handle for row reordering
```

When closed, the preview and raw text editor update with changes.

### 7. Task List Interaction

Task lists (`- [ ]` and `- [x]`) are **interactively editable** in the preview.

**Behavior:**
- Left-click checkbox → Toggle checked/unchecked state
- Right-click checkbox → Context menu (delete item, convert to regular list)
- The underlying markdown updates automatically

**Example:**
```markdown
- [x] Completed task
- [ ] Pending task
```

Clicking the unchecked box changes it to:
```markdown
- [x] Completed task
- [x] Pending task  ← now checked
```

### 8. Mermaid Diagram Support

Mermaid diagrams are rendered as interactive visualizations:

**Supported Diagram Types:**

| Type | Support Level |
|------|--------------|
| Flowchart | Full |
| Sequence diagram | Full |
| Class diagram | Full |
| State diagram | Full |
| Entity relationship | Full |
| User journey | Full |
| Gantt chart | Full |
| Pie chart | Full |
| Mindmap | Full |
| Timeline | Full |
| Quadrant chart | Full |
| Git graph | Full |

**Mermaid Features:**

- Live rendering in preview
- Error highlighting for invalid syntax
- Click-to-edit opens source
- Export as SVG/PNG
- Pan/zoom for large diagrams

### 9. Schema Validation and Scaffolding

Integration with `tom_doc_specs` for document validation. The editor provides UI controls for picking schemas and generating skeleton documents.

**Schema Declaration:**

Documents declare their schema via a comment in the first line:

```markdown
<!-- docspec: specification/1.0 -->
# My Document Title
```

**Schema Picker:**

Users can associate a schema with a document via:

- **Toolbar button** — "Pick Schema" button opens a file picker
- **Configurable folder** — Schema files are loaded from a configurable `docSpecsSchemaFolder` path (defaults to `.tom/docspecs-schema/` in the workspace)
- **Auto-insert** — When a schema is selected, the editor inserts the `<!-- docspec: ... -->` comment automatically

```dart
MdEditorSettings(
  // Path to folder containing .docspec-schema.yaml files
  docSpecsSchemaFolder: '/path/to/.tom/docspecs-schema',
)
```

**Skeleton Generation:**

Once a schema is loaded, the user can generate a skeleton document containing all required sections:

```dart
// Generate skeleton from schema using tom_doc_specs
final skeleton = DocSpecsSkeletonGenerator.generate(schema);
controller.markdown = skeleton;
```

The skeleton includes:
- DocSpec schema comment at the top
- All required sections with correct heading levels
- Section IDs matching the schema prefix patterns
- Placeholder text indicating where content should be added
- Schema description comments for guidance

**Example generated skeleton:**

```markdown
<!-- docspec: specification/1.0 -->

# [overview-title] Document Title

<!-- Brief description of what the component does and why it exists -->

TODO: Add content for this section.

## [overview-main] Overview

TODO: Add content for this section.

## [terminology-main] Terminology

### [term-term_1] Term 1

<!-- Single term definition -->

TODO: Add content for this section.
```

**Validation Features:**

| Feature | Description |
|---------|-------------|
| Real-time validation | Errors update as document changes |
| Error display | Markers in tree and inline in preview |
| Quick fixes | Suggested actions for common errors |
| Schema info | Hover to see expected structure |

**Validation Error Types:**

| Error | Description |
|-------|-------------|
| Missing required section | Schema requires section that doesn't exist |
| Invalid section type | Section ID doesn't match any type prefix |
| Exceeds max count | Too many sections of a type |
| Missing required text | Section text is empty when required |
| Text too short/long | Text violates length constraints |
| Invalid ID pattern | ID doesn't match required pattern |
| Missing field | Required form field not present |
| Invalid subsection | Child section type not allowed |

**MdSchemaValidator:**

The `MdSchemaValidator` class adapts `tom_doc_specs` validation for the editor's model:

```dart
class MdSchemaValidator {
  /// Whether a schema is loaded.
  bool get hasSchema;

  /// Current schema ID.
  String? get schemaId;

  /// Set the schema to validate against.
  void setSchema(DocSpecSchema schema);

  /// Clear the current schema.
  void clearSchema();

  /// Validate an MdDocument against the loaded schema.
  List<ValidationError> validate(MdDocument document);
}
```

**Controller Schema Methods:**

```dart
class MdEditorController {
  /// Set a schema for document validation.
  void setSchema(DocSpecSchema schema);

  /// Clear the schema, removing all validation errors.
  void clearSchema();

  /// Current validation errors.
  List<ValidationError> get validationErrors;

  /// Schema ID from the document (if declared).
  String? get schemaId;
}
```

### 10. Content Plugin System

The editor uses an extensible **content plugin architecture** for rendering and editing rich content blocks (tables, math, mermaid diagrams, code blocks, and custom content types). Plugins handle detection, rendering, editing, and insertion of content — replacing the earlier `MdContentRenderer` interface with a more capable, unified system.

#### Plugin Architecture Overview

```
MdPluginRegistry
├── MdTablePlugin        (built-in, preprocessor-based)
├── MdMathPlugin         (built-in, preprocessor-based)
├── MdMermaidPlugin      (built-in, fenced code block)
├── MdCodePlugin         (built-in, insert-only)
└── [Custom plugins]     (user-registered)
```

**Two detection mechanisms:**

| Mechanism | Used By | How It Works |
|-----------|---------|--------------|
| **Preprocessor** | Tables, Math | Regex-matches non-fenced markdown, converts to synthetic fenced blocks (e.g., `` ```table-edit-0 ``) before rendering |
| **Fenced code block** | Mermaid, Code | Matches the language tag of native fenced code blocks (e.g., `` ```mermaid ``) |

#### MdPreprocessor

Transforms non-fenced markdown content into synthetic fenced code blocks so the code block builder pipeline can render and edit them.

```dart
class MdPreprocessor {
  const MdPreprocessor({
    required this.pattern,
    required this.tagPrefix,
    this.contentExtractor,
  });

  /// Regex to match the content in raw markdown.
  final RegExp pattern;

  /// Prefix for the synthetic language tag (e.g., `table-edit`).
  /// The full tag will be `{tagPrefix}-{index}`.
  final String tagPrefix;

  /// Extracts the renderable content from a regex match.
  /// If null, uses the full match as fenced block content.
  /// Example: math preprocessor extracts LaTeX from within `$$..$$`.
  final String Function(Match m)? contentExtractor;
}
```

**Preprocessing flow:**

1. Before markdown rendering, each plugin's preprocessor regex is applied
2. Matches are replaced with synthetic fenced code blocks: `` ```{tagPrefix}-{index}\ncontent\n``` ``
3. Original content is stored in a `contentMap` keyed by the synthetic tag
4. The code block builder looks up the plugin by synthetic tag and delegates rendering

#### MdContentPlugin — Abstract Plugin Interface

Every content plugin implements `MdContentPlugin`:

```dart
abstract class MdContentPlugin {
  /// Unique identifier (e.g., 'table', 'mermaid', 'math', 'code').
  String get id;

  /// Display name shown in context menus and UI.
  String get displayName;

  /// Icon shown in context menus and overlay buttons.
  IconData get icon;

  /// Whether this plugin appears in the insert context menu.
  bool get canInsert => true;

  /// Default markdown template inserted via the context menu.
  String get insertTemplate;

  /// Languages this plugin handles in fenced code blocks.
  /// Empty if plugin only uses preprocessing.
  List<String> get languages;

  /// Optional preprocessor for non-fenced content.
  /// Return null if only handling native fenced code blocks.
  MdPreprocessor? get preprocessor => null;

  /// Whether this plugin handles the given language tag.
  /// Override for dynamic matching (e.g., prefix-based: 'table-edit-0').
  bool matchesLanguage(String language);

  /// Build the preview widget. Return null to fall through to default rendering.
  Widget? buildPreview(String content, MdBasicTheme theme, {required VoidCallback onEdit});

  /// Open the editor dialog. Returns edited content, or null if cancelled.
  Future<String?> openEditor(BuildContext context, String currentContent, MdEditorTheme theme);

  /// Wrap edited content into its full markdown syntax for storage.
  String wrapForMarkdown(String content);
}
```

**Plugin lifecycle per content block:**

| Step | Method | Description |
|------|--------|-------------|
| 1. Detection | `preprocessor` or `matchesLanguage()` | Find the right plugin for content |
| 2. Rendering | `buildPreview()` | Render preview widget with hover edit button |
| 3. Editing | `openEditor()` | Open overlay editor, return edited content |
| 4. Wrapping | `wrapForMarkdown()` | Convert back to markdown syntax |
| 5. Insertion | `insertTemplate` | Template for inserting new content via context menu |

#### MdPluginRegistry

Central registry for all content plugins:

```dart
class MdPluginRegistry {
  MdPluginRegistry([List<MdContentPlugin>? plugins]);

  /// Register a content plugin.
  void register(MdContentPlugin plugin);

  /// Find the plugin that handles the given language tag.
  MdContentPlugin? forLanguage(String language);

  /// Find a plugin by its unique ID.
  MdContentPlugin? forId(String id);

  /// All plugins that can be inserted via the context menu.
  List<MdContentPlugin> get insertable;

  /// All registered plugins.
  List<MdContentPlugin> get all;
}
```

#### Built-In Plugins

##### MdTablePlugin

| Property | Value |
|----------|-------|
| ID | `table` |
| Detection | Preprocessor: regex matches markdown table syntax |
| Tag prefix | `table-edit` (dynamic: `table-edit-0`, `table-edit-1`, ...) |
| Preview | Interactive `Table` widget with hover edit button |
| Editor | `MdTableOverlay` (cell editing, add/remove rows/columns) |
| `wrapForMarkdown` | Returns content as-is (tables are their own markdown) |
| Insert template | 3-column table with header and one data row |

##### MdMathPlugin

| Property | Value |
|----------|-------|
| ID | `math` |
| Detection | Preprocessor: `$$..$$` pattern with content extraction |
| Tag prefix | `math-display` (dynamic: `math-display-0`, `math-display-1`, ...) |
| Preview | Rendered LaTeX via `flutter_math_fork` with hover edit button |
| Editor | `MdMathOverlay` (LaTeX editor with live preview) |
| `wrapForMarkdown` | Wraps in `$$\n...\n$$` |
| Insert template | `$$\nE = mc^2\n$$` |

**Note:** Inline math (`$...$`) is handled separately by the preview panel's inline syntax extension, not by this plugin.

##### MdMermaidPlugin

| Property | Value |
|----------|-------|
| ID | `mermaid` |
| Detection | Fenced code block language: `mermaid` |
| Preprocessor | None (native fenced block) |
| Preview | `MermaidDiagram` widget (renders supported types), falls back to source display |
| Editor | Text-based `MdMermaidOverlay`, or custom `MdMermaidDiagramEditor` per diagram type |
| `wrapForMarkdown` | Wraps in `` ```mermaid\n...\n``` `` |
| Insert template | Flowchart: `graph TD\n  A[Start] --> B[End]` |

**Diagram type detection:** The plugin inspects the first line of the mermaid source to determine the diagram type:

| Prefix | Diagram Type |
|--------|-------------|
| `graph`, `flowchart` | `flowchart` |
| `sequenceDiagram` | `sequence` |
| `classDiagram` | `class` |
| `stateDiagram` | `state` |
| `erDiagram` | `er` |
| `pie` | `pie` |
| `gantt` | `gantt` |
| `timeline` | `timeline` |
| `kanban` | `kanban` |
| `mindmap` | `mindmap` |
| `xychart-beta` | `xychart` |
| `radar-beta` | `radar` |
| `gitGraph` | `git` |
| `journey` | `journey` |
| `quadrantChart` | `quadrant` |

##### MdCodePlugin

| Property | Value |
|----------|-------|
| ID | `code` |
| Detection | None — `matchesLanguage()` always returns `false` |
| Purpose | Insert-only; provides the "Code Block" context menu entry |
| Preview | `null` — code blocks use the default code block widget |
| Editor | `MdCodeBlockOverlay` |
| `wrapForMarkdown` | Wraps in `` ```\n...\n``` `` |
| Insert template | `` ```\n// code here\n``` `` |

#### Registering Custom Content Plugins

Create a custom plugin by extending `MdContentPlugin` and register it with the plugin registry:

```dart
// 1. Define a custom plugin
class PlantUmlPlugin extends MdContentPlugin {
  @override String get id => 'plantuml';
  @override String get displayName => 'PlantUML Diagram';
  @override IconData get icon => Icons.account_tree;
  @override List<String> get languages => ['plantuml'];
  @override String get insertTemplate => '```plantuml\n@startuml\nAlice -> Bob\n@enduml\n```';

  @override
  Widget? buildPreview(String content, MdBasicTheme theme, {required VoidCallback onEdit}) {
    return PlantUmlPreview(source: content, onEdit: onEdit);
  }

  @override
  Future<String?> openEditor(BuildContext context, String content, MdEditorTheme theme) {
    return showDialog<String>(
      context: context,
      builder: (_) => PlantUmlEditorDialog(source: content, theme: theme),
    );
  }

  @override
  String wrapForMarkdown(String content) => '```plantuml\n$content\n```';
}

// 2. Register with MdEditor via pluginRegistry
final registry = createDefaultPluginRegistry();
registry.register(PlantUmlPlugin());

MdEditor(
  markdown: content,
  pluginRegistry: registry,
)
```

**Preprocessor-based custom plugin** (for non-fenced content):

```dart
class AlertBoxPlugin extends MdContentPlugin {
  @override String get id => 'alert';
  @override String get displayName => 'Alert Box';
  @override IconData get icon => Icons.warning;
  @override List<String> get languages => [];
  @override String get insertTemplate => '::: warning\nAlert text here\n:::';

  @override
  bool matchesLanguage(String language) => language.startsWith('alert-box-');

  @override
  MdPreprocessor get preprocessor => MdPreprocessor(
    pattern: RegExp(r'^:::\s*(warning|info|danger)\n([\s\S]*?)^:::', multiLine: true),
    tagPrefix: 'alert-box',
    contentExtractor: (m) => '${m.group(1)}\n${m.group(2)!.trim()}',
  );

  @override
  Widget? buildPreview(String content, MdBasicTheme theme, {required VoidCallback onEdit}) {
    final lines = content.split('\n');
    final type = lines.first;
    final text = lines.skip(1).join('\n');
    return AlertBoxWidget(type: type, text: text, onEdit: onEdit);
  }

  @override
  Future<String?> openEditor(BuildContext context, String content, MdEditorTheme theme) {
    // ... editor dialog
  }

  @override
  String wrapForMarkdown(String content) {
    final lines = content.split('\n');
    return '::: ${lines.first}\n${lines.skip(1).join('\n')}\n:::';
  }
}
```

#### Default Plugin Registry Factory

The `createDefaultPluginRegistry()` factory creates a registry with all built-in plugins, respecting editor settings:

```dart
MdPluginRegistry createDefaultPluginRegistry({MdEditorSettings? settings});
```

| Plugin | Condition |
|--------|-----------|
| `MdTablePlugin` | Always included |
| `MdMathPlugin` | When `settings.enableMath` is `true` |
| `MdMermaidPlugin` | When `settings.enableMermaid` is `true` |
| `MdCodePlugin` | Always included |

If no `pluginRegistry` is passed to `MdEditor`, the default registry is created automatically based on the current `MdEditorSettings`.

#### MdMermaidDiagramEditor — Custom Graphical Editors for Mermaid

The `MdMermaidPlugin` supports registering custom graphical editors for specific Mermaid diagram types. This enables visual editors (e.g., a node-and-edge editor for flowcharts) to be plugged in alongside the default text-based editor.

```dart
abstract class MdMermaidDiagramEditor {
  /// The diagram type this editor handles (e.g., 'flowchart', 'sequence').
  String get diagramType;

  /// Display name for the editor.
  String get displayName;

  /// Open the graphical editor. Returns edited Mermaid source, or null if cancelled.
  Future<String?> openEditor(BuildContext context, String currentSource, MdEditorTheme theme);
}
```

**Registering a custom Mermaid diagram editor:**

```dart
class FlowchartVisualEditor implements MdMermaidDiagramEditor {
  @override String get diagramType => 'flowchart';
  @override String get displayName => 'Visual Flowchart Editor';

  @override
  Future<String?> openEditor(BuildContext context, String source, MdEditorTheme theme) {
    return showDialog<String>(
      context: context,
      builder: (_) => FlowchartEditorDialog(source: source),
    );
  }
}

// Register via constructor
final mermaidPlugin = MdMermaidPlugin(
  diagramEditors: [FlowchartVisualEditor()],
);

// Or register after creation
mermaidPlugin.registerDiagramEditor(FlowchartVisualEditor());
```

**Editor dispatch behavior:**

1. When a mermaid diagram is edited, the plugin detects the diagram type from the source
2. If a custom `MdMermaidDiagramEditor` is registered for that type, it receives the edit request
3. Otherwise, the default text-based `MdMermaidOverlay` is used

#### Insert Context Menu

Right-clicking in the preview panel opens an insert context menu populated by the plugin registry. Each registered plugin with `canInsert == true` appears as a menu entry with its `displayName` and `icon`.

**Behavior:**

| Action | Result |
|--------|--------|
| Right-click on preview panel | Shows insert context menu |
| Select a plugin entry | Inserts `plugin.insertTemplate` at the end of the document |
| Template is appended | Raw text editor and preview update immediately |

**Menu entries (default registry):**

| Plugin | Menu Label | Icon | Template |
|--------|-----------|------|----------|
| Table | Table | `table_chart` | 3-column markdown table |
| Math (LaTeX) | Math (LaTeX) | `functions` | `$$\nE = mc^2\n$$` |
| Mermaid Diagram | Mermaid Diagram | `schema` | Flowchart template |
| Code Block | Code Block | `code` | Empty fenced code block |

#### MdOverlayButton

Shared widget used by plugins for hover-triggered action buttons (edit, copy, etc.):

```dart
class MdOverlayButton extends StatelessWidget {
  const MdOverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.theme,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final MdBasicTheme theme;
}
```

All built-in plugins use `MdOverlayButton` for their hover edit buttons, ensuring a consistent look and feel.

---

## Component Architecture

The editor's complexity justifies a modular component architecture. Each major feature is a separate component that can be developed, tested, and themed independently.

### Core Components

```
MdEditor (orchestrator)
├── MdPluginRegistry            # Content plugin registry
│   ├── MdTablePlugin           # Table rendering & editing
│   ├── MdMathPlugin            # LaTeX math rendering & editing
│   ├── MdMermaidPlugin         # Mermaid diagram rendering & editing
│   ├── MdCodePlugin            # Code block insertion
│   └── [Custom plugins]        # User-registered plugins
│
├── MdNavigationPanel
│   ├── MdTreeView              # Section tree with drag-drop
│   ├── MdSearchBox             # Search input
│   └── MdSearchResults         # Clickable results list
│
├── MdPreviewPanel
│   ├── MdMarkdownRenderer      # Core markdown rendering
│   ├── MdSectionRenderer       # Section-aware rendering with click zones
│   ├── Plugin preprocessing    # Regex → synthetic fenced blocks
│   ├── Plugin code block builder # Delegates to plugin.buildPreview()
│   └── Insert context menu     # Right-click to insert content
│
├── MdRawTextEditor             # Plain text markdown editing
│
└── Overlay Editors (modal):
    ├── MdCodeBlockOverlay      # Code block editing
    ├── MdTableOverlay          # Table manipulation
    ├── MdMermaidOverlay        # Diagram source editing
    ├── MdMathOverlay           # LaTeX editing
    └── [Custom editors]        # Plugin-provided editors
```

### Component Interfaces

Content rendering and editing is handled by the plugin system. Each plugin implements `MdContentPlugin` (see Section 10: Content Plugin System for the full API).

```dart
abstract class MdContentPlugin {
  String get id;
  String get displayName;
  IconData get icon;
  bool get canInsert;
  String get insertTemplate;
  List<String> get languages;
  MdPreprocessor? get preprocessor;
  bool matchesLanguage(String language);
  Widget? buildPreview(String content, MdBasicTheme theme, {required VoidCallback onEdit});
  Future<String?> openEditor(BuildContext context, String currentContent, MdEditorTheme theme);
  String wrapForMarkdown(String content);
}
```

Plugins are registered in an `MdPluginRegistry` and passed to `MdEditor` via the `pluginRegistry` parameter. See Section 10 for full details on creating and registering custom plugins.

### Registering Custom Content Plugins

```dart
final registry = createDefaultPluginRegistry();
registry.register(PlantUmlPlugin());
registry.register(ChartJsPlugin());

MdEditor(
  markdown: content,
  pluginRegistry: registry,
)
```

### Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│ Toolbar (optional)                                          │
├────────────┬────────────────────────────────────────────────┤
│            │                                                │
│ Tree View  │  Preview Panel                                 │
│            │  (rendered markdown)                           │
│            │                                                │
│ ══════════ │ ← draggable separator                         │
│            │                                                │
│ Search Box │                                                │
│            │                                                │
│ ══════════ │ ← draggable separator                         │
│            ├────────────────────────────────────────────────┤
│ Search     │  Raw Text Editor                               │
│ Results    │  (markdown source)                             │
│            │                                                │
├────────────┴────────────────────────────────────────────────┤
│ Status Bar (optional)                                       │
└─────────────────────────────────────────────────────────────┘
     ↑                    ↑
     └── draggable ───────┘
```

**Alternative Layout (Raw Editor on Right):**

```
┌─────────────────────────────────────────────────────────────┐
│ Toolbar                                                     │
├────────────┬──────────────────────────┬─────────────────────┤
│            │                          │                     │
│ Tree View  │  Preview Panel           │  Raw Text Editor    │
│            │                          │                     │
│ ══════════ │                          │                     │
│            │                          │                     │
│ Search Box │                          │                     │
│ ══════════ │                          │                     │
│ Results    │                          │                     │
│            │                          │                     │
├────────────┴──────────────────────────┴─────────────────────┤
│ Status Bar                                                  │
└─────────────────────────────────────────────────────────────┘
                          ↑                    ↑
                          └── draggable ───────┘
```

### Draggable Separators

All panel separators are draggable to resize:

| Separator | Between | Behavior |
|-----------|---------|----------|
| Tree/Preview | Navigation panel and preview | Horizontal drag |
| Preview/Editor | Preview and raw editor (when below) | Vertical drag |
| Preview/Editor | Preview and raw editor (when right) | Horizontal drag |
| Tree/Search | Tree view and search box | Vertical drag |
| Search/Results | Search box and results list | Vertical drag |

```dart
class MdEditorSettings {
  // ... other settings ...
  
  /// Position of raw text editor relative to preview
  final RawEditorPosition rawEditorPosition;  // below, right
  
  /// Allow user to interactively change editor position
  final bool allowEditorPositionChange;
  
  /// Remember separator positions
  final bool persistSeparatorPositions;
  
  /// Initial/default separator positions (0.0-1.0)
  final double treePanelWidth;       // default: 0.25
  final double rawEditorHeight;      // default: 0.35 (when below)
  final double rawEditorWidth;       // default: 0.4 (when right)
  final double searchResultsHeight;  // default: 0.5 of nav panel
}

enum RawEditorPosition { below, right }
```

---

## Theming System

### Design Philosophy

The theming system integrates with Flutter's `ThemeData` and leverages the markdown renderer's styling capabilities. Two complementary levels:

1. **Basic Theme** — Comprehensive styling that covers most use cases without per-tag work
2. **Tag Overrides** — Hierarchical overrides for fine-grained control when needed

Most users only need the basic theme. Tag overrides use inheritance so you specify only differences from the base.

### Theme Structure

```dart
class MdEditorTheme {
  // Comprehensive basic theme (covers 90% of use cases)
  final MdBasicTheme basic;
  
  // Optional: hierarchical tag overrides
  final MdTagOverrides? tagOverrides;
  
  // Component themes (derive from basic by default)
  final MdTreeTheme? tree;
  final MdToolbarTheme? toolbar;
  final MdTextEditorTheme? textEditor;
  
  // Integration with Flutter theme
  factory MdEditorTheme.fromThemeData(ThemeData theme);
  
  // Built-in themes
  static MdEditorTheme dark();
  static MdEditorTheme light();
}
```

### Basic Theme (Comprehensive)

The basic theme provides complete styling for all elements using semantic tokens. Element styles are derived automatically.

```dart
class MdBasicTheme {
  // === Color Palette ===
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSecondary;
  final Color border;
  final Color borderSubtle;
  final Color selection;
  final Color highlight;
  final Color error;
  final Color warning;
  final Color success;
  
  // === Typography ===
  final String fontFamily;
  final String monoFontFamily;
  final double baseFontSize;
  final double lineHeight;
  final FontWeight normalWeight;
  final FontWeight boldWeight;
  
  // Heading scale (multipliers of baseFontSize)
  final double h1Scale;  // default: 2.0
  final double h2Scale;  // default: 1.5
  final double h3Scale;  // default: 1.25
  final double h4Scale;  // default: 1.1
  final double h5Scale;  // default: 1.0
  final double h6Scale;  // default: 0.9
  
  // Heading shared style
  final FontWeight headingWeight;
  final double headingLineHeight;
  final Color? headingColor;  // null = use text color
  final bool headingBorderBottom;  // h1/h2 get border
  
  // === Spacing ===
  final double sectionSpacing;
  final double paragraphSpacing;
  final double headingMarginTop;
  final double headingMarginBottom;
  final double listIndent;
  final double blockPadding;
  final double blockMargin;
  
  // === Block Styling ===
  final double borderRadius;
  final double borderWidth;
  
  // Code blocks
  final Color codeBackground;
  final Color codeBorder;
  final Color inlineCodeBackground;
  final SyntaxColorScheme syntaxColors;  // or use syntaxTheme name
  final String? syntaxTheme;  // 'monokai', 'github', 'dracula', etc.
  
  // Blockquotes
  final Color blockquoteBackground;
  final Color blockquoteBorder;
  final double blockquoteBorderWidth;
  
  // Tables
  final Color tableHeaderBackground;
  final Color tableRowAlternate;
  final Color tableBorder;
  
  // Links
  final Color linkColor;
  final Color linkHoverColor;
  final TextDecoration linkDecoration;
  
  // === Derived Styles ===
  // These are computed from the above values
  TextStyle get h1Style => ...;
  TextStyle get h2Style => ...;
  TextStyle get paragraphStyle => ...;
  BoxDecoration get codeBlockDecoration => ...;
  // etc.
}
```

### Tag Overrides (Hierarchical)

For fine-grained control, tag overrides use inheritance. Each level inherits from its parent and only specifies differences.

```dart
class MdTagOverrides {
  // Base styles that descendants inherit from
  final MdTextStyleOverride? textBase;      // All text inherits
  final MdHeadingStyleOverride? headingBase; // All headings inherit
  final MdBlockStyleOverride? blockBase;    // All blocks inherit
  final MdListStyleOverride? listBase;      // All lists inherit
  
  // Specific overrides (inherit from base, specify only differences)
  final MdHeadingStyleOverride? h1;
  final MdHeadingStyleOverride? h2;
  final MdHeadingStyleOverride? h3;
  final MdHeadingStyleOverride? h4;
  final MdHeadingStyleOverride? h5;
  final MdHeadingStyleOverride? h6;
  
  final MdTextStyleOverride? paragraph;
  final MdTextStyleOverride? bold;
  final MdTextStyleOverride? italic;
  final MdTextStyleOverride? strikethrough;
  final MdTextStyleOverride? inlineCode;
  
  final MdBlockStyleOverride? codeBlock;
  final MdBlockStyleOverride? blockquote;
  final MdBlockStyleOverride? table;
  final MdBlockStyleOverride? mermaid;
  
  final MdListStyleOverride? orderedList;
  final MdListStyleOverride? unorderedList;
  final MdListStyleOverride? taskList;
  
  final MdLinkStyleOverride? link;
  final MdImageStyleOverride? image;
}
```

### Override Classes (Nullable Fields = Inherit)

Override classes use nullable fields — `null` means inherit from parent/base:

```dart
class MdHeadingStyleOverride {
  final Color? color;           // null = inherit from headingBase or basic.headingColor
  final double? fontSize;       // null = use scale from basic theme
  final FontWeight? fontWeight; // null = inherit from headingBase
  final double? marginTop;
  final double? marginBottom;
  final Color? borderBottomColor;
  final double? borderBottomWidth;
  final double? letterSpacing;
  
  // Merge with parent override
  MdHeadingStyleOverride merge(MdHeadingStyleOverride? parent);
}

class MdBlockStyleOverride {
  final Color? background;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  
  MdBlockStyleOverride merge(MdBlockStyleOverride? parent);
}

class MdTextStyleOverride {
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final FontStyle? fontStyle;
  final TextDecoration? decoration;
  final Color? decorationColor;
  final Color? background;
  
  MdTextStyleOverride merge(MdTextStyleOverride? parent);
}

class MdLinkStyleOverride {
  final Color? color;
  final Color? hoverColor;
  final Color? visitedColor;
  final TextDecoration? decoration;
  final TextDecoration? hoverDecoration;
}
```

### Inheritance Resolution

Style resolution follows this hierarchy:

```
Flutter ThemeData (if using fromThemeData)
    ↓
MdBasicTheme (comprehensive defaults)
    ↓
MdTagOverrides.{category}Base (e.g., headingBase)
    ↓
MdTagOverrides.{specific} (e.g., h1, h2)
```

Example: Resolving `h2` style:
1. Start with `basic.h2Style` (derived from basic theme)
2. Apply `tagOverrides.headingBase` (shared heading overrides)
3. Apply `tagOverrides.h2` (h2-specific overrides)

### Theme Examples

**Simple: Just use basic theme**

```dart
// Dark theme with custom accent
MdEditorTheme.dark().copyWith(
  basic: MdBasicTheme(
    accent: Color(0xFF007ACC),
    syntaxTheme: 'monokai',
  ),
)
```

**From Flutter ThemeData**

```dart
// Automatically derive from app theme
MdEditorTheme.fromThemeData(Theme.of(context))
```

**Customize all headings uniformly**

```dart
MdEditorTheme.dark().copyWith(
  tagOverrides: MdTagOverrides(
    // All headings get these settings
    headingBase: MdHeadingStyleOverride(
      color: Color(0xFF90CAF9),
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
    ),
    // Only h1 gets a border, inherits rest from headingBase
    h1: MdHeadingStyleOverride(
      borderBottomColor: Color(0xFF3C3C3C),
      borderBottomWidth: 1,
    ),
  ),
)
```

**Custom code blocks only**

```dart
MdEditorTheme.light().copyWith(
  tagOverrides: MdTagOverrides(
    codeBlock: MdBlockStyleOverride(
      background: Color(0xFFF5F5F5),
      borderRadius: 12,
      padding: EdgeInsets.all(16),
    ),
  ),
)
```

---

## Settings

### MdEditorSettings

All features can be toggled:

```dart
class MdEditorSettings {
  // === Layout ===
  final bool showTree;
  final bool showToolbar;
  final bool showStatusBar;
  final bool showSearchBox;
  
  // === Raw Editor Position ===
  final RawEditorPosition rawEditorPosition;  // below, right
  final bool allowEditorPositionChange;       // user can toggle interactively
  final bool autoHideEditor;                  // hide when not editing
  final bool livePreview;                     // update preview while typing
  final int livePreviewDebounceMs;
  
  // === Separator Settings ===
  final bool draggableSeparators;             // allow resizing panels
  final bool persistSeparatorPositions;       // remember positions
  final double treePanelWidthRatio;           // 0.0-1.0, default: 0.25
  final double rawEditorHeightRatio;          // when below, default: 0.35
  final double rawEditorWidthRatio;           // when right, default: 0.4
  final double searchResultsHeightRatio;      // in nav panel, default: 0.5
  
  // === Main Panel ===
  final bool showLineNumbers;
  final bool showSectionBorders;
  final bool highlightCurrentSection;
  final bool enableSmoothScrolling;
  
  // === Tree View ===
  final bool expandAllByDefault;
  final bool showValidationMarkers;
  final bool enableDragAndDrop;
  final bool showSectionIcons;
  
  // === Search ===
  final bool enableSearch;
  final bool enableReplace;
  final bool enableRegexSearch;
  
  // === Markdown Features ===
  final bool enableMermaid;
  final bool enableMath;
  final bool enableFootnotes;
  final bool enableTaskLists;
  final bool enableInteractiveTaskLists;     // click to toggle checkboxes
  final bool enableTables;
  final bool enableSyntaxHighlighting;
  
  // === Code Blocks ===
  final bool showCodeBlockLanguage;
  final bool showCopyCodeButton;
  final bool showCodeEditButton;             // overlay editor button
  final bool enableCodeEditing;
  
  // === Tables ===
  final bool showTableEditButton;            // edit icon on hover
  final bool enableTableEditing;
  
  // === Schema Validation ===
  final bool enableSchemaValidation;
  final bool showSchemaErrors;
  final bool enableAutoScaffold;
  
  // === Behavior ===
  final bool readOnly;
  final bool enableUndo;
  final int maxUndoHistory;
  final bool confirmDelete;
  final bool autoSave;
  final int autoSaveDebounceMs;
}

enum RawEditorPosition { below, right }
```

### Settings Example

```dart
MdEditorSettings(
  // Compact mode - no tree, minimal UI
  showTree: false,
  showToolbar: false,
  showStatusBar: false,
  
  // Editor on right for wide screens
  rawEditorPosition: RawEditorPosition.right,
  allowEditorPositionChange: true,
  
  // Draggable panels
  draggableSeparators: true,
  
  // Enable advanced features
  enableMermaid: true,
  enableMath: true,
  enableSyntaxHighlighting: true,
  enableInteractiveTaskLists: true,
  
  // Tables
  showTableEditButton: true,
  enableTableEditing: true,
  
  // Validation
  enableSchemaValidation: true,
  showSchemaErrors: true,
)
```

---

## Widget API

### MdEditor — Single Widget for All Use Cases

One widget with sensible defaults. Use as a one-liner or configure extensively — all parameters except content source are optional.

**One-liner usage:**

```dart
// Absolute minimum
MdEditor(markdown: '# Hello\n\nWorld')

// With save callback
MdEditor(markdown: content, onChanged: (md) => save(md))

// From file
MdEditor(provider: FileDocumentProvider(path: 'doc.md'))
```

**Full API:**

```dart
class MdEditor extends StatefulWidget {
  const MdEditor({
    // === Content Source (provide one) ===
    this.markdown,
    this.provider,
    
    // === Controller (optional - created internally if not provided) ===
    this.controller,
    
    // === Basic Callbacks ===
    this.onChanged,
    this.onSectionSelected,
    this.onValidationChanged,
    this.onLinkTap,
    
    // === Event Handlers (for intercepting operations) ===
    this.eventHandlers,
    
    // === Appearance ===
    this.theme,
    this.settings,
    
    // === Content Plugins ===
    this.pluginRegistry,
    
    // === Schema ===
    this.schemaId,
    this.schemaProvider,
    
    // === Behavior ===
    this.readOnly = false,
    this.autofocus = false,
    this.autoSave = false,
    this.autoSaveDebounce = const Duration(seconds: 2),
  });
  
  // --- Content Source ---
  
  /// Initial markdown content (mutually exclusive with provider)
  final String? markdown;
  
  /// Document provider for loading/saving (mutually exclusive with markdown)
  final MdDocumentProvider? provider;
  
  // --- Controller ---
  
  /// External controller for programmatic access.
  /// If not provided, an internal controller is created.
  final MdEditorController? controller;
  
  // --- Basic Callbacks ---
  
  /// Called when markdown content changes
  final ValueChanged<String>? onChanged;
  
  /// Called when a section is selected (clicked)
  final ValueChanged<Section>? onSectionSelected;
  
  /// Called when validation errors change
  final ValueChanged<List<ValidationError>>? onValidationChanged;
  
  /// Called when a link is tapped
  final ValueChanged<String>? onLinkTap;
  
  // --- Event Handlers ---
  
  /// Handlers for intercepting/blocking/modifying operations
  final MdEditorEventHandlers? eventHandlers;
  
  // --- Appearance ---
  
  /// Theme customization (defaults to MdEditorTheme.fromContext or .light())
  final MdEditorTheme? theme;
  
  /// Feature settings (defaults to MdEditorSettings.standard())
  final MdEditorSettings? settings;
  
  // --- Content Plugins ---
  
  /// Registry of content plugins for rendering and editing rich content blocks.
  /// If not provided, a default registry is created from settings
  /// via createDefaultPluginRegistry().
  final MdPluginRegistry? pluginRegistry;
  
  // --- Schema ---
  
  /// Schema ID for validation (e.g., 'quest-overview-1.0')
  final String? schemaId;
  
  /// Custom schema provider (defaults to built-in schema loader)
  final MdSchemaProvider? schemaProvider;
  
  // --- Behavior ---
  
  /// Read-only mode (no editing, just viewing)
  final bool readOnly;
  
  /// Auto-focus the editor on mount
  final bool autofocus;
  
  /// Auto-save via provider after changes
  final bool autoSave;
  
  /// Debounce duration for auto-save
  final Duration autoSaveDebounce;
}
```

**Progressive complexity examples:**

```dart
// Level 1: Display only
MdEditor(markdown: readme, readOnly: true)

// Level 2: Simple editing with save
MdEditor(
  markdown: content,
  onChanged: (md) => setState(() => content = md),
)

// Level 3: File-backed with auto-save
MdEditor(
  provider: FileDocumentProvider(path: 'notes.md'),
  autoSave: true,
)

// Level 4: Schema validation
MdEditor(
  markdown: questOverview,
  schemaId: 'quest-overview-1.0',
  onValidationChanged: (errors) => showErrors(errors),
)

// Level 5: Custom theme and settings
MdEditor(
  markdown: content,
  theme: MdEditorTheme.dark().copyWith(
    basic: MdBasicTheme(accent: Colors.teal),
  ),
  settings: MdEditorSettings(
    showTree: true,
    enableMermaid: true,
    showToolbar: false,
  ),
)

// Level 5b: Custom content plugins
final registry = createDefaultPluginRegistry();
registry.register(PlantUmlPlugin());

MdEditor(
  markdown: content,
  pluginRegistry: registry,
)

// Level 6: Event interception
MdEditor(
  markdown: content,
  eventHandlers: MdEditorEventHandlers(
    onBeforeSectionDelete: (event) {
      if (protectedIds.contains(event.section.id)) {
        throw MdOperationBlockedException(message: 'Cannot delete');
      }
      return event;
    },
    onBeforeHeadlineChange: (event) {
      return event.copyWith(newHeadline: event.newHeadline.trim());
    },
  ),
)

// Level 7: External controller for programmatic access
final controller = MdEditorController();
// ... later
MdEditor(
  controller: controller,
  markdown: content,
  schemaId: 'spec-1.0',
)
// Access: controller.document, controller.findSectionById('intro'), etc.

// Level 8: Full configuration
MdEditor(
  provider: DatabaseDocumentProvider(docId: 'doc-123', db: db),
  controller: controller,
  schemaId: 'technical-spec-1.0',
  theme: customTheme,
  settings: MdEditorSettings(
    showTree: true,
    treePosition: TreePosition.right,
    enableMermaid: true,
    enableMath: true,
    showValidationMarkers: true,
    livePreview: true,
    livePreviewDebounceMs: 200,
  ),
  eventHandlers: MdEditorEventHandlers(
    onBeforeSectionCreate: validateNewSection,
    onBeforeSectionDelete: confirmDelete,
    onSectionCreated: trackAnalytics,
    onValidationChanged: syncToServer,
  ),
  onChanged: (md) => markDirty(),
  onSectionSelected: (s) => updateBreadcrumb(s),
  autoSave: true,
  autoSaveDebounce: Duration(seconds: 5),
)
```

### MdViewer — Convenience Alias

For read-only display, `MdViewer` is a convenience wrapper:

```dart
// These are equivalent:
MdViewer(markdown: content)
MdEditor(markdown: content, readOnly: true)

// MdViewer with options
MdViewer(
  markdown: content,
  theme: MdEditorTheme.light(),
  onLinkTap: (url) => launchUrl(url),
  onSectionTap: (section) => scrollTo(section),
)
```

---

## Document Provider

The `MdDocumentProvider` interface enables flexible document sources beyond simple strings.

### Interface

```dart
abstract class MdDocumentProvider {
  /// Load the document content
  Future<String> load();
  
  /// Save the document content (optional)
  Future<void> save(String markdown);
  
  /// Whether save is supported
  bool get canSave;
  
  /// Stream of external changes (for live reload)
  Stream<String>? get externalChanges;
  
  /// Document metadata (optional)
  MdDocumentMetadata? get metadata;
}

class MdDocumentMetadata {
  final String? title;
  final String? path;
  final DateTime? lastModified;
  final String? schemaId;
  final Map<String, dynamic>? custom;
}
```

### Built-in Providers

```dart
// Simple string (default behavior)
StringDocumentProvider(markdown: '# Hello')

// File system
FileDocumentProvider(
  path: '/path/to/doc.md',
  watch: true,  // Auto-reload on external changes
)

// Network
HttpDocumentProvider(
  url: 'https://api.example.com/docs/123',
  headers: {'Authorization': 'Bearer ...'},
)

// Asset bundle
AssetDocumentProvider(asset: 'assets/docs/guide.md')
```

### Custom Provider Example

```dart
class DatabaseDocumentProvider implements MdDocumentProvider {
  final String documentId;
  final DatabaseService db;
  
  DatabaseDocumentProvider({required this.documentId, required this.db});
  
  @override
  Future<String> load() => db.getDocument(documentId);
  
  @override
  Future<void> save(String markdown) => db.saveDocument(documentId, markdown);
  
  @override
  bool get canSave => true;
  
  @override
  Stream<String>? get externalChanges => db.watchDocument(documentId);
  
  @override
  MdDocumentMetadata? get metadata => null;
}

// Usage
SimpleMdEditor(
  provider: DatabaseDocumentProvider(documentId: 'doc-123', db: myDb),
)
```

---

## Event Handlers

Comprehensive event system for intercepting and controlling all document operations.

### MdEditorEventHandlers

```dart
class MdEditorEventHandlers {
  // === Section Events ===
  
  /// Before a section is created. Return modified event or throw to block.
  final MdEventHandler<SectionCreateEvent>? onBeforeSectionCreate;
  /// After a section was created.
  final MdEventCallback<SectionCreatedEvent>? onSectionCreated;
  
  /// Before a section is deleted. Return modified event or throw to block.
  final MdEventHandler<SectionDeleteEvent>? onBeforeSectionDelete;
  /// After a section was deleted.
  final MdEventCallback<SectionDeletedEvent>? onSectionDeleted;
  
  /// Before a section is moved. Return modified event or throw to block.
  final MdEventHandler<SectionMoveEvent>? onBeforeSectionMove;
  /// After a section was moved.
  final MdEventCallback<SectionMovedEvent>? onSectionMoved;
  
  // === Content Events ===
  
  /// Before headline text changes. Return modified event or throw to block.
  final MdEventHandler<HeadlineChangeEvent>? onBeforeHeadlineChange;
  /// After headline text changed.
  final MdEventCallback<HeadlineChangedEvent>? onHeadlineChanged;
  
  /// Before section text changes. Return modified event or throw to block.
  final MdEventHandler<TextChangeEvent>? onBeforeTextChange;
  /// After section text changed.
  final MdEventCallback<TextChangedEvent>? onTextChanged;
  
  // === Selection Events ===
  
  /// When a section is selected (clicked in tree or main panel).
  final MdEventCallback<SectionSelectedEvent>? onSectionSelected;
  
  // === Validation Events ===
  
  /// When validation errors change.
  final MdEventCallback<ValidationChangedEvent>? onValidationChanged;
  
  // === Document Events ===
  
  /// Before document is saved (via provider).
  final MdEventHandler<DocumentSaveEvent>? onBeforeSave;
  /// After document was saved.
  final MdEventCallback<DocumentSavedEvent>? onSaved;
  
  /// When document is loaded/reloaded.
  final MdEventCallback<DocumentLoadedEvent>? onLoaded;
}
```

### Event Handler Types

```dart
/// Handler that can modify or block the event
typedef MdEventHandler<T extends MdEvent> = FutureOr<T> Function(T event);

/// Simple callback after event occurred
typedef MdEventCallback<T extends MdEvent> = void Function(T event);
```

### Event Classes

All events provide access to both the markdown AST and DocScanner model:

```dart
abstract class MdEvent {
  /// Access to the markdown AST (from markdown parser)
  MarkdownDocument get markdownAst;
  
  /// Access to the DocScanner Document model
  Document get document;
  
  /// The controller for additional operations
  MdEditorController get controller;
}

class SectionCreateEvent extends MdEvent {
  /// The parent section (null for root level)
  final Section? parent;
  
  /// Position among siblings
  final int index;
  
  /// Heading level (1-6)
  final int level;
  
  /// The headline text to create
  String headline;
  
  /// Initial section text (optional)
  String? text;
  
  /// Copy with modifications
  SectionCreateEvent copyWith({String? headline, String? text, int? level});
}

class SectionCreatedEvent extends MdEvent {
  /// The newly created section
  final Section section;
}

class SectionDeleteEvent extends MdEvent {
  /// The section about to be deleted
  final Section section;
  
  /// Whether to delete subsections (always true, informational)
  final bool includeSubsections;
}

class HeadlineChangeEvent extends MdEvent {
  /// The section being modified
  final Section section;
  
  /// The current headline
  final String oldHeadline;
  
  /// The new headline (can be modified)
  String newHeadline;
  
  HeadlineChangeEvent copyWith({String? newHeadline});
}

class TextChangeEvent extends MdEvent {
  /// The section being modified
  final Section section;
  
  /// The current text
  final String oldText;
  
  /// The new text (can be modified)
  String newText;
  
  TextChangeEvent copyWith({String? newText});
}

class SectionMoveEvent extends MdEvent {
  /// The section being moved
  final Section section;
  
  /// Current parent (null = root)
  final Section? fromParent;
  
  /// Current index among siblings
  final int fromIndex;
  
  /// New parent (null = root, can be modified)
  Section? toParent;
  
  /// New index (can be modified)
  int toIndex;
}
```

### Blocking Operations

To block an operation, throw `MdOperationBlockedException`:

```dart
MdEditorEventHandlers(
  onBeforeSectionDelete: (event) {
    if (event.section.id == 'protected') {
      throw MdOperationBlockedException(
        message: 'This section cannot be deleted',
        showToUser: true,  // Display in UI
      );
    }
    return event;
  },
)
```

### Modifying Operations

Return a modified event to change the operation:

```dart
MdEditorEventHandlers(
  onBeforeHeadlineChange: (event) {
    // Auto-capitalize headlines
    return event.copyWith(
      newHeadline: event.newHeadline.toUpperCase(),
    );
  },
  
  onBeforeSectionCreate: (event) async {
    // Validate with external service
    final isValid = await validateHeadline(event.headline);
    if (!isValid) {
      throw MdOperationBlockedException(message: 'Invalid headline format');
    }
    // Auto-generate ID
    return event.copyWith(
      headline: '[${generateId()}] ${event.headline}',
    );
  },
)
```

### Event Handler Example

```dart
SimpleMdEditor(
  markdown: content,
  eventHandlers: MdEditorEventHandlers(
    // Log all changes
    onSectionCreated: (event) {
      analytics.track('section_created', {'id': event.section.id});
    },
    
    // Prevent deletion of required sections
    onBeforeSectionDelete: (event) {
      if (requiredSections.contains(event.section.id)) {
        throw MdOperationBlockedException(
          message: 'Required section cannot be deleted',
          showToUser: true,
        );
      }
      return event;
    },
    
    // Auto-format headlines
    onBeforeHeadlineChange: (event) {
      return event.copyWith(
        newHeadline: formatHeadline(event.newHeadline),
      );
    },
    
    // Sync validation errors to external system
    onValidationChanged: (event) {
      errorService.report(event.errors);
    },
  ),
)
```

---

## Document Access

The controller provides access to document content in multiple formats.

### MdEditorController Access Methods

```dart
class MdEditorController {
  // === Content Access ===
  
  /// Raw markdown string
  String get markdown;
  set markdown(String value);
  
  /// Markdown AST (from markdown parser)
  MarkdownDocument get markdownAst;
  
  /// DocScanner Document model
  Document get document;
  
  /// DocSpecs SpecDoc (if schema is set)
  SpecDoc? get specDocument;
  
  // === Section Access ===
  
  /// All sections as flat list
  List<Section> get allSections;
  
  /// Find section by ID
  Section? findSectionById(String id);
  
  /// Find sections by type (DocSpecs)
  List<Section> findSectionsByType(String typeName);
  
  /// Currently selected section
  Section? get selectedSection;
  
  // === Modification ===
  
  /// Update section text
  void updateSectionText(Section section, String newText);
  
  /// Update section headline
  void updateSectionHeadline(Section section, String newHeadline);
  
  /// Insert new section
  Section insertSection({
    Section? parent,
    int index = 0,
    required int level,
    required String headline,
    String? text,
  });
  
  /// Move section
  void moveSection(Section section, {Section? newParent, required int newIndex});
  
  /// Delete section
  void deleteSection(Section section);
  
  // === Conversion ===
  
  /// Export to markdown string
  String toMarkdown({bool preserveIds = true});
  
  /// Export to JSON (DocScanner format)
  Map<String, dynamic> toJson();
}
```

### Accessing Both Models

```dart
// In an event handler
onBeforeTextChange: (event) {
  // Access markdown AST
  final ast = event.markdownAst;
  final headings = ast.children.whereType<Heading>();
  
  // Access DocScanner model
  final doc = event.document;
  final sections = doc.sections ?? [];
  
  // Find related section in DocScanner model
  final section = event.section;
  print('Editing section: ${section.name} (${section.id})');
  
  return event;
},

// Via controller
Widget build(BuildContext context) {
  return Column(
    children: [
      MdEditor(controller: _controller, ...),
      ElevatedButton(
        onPressed: () {
          // Access document
          final doc = _controller.document;
          print('Document has ${doc.hierarchyDepth} levels');
          
          // Find specific section
          final intro = _controller.findSectionById('intro');
          
          // Access AST for custom processing
          final ast = _controller.markdownAst;
        },
        child: Text('Analyze'),
      ),
    ],
  );
}
```

---

## Markdown Extensions Supported

| Extension | Description | Standard |
|-----------|-------------|----------|
| GFM Tables | GitHub Flavored Markdown tables | GFM |
| Task Lists | `- [ ]` and `- [x]` checkboxes | GFM |
| Strikethrough | `~~text~~` | GFM |
| Autolinks | Automatic URL detection | GFM |
| Fenced Code | Triple backtick code blocks | CommonMark |
| Syntax Highlighting | Language-specific highlighting | Extension |
| **Mermaid** | Diagram blocks | Extension |
| Math/KaTeX | `$inline$` and `$$block$$` | Extension |
| Footnotes | `[^1]` references | Extension |
| Definition Lists | `term\n: definition` | Extension |
| Abbreviations | `*[HTML]: Hypertext Markup Language` | Extension |
| Emoji | `:smile:` shortcuts | Extension |
| Superscript/Subscript | `^super^` and `~sub~` | Extension |
| Highlight | `==highlighted==` | Extension |
| Custom Containers | `::: warning\ncontent\n:::` | Extension |

---

## Edit Operations

### Section Manipulation

```dart
// Insert new section
controller.insertSection(
  parent: parentSection,   // null for root level
  index: 0,                // position among siblings
  level: 2,                // heading level (##)
  headline: 'New Section',
);

// Move section (with all subsections)
controller.moveSection(
  section: section,
  newParent: targetParent,
  newIndex: 2,
);

// Delete section
controller.deleteSection(section);

// Update content
controller.updateSectionText(section, 'New content');
controller.updateSectionHeadline(section, 'New Title');
```

### Markdown Generation

When structure changes, markdown is regenerated:

```dart
String markdown = controller.toMarkdown(
  preserveIds: true,          // Keep <!--[id]--> markers
  normalizeWhitespace: true,  // Clean up spacing
);
```

---

## Error Handling

### Headline Markers in Text

When user types `#` or `##` in section text:

1. **Detection**: Pattern match for `^#{1,6}\s` at line start
2. **Warning**: Show inline warning marker
3. **Tooltip**: "Headlines cannot be added in section text"
4. **Actions** (popup menu):
   - "Insert Section Below" — Creates sibling section
   - "Insert Subsection" — Creates child section
   - "Escape as Code" — Wraps in backticks
   - "Ignore" — Keeps as raw text (shows in preview as `#...`)

### Schema Validation Errors

```dart
class ValidationError {
  final ValidationSeverity severity;  // error, warning, info
  final String code;                  // e.g., 'missing-required-section'
  final String message;               // Human-readable description
  final Section? section;             // Related section (if applicable)
  final int? lineNumber;              // Source line
  final FixSuggestion? fix;           // Auto-fix suggestion
}

class FixSuggestion {
  final String label;                 // e.g., "Add missing section"
  final void Function() apply;        // Action to fix
}
```

---

## Accessibility

| Feature | Implementation |
|---------|----------------|
| Keyboard navigation | Tab/Shift+Tab through sections |
| Screen reader | ARIA labels for all interactive elements |
| High contrast | Respects system high contrast mode |
| Focus indicators | Visible focus rings |
| Reduced motion | Disable animations when requested |
| Text scaling | Respects system font size |

---

## Platform Considerations

| Platform | Notes |
|----------|-------|
| **Desktop** | Full feature set, keyboard shortcuts |
| **Web** | WebView for Mermaid, lazy load heavy components |
| **Mobile** | Responsive layout, touch-friendly tree |
| **Tablet** | Side-by-side tree and preview |

---

## Future Enhancements

| Enhancement | Priority | Description |
|-------------|----------|-------------|
| Collaborative editing | Medium | Real-time multi-user editing |
| Version diff view | Low | Compare document versions |
| Export to PDF | Medium | Generate PDF from document |
| Import from HTML | Low | Convert HTML to markdown |
| AI assistance | Low | Schema-aware content suggestions |
| ~~Custom blocks~~ | ~~Medium~~ | ~~Plugin system for new block types~~ — **Implemented** (Section 10: Content Plugin System) |

---

## Package Research and Dependencies

### Markdown Rendering

#### flutter_markdown (Official)

**Package:** `flutter_markdown` (pub.dev)
**Maintainer:** Flutter team

| Aspect | Details |
|--------|---------|
| Pros | Official package, stable, good Flutter integration, extensible builders |
| Cons | Limited extension support, basic styling API |
| GFM Tables | ✅ Yes |
| Task Lists | ✅ Yes |
| Syntax Highlighting | ✅ Via `highlight` package |
| Custom Builders | ✅ Yes — `MarkdownElementBuilder` |
| Tap Handlers | ✅ `onTapLink`, but limited for other elements |

**Extensibility:**
```dart
Markdown(
  data: content,
  builders: {
    'code': CodeElementBuilder(),
    'pre': PreElementBuilder(),
  },
  onTapLink: (text, href, title) => handleLink(href),
)
```

**Assessment:** Good base, but needs significant wrapping for click zones and overlay editors.

#### markdown_widget

**Package:** `markdown_widget` (pub.dev)

| Aspect | Details |
|--------|---------|
| Pros | Rich features, better extension system, table support |
| Cons | Less official, some API instability |
| GFM Tables | ✅ Yes |
| Task Lists | ✅ Yes |
| Math/LaTeX | ✅ Built-in with `flutter_math_fork` |
| Mermaid | ⚠️ Partial (via custom widget) |
| Custom Nodes | ✅ `SpanNodeGeneratorWithTag` |
| Tap Handlers | ✅ `WidgetConfig.onTap` per node type |

**Extensibility:**
```dart
MarkdownWidget(
  data: content,
  config: MarkdownConfig(
    configs: [
      PreConfig(
        builder: (code, language) => CustomCodeBlock(code, language),
      ),
      PConfig(onTapCallback: (node) => handleParagraphTap(node)),
    ],
  ),
)
```

**Assessment:** More feature-rich, better tap handling per element type. Strong candidate.

#### flutter_html

**Package:** `flutter_html` (pub.dev)

| Aspect | Details |
|--------|---------|
| Pros | Full HTML support, fine-grained styling, custom tags |
| Cons | Requires markdown→HTML conversion step, heavier |
| Custom Tags | ✅ `tagExtension` for any element |
| Styling | ✅ CSS-like `Style` objects per tag |
| Tap Handlers | ✅ `onLinkTap`, `onAnchorTap` |

**Assessment:** Overkill for markdown, but useful if we need HTML-level control.

#### Recommendation

**Primary:** `markdown_widget` — Best balance of features and extensibility
**Fallback:** `flutter_markdown` — If stability is paramount

### Syntax Highlighting

#### highlight

**Package:** `highlight` (pub.dev)

| Aspect | Details |
|--------|---------|
| Languages | 190+ languages |
| Themes | 80+ highlight.js themes |
| Flutter Integration | Via `HighlightView` widget |
| Performance | Good, tree-shaking for unused languages |

#### flutter_highlight

**Package:** `flutter_highlight` (pub.dev)

| Aspect | Details |
|--------|---------|
| Based On | `highlight` package |
| Additional | Flutter widgets, better theming |
| Line Numbers | ✅ Built-in support |

#### Recommendation

**Primary:** `flutter_highlight` — Better Flutter integration

### Mermaid Diagrams

#### mermaid_flutter (Planned Package)

No mature Flutter-native Mermaid renderer exists. Options:

| Approach | Pros | Cons |
|----------|------|------|
| **WebView + mermaid.js** | Full compatibility, official renderer | Heavy, platform issues |
| **flutter_svg + mermaid CLI** | Native rendering, fast | Build-time generation only |
| **Custom Dart renderer** | Full control, native | Massive effort, incomplete |

**Recommended Approach:**

1. Use `webview_flutter` with embedded `mermaid.js` for full compatibility
2. Implement message passing for click events
3. Consider pre-rendering to SVG for static diagrams

```dart
class MermaidRenderer extends StatelessWidget {
  final String source;
  
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebMermaidRenderer(source: source);
    } else {
      return NativeMermaidFallback(source: source);
    }
  }
}
```

### Math/LaTeX

#### flutter_math_fork

**Package:** `flutter_math_fork` (pub.dev)

| Aspect | Details |
|--------|---------|
| Syntax | LaTeX subset |
| Rendering | Native Flutter (no WebView) |
| Performance | Excellent |
| Completeness | Most common LaTeX symbols |

#### catex

**Package:** `catex` (pub.dev)

| Aspect | Details |
|--------|---------|
| Syntax | LaTeX |
| Rendering | Native Flutter |
| Maturity | Less mature than flutter_math_fork |

#### Recommendation

**Primary:** `flutter_math_fork` — More complete, better maintained

### Text Editing

#### code_editor (For Raw Text)

**Package:** `code_editor` (pub.dev)

| Aspect | Details |
|--------|---------|
| Syntax Highlighting | ✅ Multiple languages |
| Line Numbers | ✅ Built-in |
| Undo/Redo | ✅ Built-in |
| Multiple Cursors | ❌ No |

#### re_editor

**Package:** `re_editor` (pub.dev)

| Aspect | Details |
|--------|---------|
| Features | Line numbers, highlighting, autocomplete |
| Performance | Good for large files |
| Customization | Extensive |

#### Recommendation

For raw markdown editing, use `re_editor` or our own `tom_dart_editor` architecture adapted for markdown syntax.

### Table Editing

No existing Flutter table editor package is suitable. Build custom:

**Required Components:**
- Editable cell `TextField` widgets
- Row/column selection
- Drag handles for reordering
- Context menus

Consider forking/adapting:
- `pluto_grid` — Data grid with editing (overkill but reference)
- `editable` — Simple editable table (limited features)

### DocScanner/DocSpecs Integration

Our own packages for document structure:

```dart
import 'package:tom_doc_scanner/tom_doc_scanner.dart';
import 'package:tom_doc_specs/tom_doc_specs.dart';

// Parse markdown into Document model
final document = DocScanner.parseMarkdown(markdown);

// Validate against schema
final specDoc = await DocSpecs.validateDocument(
  document: document,
  schemaId: 'quest-overview-1.0',
);

// Access validation errors
if (!specDoc.isValid) {
  for (final error in specDoc.validationErrors) {
    print('${error.code}: ${error.message}');
  }
}
```

### Summary: Recommended Package Stack

| Component | Package | Alternative |
|-----------|---------|-------------|
| **Markdown Rendering** | `markdown_widget` | `flutter_markdown` |
| **Syntax Highlighting** | `flutter_highlight` | `highlight` |
| **Mermaid Diagrams** | WebView + mermaid.js | Custom SVG |
| **Math/LaTeX** | `flutter_math_fork` | — |
| **Raw Text Editor** | `re_editor` or custom | `code_editor` |
| **Table Editor** | Custom build | — |
| **Document Model** | `tom_doc_scanner` | — |
| **Schema Validation** | `tom_doc_specs` | — |

### Integration Strategy

1. **Wrap** `markdown_widget` for core rendering
2. **Inject** custom builders for code blocks, tables, Mermaid
3. **Register** tap handlers at element level for click zones
4. **Overlay** editors use separate widgets in `Stack`/modal
5. **Bridge** markdown AST ↔ DocScanner model for dual access

---

## Implementation Plan

### Phase 1: Foundation (Week 1-2)

**Goal:** Core widget structure with basic rendering

| Task | Description | Estimate |
|------|-------------|----------|
| 1.1 | Create `tom_md_editor` Flutter package scaffold | 2h |
| 1.2 | Implement `MdEditorController` with basic state | 4h |
| 1.3 | Integrate `markdown_widget` as rendering backend | 4h |
| 1.4 | Implement `MdEditor` widget shell with three-panel layout | 6h |
| 1.5 | Add `MdDocumentProvider` interface + `StringProvider` | 3h |
| 1.6 | Basic theme support (`MdBasicTheme`) | 4h |
| 1.7 | Unit tests for controller and providers | 4h |

**Deliverable:** Widget renders markdown with basic styling, controller exposes content.

### Phase 2: Navigation & Structure (Week 3-4)

**Goal:** Tree view navigation and document model integration

| Task | Description | Estimate |
|------|-------------|----------|
| 2.1 | Implement tree view panel with heading extraction | 6h |
| 2.2 | Integrate `tom_doc_scanner` for Document model | 4h |
| 2.3 | Implement section selection and scroll sync | 4h |
| 2.4 | Add drag-drop reordering in tree view | 6h |
| 2.5 | Implement search box with results list | 4h |
| 2.6 | Add draggable separators between panels | 3h |
| 2.7 | Unit tests for tree operations | 3h |

**Deliverable:** Full navigation with tree view, search, and document model access.

### Phase 3: Click Interactions (Week 5-6)

**Goal:** Click zones and editing triggers

| Task | Description | Estimate |
|------|-------------|----------|
| 3.1 | Implement element tap handlers in preview | 6h |
| 3.2 | Add headline marker click zones (expand/collapse) | 4h |
| 3.3 | Implement right-click context menus | 4h |
| 3.4 | Add section text editing inline | 6h |
| 3.5 | Implement `MdEditorEventHandlers` system | 4h |
| 3.6 | Add event interception (before/after handlers) | 4h |
| 3.7 | Integration tests for click behaviors | 4h |

**Deliverable:** Full click interaction with left/right click behaviors, event handlers.

### Phase 4: Raw Text Editor (Week 7)

**Goal:** Synchronized raw text editing

| Task | Description | Estimate |
|------|-------------|----------|
| 4.1 | Implement raw text editor panel | 4h |
| 4.2 | Add markdown syntax highlighting | 4h |
| 4.3 | Implement bidirectional sync (preview ↔ raw) | 6h |
| 4.4 | Add position toggle (right/below) | 2h |
| 4.5 | Implement line number display | 2h |
| 4.6 | Add undo/redo support | 4h |
| 4.7 | Performance optimization for large documents | 4h |

**Deliverable:** Full raw text editing with live preview sync.

### Phase 5: Code Block Support (Week 8-9)

**Goal:** Syntax highlighting and code block editing

| Task | Description | Estimate |
|------|-------------|----------|
| 5.1 | Integrate `flutter_highlight` for syntax coloring | 4h |
| 5.2 | Implement code block overlay editor | 6h |
| 5.3 | Add language selector dropdown | 3h |
| 5.4 | Implement copy button | 2h |
| 5.5 | Add line numbers in code blocks | 3h |
| 5.6 | Implement `MdCodeBlockRenderer` extension API | 4h |
| 5.7 | Add registerable overlay editors | 4h |
| 5.8 | Unit tests for code block operations | 3h |

**Deliverable:** Full code block support with 26 languages, overlay editing, extensibility.

### Phase 6: Table Editor (Week 10)

**Goal:** Interactive table editing

| Task | Description | Estimate |
|------|-------------|----------|
| 6.1 | Implement table rendering with edit button | 4h |
| 6.2 | Build table editor overlay widget | 8h |
| 6.3 | Add cell editing with tab navigation | 4h |
| 6.4 | Implement row/column insert/delete | 4h |
| 6.5 | Add drag-drop row reordering | 4h |
| 6.6 | Implement column alignment controls | 3h |
| 6.7 | Unit tests for table operations | 3h |

**Deliverable:** Full table editing overlay with all operations.

### Phase 7: Special Content (Week 11-12)

**Goal:** Mermaid, math, and task lists

| Task | Description | Estimate |
|------|-------------|----------|
| 7.1 | Integrate WebView for Mermaid rendering | 6h |
| 7.2 | Implement Mermaid click-to-edit | 4h |
| 7.3 | Add Mermaid error display | 3h |
| 7.4 | Integrate `flutter_math_fork` for LaTeX | 4h |
| 7.5 | Implement interactive task list checkboxes | 3h |
| 7.6 | Add task list state callbacks | 2h |
| 7.7 | Integration tests for special content | 4h |

**Deliverable:** Full Mermaid, math, and task list support.

### Phase 8: Schema Validation (Week 13)

**Goal:** DocSpecs integration

| Task | Description | Estimate |
|------|-------------|----------|
| 8.1 | Integrate `tom_doc_specs` for validation | 4h |
| 8.2 | Implement validation status indicator | 3h |
| 8.3 | Add error markers on sections | 4h |
| 8.4 | Implement error list panel | 4h |
| 8.5 | Add auto-validation on content change | 3h |
| 8.6 | Unit tests for validation | 3h |

**Deliverable:** Full schema validation with visual feedback.

### Phase 9: Theming & Polish (Week 14)

**Goal:** Complete theming system and refinements

| Task | Description | Estimate |
|------|-------------|----------|
| 9.1 | Implement `MdTagOverrides` hierarchical system | 4h |
| 9.2 | Add theme inheritance resolution | 3h |
| 9.3 | Create default light/dark themes | 4h |
| 9.4 | Implement `MdEditorSettings` full support | 4h |
| 9.5 | Add keyboard shortcuts | 4h |
| 9.6 | Performance profiling and optimization | 6h |
| 9.7 | Documentation and examples | 6h |

**Deliverable:** Production-ready widget with full theming.

### Phase 10: Integration & Testing (Week 15-16)

**Goal:** Integration with Tom Forge ecosystem

| Task | Description | Estimate |
|------|-------------|----------|
| 10.1 | Integrate with `tom_forge_ui` | 4h |
| 10.2 | Add `FileProvider` and `AssetProvider` | 4h |
| 10.3 | Implement `SpecDocProvider` for quest files | 4h |
| 10.4 | End-to-end testing | 8h |
| 10.5 | Cross-platform testing (iOS, Android, Web, Desktop) | 8h |
| 10.6 | Bug fixes and refinements | 8h |
| 10.7 | Release preparation | 4h |

**Deliverable:** Published `tom_md_editor` package.

### Milestone Summary

| Milestone | Week | Key Deliverable |
|-----------|------|-----------------|
| **M1: Core** | 2 | Basic rendering widget |
| **M2: Navigation** | 4 | Tree view + document model |
| **M3: Interaction** | 6 | Click handling + events |
| **M4: Raw Editor** | 7 | Bidirectional editing |
| **M5: Code Blocks** | 9 | Syntax highlighting + overlay |
| **M6: Tables** | 10 | Table editor overlay |
| **M7: Special** | 12 | Mermaid + math + tasks |
| **M8: Validation** | 13 | DocSpecs integration |
| **M9: Theming** | 14 | Full theming system |
| **M10: Release** | 16 | Published package |

### Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Mermaid WebView performance | Pre-render SVG for static diagrams, lazy load WebView |
| Large document performance | Virtual scrolling, incremental parsing |
| Cross-platform WebView issues | Fallback to static image for problematic platforms |
| markdown_widget limitations | Prepare flutter_markdown fallback path |
| Bidirectional sync bugs | Comprehensive unit tests, debounced updates |

### Dependencies

```yaml
# pubspec.yaml (planned)
dependencies:
  flutter:
    sdk: flutter
  markdown_widget: ^2.3.0
  flutter_highlight: ^0.7.0
  flutter_math_fork: ^0.7.0
  webview_flutter: ^4.4.0
  tom_doc_scanner:
    path: ../tom_ai/ai_build/tom_doc_scanner
  tom_doc_specs:
    path: ../tom_ai/ai_build/tom_doc_specs
  tom_core_flutter:
    path: ../tom_ai/core/tom_core_flutter
```

### First Sprint Tasks (Week 1)

1. Create package: `flutter create --template=package tom_md_editor`
2. Set up pubspec.yaml with dependencies
3. Create `lib/src/` directory structure:
   - `controller/md_editor_controller.dart`
   - `widgets/md_editor.dart`
   - `providers/md_document_provider.dart`
   - `theme/md_basic_theme.dart`
4. Implement minimal `MdEditor` rendering static markdown
5. Add basic unit test

---

## Gap Analysis — Remaining Implementation Steps

The initial implementation delivered the core architecture: models (MdParser, MdDocument, MdSection), controller (CRUD, undo/redo, search/replace, events), full event system, settings (50+ fields), theming (MdBasicTheme, MdTagOverrides, dark/light/fromThemeData), providers (MdDocumentProvider, StringDocumentProvider), layout widgets (MdEditor, MdViewer, MdTreeView, MdSearchPanel, MdPreviewPanel, MdRawTextEditor), overlay editors (MdCodeBlockOverlay, MdTableOverlay), shared components in tom_editors_shared (DraggableSeparator, SplitPanel, EditorLogger, SearchBox), constants, debug infrastructure, demo app, and 32 passing unit tests.

The following five steps complete the remaining specification requirements, ordered by dependency and priority.

### Step 1: Widget API, Registries, and Convenience Layer

**Goal:** Make `MdEditor(markdown: '# Hello')` work as a one-liner and add extensibility registries.

**1.1 MdEditor Widget API**

Update `MdEditor` to match the spec's full constructor:

| Parameter | Type | Purpose |
|-----------|------|---------|
| `markdown` | `String?` | Direct content source (mutually exclusive with `provider`) |
| `provider` | `MdDocumentProvider?` | Document provider (mutually exclusive with `markdown`) |
| `controller` | `MdEditorController?` | Optional — create internally if not provided |
| `onChanged` | `ValueChanged<String>?` | Called when markdown content changes |
| `onValidationChanged` | `ValueChanged<List<ValidationError>>?` | Validation error changes |
| `readOnly` | `bool` | Direct read-only flag (default: `false`) |
| `autofocus` | `bool` | Auto-focus on mount (default: `false`) |
| `autoSave` | `bool` | Auto-save via provider (default: `false`) |
| `autoSaveDebounce` | `Duration` | Debounce for auto-save (default: 2s) |
| `schemaId` | `String?` | Schema for validation |
| `schemaProvider` | `MdSchemaProvider?` | Custom schema loader |
| `codeEditorRegistry` | `MdCodeEditorRegistry?` | Custom code editors |
| `languageRenderers` | `MdLanguageRendererRegistry?` | Custom language renderers |
| `contentRenderers` | `List<MdContentRenderer>?` | Custom content renderers |

Make `controller` optional: if not provided, create an internal `MdEditorController` initialized from `markdown` or `provider`. Dispose the internal controller on widget dispose.

Wire `onChanged` to `MdEditorController.addListener` — fire whenever `markdown` changes.

Update `MdViewer` to also accept `markdown` directly.

**1.2 MdCodeEditorRegistry**

Create `lib/src/registries/md_code_editor_registry.dart`:

```dart
class MdCodeEditorRegistration {
  final List<String> languages;
  final Widget Function(String code, ValueChanged<String> onChanged) editorBuilder;
  final String? displayName;
  final IconData? icon;
}

class MdCodeEditorRegistry {
  MdCodeEditorRegistry(List<MdCodeEditorRegistration> registrations);
  void register(MdCodeEditorRegistration registration);
  Widget buildEditor(String language, String code, ValueChanged<String> onChanged);
  bool hasCustomEditor(String language);
}
```

Pass the registry to `MdPreviewPanel` and `MdCodeBlockOverlay` so they use custom editors when available.

**1.3 MdLanguageRendererRegistry**

Create `lib/src/registries/md_language_renderer_registry.dart`:

```dart
class MdLanguageRenderer {
  final List<String> languages;
  final Widget Function(String code, MdBasicTheme theme) renderer;
}

class MdLanguageRendererRegistry {
  MdLanguageRendererRegistry(List<MdLanguageRenderer> renderers);
  void register(MdLanguageRenderer renderer);
  Widget? buildRenderer(String language, String code, MdBasicTheme theme);
}
```

Integrate into `_CodeBlockBuilder` in the preview panel — check registry before default rendering.

**1.4 MdContentRenderer Interface**

Create `lib/src/registries/md_content_renderer.dart`:

```dart
abstract class MdContentRenderer {
  List<String> get contentTypes;
  Widget build(MdContentContext context);
  Widget? buildEditor(MdContentContext context, ValueChanged<String> onChanged);
  bool get hasOverlayEditor;
}

class MdContentContext {
  final String content;
  final String? language;
  final MdBasicTheme theme;
  final MdEditorController controller;
  final MdSection? containingSection;
}
```

**1.5 Missing Event Classes**

Add to `md_events.dart`:

- `ValidationChangedEvent` with `List<ValidationError> errors`
- `DocumentLoadedEvent` with `MdDocument document`
- `DocumentSaveEvent` (before-save event) with `String markdown`

Add corresponding handler slots to `MdEditorEventHandlers`:

- `onValidationChanged: MdEventCallback<ValidationChangedEvent>?`
- `onLoaded: MdEventCallback<DocumentLoadedEvent>?`
- `onBeforeSave: MdEventHandler<DocumentSaveEvent>?`

**1.6 Settings copyWith Completion**

Extend `MdEditorSettings.copyWith()` to support all 50+ fields.

**1.7 Tests**

- Test MdEditor with `markdown:` param (no controller)
- Test MdEditor with `provider:` param
- Test `onChanged` fires on content changes
- Test `MdCodeEditorRegistry` lookup and fallback
- Test `MdLanguageRendererRegistry` lookup
- Test new events

**Files to create:**
- `lib/src/registries/md_code_editor_registry.dart`
- `lib/src/registries/md_language_renderer_registry.dart`
- `lib/src/registries/md_content_renderer.dart`

**Files to modify:**
- `lib/src/widgets/md_editor.dart` — new params, internal controller
- `lib/src/events/md_events.dart` — new event classes + handlers
- `lib/src/settings/md_editor_settings.dart` — complete copyWith
- `lib/src/widgets/preview/md_preview_panel.dart` — registry integration
- `lib/src/widgets/overlays/md_code_block_overlay.dart` — registry integration
- `lib/tom_md_editor.dart` — export new files
- `test/tom_md_editor_test.dart` — new tests

---

### Step 2: Tree View Interactivity and Preview Click Behaviors

**Goal:** Full drag-drop in tree, complete context menus, and preview click zones.

**2.1 Tree View Drag-and-Drop**

Implement drag-and-drop section reordering in `MdTreeView`:

- Use Flutter's `Draggable`/`DragTarget` or `ReorderableListView` pattern
- Show drop indicators (before, after, inside)
- Auto-adjust heading levels based on new parent depth
- Move all subsections with their parent
- Fire `onBeforeSectionMove` / `onSectionMoved` events

**2.2 Extended Tree Context Menu**

Add missing context menu items:

| Action | Implementation |
|--------|----------------|
| Add Subsection (Top) | `insertSection(parent: section, index: 0, level: section.level + 1)` |
| Add Subsection (Bottom) | `insertSection(parent: section, index: section.subsections.length, level: section.level + 1)` |
| Move Up | Swap with previous sibling via `moveSection` |
| Move Down | Swap with next sibling via `moveSection` |
| Promote | Decrease heading level (`###` → `##`) via `updateSectionHeadline` + level adjustment |
| Demote | Increase heading level (`##` → `###`) via `updateSectionHeadline` + level adjustment |

Add `promoteSection(MdSection)` and `demoteSection(MdSection)` methods to `MdEditorController`.

**2.3 Validation Markers in Tree**

When `showValidationMarkers` is enabled and `validationErrors` is non-empty:

- Show error/warning icon next to section nodes with validation issues
- Click on icon → show error details tooltip
- Right-click on icon → quick-fix menu (if `FixSuggestion` available)

**2.4 Section Icons**

When `showSectionIcons` is enabled, show level-appropriate icons next to section names in the tree (e.g., document icon for H1, section icon for H2, paragraph icon for H3+).

**2.5 Preview Right-Click Context Menus**

Add `GestureDetector` with `onSecondaryTapDown` to rendered elements:

| Element | Context Menu Items |
|---------|-------------------|
| Headline | Edit headline, Delete section, Add sibling above/below, Add subsection |
| Body text | Edit section in raw editor |
| Code block | Open code editor overlay, Copy code |
| Link | Edit link, Copy URL, Open in browser |
| Image | Edit alt text, Replace image, Image properties |
| Table | Open table editor |

**2.6 Preview Hover Behaviors**

- Tables: show edit icon on hover (using `MouseRegion` + overlay)
- Links: show URL tooltip on hover
- Images: show alt text tooltip on hover
- Code blocks: already have copy/edit buttons on hover (done)

**2.7 Search Result → Raw Editor Navigation**

When clicking a search result in `MdSearchPanel`:
1. Select the containing section in the controller
2. Open the raw text editor for that section
3. Position cursor at the match offset

**2.8 Tests**

- Test promote/demote changes heading level correctly
- Test move up/down swaps siblings
- Test drag-drop fires correct move events
- Test context menu actions

**Files to modify:**
- `lib/src/widgets/tree/md_tree_view.dart` — drag-drop, extended context menu, validation markers, icons
- `lib/src/widgets/preview/md_preview_panel.dart` — right-click menus, hover behaviors
- `lib/src/widgets/tree/md_search_panel.dart` — raw editor navigation
- `lib/src/controller/md_editor_controller.dart` — promoteSection, demoteSection
- `test/tom_md_editor_test.dart` — new tests

---

### Step 3: Raw Text Editor Enhancements and Toolbar/Status Bar

**Goal:** Syntax highlighting in raw editor, headline marker detection, toolbar, and status bar.

**3.1 Markdown Syntax Highlighting in Raw Editor**

Add basic markdown syntax highlighting to `MdRawTextEditor`:

- Headlines (`#`) — bold + accent color
- Bold (`**...**`) — bold
- Italic (`*...*`) — italic
- Code (`` `...` ``) — monospace + background
- Links (`[text](url)`) — accent color
- Lists (`- `, `1. `) — muted color for markers

Implementation options:
- Custom `TextEditingController` with `buildTextSpan()` override
- Or use `re_editor` package for richer editing

**3.2 Headline Marker Detection**

When user types `#` at start of a line in the raw text editor:

1. Detect pattern `^#{1,6}\s` via regex on each text change
2. Show inline warning indicator (yellow underline or icon)
3. Show tooltip: "Headlines cannot be added in section text"
4. On clicking the warning, show popup menu:
   - "Insert Section Below" → `insertSection` as sibling
   - "Insert Subsection" → `insertSection` as child
   - "Escape as Code" → wrap in backticks
   - "Ignore" → keep as-is

**3.3 Interactive Editor Position Toggle**

When `allowEditorPositionChange` is true:

- Add a toggle button in the raw editor title bar
- Clicking switches between `RawEditorPosition.below` and `RawEditorPosition.right`
- Update layout immediately

**3.4 MdEditorToolbar**

Create `lib/src/widgets/toolbar/md_editor_toolbar.dart`:

| Button | Action |
|--------|--------|
| Bold | Wrap selection in `**...**` |
| Italic | Wrap selection in `*...*` |
| Strikethrough | Wrap selection in `~~...~~` |
| Code | Wrap selection in backticks |
| Link | Insert `[text](url)` template |
| Image | Insert `![alt](url)` template |
| Heading (dropdown) | Insert `#` - `######` |
| List (unordered) | Insert `- ` prefix |
| List (ordered) | Insert `1. ` prefix |
| Task list | Insert `- [ ] ` prefix |
| Code block | Insert fenced code block |
| Table | Insert 2x2 table template |
| Horizontal rule | Insert `---` |
| Undo | `controller.undo()` |
| Redo | `controller.redo()` |

Toolbar only visible when `settings.showToolbar` is true.

**3.5 MdEditorStatusBar**

Create `lib/src/widgets/status_bar/md_editor_status_bar.dart`:

Display:
- Current section name/path
- Document word count / character count
- Line count
- Schema validation status (valid / N errors)
- Read-only indicator

Status bar only visible when `settings.showStatusBar` is true.

**3.6 Tests**

- Test toolbar button actions modify markdown correctly
- Test status bar displays correct counts
- Test headline marker detection triggers warning
- Test position toggle switches layout

**Files to create:**
- `lib/src/widgets/toolbar/md_editor_toolbar.dart`
- `lib/src/widgets/status_bar/md_editor_status_bar.dart`

**Files to modify:**
- `lib/src/widgets/raw_editor/md_raw_text_editor.dart` — syntax highlighting, headline detection, position toggle
- `lib/src/widgets/md_editor.dart` — wire toolbar and status bar
- `lib/tom_md_editor.dart` — export new files
- `test/tom_md_editor_test.dart` — new tests

---

### Step 4: Advanced Rendering — Mermaid, Math/LaTeX, and Table Editor

**Goal:** Render Mermaid diagrams, LaTeX math, and complete the table editor.

**4.1 Math/LaTeX Rendering**

Add `flutter_math_fork` dependency to `pubspec.yaml`.

Create `lib/src/widgets/renderers/md_math_renderer.dart`:

- Detect inline math `$...$` and block math `$$...$$` in markdown
- Register a custom `MarkdownElementBuilder` for math blocks
- Render using `Math.tex()` from `flutter_math_fork`
- Right-click → open LaTeX editor overlay

Create `lib/src/widgets/overlays/md_math_overlay.dart`:

- Text field for LaTeX source
- Live preview using `Math.tex()`
- Save/cancel buttons

Only active when `settings.enableMath` is true.

**4.2 Mermaid Diagram Rendering**

Add `webview_flutter` dependency (or `flutter_inappwebview`).

Create `lib/src/widgets/renderers/md_mermaid_renderer.dart`:

- Detect ` ```mermaid ` code blocks
- Register as custom code block builder
- Render using WebView with embedded `mermaid.js`
- Support all 12 diagram types (flowchart, sequence, class, state, ER, journey, gantt, pie, mindmap, timeline, quadrant, git graph)
- Error display for invalid syntax
- Click-to-edit opens source in overlay

Create `lib/src/widgets/overlays/md_mermaid_overlay.dart`:

- Text editor for Mermaid source
- Live preview via WebView
- Error highlighting

Only active when `settings.enableMermaid` is true. Platform fallback for unsupported WebView targets.

**4.3 Table Editor Completion**

Enhance `MdTableOverlay` with:

| Feature | Implementation |
|---------|----------------|
| Move row up/down | Drag handles on left side of each row |
| Move column left/right | Drag handles on column headers or arrow buttons |
| Header row toggle | Checkbox to convert first row to/from header |
| Column alignment | Dropdown per column: left / center / right (updates `:---`, `:---:`, `---:`) |
| Sort by column | Click column header to sort (temporary preview, not persisted) |
| Tab navigation | Tab key moves between cells, Shift+Tab moves backward |
| Keyboard shortcuts | Ctrl+Enter adds row, Delete removes selected row |

**4.4 Tests**

- Test math rendering detects inline/block math
- Test Mermaid block detection
- Test table editor alignment generates correct markdown syntax
- Test table editor row/column operations

**Files to create:**
- `lib/src/widgets/renderers/md_math_renderer.dart`
- `lib/src/widgets/overlays/md_math_overlay.dart`
- `lib/src/widgets/renderers/md_mermaid_renderer.dart`
- `lib/src/widgets/overlays/md_mermaid_overlay.dart`

**Files to modify:**
- `pubspec.yaml` — add `flutter_math_fork`, `webview_flutter`
- `lib/src/widgets/preview/md_preview_panel.dart` — integrate math + mermaid renderers
- `lib/src/widgets/overlays/md_table_overlay.dart` — complete features
- `lib/tom_md_editor.dart` — export new files
- `test/tom_md_editor_test.dart` — new tests

---

### Step 5: Schema Validation, Additional Providers, and Accessibility

**Goal:** DocSpecs integration, file/network providers, and accessibility compliance.

**5.1 Schema Validation Integration**

Add `tom_doc_scanner` and `tom_doc_specs` dependencies to `pubspec.yaml`.

Add to `MdEditorController`:

```dart
SpecDoc? get specDocument;
List<Section> findSectionsByType(String typeName);
void scaffoldFromSchema(DocSpecSchema schema);
Future<void> validateDocument();
Map<String, dynamic> toJson();
```

Wire validation:
- Parse document with `DocScanner.parseMarkdown()` in addition to `MdParser`
- When `schemaId` is set, validate on every content change (debounced)
- Store validation errors in `_validationErrors`
- Fire `ValidationChangedEvent` when errors change
- Show errors in tree (via validation markers from Step 2) and preview (inline markers)

Implement `scaffoldFromSchema`:
- Generate required sections with placeholder text
- Correct heading levels
- Section IDs matching schema patterns

**5.2 Dual Document Model Access**

Add to `MdEditorController`:

```dart
MarkdownDocument get markdownAst;  // from markdown package parser
Document get document;              // from tom_doc_scanner
```

Add AST access to event classes — update `MdEvent` base class with `markdownAst` and `document` getters.

**5.3 Additional Document Providers**

Create `lib/src/providers/file_document_provider.dart`:

```dart
class FileDocumentProvider implements MdDocumentProvider {
  FileDocumentProvider({ required String path, bool watch = false });
  // Load/save from file system, optional file watching for external changes
}
```

Create `lib/src/providers/asset_document_provider.dart`:

```dart
class AssetDocumentProvider implements MdDocumentProvider {
  AssetDocumentProvider({ required String asset });
  // Load from Flutter asset bundle (read-only)
}
```

Create `lib/src/providers/http_document_provider.dart`:

```dart
class HttpDocumentProvider implements MdDocumentProvider {
  HttpDocumentProvider({ required String url, Map<String, String>? headers });
  // Load/save via HTTP (GET/PUT)
}
```

**5.4 MdEditorController Missing Methods**

- `toJson()` — export to DocScanner JSON format
- `toMarkdown(normalizeWhitespace: true)` — add whitespace normalization
- `findSectionsByType(String typeName)` — filter by DocSpecs type

**5.5 Accessibility**

| Feature | Implementation |
|---------|----------------|
| Keyboard navigation | Tab/Shift+Tab through tree nodes and sections |
| Focus indicators | Visible focus rings on all interactive elements via `FocusNode` |
| Screen reader | `Semantics` widgets with labels on tree nodes, buttons, panels |
| High contrast | Detect `MediaQuery.highContrast` and adjust theme |
| Reduced motion | Check `MediaQuery.disableAnimations` and skip transitions |
| Text scaling | Use `MediaQuery.textScaleFactor` for all text |

Add keyboard shortcuts:
- `F3` / `Shift+F3` — next/previous search result
- `Ctrl+Z` / `Ctrl+Shift+Z` — undo/redo
- `Ctrl+S` — save
- `Ctrl+F` — focus search box

**5.6 Tests**

- Test schema validation detects missing required sections
- Test scaffoldFromSchema generates correct structure
- Test FileDocumentProvider load/save
- Test accessibility semantics on key widgets
- Test keyboard shortcuts

**Files to create:**
- `lib/src/providers/file_document_provider.dart`
- `lib/src/providers/asset_document_provider.dart`
- `lib/src/providers/http_document_provider.dart`

**Files to modify:**
- `pubspec.yaml` — add `tom_doc_scanner`, `tom_doc_specs` dependencies
- `lib/src/controller/md_editor_controller.dart` — schema validation, dual model, toJson, findSectionsByType
- `lib/src/events/md_events.dart` — add markdownAst/document to MdEvent
- `lib/src/widgets/md_editor.dart` — accessibility, keyboard shortcuts
- `lib/src/widgets/tree/md_tree_view.dart` — keyboard navigation, semantics
- `lib/tom_md_editor.dart` — export new files
- `test/tom_md_editor_test.dart` — new tests
