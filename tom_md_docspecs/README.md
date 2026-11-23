# Tom Markdown DocSpecs

DocSpecs schemas for the Markdown editor (`tom_md_editor`), through
`tom_doc_specs` and `tom_doc_scanner`: validation as you type, typed sections
with their templates, id prefixes and patterns, tags and required fields,
schema-aware insert menus and drag and drop, quick fixes, scaffolding of
required sections, for-each sync with a registry, forms for form-type
sections, and the schema panels (for-each banner, info panel, validation
prompts, character counter).

```dart
import 'package:tom_md_docspecs/tom_md_docspecs.dart';

controller.setSchema(schema); // a DocSpecSchema
controller.schema;            // the schema attached, or null
await controller.scaffoldMissingSections();
```

`setSchema` attaches `MdDocSpecsSupport`, the package's implementation of the
core's schema extension point (`MdSchemaSupport`). Importing the package
registers nothing; without a schema the editor shows plain Markdown.

## License

BSD-3-Clause — see [LICENSE](LICENSE).
