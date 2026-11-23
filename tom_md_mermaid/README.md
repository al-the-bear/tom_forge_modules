# Tom Markdown Mermaid

Mermaid diagrams for the Markdown editor (`tom_md_editor`): a content plugin
that draws ` ```mermaid ` fences with mermaid.js in a webview
(`tom_mermaid_view`, 2.9 MB of JavaScript), shows their source on request and
edits them in a text editor, or in a graphical editor registered per diagram
type (`MdMermaidDiagramEditor`).

```dart
import 'package:tom_md_mermaid/tom_md_mermaid.dart';

MdEditor(controller: controller, plugins: [mdMermaidPlugin()]);
```

The plugin is used while `MdEditorSettings.enableMermaid` is on. Importing
the package registers nothing. Also here: `MdMermaidRenderer`,
`MdMermaidOverlay`, `containsMermaid`, `extractMermaidSources`.

## License

BSD-3-Clause — see [LICENSE](LICENSE); mermaid.js is MIT (`tom_mermaid_view`).
