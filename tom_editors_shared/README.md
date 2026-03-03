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
| **Undo/Redo** | `UndoHistory`, `UndoEntry` | Typed undo/redo stack with configurable depth and description tracking |
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

```dart
final history = UndoHistory<String>(maxDepth: 50);

history.push(oldState: 'v1', newState: 'v2', description: 'edit');
final entry = history.undo(); // => UndoEntry(oldState: 'v1', newState: 'v2')
history.redo();               // re-applies
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

See the repository root `LICENSE` file.
