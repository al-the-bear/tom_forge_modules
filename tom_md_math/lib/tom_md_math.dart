/// LaTeX math for the Markdown editor (`tom_md_editor`): display math
/// (`$$…$$`) rendered and edited in the preview, inline math (`$…$`) inside
/// paragraphs, with `flutter_math_fork`.
///
/// The entry point is [mdMathPlugin]: pass it to the editor
/// (`MdEditor(plugins: [mdMathPlugin()])`) or put it in a plugin registry.
/// Importing the package registers nothing.
library;

import 'package:tom_md_editor/tom_md_editor.dart';

import 'src/md_math_plugin.dart';

export 'src/md_inline_math.dart';
export 'src/md_math_overlay.dart';
export 'src/md_math_plugin.dart';
export 'src/md_math_renderer.dart';

/// The math plugin, used while the editor settings enable math
/// ([MdEditorSettings.enableMath]).
MdMathPlugin mdMathPlugin() => MdMathPlugin();
