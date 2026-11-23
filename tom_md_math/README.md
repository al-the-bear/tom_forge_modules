# Tom Markdown Math

LaTeX math for the Markdown editor (`tom_md_editor`): a content plugin that
renders display math (`$$…$$`) with a hover edit button and an editor
(`MdMathOverlay`), and inline math (`$…$`) inside paragraphs, with
`flutter_math_fork`.

```dart
import 'package:tom_md_math/tom_md_math.dart';

MdEditor(controller: controller, plugins: [mdMathPlugin()]);
```

The plugin is used while `MdEditorSettings.enableMath` is on. Importing the
package registers nothing. Also here: `MdMathRenderer`, `containsInlineMath`,
`containsBlockMath`, `extractInlineMath`, `extractBlockMath`.

## License

BSD-3-Clause — see [LICENSE](LICENSE).
