import '../settings/md_editor_settings.dart';
import 'md_code_plugin.dart';
import 'md_content_plugin.dart';
import 'md_math_plugin.dart';
import 'md_mermaid_plugin.dart';
import 'md_table_plugin.dart';

/// Creates a [MdPluginRegistry] with all built-in content plugins.
///
/// Respects [settings] for conditionally enabling plugin types:
/// - [MdTablePlugin] is always included
/// - [MdMathPlugin] is included when [MdEditorSettings.enableMath] is `true`
/// - [MdMermaidPlugin] is included when [MdEditorSettings.enableMermaid] is `true`
/// - [MdCodePlugin] is always included (insert-only, no special rendering)
MdPluginRegistry createDefaultPluginRegistry({MdEditorSettings? settings}) {
  final s = settings ?? MdEditorSettings.standard();
  return MdPluginRegistry([
    MdTablePlugin(),
    if (s.enableMath) MdMathPlugin(),
    if (s.enableMermaid) MdMermaidPlugin(),
    MdCodePlugin(),
  ]);
}
