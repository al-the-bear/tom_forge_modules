/// Mermaid diagrams for the Markdown editor (`tom_md_editor`): ` ```mermaid `
/// fences drawn by mermaid.js in a webview (`tom_mermaid_view`), with a text
/// editor and optional graphical editors per diagram type.
///
/// The entry point is [mdMermaidPlugin]: pass it to the editor
/// (`MdEditor(plugins: [mdMermaidPlugin()])`) or put it in a plugin registry.
/// Importing the package registers nothing.
library;

import 'package:tom_md_editor/tom_md_editor.dart';

import 'src/md_mermaid_plugin.dart';

export 'src/md_mermaid_overlay.dart';
export 'src/md_mermaid_plugin.dart';
export 'src/md_mermaid_renderer.dart';

/// The Mermaid plugin, used while the editor settings enable Mermaid
/// ([MdEditorSettings.enableMermaid]); [diagramEditors] are graphical editors
/// for diagram types, the text editor the fallback.
MdMermaidPlugin mdMermaidPlugin({
  List<MdMermaidDiagramEditor>? diagramEditors,
}) => MdMermaidPlugin(diagramEditors: diagramEditors);
