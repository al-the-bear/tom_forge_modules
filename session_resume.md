# YAML Editor — Session Resume

**Date:** 3 March 2026
**Latest commit:** `9ca182292b1` — `feat: add right-click context menus and complex workflow dataset`
**Git status:** Clean (no uncommitted changes)
**Branch:** `main`

---

## 1. Project Overview

A non-destructive, schema-aware YAML editor built as a Flutter widget ecosystem. Split into three packages under `tom_editors/`:

| Package | Purpose | Version |
|---------|---------|---------|
| `tom_editors_shared` | Reusable tree, validation, undo, text editor, controls | 0.1.0 |
| `tom_yaml_editor` | Schema-aware YAML editor widget library | 0.1.0 |
| `tom_yaml_editor_test` | Flutter macOS test app demonstrating all features | 0.1.0 |

**Architecture doc:** `tom_yaml_editor/doc/yaml_editor_architecture_design.md` (1073 lines, full component design + 52-task implementation plan)

---

## 2. What Has Been Built (Complete)

### Phase 1–8: Core Architecture (All Complete)

| Phase | Commit | Content |
|-------|--------|---------|
| 1–2 | `b6265f7043d` | `tom_editors_shared` (TreeView, TreeController, UndoHistory, ValidationError, ErrorPropagator, ValidationBadge, TextEditorCore) + `tom_yaml_editor` YAML Document Layer (YamlDocumentModel wrapping `yaml_edit`, YamlEditOperation, YamlEditKind) |
| 3–4 | `8cca4b567bf` | Built-in type editors (StringEditor, IntegerEditor, NumberEditor, BooleanEditor, NullEditor, EnumEditor, BuiltInEditorFactory) + Tree rendering (YamlTreeNodeBuilder, MapNodeRow, ListNodeRow, KeyLabel, YamlNodeActions, YamlSchemaEditor) |
| 5–6 | `5bee4a4c3df` | SubtreeInspector (side panel, bottom sheet, dialog modes) + ValidationErrorList with error-tap navigation |
| 7–8 | `52874c53a19` | Custom embedded editors (EditorRegistry with suffix convention), SchemaWalker, SchemaMarkerGenerator, API docs, READMEs, perf + a11y |

### Post-Phase Polish (All Complete)

| Feature | Commit | Details |
|---------|--------|---------|
| Variable-height rows | `848cf6e3209` | `TreeTheme.rowHeight` made nullable — `null` means variable height for embedded editors |
| Editor alignment | `25c53970ce8` | `keyLabelWidth` param on MapNodeRow, smaller boolean toggles (FittedBox 32×18), centered color picker, reduced color picker height |
| Indent guides + dynamic widths | `4d6b190d8b0` | Replaced `_TreeLinePainter` with `_IndentGuidePainter` (VS Code-style ├/└/│ guides using `_GuideType` enum). Made `keyLabelWidth` nullable with auto-computation per sibling group via TextPainter |
| Gap reduction | `b44a80597a2` + `5d1fab0beed` | Badge padding 30→12px, gap 8→4px |
| Double-click toggle | `2edab88be70` | `onNodeDoubleTap` in YamlSchemaEditor toggles expand/collapse |
| Right-click context menus | `9ca182292b1` | **This session's main deliverable** — see section 3 |

---

## 3. This Session's Work (Commit `9ca182292b1`)

### 3.1 Right-Click Context Menus

**New file:** `tom_yaml_editor/lib/src/tree/node_context_menu.dart`

Two enum types and three helper functions:

- **`MapContextAction`** — `insertKeyAbove`, `insertKeyBelow`, `removeKey`, `inspectAsYaml`
- **`ListContextAction`** — `moveUp`, `moveDown`, `moveToTop`, `moveToBottom`, `insertAbove`, `insertBelow`, `duplicate`, `remove`
- **`showMapContextMenu()`** — Shows popup for map entries. Only shows "Insert key above/below" when `suggestedKeys` is non-empty. Respects `canRemove` / `canInspect` flags.
- **`showListContextMenu()`** — Shows popup for list items. Move actions are disabled when at boundary (first/last). All items get insert, duplicate, remove.
- **`showKeySelectionMenu()`** — Sub-menu letting user pick which key to insert (from schema suggestions). Returns immediately if only one key.

### 3.2 MapNodeRow Changes

- Added `import 'node_context_menu.dart'`
- Wrapped `MouseRegion` in `GestureDetector(onSecondaryTapUp: ...)` for right-click
- Added `_showContextMenu()` method:
  - Gets suggested keys from controller (using parent path)
  - On `insertKeyAbove`/`insertKeyBelow`: opens key selection sub-menu, then calls `controller.insertKeyAdjacent()`
  - On `removeKey`: calls `controller.removeKey()`
  - On `inspectAsYaml`: calls `widget.onInspect`

### 3.3 ListNodeRow Changes

- Added imports for `node_context_menu.dart` and `yaml_schema.dart` (for `SchemaType`)
- Wrapped `MouseRegion` in `GestureDetector(onSecondaryTapUp: ...)` for right-click
- Added helper getters: `_parentListPath`, `_currentIndex`
- Added `_showContextMenu()` method:
  - Gets list length from controller
  - Handles all `ListContextAction` values with proper index arithmetic
  - `moveDown` uses `currentIndex + 1` (controller adjusts internally)
  - `moveToBottom` uses `length - 1`
  - `duplicate` copies `_data.value` and inserts at `currentIndex + 1`
- Added `_defaultListItemValue()` — creates defaults from schema `items` type

### 3.4 Controller Methods Added

In `yaml_editor_controller.dart`, after `removeKey()`:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `insertListItem` | `(List<String> listPath, int index, Object? value)` | Insert at specific index |
| `appendListItem` | `(List<String> listPath, Object? value)` | Append to end |
| `moveListItem` | `(List<String> listPath, int oldIndex, int newIndex)` | Remove + reinsert with adjusted index |
| `listLength` | `(List<String> listPath) → int` | Returns list length (0 if not a list) |
| `insertKeyAdjacent` | `(List<String> siblingPath, String newKey, Object? value, {bool above})` | Falls back to normal `withInsertedKey` — yaml_edit doesn't support positional map insert |

**Known limitation:** `insertKeyAdjacent` does not actually insert above/below the sibling — it appends to the map. The `yaml_edit` package doesn't expose positional map key insertion. The key appears at the end of the map. A future improvement would re-serialize the YAML with the desired key order.

### 3.5 Complex Test Data

**`tom_yaml_editor_test/assets/complex_schema.json`** (~267 lines):
- Root type: `workflow` (object)
- Sections: `meta-data` (9 fields incl. color), `environment` (6 fields incl. env-vars map + runtime enum), `steps` (array of objects, 11 fields each incl. dart/json/regex/markdown editors, enums, depends-on array), `notifications` (array, 5 fields with event/channel enums), `output` (5 fields), `schedule` (4 fields incl. cron pattern)
- Uses `x-editor-type` for embedded editors
- Exercises nested maps, arrays of objects, enums, patterns, min/max constraints

**`tom_yaml_editor_test/assets/complex_workflow.yaml`** (~254 lines):
- 7 workflow steps: fetch-data, validate-schema, transform, enrich, quality-check, report, route
- 4 notifications: slack, email, telegram, webhook
- Environment config with env-vars map and runtime enum
- Output config with format, compression, partitioning
- Schedule with cron expression

### 3.6 Test App Updates

In `tom_yaml_editor_test/lib/main.dart`:
- Added `_activeDataset` state (`'prompt'` or `'workflow'`)
- Added `_switchDataset(String dataset)` method — loads the appropriate schema JSON + YAML file, recreates controller
- Added `SegmentedButton<String>` in the app bar to toggle between "Prompt" and "Workflow" datasets
- Updated `_loadSchema()` to use `_activeDataset` for schema file selection
- Updated `_loadSampleYaml()` to load the appropriate sample YAML based on active dataset

---

## 4. File Inventory

### tom_editors_shared

```
lib/
  tom_editors_shared.dart              # Barrel file
  src/
    controls/
      action_button.dart               # Reusable icon button for actions
      collapse_toggle.dart             # Expand/collapse triangle toggle
      node_action_row.dart             # Row of action buttons
    text_editor/
      syntax_highlighter.dart          # Base syntax highlighter interface
      text_editor_core.dart            # Syntax-highlighted text field widget
      text_editor_theme.dart           # Text editor theming
      text_marker.dart                 # Text marker model
    tree/
      tree_controller.dart             # Selection, focus, expand/collapse state
      tree_node.dart                   # Generic TreeNode<T> model
      tree_theme.dart                  # TreeTheme (rowHeight nullable)
      tree_view.dart                   # TreeView widget with indent guide painter
    undo_history.dart                  # Generic UndoHistory<T> with UndoEntry
    validation/
      error_propagator.dart            # Propagates errors up the tree
      validation_badge.dart            # Inline error/warning badge
      validation_error.dart            # ValidationError + ValidationSeverity
      validation_tooltip.dart          # Rich tooltip for validation errors
```

### tom_yaml_editor

```
lib/
  tom_yaml_editor.dart                 # Barrel file (all public exports)
  src/
    editors/
      built_in/
        boolean_editor.dart            # Toggle switch (FittedBox 32×18)
        built_in_editor_factory.dart   # Schema-type → editor factory
        enum_editor.dart               # Dropdown for enum values
        integer_editor.dart            # Integer input with validation
        null_editor.dart               # Read-only null display
        number_editor.dart             # Numeric input with decimal support
        string_editor.dart             # Text field for strings
      editor_registry.dart             # EditorRegistry (suffix→factory map)
      embedded_editor.dart             # EmbeddedEditor typedef + EditorSuffix
    inspector/
      inspector_dialog.dart            # Modal dialog inspector
      inspector_layouts.dart           # Side panel + bottom sheet layouts
      subtree_inspector.dart           # Raw YAML text editor for subtrees
    model/
      yaml_document_model.dart         # Non-destructive YAML model (yaml_edit)
      yaml_edit_operation.dart          # YamlEditOperation + YamlEditKind enum
    schema/
      schema_marker_generator.dart     # Generates TextMarkers from schema
      schema_walker.dart               # SchemaWalker (path→schema resolution)
      yaml_schema.dart                 # YamlSchema, SchemaNode, SchemaType
    text_editor/
      yaml_syntax_highlighter.dart     # YAML syntax highlighting
    tree/
      key_label.dart                   # Key name label with required dot
      list_node_row.dart               # List item renderer (+ context menu)
      map_node_row.dart                # Map entry renderer (+ context menu)
      node_actions.dart                # Hover action buttons (add/remove/inspect)
      node_context_menu.dart           # Right-click context menus (NEW)
      yaml_tree_node_builder.dart      # Builds TreeNode<YamlTreeData> from YAML
    validation/
      validation_error_list.dart       # Scrollable error list panel
    yaml_editor_controller.dart        # Controller (state, undo/redo, validation)
    yaml_editor_theme.dart             # Full theme system (colors, fonts, spacing)
    yaml_schema_editor.dart            # Main widget (tree + inspector + errors)
doc/
  yaml_editor_architecture_design.md   # Full architecture + 52-task plan
```

### tom_yaml_editor_test

```
lib/
  main.dart                            # Test app (controls, log, dataset switcher)
  editors/
    editors.dart                       # Barrel file for stub editors
    color_picker_stub.dart             # Color editor stub
    dart_editor_stub.dart              # Dart code editor stub
    json_editor_stub.dart              # JSON editor stub
    markdown_editor_stub.dart          # Markdown editor stub
    regex_editor_stub.dart             # Regex editor stub
assets/
  prompt_schema.json                   # Simple prompt schema
  sample_prompt.yaml                   # Simple prompt YAML
  complex_schema.json                  # Complex workflow schema (NEW)
  complex_workflow.yaml                # Complex workflow YAML (NEW)
```

---

## 5. Key Architecture Decisions

### Theme System
- `YamlEditorTheme` with `YamlEditorColors`, `YamlStructureColors`, `YamlEditorFontSettings`
- Dark and light presets via factory constructors
- `copyWith` for selective overrides
- `keyLabelWidth`: nullable — `null` enables auto-compute per sibling group
- `keyLabelMinWidth`: floor for auto-computed widths (default 60px)
- `badgePadding`: 12px (buffer for required dot in auto-width mode)

### Tree Rendering
- `TreeView` in `tom_editors_shared` — generic, data-agnostic tree widget
- `TreeTheme.rowHeight`: nullable — `null` means variable height (needed for embedded editors)
- `_IndentGuidePainter`: VS Code-style indent guides using `_GuideType` enum (none/continues/lastChild)
- Bottom-to-top scan for determining which connector to draw (├ vs └ vs │)
- Expand/collapse state persisted in `_persistedExpanded` set (survives document rebuilds)

### Document Model
- `YamlDocumentModel` wraps `package:yaml_edit` for non-destructive edits
- All mutations return new model instances (immutable pattern)
- Operations: `withValueAt`, `withInsertedKey`, `withRemovedKey`, `withAppendedToList`, `withInsertedIntoList`, `withRemovedFromList`, `replaceSubtreeAt`
- Comments and whitespace preserved through `yaml_edit`

### Editor Registry
- Suffix convention: key `-dart` → Dart editor, `-markdown` → Markdown editor, etc.
- Schema override: `x-editor-type` in JSON Schema
- `EditorRegistry.resolve()` checks: (1) schema `x-editor-type`, (2) key suffix, (3) explicit registrations
- Custom resolver functions for cross-cutting concerns (e.g., color editor matches `*-color` AND `SchemaType.string` with `x-editor-type: color`)

### Context Menus
- `GestureDetector(onSecondaryTapUp:)` wrapping each row's `MouseRegion`
- `showMenu<T>()` for native Flutter popup menus
- Items disabled at boundary conditions (first item can't move up, etc.)
- Menu items have 32px height, 12px font, 16px icons with theme-colored icons

---

## 6. How to Run

```bash
# From workspace root
cd tom_editors/tom_yaml_editor_test
flutter run -d macos
```

The test app opens with the "Prompt" dataset by default. Use the **Prompt/Workflow** segmented button in the toolbar to switch datasets. Right-click any tree node to see context menu options.

### Key Test App Controls (right panel):
- **Dark/Light theme** toggle
- **Read only** mode
- **Display toggles**: tree lines, collapse toggles, add/remove buttons, inline validation
- **Inspector mode**: Side panel / Bottom sheet / Dialog
- **Error list position**: Off / Bottom / Side
- **Error row highlighting** toggle
- **Toolbar**: Undo, Redo, Load sample, Reset, 500-key stress test, Copy YAML

---

## 7. Known Limitations & Future Work

### Known Limitations
1. **`insertKeyAdjacent` is positionally inaccurate** — `yaml_edit` doesn't support positional map key insertion. New keys always appear at the end of the map, not above/below the sibling. Would require custom YAML re-serialization.
2. **No drag-and-drop** for list reordering — only right-click menu.
3. **Schema is read-only** — no runtime schema editing or schema generation from YAML.
4. **Single-document** — no multi-document YAML support.

### Potential Next Steps
- Fix positional key insertion (re-serialize map with desired key order)
- Add drag-and-drop for list items
- Add keyboard shortcuts for context menu actions (Ctrl+Shift+Up/Down for move)
- Add "Add to top" / "Add to bottom" actions for list parent nodes (currently only on items)
- Add "Collapse all" / "Expand all" to context menus for container nodes
- Consider adding an "Add item" context menu option when right-clicking the list parent node itself (not just individual items)

---

## 8. Dependencies

### tom_editors_shared
- `flutter` SDK

### tom_yaml_editor
- `flutter` SDK
- `yaml: ^3.1.0` — YAML parsing
- `yaml_edit: ^2.2.0` — Non-destructive YAML editing
- `tom_editors_shared` (path dependency)

### tom_yaml_editor_test
- `flutter` SDK
- `tom_yaml_editor` (path dependency)
- `flutter_lints: ^5.0.0` (dev)

---

## 9. Commit History (Chronological)

```
5b939a44b44  feat: add tom_yaml_editor library and tom_yaml_editor_test app
a97d114d476  feat(tom_yaml_editor): implement non-destructive YAML parser/writer
1f9209c3607  docs: rename and expand yaml_schema-based_editor.md
2a5a41f99f7  docs: add mermaid diagrams to spec, create architecture design doc
b6265f7043d  Phase 1-2: tom_editors_shared + YAML Document Layer
8cca4b567bf  Phase 3-4: Built-in type editors + tree rendering
5bee4a4c3df  Phase 5-6: Subtree inspector + validation error list
52874c53a19  Phase 7-8: Custom editors, API docs, READMEs, perf & a11y
848cf6e3209  fix: variable-height tree rows for embedded editors
25c53970ce8  fix: align editors by depth, shrink boolean toggle & color picker
4d6b190d8b0  feat: VS Code-style indent guides + dynamic key label widths
b44a80597a2  fix: reduce key-to-editor gap (badge padding 30→6, gap 8→4px)
5d1fab0beed  fix: increase badge padding to 12px to prevent required-dot overflow
2edab88be70  feat: double-click on container node toggles expand/collapse
ebcb596bc85  chore: gitignore editor build artifacts
9ca182292b1  feat: add right-click context menus and complex workflow dataset
```

---

## 10. Quick Reference for Resuming

1. **Read this file** for full context
2. **Architecture doc**: `tom_yaml_editor/doc/yaml_editor_architecture_design.md`
3. **Run the app**: `cd tom_editors/tom_yaml_editor_test && flutter run -d macos`
4. **Analyze**: `cd tom_editors/tom_yaml_editor && dart analyze` (expect only the path-dependency warning)
5. **All code is committed and clean** — no uncommitted changes as of `9ca182292b1`
