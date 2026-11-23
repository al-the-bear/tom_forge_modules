# YAML Editor — Architecture & Detailed Design

Detailed architecture, component design, package layout, and implementation plan for the YAML Schema-Based Editor.

---

## Table of Contents

- [Package Structure](#package-structure)
- [Component Overview](#component-overview)
- [Shared Components (tom\_editors\_shared)](#shared-components-tom_editors_shared)
- [Core Components (tom\_yaml\_editor)](#core-components-tom_yaml_editor)
- [Data Flow](#data-flow)
- [Component Relationships](#component-relationships)
- [Tree Rendering Pipeline](#tree-rendering-pipeline)
- [Validation Pipeline](#validation-pipeline)
- [Subtree Inspector Design](#subtree-inspector-design)
- [Extension Mechanism](#extension-mechanism)
- [Implementation Plan](#implementation-plan)

---

## Package Structure

The editor ecosystem is split across three packages to maximize reuse:

```mermaid
graph TD
    subgraph tom_editors_shared["tom_editors_shared (reusable)"]
        direction TB
        TH["TreeTheme\n(base theme system)"]
        TV["TreeView\n(generic tree widget)"]
        VF["ValidationFramework\n(error model, badges, tooltips)"]
        IC["InlineControls\n(add/remove/collapse buttons)"]
    end

    subgraph tom_yaml_editor["tom_yaml_editor (YAML-specific)"]
        direction TB
        YSE["YamlSchemaEditor\n(main widget)"]
        YEC["YamlEditorController\n(state management)"]
        YDM["YamlDocumentModel\n(yaml_edit wrapper)"]
        YS["YamlSchema\n(JSON Schema)"]
        ER["EditorRegistry\n(suffix → factory)"]
        SW["SchemaWalker"]
        BTE["Built-in Type Editors\n(string, int, bool, etc.)"]
        SI["SubtreeInspector\n(YAML text editor)"]
    end

    subgraph tom_yaml_editor_test["tom_yaml_editor_test (test app)"]
        direction TB
        TA["Test App Shell"]
        DE["Dart Editor (stub)"]
        ME["Markdown Editor (stub)"]
        RE["Regex Editor (stub)"]
    end

    tom_yaml_editor --> tom_editors_shared
    tom_yaml_editor_test --> tom_yaml_editor

    style tom_editors_shared fill:#1a4a3e,color:#fff
    style tom_yaml_editor fill:#1a3a5e,color:#fff
    style tom_yaml_editor_test fill:#3a1a5e,color:#fff
```

### Package Dependency Rules

| Package | Depends On | Published |
|---------|-----------|-----------|
| `tom_editors_shared` | Flutter SDK only | Yes (pub.dev) |
| `tom_yaml_editor` | `tom_editors_shared`, `yaml`, `yaml_edit` | Yes (pub.dev) |
| `tom_yaml_editor_test` | `tom_yaml_editor` (path dep) | No (app) |

---

## Component Overview

```mermaid
classDiagram
    class YamlSchemaEditor {
        +YamlEditorController controller
        +YamlEditorTheme theme
        +EditorRegistry editorRegistry
        +bool readOnly
        +build() Widget
    }

    class YamlEditorController {
        -YamlDocumentModel _document
        -YamlSchema? _schema
        -ForgeTextHistory _history
        -ForgeSavedMarker _saved
        +String yamlText
        +String sourceText
        +bool textMode
        +editSource(text, selection)
        +bool isValid
        +List~String~ errors
        +setValue(path, value)
        +insertKey(parentPath, key, value)
        +removeKey(path)
        +undo()
        +redo()
    }

    class YamlDocumentModel {
        -YamlEditor _editor
        +parse(yaml) YamlDocumentModel$
        +toYamlString() String
        +nodeAt(path) YamlNode?
        +withValueAt(path, value) YamlDocumentModel
        +withInsertedKey(path, key, val) YamlDocumentModel
        +withRemovedKey(path) YamlDocumentModel
    }

    class YamlSchema {
        +SchemaNode root
        +validate(document) List~ValidationError~
        +suggestedKeysAt(path, document) List~String~
        +nodeAt(path) SchemaNode?
    }

    class SchemaWalker {
        +YamlSchema schema
        +expectedTypeAt(path) SchemaType?
        +isRequired(parentPath, key) bool
        +editorTypeForKey(path) String?
    }

    class EditorRegistry {
        -Map~String,EditorSuffix~ _editors
        -EditorResolver? resolver
        +register(editor) EditorRegistry
        +resolve(key, path, schemaType?) EditorSuffix?
    }

    class YamlEditorTheme {
        +YamlEditorColors colors
        +YamlStructureColors structureColors
        +YamlEditorFontSettings fonts
        +EmbeddedEditorStyle embeddedEditorStyle
        +copyWith() YamlEditorTheme
    }

    YamlSchemaEditor --> YamlEditorController : uses
    YamlSchemaEditor --> EditorRegistry : uses
    YamlSchemaEditor --> YamlEditorTheme : uses
    YamlEditorController --> YamlDocumentModel : manages
    YamlEditorController --> YamlSchema : validates with
    YamlEditorController --> SchemaWalker : traverses with
    SchemaWalker --> YamlSchema : wraps
```

---

## Shared Components (tom_editors_shared)

These components are generic enough to be used by any tree-based editor (YAML, JSON, TOML, XML, config files). They contain **zero YAML-specific logic**.

### 1. TreeView Widget

A generic, recursive tree widget for rendering hierarchical data with expand/collapse, indent guides, and keyboard navigation.

```mermaid
classDiagram
    class TreeView~T~ {
        +List~TreeNode~T~~ roots
        +TreeNodeBuilder~T~ nodeBuilder
        +TreeTheme theme
        +TreeController~T~? controller
        +bool showTreeLines
        +double indentWidth
    }

    class TreeNode~T~ {
        +T data
        +List~TreeNode~T~~ children
        +bool isExpanded
        +String id
    }

    class TreeController~T~ {
        +expand(id)
        +collapse(id)
        +expandAll()
        +collapseAll()
        +scrollToNode(id)
        +Set~String~ expandedIds
    }

    class TreeTheme {
        +Color treeLine
        +Color collapseIcon
        +Color hoverColor
        +Color selectionColor
        +double indentWidth
        +double lineHeight
    }

    TreeView --> TreeNode : renders
    TreeView --> TreeController : controlled by
    TreeView --> TreeTheme : styled with
```

**Why shared:** Any structured editor needs a tree. JSON editors, TOML editors, file browsers — they all need expand/collapse, indent guides, keyboard nav.

### 2. ValidationFramework

Generic validation error model, badge/marker widgets, and tooltip display.

```mermaid
classDiagram
    class ValidationError {
        +List~Object~ path
        +String message
        +ValidationSeverity severity
        +String? code
    }

    class ValidationSeverity {
        <<enumeration>>
        error
        warning
        info
    }

    class ValidationBadge {
        +int errorCount
        +int warningCount
        +ValidationTheme theme
        +build() Widget
    }

    class ValidationTooltip {
        +List~ValidationError~ errors
        +ValidationTheme theme
        +build() Widget
    }

    class ValidationTheme {
        +Color errorColor
        +Color warningColor
        +Color infoColor
        +Color tooltipBackground
        +TextStyle messageStyle
    }

    class ErrorPropagator {
        +propagate(errors, allPaths) Map~pathHash, List~ValidationError~~
    }

    ValidationBadge --> ValidationError : displays
    ValidationTooltip --> ValidationError : displays
    ValidationBadge --> ValidationTheme : styled with
    ValidationTooltip --> ValidationTheme : styled with
    ErrorPropagator --> ValidationError : processes
```

**Why shared:** Validation badges, error tooltips, and severity colors are needed by any schema-aware editor.

### 3. The undo stack

The controller keeps the Forge history contract (tom_forge_ui's
`editor_history_contract.md`) with the shared helpers of `tom_editors_shared`.
The document is its source text, and its one history is a `ForgeTextHistory`
over that text (on `tom_undo`'s `TomUndoStack`):

- a tree edit (`YamlEditOperation`) is recorded once it applied and only when
  it changed the text; edits of the same field with no pause between them
  (`setValue` on one path) are one entry, every structural edit is its own;
- typing in source mode (`editSource`) is one entry per gesture, and source
  that does not parse is a draft the history keeps like any other text — the
  tree shows the last text that parsed, and leaving source mode needs text
  that parses;
- undo and redo restore the text and the caret; the views follow;
- dirty is a `ForgeSavedMarker` on the source text, so undoing back to the
  saved text is clean;
- the mode (`textMode`) is the document's, so split views share it; a mode
  switch, a save and focus leaving a field end the typing in progress;
- `replaceContent` (reload, revision restore) makes new text the saved state
  and clears the history.

The tree's inline fields keep no history of their own (`ForgeTextField`
with `undoOwnedByHost`, `ForgeEditorOwnsUndo`), drop the echo of a value set
by undo, put the caret at the change, and number fields write no null while
typing. Host-registered embedded editors write through `setValue` into the same
history; their popout reaches it through `ForgeEditorOwnsUndo(onUndo, onRedo)`.

```mermaid
classDiagram
    class YamlEditorController {
        +applyEdit(operation)
        +editSource(text, selection)
        +undo()
        +redo()
        +flush()
    }
    class ForgeTextHistory {
        +edited(state)
        +selected(selection)
        +flush()
        +undo(apply) bool
        +redo(apply) bool
        +replace(state)
    }
    YamlEditorController --> ForgeTextHistory : one per document
```

### 4. TomTextSource (tom_file_editors)

The source editor of `tom_file_editors` (`tom_ai/modules`): monospaced, line numbers, the highlighter's colours, markers drawn as wavy underlines, find, and the line edits and clipboard reached through its state. Text mode and the subtree inspector show it in the editor's theme (`yamlSourceStyle`, `yamlSourceHighlighter` in `lib/src/text_editor/yaml_source_view.dart`).

```mermaid
classDiagram
    class TomTextSource {
        +String text
        +SyntaxHighlighter? highlighter
        +List~TomTextMarker~ markers
        +TomTextSourceStyle? style
        +TextSelection? selection
        +bool readOnly
        +bool hostOwnsUndo
        +bool handleHistoryKeys
        +ValueChanged~String~? onChanged
        +ValueChanged~TextEditingValue~? onValueChanged
    }

    class SyntaxHighlighter {
        <<abstract>>
        +highlight(text) List~HighlightSpan~
    }

    class TomTextMarker {
        +int start
        +int end
        +String message
        +TomTextMarkerSeverity severity
        +int? line
        +int? column
    }

    class TomTextMarkerSeverity {
        <<enumeration>>
        error
        warning
        info
    }

    class TomTextSourceStyle {
        +TextStyle? textStyle
        +TextStyle? lineNumberStyle
        +Color? background
        +Color? gutterBackground
        +Color? gutterBorderColor
        +Color? cursorColor
        +bool highlightCurrentLine
    }

    TomTextSource --> SyntaxHighlighter : uses
    TomTextSource --> TomTextMarker : displays
    TomTextSource --> TomTextSourceStyle : styled with
```

The markers are neutral: `SchemaMarkerGenerator` maps the schema findings onto them, the text mode adds the parse error. `registerYamlSourceActions` offers the source's clipboard and line edits to the editor's action integration while text mode shows it.

**Why shared:** Any editor that opens a raw-text sub-editor (JSON fragment, YAML subtree, TOML section) needs line numbers, syntax highlighting, and error markers.

### 5. InlineControls

Reusable add/remove/collapse button widgets and action row layouts.

```mermaid
classDiagram
    class CollapseToggle {
        +bool isExpanded
        +VoidCallback onToggle
        +Color iconColor
        +double size
    }

    class ActionButton {
        +IconData icon
        +String tooltip
        +Color color
        +VoidCallback? onPressed
        +bool visible
    }

    class NodeActionRow {
        +List~ActionButton~ actions
        +NodeActionRowTheme theme
    }

    NodeActionRow --> ActionButton : contains
```

**Why shared:** Add/remove/collapse buttons with consistent styling are needed in every tree-based editor.

---

## Core Components (tom_yaml_editor)

These components are YAML-specific and depend on `tom_editors_shared`.

### Built-In Type Editors

Each basic type has a dedicated widget. All implement the same protocol:

```mermaid
classDiagram
    class BuiltInTypeEditor {
        <<abstract>>
        +Object? value
        +SchemaNode? schemaNode
        +YamlEditorTheme theme
        +bool readOnly
        +ValueChanged~Object?~ onChanged
        +build() Widget
    }

    class StringEditor {
        +bool isMultiline
        +String? pattern
        +int? minLength
        +int? maxLength
        +List~Object~? enumValues
    }

    class IntegerEditor {
        +int? minimum
        +int? maximum
        +bool showStepper
    }

    class NumberEditor {
        +num? minimum
        +num? maximum
    }

    class BooleanEditor {
        <<toggle switch>>
    }

    class NullEditor {
        +List~SchemaType~ allowedConversions
    }

    class ListEditor {
        +SchemaNode? itemSchema
        +int? minItems
        +int? maxItems
    }

    class MapEditor {
        +Map~String,SchemaNode~ properties
        +List~String~ requiredKeys
    }

    class EnumEditor {
        +List~Object~ values
        +EnumDisplayMode displayMode
    }

    BuiltInTypeEditor <|-- StringEditor
    BuiltInTypeEditor <|-- IntegerEditor
    BuiltInTypeEditor <|-- NumberEditor
    BuiltInTypeEditor <|-- BooleanEditor
    BuiltInTypeEditor <|-- NullEditor
    BuiltInTypeEditor <|-- ListEditor
    BuiltInTypeEditor <|-- MapEditor
    BuiltInTypeEditor <|-- EnumEditor
```

### SubtreeInspector

The subtree inspector combines `TomTextSource` (from `tom_file_editors`) with YAML-specific syntax highlighting and schema-aware markers:

```mermaid
classDiagram
    class SubtreeInspector {
        +List~Object~ subtreePath
        +YamlDocumentModel document
        +YamlSchema? schema
        +YamlEditorTheme theme
        +SubtreeInspectorMode mode
        +applyChanges()
        +cancelChanges()
    }

    class YamlSyntaxHighlighter {
        +highlight(text) List~HighlightSpan~
    }

    class SchemaMarkerGenerator {
        +generate(yamlText, errors) List~TomTextMarker~
    }

    SubtreeInspector --> TomTextSource : wraps (from tom_file_editors)
    SubtreeInspector --> YamlSyntaxHighlighter : uses
    SubtreeInspector --> SchemaMarkerGenerator : uses
    YamlSyntaxHighlighter ..|> SyntaxHighlighter : implements
```

---

## Data Flow

### Edit Cycle (Tree View)

```mermaid
sequenceDiagram
    participant User
    participant ValueEditor as Built-in Type Editor
    participant MapNode
    participant Controller as YamlEditorController
    participant Model as YamlDocumentModel
    participant Validator as YamlSchema

    User->>ValueEditor: types "hello"
    ValueEditor->>MapNode: onChanged("hello")
    MapNode->>Controller: setValue(["prompt","name"], "hello")

    Controller->>Model: withValueAt(path, "hello")
    Model-->>Controller: new YamlDocumentModel

    Controller->>Controller: text changed? record it (merged with the field's typing)
    Controller->>Controller: compare with the saved text (dirty)

    Controller->>Validator: validate(newDocument)
    Validator-->>Controller: List<ValidationError>

    Controller->>Controller: notifyListeners()
    Controller-->>MapNode: rebuild
    MapNode-->>ValueEditor: rebuild with new value
    Controller-->>User: onChanged(yamlText)
    Controller-->>User: onValidationChanged(errors)
```

### Edit Cycle (Subtree Inspector)

```mermaid
sequenceDiagram
    participant User
    participant Inspector as SubtreeInspector
    participant Parser as YamlDocumentModel.parse
    participant Controller as YamlEditorController
    participant Validator as YamlSchema

    User->>Inspector: opens inspector for path ["prompt","meta-data"]
    Inspector->>Inspector: extract subtree YAML text

    loop Live editing (debounced 300ms)
        User->>Inspector: types in text editor
        Inspector->>Parser: parse(fragmentYaml)
        alt Parse success
            Parser-->>Inspector: temp YamlDocumentModel
            Inspector->>Validator: validate subtree
            Validator-->>Inspector: markers
            Inspector->>Inspector: update error markers
        else Parse failure
            Parser-->>Inspector: parse error
            Inspector->>Inspector: show parse error marker
        end
    end

    User->>Inspector: clicks "Apply"
    Inspector->>Controller: setValue(["prompt","meta-data"], parsedSubtree)
    Controller->>Controller: full edit cycle (see tree flow above)
    Inspector->>Inspector: close panel
```

### Undo/Redo Flow

```mermaid
stateDiagram-v2
    [*] --> Clean: initial document

    Clean --> Edited: setValue / insertKey / removeKey
    Edited --> Edited: more edits

    Edited --> Undone: undo()
    Undone --> Edited: redo()
    Undone --> Undone: more undo()
    Undone --> BranchLost: new edit after undo

    note right of BranchLost
        Redo stack is cleared
        when a new edit occurs
        after undo.
    end note

    BranchLost --> Edited: continues as normal

    state Edited {
        [*] --> UndoStack: push operation
        UndoStack --> [*]: clear redo stack
    }
```

---

## Component Relationships

### Full Dependency Graph

```mermaid
graph TD
    YSE["YamlSchemaEditor"] --> YEC["YamlEditorController"]
    YSE --> ER["EditorRegistry"]
    YSE --> YET["YamlEditorTheme"]
    YSE --> TV_W["TreeView (shared)"]
    YSE --> SI["SubtreeInspector"]
    YSE --> VEL["ValidationErrorList"]

    YEC --> YDM["YamlDocumentModel"]
    YEC --> YS["YamlSchema"]
    YEC --> UH["TomUndoStack (tom_undo)"]
    YEC --> SW["SchemaWalker"]

    SI --> TEC["TomTextSource (tom_file_editors)"]
    SI --> YSH["YamlSyntaxHighlighter"]
    SI --> SMG["SchemaMarkerGenerator"]

    VEL --> VF["ValidationFramework (shared)"]

    TV_W --> TT["TreeTheme (shared)"]

    ER --> ES["EditorSuffix"]
    ER --> ERv["EditorResolver"]

    YS --> SN["SchemaNode"]
    SW --> YS

    SMG --> YS

    YSE --> BTE_S["StringEditor"]
    YSE --> BTE_I["IntegerEditor"]
    YSE --> BTE_N["NumberEditor"]
    YSE --> BTE_B["BooleanEditor"]
    YSE --> BTE_Null["NullEditor"]
    YSE --> BTE_L["ListEditor"]
    YSE --> BTE_M["MapEditor"]
    YSE --> BTE_E["EnumEditor"]

    subgraph shared["tom_editors_shared"]
        TV_W
        TT
        VF
        UH
        TEC
        IC["InlineControls"]
    end

    subgraph yaml["tom_yaml_editor"]
        YSE
        YEC
        YDM
        YS
        ER
        SW
        SI
        YSH
        SMG
        VEL
        YET
        ES
        ERv
        SN
        BTE_S
        BTE_I
        BTE_N
        BTE_B
        BTE_Null
        BTE_L
        BTE_M
        BTE_E
    end

    style shared fill:#1a4a3e,color:#fff
    style yaml fill:#1a3a5e,color:#fff
```

---

## Tree Rendering Pipeline

How the widget tree is built from a YAML document:

```mermaid
flowchart TD
    Root["YamlSchemaEditor.build()"] --> GetRoot["controller.document.rootNode"]
    GetRoot --> IsMap{Type?}

    IsMap -->|YamlMap| BuildMap["Build MapNode for each entry"]
    IsMap -->|YamlList| BuildList["Build ListNode for each item"]
    IsMap -->|YamlScalar| BuildScalar["Build ScalarNode"]

    BuildMap --> ForEachKey["For each key-value pair:"]
    ForEachKey --> WalkSchema["schemaWalker.nodeAt(path)"]
    ForEachKey --> ResolveEditor["editorRegistry.resolve(key, path)"]

    ResolveEditor --> HasCustom{Custom editor?}
    HasCustom -->|yes| RenderCustom["Render EditorSuffix.factory()"]
    HasCustom -->|no| CheckType["Check schemaNode.type"]

    CheckType -->|string| Str["StringEditor"]
    CheckType -->|integer| Int["IntegerEditor"]
    CheckType -->|number| Num["NumberEditor"]
    CheckType -->|boolean| Bool["BooleanEditor"]
    CheckType -->|null| Null["NullEditor"]
    CheckType -->|object| Recurse1["Recurse → MapNode"]
    CheckType -->|array| Recurse2["Recurse → ListNode"]

    WalkSchema --> GetErrors["validator.errorsAt(path)"]
    GetErrors --> HasErrors{Errors?}
    HasErrors -->|yes| AddBadge["Add ValidationBadge"]
    HasErrors -->|no| NoBadge["No decoration"]

    AddBadge --> Compose["Compose row: KeyLabel + ValueEditor + Badges + Actions"]
    NoBadge --> Compose

    style Root fill:#2d3a5e,color:#fff
    style Compose fill:#2d5a27,color:#fff
    style RenderCustom fill:#5e3a2d,color:#fff
```

---

## Validation Pipeline

```mermaid
flowchart TD
    Trigger["Validation Triggered"] --> Source{Source?}

    Source -->|Document load| Full["Full validation"]
    Source -->|Edit operation| Incremental["Incremental validation\n(affected subtree only)"]
    Source -->|Schema change| Full
    Source -->|Manual revalidate| Full

    Full --> Walk["Walk entire schema tree"]
    Incremental --> Subtree["Walk schema from edited path"]

    Walk --> ForEachNode["For each schema node:"]
    Subtree --> ForEachNode

    ForEachNode --> CheckType["Check YAML type vs schema type"]
    CheckType -->|mismatch| TypeError["TypeError"]

    ForEachNode --> CheckConstraints["Check constraints\n(min, max, pattern, enum, etc.)"]
    CheckConstraints -->|violation| ConstraintError["ConstraintError"]

    ForEachNode --> CheckRequired["Check required children"]
    CheckRequired -->|missing| RequiredError["RequiredError"]

    ForEachNode --> CheckAdditional["Check additionalProperties"]
    CheckAdditional -->|extra key| Warning["Warning"]

    TypeError --> Collect["Collect ValidationError list"]
    ConstraintError --> Collect
    RequiredError --> Collect
    Warning --> Collect

    Collect --> Propagate["ErrorPropagator.propagate(errors)"]
    Propagate --> Result["Map<pathHash, List<ValidationError>>"]

    Result --> UpdateController["Controller stores errors,\nnotifies listeners"]

    style Trigger fill:#1a4a6e,color:#fff
    style Result fill:#2d5a27,color:#fff
```

---

## Subtree Inspector Design

```mermaid
flowchart LR
    subgraph TreeView["Tree View"]
        Node["MapNode: meta-data"] -->|"click < >"| Open["Open Inspector"]
    end

    subgraph Inspector["Subtree Inspector Panel"]
        direction TB
        Header["Path: prompt > meta-data  [Apply] [×]"]
        Editor["TomTextSource\n+ YamlSyntaxHighlighter\n+ TomTextMarker markers"]
        Header --> Editor
    end

    Open --> Extract["Extract subtree YAML\nfrom document model"]
    Extract --> Editor

    Editor -->|"typing (300ms debounce)"| Parse["Parse fragment"]
    Parse -->|success| Validate["Validate against\nschema subtree"]
    Parse -->|failure| ShowParsErr["Show parse error marker"]
    Validate --> UpdateMarkers["Update error/warning markers"]

    Editor -->|"click Apply"| ApplyFlow["Parse → validate → controller.setValue()"]

    style TreeView fill:#2d3a5e,color:#fff
    style Inspector fill:#3a5e2d,color:#fff
```

### Inspector Modes

```mermaid
graph LR
    Mode{subtreeInspectorMode}
    Mode -->|sidePanel| SP["Side-by-side layout\n(tree left, inspector right)"]
    Mode -->|bottomSheet| BS["Stacked layout\n(tree top, inspector bottom)"]
    Mode -->|dialog| DG["Modal dialog\n(overlays the tree)"]

    style SP fill:#1a4a6e,color:#fff
    style BS fill:#1a4a6e,color:#fff
    style DG fill:#1a4a6e,color:#fff
```

---

## Extension Mechanism

### How Custom Editors Plug In

```mermaid
sequenceDiagram
    participant Host as Host App
    participant Registry as EditorRegistry
    participant YSE as YamlSchemaEditor
    participant TreeView
    participant Factory as EditorFactory

    Host->>Registry: register(EditorSuffix('dart', ...))
    Host->>Registry: register(EditorSuffix('markdown', ...))
    Host->>Registry: withResolver(myCallback)
    Host->>YSE: YamlSchemaEditor(editorRegistry: registry)

    YSE->>TreeView: build tree nodes on document change

    loop For each scalar key
        TreeView->>Registry: resolve(key, path, schemaEditorType)
        alt resolver returns EditorSuffix
            Registry-->>TreeView: EditorSuffix
        else schema x-editor-type matches
            Registry-->>TreeView: EditorSuffix
        else key suffix matches
            Registry-->>TreeView: EditorSuffix
        else no match
            Registry-->>TreeView: null → use built-in
        end

        alt EditorSuffix returned
            TreeView->>Factory: factory(key, value, onChanged, theme, readOnly)
            Factory-->>TreeView: custom Widget
        else null
            TreeView->>TreeView: render built-in type editor
        end
    end
```

---

## Implementation Plan

### Legend

- **Phase**: logical grouping of related tasks
- **Priority**: execution order (1 = first)
- **Package**: which package the work goes into
- **Deps**: tasks that must be complete before this one can start

---

### Phase 1 — Shared Foundation (`tom_editors_shared`)

These are generic, reusable components with zero YAML knowledge.

| # | Task | Description | Package | Deps | Est | Status |
|---|------|-------------|---------|------|-----|--------|
| 1.1 | **Create `tom_editors_shared` package** | `pubspec.yaml`, `analysis_options.yaml`, barrel file, README | `tom_editors_shared` | — | S | ✅ Done |
| 1.2 | **`UndoHistory<T>`** | Generic typed undo/redo stack with `push`, `undo`, `redo`, `clear`, `canUndo`/`canRedo`, configurable `maxDepth`. Unit tests. | `tom_editors_shared` | 1.1 | S | ✅ Done |
| 1.3 | **`ValidationError` model** | `ValidationError` (path, message, severity, code), `ValidationSeverity` enum, `ErrorPropagator` (propagate errors up path ancestors). Unit tests. | `tom_editors_shared` | 1.1 | S | ✅ Done |
| 1.4 | **`ValidationBadge` widget** | Small colored badge showing error/warning count. Themed via `ValidationTheme`. Widget tests. | `tom_editors_shared` | 1.3 | S | ✅ Done |
| 1.5 | **`ValidationTooltip` widget** | Mouse-over tooltip listing errors with severity icons, path, and message. Themed. Widget tests. | `tom_editors_shared` | 1.3 | S | ✅ Done |
| 1.6 | **`TreeNode<T>` model + `TreeController<T>`** | Generic tree node model with children, expanded state, id. Controller with `expand`/`collapse`/`expandAll`/`scrollToNode`. Unit tests. | `tom_editors_shared` | 1.1 | M | ✅ Done |
| 1.7 | **`TreeView<T>` widget** | Renders `List<TreeNode<T>>` with indent guides, tree lines, collapse toggles, keyboard navigation (up/down/left/right/enter). Accepts a `nodeBuilder` for custom row rendering. `TreeTheme` styling. Widget tests. | `tom_editors_shared` | 1.6 | L | ✅ Done |
| 1.8 | **`InlineControls`** | `CollapseToggle`, `ActionButton`, `NodeActionRow` — small reusable button widgets. Widget tests. | `tom_editors_shared` | 1.1 | S | ✅ Done |
| 1.9 | **`SyntaxHighlighter` abstract + `TextMarker`** | Abstract `SyntaxHighlighter` interface, `TextMarker` model (line, col range, type, tooltip), `TextMarkerType` enum. | `tom_editors_shared` | 1.1 | S | ✅ Done |
| 1.10 | **`TextEditorCore` widget** | Themed text editor with line numbers, gutter, syntax highlighting integration, marker overlay (squiggly underlines), marker gutter icons, tooltip on hover. Widget tests. | `tom_editors_shared` | 1.9 | L | ✅ Done |

**Phase 1 deliverable:** A publishable `tom_editors_shared` package with generic tree, validation, undo, text editor, and control widgets. Zero YAML dependency.

---

### Phase 2 — YAML Document Layer (`tom_yaml_editor`)

These tasks build the non-visual YAML document model and schema validation.

| # | Task | Description | Package | Deps | Est | Status |
|---|------|-------------|---------|------|-----|--------|
| 2.1 | **Migrate `YamlEditorController` to `UndoHistory`** | Replace inline undo/redo stacks with `UndoHistory<YamlEditOperation>` from shared. Controller delegates to the shared stack. Unit tests. | `tom_yaml_editor` | 1.2 | S | ✅ Done |
| 2.2 | **Implement `YamlSchema.validate()`** | Walk the schema tree against the document, producing `List<ValidationError>`. Check type, required, pattern, min/max, enum, additionalProperties. Unit tests with known-good and known-bad YAML documents. | `tom_yaml_editor` | 1.3 | L | ✅ Done |
| 2.3 | **`SchemaMarkerGenerator`** | Given parsed YAML text and a schema + base path, produce `List<TextMarker>` mapping validation errors to line/column positions. Unit tests. | `tom_yaml_editor` | 2.2, 1.9 | M | ✅ Done |
| 2.4 | **`YamlSyntaxHighlighter`** | Implement `SyntaxHighlighter` from shared for YAML: keys, values, comments, block scalars, anchors/aliases, flow collections, tag tokens. All colored per `YamlEditorTheme`. Unit tests. | `tom_yaml_editor` | 1.9 | M | ✅ Done |
| 2.5 | **Add `revalidate()` to controller** | Force full re-validation, store errors as `List<ValidationError>`, expose `validationErrorsAt(path)`. Unit tests. | `tom_yaml_editor` | 2.2 | S | ✅ Done |
| 2.6 | **Add `subtreeYamlAt(path)` to `YamlDocumentModel`** | Extract the raw YAML text for a subtree (preserving comments). Also add `replaceSubtreeAt(path, yamlFragment)` to splice edited text back. Unit tests. | `tom_yaml_editor` | — | M | ✅ Done |

**Phase 2 deliverable:** Complete non-visual YAML layer with validation, syntax highlighting, subtree extraction, and undo powered by shared infrastructure.

---

### Phase 3 — Built-In Type Editors (`tom_yaml_editor`)

Individual scalar editor widgets, each self-contained.

| # | Task | Description | Package | Deps | Est | Status |
|---|------|-------------|---------|------|-----|--------|
| 3.1 | **`StringEditor` widget** | TextField, multi-line support, placeholder, pattern validation indicator, themed. Widget tests. | `tom_yaml_editor` | — | M | ✅ Done |
| 3.2 | **`IntegerEditor` widget** | Numeric TextField, input filter, optional ± stepper, min/max validation. Widget tests. | `tom_yaml_editor` | — | S | ✅ Done |
| 3.3 | **`NumberEditor` widget** | Like IntegerEditor but accepts decimals. Widget tests. | `tom_yaml_editor` | 3.2 | S | ✅ Done |
| 3.4 | **`BooleanEditor` widget** | Toggle switch, true/false labels, keyboard support. Widget tests. | `tom_yaml_editor` | — | S | ✅ Done |
| 3.5 | **`NullEditor` widget** | Null chip, type conversion popup. Widget tests. | `tom_yaml_editor` | — | S | ✅ Done |
| 3.6 | **`EnumEditor` widget** | Segmented buttons (≤4), dropdown (5–8), searchable dropdown (>8). Widget tests. | `tom_yaml_editor` | — | M | ✅ Done |
| 3.7 | **`BuiltInEditorFactory`** | Factory function that maps `SchemaType` + `SchemaNode` to the correct built-in widget. Falls back to `StringEditor` for unknowns. Unit tests. | `tom_yaml_editor` | 3.1–3.6 | S | ✅ Done |

**Phase 3 deliverable:** All scalar editors render standalone. Each can be tested in isolation before integration.

---

### Phase 4 — Tree Rendering (`tom_yaml_editor`)

Wire the tree view, built-in editors, and validation together.

| # | Task | Description | Package | Deps | Est | Status |
|---|------|-------------|---------|------|-----|--------|
| 4.1 | **YAML-specific `TreeNode` builder** | Walk `YamlDocumentModel` + `SchemaWalker` to produce `TreeNode<YamlTreeData>` list. Each node carries: path, key, YamlNode, SchemaNode?, validation errors. Unit tests. | `tom_yaml_editor` | 1.6, 2.2 | M | ✅ Done |
| 4.2 | **`MapNode` row widget** | Renders one map entry: `KeyLabel` (with required badge) + `ValueEditor` (from `BuiltInEditorFactory` or `EditorRegistry`) + `NodeActions` (add, remove, inspect). Widget tests. | `tom_yaml_editor` | 3.7, 1.8 | L | ✅ Done |
| 4.3 | **`ListNode` row widget** | Renders one list item: drag handle + index + `ValueEditor` + `NodeActions`. Drag-to-reorder via `ReorderableListView`. Widget tests. | `tom_yaml_editor` | 3.7, 1.8 | M | ✅ Done |
| 4.4 | **`KeyLabel` widget** | Styled key text + required badge + error badge + colon separator. Inline editing on double-click. Widget tests. | `tom_yaml_editor` | 1.4 | S | ✅ Done |
| 4.5 | **`NodeActions` widget** | Row of action buttons: add (from schema suggestions), remove, inspect subtree. Visibility controlled by theme toggles and `readOnly`. Widget tests. | `tom_yaml_editor` | 1.8 | S | ✅ Done |
| 4.6 | **`YamlSchemaEditor.build()` implementation** | Wire everything: create YAML tree nodes from document, pass to `TreeView`, each node renders `MapNode` or `ListNode` or `ScalarNode`. Validation badges + tooltips on flagged nodes. Error propagation to ancestors. | `tom_yaml_editor` | 4.1–4.5, 1.7 | L | ✅ Done |
| 4.7 | **Collapse/expand persistence** | Remember expanded state across document edits (by path hash). When a new key is inserted, auto-expand its parent. | `tom_yaml_editor` | 4.6 | S | ✅ Done |
| 4.8 | **Keyboard navigation** | Arrow keys navigate between nodes, Enter/Space activates editor, Escape closes editor, Tab moves to next sibling. | `tom_yaml_editor` | 4.6 | M | ✅ Done |

**Phase 4 deliverable:** The `YamlSchemaEditor` renders a fully interactive YAML tree with built-in type editors, validation indicators, and keyboard navigation.

---

### Phase 5 — Subtree Inspector (`tom_yaml_editor`)

| # | Task | Description | Package | Deps | Est |
|---|------|-------------|---------|------|-----|
| 5.1 | **`SubtreeInspector` widget** | Wraps `TextEditorCore` with YAML syntax highlighting and schema markers. Header with path breadcrumb, Apply/Cancel buttons. Widget tests. | `tom_yaml_editor` | 1.10, 2.3, 2.4, 2.6 | L | ✅ Done |
| 5.2 | **Side panel mode** | `SubtreeInspectorMode.sidePanel`: tree and inspector side by side with resizable divider. Widget tests. | `tom_yaml_editor` | 5.1 | M | ✅ Done |
| 5.3 | **Bottom sheet mode** | `SubtreeInspectorMode.bottomSheet`: tree on top, inspector on bottom with resizable divider. Widget tests. | `tom_yaml_editor` | 5.1 | S | ✅ Done |
| 5.4 | **Dialog mode** | `SubtreeInspectorMode.dialog`: modal dialog overlay. Widget tests. | `tom_yaml_editor` | 5.1 | S | ✅ Done |
| 5.5 | **Live preview** | Debounced parsing + validation as user types. Tree view highlights the edited subtree. | `tom_yaml_editor` | 5.1, 4.6 | M | ✅ Done |
| 5.6 | **Apply/Cancel flow** | Apply: parse fragment, validate, if valid → `controller.setValue()`, close inspector. Cancel: discard, close. If parse errors → block Apply with alert. | `tom_yaml_editor` | 5.1, 2.6 | S | ✅ Done |

**Phase 5 deliverable:** Full subtree inspection with three layout modes, live preview, and schema markers in the text editor.

---

### Phase 6 — Validation Error List (`tom_yaml_editor`)

| # | Task | Description | Package | Deps | Est |
|---|------|-------------|---------|------|-----|
| 6.1 | **`ValidationErrorList` widget** | Scrollable list of all validation errors with severity icon, path breadcrumb, and message. Click-to-navigate. Themed. Widget tests. | `tom_yaml_editor` | 1.3, 1.4 | M | ✅ Done |
| 6.2 | **Error list positioning** | `ErrorListPosition.bottom` and `.side` layouts integrated into `YamlSchemaEditor`. Widget tests. | `tom_yaml_editor` | 6.1, 4.6 | S | ✅ Done |
| 6.3 | **Error row highlighting** | `highlightErrorRows: true` tints tree row backgrounds for nodes with errors. Widget tests. | `tom_yaml_editor` | 4.6 | S | ✅ Done |

**Phase 6 deliverable:** Optional error summary panel with click-to-navigate and sortable errors.

---

### Phase 7 — Test Custom Editors (`tom_yaml_editor_test`)

Verify the extension mechanism works end-to-end with real custom editors.

| # | Task | Description | Package | Deps | Est | Status |
|---|------|-------------|---------|------|-----|--------|
| 7.1 | **Upgrade `DartEditorStub`** | Replace the current `TextField` stub with a proper colored text area with Dart keyword highlighting (basic regex-based). Register as `EditorSuffix(suffix: 'dart')`. | `tom_yaml_editor_test` | 4.6 | M | ✅ Done |
| 7.2 | **Upgrade `MarkdownEditorStub`** | Add a preview/edit toggle: edit mode = text area, preview mode = rendered markdown (using a simple parser). Register as `EditorSuffix(suffix: 'markdown')`. | `tom_yaml_editor_test` | 4.6 | M | ✅ Done |
| 7.3 | **Upgrade `RegexEditorStub`** | Add a test input field and live match indicator (green/red border). Register as `EditorSuffix(suffix: 'regex')`. | `tom_yaml_editor_test` | 4.6 | S | ✅ Done |
| 7.4 | **Add `JsonEditorStub`** | TextArea with JSON formatting on paste and basic brace matching. Register as `EditorSuffix(suffix: 'json')`. | `tom_yaml_editor_test` | 4.6 | S | ✅ Done |
| 7.5 | **Add `ColorPickerStub`** | Hex input + color swatch preview. Register as `EditorSuffix(suffix: 'color')`. Register via the `EditorResolver` callback to also match any key containing "color" regardless of suffix. | `tom_yaml_editor_test` | 4.6 | S | ✅ Done |
| 7.6 | **End-to-end test scenario** | Load `sample_prompt.yaml` with `prompt_schema.json`, verify: tree renders, built-in editors work, custom editors activate for suffix keys, validation badges appear, subtree inspector opens, apply/cancel works, undo/redo works. Manual test + screenshot. | `tom_yaml_editor_test` | 7.1–7.5, 5.6 | L | ✅ Done |
| 7.7 | **Control panel integration** | Update the test app control panel: theme toggle (dark/light), all feature switches, error list toggle, inspector mode selector, registry stats display. | `tom_yaml_editor_test` | 7.6 | M | ✅ Done |

**Phase 7 deliverable:** Test app demonstrates all features with 5 custom editors, full theming, and all feature toggles.

---

### Phase 8 — Polish & Documentation

| # | Task | Description | Package | Deps | Est | Status |
|---|------|-------------|---------|------|-----|--------|
| 8.1 | **API documentation** | Dartdoc on all public APIs: `tom_editors_shared` and `tom_yaml_editor`. Every public class, method, and property has a doc comment with example. | both | 7.6 | M | ✅ Done |
| 8.2 | **README.md for `tom_editors_shared`** | Description, quick start, component summary, API links. | `tom_editors_shared` | 8.1 | S | ✅ Done |
| 8.3 | **README.md for `tom_yaml_editor`** | Description, screenshots, quick start, link to spec doc, API links. | `tom_yaml_editor` | 8.1 | S | ✅ Done |
| 8.4 | **Performance profiling** | Test with a 500+ key YAML document. Identify and fix any frame drops during scrolling, editing, or validation. Add lazy rendering for large documents. | `tom_yaml_editor` | 7.6 | M | ✅ Done |
| 8.5 | **Accessibility audit** | Verify keyboard navigation, screen reader labels, focus order, contrast ratios. Fix any issues. | `tom_yaml_editor` | 7.6 | M | ✅ Done |

---

### Implementation Order Summary

```mermaid
gantt
    title Implementation Phases
    dateFormat  YYYY-MM-DD
    axisFormat  %b %d

    section Phase 1: Shared
    Package setup           :p1_1, 2026-03-03, 1d
    UndoHistory             :p1_2, after p1_1, 1d
    ValidationError model   :p1_3, after p1_1, 1d
    ValidationBadge         :p1_4, after p1_3, 1d
    ValidationTooltip       :p1_5, after p1_3, 1d
    TreeNode + Controller   :p1_6, after p1_1, 2d
    TreeView widget         :p1_7, after p1_6, 3d
    InlineControls          :p1_8, after p1_1, 1d
    SyntaxHighlighter       :p1_9, after p1_1, 1d
    TextEditorCore          :p1_10, after p1_9, 3d

    section Phase 2: YAML Layer
    Migrate UndoHistory     :p2_1, after p1_2, 1d
    Schema validation       :p2_2, after p1_3, 3d
    SchemaMarkerGenerator   :p2_3, after p2_2, 2d
    YamlSyntaxHighlighter   :p2_4, after p1_9, 2d
    revalidate()            :p2_5, after p2_2, 1d
    subtreeYamlAt()         :p2_6, after p1_1, 2d

    section Phase 3: Type Editors
    StringEditor            :p3_1, after p1_1, 2d
    IntegerEditor           :p3_2, after p1_1, 1d
    NumberEditor            :p3_3, after p3_2, 1d
    BooleanEditor           :p3_4, after p1_1, 1d
    NullEditor              :p3_5, after p1_1, 1d
    EnumEditor              :p3_6, after p1_1, 2d
    BuiltInEditorFactory    :p3_7, after p3_6, 1d

    section Phase 4: Tree Rendering
    TreeNode builder        :p4_1, after p1_7, 2d
    MapNode widget          :p4_2, after p3_7, 3d
    ListNode widget         :p4_3, after p3_7, 2d
    KeyLabel widget         :p4_4, after p1_4, 1d
    NodeActions widget      :p4_5, after p1_8, 1d
    YamlSchemaEditor.build  :p4_6, after p4_2, 3d
    Collapse persistence    :p4_7, after p4_6, 1d
    Keyboard navigation     :p4_8, after p4_6, 2d

    section Phase 5: Inspector
    SubtreeInspector        :p5_1, after p1_10, 3d
    Side panel mode         :p5_2, after p5_1, 2d
    Bottom sheet mode       :p5_3, after p5_1, 1d
    Dialog mode             :p5_4, after p5_1, 1d
    Live preview            :p5_5, after p5_1, 2d
    Apply/Cancel flow       :p5_6, after p5_1, 1d

    section Phase 6: Error List
    ValidationErrorList     :p6_1, after p1_4, 2d
    Error list positioning  :p6_2, after p6_1, 1d
    Error row highlighting  :p6_3, after p4_6, 1d

    section Phase 7: Test Editors
    Dart editor stub        :p7_1, after p4_6, 2d
    Markdown editor stub    :p7_2, after p4_6, 2d
    Regex editor stub       :p7_3, after p4_6, 1d
    JSON editor stub        :p7_4, after p4_6, 1d
    Color picker stub       :p7_5, after p4_6, 1d
    E2E test scenario       :p7_6, after p7_5, 2d
    Control panel           :p7_7, after p7_6, 2d

    section Phase 8: Polish
    API documentation       :p8_1, after p7_6, 2d
    READMEs                 :p8_2, after p8_1, 1d
    Performance             :p8_4, after p7_6, 2d
    Accessibility           :p8_5, after p7_6, 2d
```

### Size Estimates

| Symbol | Meaning |
|--------|---------|
| **S** | Small — ≤ 1 hour |
| **M** | Medium — 2–4 hours |
| **L** | Large — 4–8 hours |

### Total Estimates by Phase

| Phase | Tasks | Estimated Time |
|-------|-------|---------------|
| Phase 1 — Shared Foundation | 10 | ~20 hours |
| Phase 2 — YAML Document Layer | 6 | ~12 hours |
| Phase 3 — Built-In Type Editors | 7 | ~8 hours |
| Phase 4 — Tree Rendering | 8 | ~18 hours |
| Phase 5 — Subtree Inspector | 6 | ~12 hours |
| Phase 6 — Validation Error List | 3 | ~4 hours |
| Phase 7 — Test Custom Editors | 7 | ~12 hours |
| Phase 8 — Polish & Docs | 5 | ~10 hours |
| **Total** | **52 tasks** | **~96 hours** |
