# Embedding the Markdown Editor

`tom_md_editor` is a Flutter widget with no host requirements: put an
`MdEditor` in any widget tree. The core renders Markdown, tables and code;
each heavy feature is a plugin package an application adds when it wants it.

## The editor alone

```yaml
dependencies:
  tom_md_editor:
    path: ../tom_md_editor
```

```dart
import 'package:tom_md_editor/tom_md_editor.dart';

final controller = MdEditorController(initialMarkdown: '# Notes\n');

Widget build(BuildContext context) => MdEditor(controller: controller);
```

A Mermaid fence is then a code block, `$$…$$` and `$…$` their LaTeX source,
CriticMarkup and review comments their text, and no schema is validated.

## Content plugins: Mermaid and math

Content plugins render blocks (and inline syntax) in the preview. Pass them
in `plugins`; the editor builds its registry from them and the core plugins
(table, code), and uses each while the settings enable it
(`MdEditorSettings.enableMermaid`, `enableMath`):

```yaml
dependencies:
  tom_md_mermaid:
    path: ../tom_md_mermaid
  tom_md_math:
    path: ../tom_md_math
```

```dart
import 'package:tom_md_math/tom_md_math.dart';
import 'package:tom_md_mermaid/tom_md_mermaid.dart';

// One list for the widget's life, so the registry is built once.
final plugins = [mdMermaidPlugin(), mdMathPlugin()];

MdEditor(controller: controller, plugins: plugins);
MdPreviewPanel(
  controller: controller,
  theme: MdEditorTheme.light(),
  settings: MdEditorSettings.viewer(),
  plugins: plugins,
);
```

A registry of your own (`pluginRegistry: MdPluginRegistry([...])`) takes the
plugins as given, whatever the settings say. `mdMermaidPlugin(diagramEditors:
[...])` adds graphical editors per diagram type.

## DocSpecs schemas

`tom_md_docspecs` attaches a DocSpecs schema to the controller; validation,
typed sections, templates, tags, forms, scaffolding and the schema panels
(for-each sync above the outline, the info panel below it, validation
prompts, the character counter) follow from it:

```dart
import 'package:tom_md_docspecs/tom_md_docspecs.dart';

controller.setSchema(schema); // a tom_doc_specs DocSpecSchema
await controller.scaffoldMissingSections();
controller.clearSchema();
```

`controller.setSchemaSupport(...)` attaches any other implementation of the
core's `MdSchemaSupport`.

## Reviews

`tom_md_review` gives the controller the review edits, each one history
entry guarded by the text the reader was shown:

```dart
import 'package:tom_md_review/tom_md_review.dart';

controller.addReviewComment(
  blockStart: 2,
  blockEnd: 3,
  text: 'Is this still true?',
  author: mdLocalCommentAuthor(),
);
controller.decideAllReviewChanges(MdMarkDecision.accept);
```

## A document on a web server

`tom_md_http` is a document provider for a REST endpoint holding one
document: `GET` opens it, `PUT` saves it, the caller supplies any headers:

```dart
import 'package:tom_md_http/tom_md_http.dart';

MdEditor(
  documentProvider: HttpDocumentProvider(
    url: 'https://docs.example.com/api/readme',
    headers: {'Authorization': 'Bearer $token'},
  ),
);
```

There is no conflict detection (the last `PUT` wins), no retry and no live
reload.
