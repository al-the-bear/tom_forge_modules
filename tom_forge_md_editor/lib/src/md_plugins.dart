import 'package:tom_md_editor/tom_md_editor.dart';
import 'package:tom_md_math/tom_md_math.dart';
import 'package:tom_md_mermaid/tom_md_mermaid.dart';

/// The content plugins Forge's Markdown editor runs with: Mermaid diagrams
/// (`tom_md_mermaid`) and LaTeX math (`tom_md_math`), each used while the
/// editor settings enable it (`enableMermaid`, `enableMath`).
///
/// The editor's DocSpecs schemas (`tom_md_docspecs`) and reviews
/// (`tom_md_review`) are on its controller; the package exports their
/// controller extensions.
List<MdContentPlugin> forgeMdContentPlugins() => [
  mdMathPlugin(),
  mdMermaidPlugin(),
];
