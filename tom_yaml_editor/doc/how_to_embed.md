# How to Embed `tom_yaml_editor`

For the easiest embedding, use `SimpleYamlSchemaEditor`.

- It manages `YamlEditorController` internally.
- You can pass either `schema` or `schemaJson`.
- It works with optional `EditorRegistry` for custom suffix editors.

## Minimal embed (one-liner)

```dart
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

SimpleYamlSchemaEditor(
  initialYaml: 'name: demo\nversion: 1\n',
  schemaJson: {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'version': {'type': 'integer'}
    }
  },
)
```

## With callbacks and custom registry

```dart
SimpleYamlSchemaEditor(
  initialYaml: yamlText,
  schema: myYamlSchema,
  editorRegistry: myRegistry,
  onChanged: (yaml) {
    // Persist YAML
  },
  onValidationChanged: (errors) {
    // Show validation summary
  },
)
```

## Advanced mode (external controller)

If you need direct controller access (undo/redo, imperative edits), use `YamlSchemaEditor` + `YamlEditorController`.

```dart
final controller = YamlEditorController(
  initialYaml: yamlText,
  schema: myYamlSchema,
);

YamlSchemaEditor(
  controller: controller,
  editorRegistry: myRegistry,
)
```

## Notes

- `SimpleYamlSchemaEditor` is recommended for most host apps.
- If both `schema` and `schemaJson` are provided, construction asserts. Pass only one.
