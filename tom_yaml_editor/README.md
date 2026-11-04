# Tom YAML Editor

A non-destructive, schema-aware YAML editor Flutter widget with convention-based
embedded editors. Detects key suffixes like `-dart`, `-markdown`, `-regex`,
`-json` to embed specialised editors inline. Fully customisable theming and
features.

**Version:** 0.1.0  
**SDK:** Dart ≥ 3.0.0 · Flutter  
**Depends on:** `tom_editors_shared`, `yaml`, `yaml_edit`

## Features

- **Non-destructive editing** — preserves comments, formatting, and key ordering
  via `yaml_edit`
- **Schema-aware** — reads JSON Schema for validation, construction help, and
  structural guidance
- **Convention-based embedded editors** — key suffixes trigger specialised
  inline editors automatically
- **Custom editor registration** — plug in any editor via `EditorRegistry` with
  suffix matchers or key-based resolvers
- **Subtree inspector** — side panel, bottom sheet, or dialog for focused
  subtree editing
- **Validation error list** — filterable, sortable error panel with row
  highlighting
- **Full theming** — colours, fonts, structure indicators, and embedded-editor
  chrome are all customisable via `YamlEditorTheme`
- **Undo/redo** — one history per document (`ForgeTextHistory` over the
  source text), shared by tree and source mode and every view: typing in the
  source or in one field is one entry per gesture, a source draft that does
  not parse survives undo and redo, dirty is measured against the saved text
  (the Forge history contract)
- **Tree view** — collapsible, keyboard-navigable YAML structure tree

## Quick Start

```yaml
dependencies:
  tom_yaml_editor:
    path: ../tom_yaml_editor   # or publish to pub.dev
```

```dart
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

final controller = YamlEditorController(
  initialYaml: myYamlString,
  schema: myJsonSchema,
);

YamlSchemaEditor(
  controller: controller,
  theme: YamlEditorTheme.dark(),
  editorRegistry: EditorRegistry.defaults(),
)
```

## Embedding Guides

- [doc/how_to_embed.md](doc/how_to_embed.md) — easiest embedding patterns for
  `SimpleYamlSchemaEditor` and advanced controller-based usage.
- [doc/how_to_embed_with_dart_editor.md](doc/how_to_embed_with_dart_editor.md)
  — register and embed `tom_dart_editor` for `-dart` YAML fields.

## Convention-Based Editors

Keys with a recognised type suffix trigger embedded editors automatically:

| Key Pattern | Editor Type | Example Key |
|-------------|-------------|-------------|
| `*-dart` | Dart code editor | `script-dart` |
| `*-markdown` | Markdown editor | `description-markdown` |
| `*-regex` | Regex pattern editor | `pattern-regex` |
| `*-json` | JSON editor | `config-json` |
| (no suffix) | Auto from schema type | `name`, `count`, `enabled` |

### Custom Editors

Register additional editors via suffix or resolver:

```dart
final registry = EditorRegistry.defaults()
    .register(EditorSuffix(suffix: 'sql', factory: mySqlEditorFactory))
    .withResolver(myKeyBasedResolver);
```

Resolvers receive the full key path, allowing editors to be matched by key
name rather than suffix (e.g. any key containing "color").

## Theming

Every visual aspect is customisable:

```dart
YamlSchemaEditor(
  theme: YamlEditorTheme(
    colors: YamlEditorColors(
      background: Colors.grey[900]!,
      keyColor: Colors.cyan,
      valueColor: Colors.white,
    ),
    fonts: YamlEditorFontSettings(fontSize: 13),
    structureColors: YamlStructureColors(),
    embeddedEditorStyle: EmbeddedEditorStyle(),
  ),
)
```

Use `YamlEditorTheme.dark()` or `YamlEditorTheme.light()` for presets.

## Components

| Export | Purpose |
|--------|---------|
| `YamlSchemaEditor` | Main editor widget |
| `YamlEditorController` | Document state, undo/redo, change callbacks |
| `YamlEditorTheme` | Full theme configuration |
| `YamlSchema` / `SchemaWalker` | JSON Schema parsing and navigation |
| `EditorRegistry` / `EditorSuffix` | Convention-based editor dispatch |
| `EmbeddedEditor` | Base class for inline editors |
| `YamlDocumentModel` | Non-destructive YAML document model |
| `SubtreeInspector` | Focused subtree editing panel |
| `ValidationErrorList` | Filterable error list widget |
| `YamlSyntaxHighlighter` | YAML token colouring |
| Built-in editors | `StringEditor`, `IntegerEditor`, `NumberEditor`, `BooleanEditor`, `NullEditor`, `EnumEditor` |

## Architecture

See [doc/yaml_editor_architecture_design.md](doc/yaml_editor_architecture_design.md)
for the full 8-phase design document.

## License

BSD-3-Clause — See [LICENSE](LICENSE) for details.
