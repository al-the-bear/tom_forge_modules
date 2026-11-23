import '../settings/md_editor_settings.dart';
import 'md_code_plugin.dart';
import 'md_content_plugin.dart';
import 'md_table_plugin.dart';

/// Creates a [MdPluginRegistry] with the core content plugins and [plugins].
///
/// The core has no plugin with a heavy dependency (R4): diagrams, math and
/// the rest come as plugin packages (`tom_md_mermaid`, `tom_md_math`), passed
/// in [plugins]. Without them the editor shows their Markdown as text.
///
/// - [MdTablePlugin] is always included first
/// - each of [plugins] follows, in order, when [MdContentPlugin.isEnabledBy]
///   accepts [settings] (the math plugin follows [MdEditorSettings.enableMath],
///   the Mermaid plugin [MdEditorSettings.enableMermaid])
/// - [MdCodePlugin] is always included last (insert-only, no special
///   rendering)
MdPluginRegistry createDefaultPluginRegistry({
  MdEditorSettings? settings,
  Iterable<MdContentPlugin> plugins = const [],
}) {
  final s = settings ?? MdEditorSettings.standard();
  return MdPluginRegistry([
    MdTablePlugin(),
    for (final plugin in plugins)
      if (plugin.isEnabledBy(s)) plugin,
    MdCodePlugin(),
  ]);
}
