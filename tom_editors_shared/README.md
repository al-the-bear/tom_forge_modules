# Tom Editors Shared

Reusable Flutter widgets and utilities for tree-based structured editors.
Provides generic tree views, a validation framework, undo/redo history,
a syntax-highlighted text editor core, and inline control widgets.

**Version:** 0.1.0  
**SDK:** Dart ≥ 3.0.0 · Flutter

## Features

| Component | Classes | Purpose |
|-----------|---------|---------|
| **Tree** | `TreeNode`, `TreeController`, `TreeView`, `TreeTheme` | Generic tree data model with expand/collapse, selection, keyboard nav, and theming |
| **Validation** | `ValidationError`, `ValidationBadge`, `ValidationTooltip`, `ErrorPropagator` | Severity-based errors that propagate up the tree, with badge and tooltip widgets |
| **Undo/Redo** | `TextUndoEntry` | A text change with its before and after selection, kept on `tom_undo`'s `TomUndoStack` — the one undo stack the workspace's editors share |
| **Text Editor** | `TextEditorCore`, `SyntaxHighlighter`, `TextMarker`, `TextEditorTheme` | Line-numbered text editor with pluggable syntax highlighting and marker overlays |
| **Controls** | `CollapseToggle`, `ActionButton`, `NodeActionRow` | Compact widgets for tree-row inline actions (expand, add, delete, etc.) |

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  tom_editors_shared:
    path: ../tom_editors_shared   # or publish to pub.dev
```

Then import:

```dart
import 'package:tom_editors_shared/tom_editors_shared.dart';
```

The package has no webview and bundles no diagram renderer: Mermaid diagrams
(`MermaidWebView`, with mermaid.js and the webview plugin) are in the package
`tom_mermaid_view`, which only applications that render diagrams take.

A library that needs only the text and editor-contract types the Forge shell shares with its editors
(`ForgeTextSettings`, `ForgeTextDefaults`, `ForgeTextContext`,
`StandardEditingActions`, `ForgeAction`, `ForgeShortcutKey`,
`EditorStateSnapshot`, `EditorActionDescriptor`, `EditorActionProvider`,
`EditorCapabilities`, `ForgeSavedMarker`) imports the smaller library
instead:

```dart
import 'package:tom_editors_shared/text_types.dart';
```

## Quick Examples

### Tree View

```dart
final nodes = [
  TreeNode<String>(
    id: 'root',
    data: 'Root',
    children: [
      TreeNode(id: 'child-1', data: 'Child 1'),
      TreeNode(id: 'child-2', data: 'Child 2'),
    ],
  ),
];

final controller = TreeController<String>(roots: nodes);

TreeView<String>(
  controller: controller,
  theme: TreeTheme(),
  rowBuilder: (context, node, isSelected, isFocused) {
    return Text(node.data);
  },
);
```

### Undo/Redo

The stack is `tom_undo`'s `TomUndoStack` (`package:tom_undo/tom_undo.dart`);
this package supplies the text entry the standalone integrations keep on it.

```dart
final history = TomUndoStack<TextUndoEntry>(maxEntries: 50);

history.push(TextUndoEntry(oldText: 'v1', newText: 'v2', description: 'edit'));
history.undo((e) => controller.text = e.oldText); // applied, then moved to redo
history.redo((e) => controller.text = e.newText);
```

### Validation

```dart
final error = ValidationError(
  path: ['server', 'port'],
  message: 'Must be between 1 and 65535',
  severity: ValidationSeverity.error,
);

// Show in UI
ValidationBadge(errors: [error]);
ValidationTooltip(errors: [error], child: myWidget);
```

### Text Editor

```dart
TextEditorCore(
  text: sourceCode,
  onChanged: (value) => setState(() => sourceCode = value),
  highlighter: MyCustomHighlighter(),
  theme: TextEditorTheme(),
  readOnly: false,
);
```

## Architecture

This package contains **zero format-specific logic**. All components are
generic and can be used for any tree-structured editor — YAML, JSON, XML,
TOML, or custom formats. The sibling package `tom_yaml_editor` builds on
these foundations for YAML-specific editing.

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.
