import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

import 'kit_yaml_tool.dart';

/// The key of the window's status line.
const Key kitStatusLineKey = ValueKey('kitExample.status');

/// The key of the menu button of [location] (File, Edit).
Key kitMenuButtonKey(ForgeMenuLocation location) =>
    ValueKey('kitExample.menu.${location.name}');

/// The example's root widget: [tool]'s window in a [MaterialApp] with
/// Forge's theme.
class KitYamlApp extends StatelessWidget {
  const KitYamlApp({super.key, required this.tool});

  final KitYamlTool tool;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Tom Forge Kit',
    theme: forgeThemeData(Brightness.light),
    darkTheme: forgeThemeData(Brightness.dark),
    home: KitYamlWindow(tool: tool),
  );
}

/// The window's own layout, top to bottom: a bar with the File and Edit
/// menus ([ForgeMenuButton] over each [ForgeMenuModel]) and the toolbar
/// ([ForgeKitActionBar] over [kitToolbarModel]), the one editor
/// ([ForgeEditorSurface], which routes its keys, undo, redo and the
/// clipboard through the kit), and a status line with the file and whether
/// it has unsaved changes.
class KitYamlWindow extends StatelessWidget {
  const KitYamlWindow({super.key, required this.tool});

  final KitYamlTool tool;

  @override
  Widget build(BuildContext context) {
    final api = tool.api;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: ForgeDialogLayer(
        dialogs: api.dialogs,
        child: ForgeNotificationLayer.forApi(
          api: api,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: colors.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      for (final location in kitMenuLocations)
                        ForgeMenuButton(
                          key: kitMenuButtonKey(location),
                          api: api,
                          location: location,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ForgeKitActionBar(
                          api: api,
                          model: kitToolbarModel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ValueListenableBuilder<ForgeEditor?>(
                  valueListenable: tool.host.current,
                  builder: (context, editor, _) => editor == null
                      ? const Center(child: Text('No file open'))
                      : ForgeEditorSurface(
                          key: ObjectKey(editor),
                          api: api,
                          editor: editor,
                          autofocus: true,
                        ),
                ),
              ),
              const Divider(height: 1),
              _StatusLine(tool: tool),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.tool});

  final KitYamlTool tool;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ForgeEditor?>(
    valueListenable: tool.host.current,
    builder: (context, editor, _) {
      if (editor == null) return const SizedBox(height: 24);
      return ValueListenableBuilder<bool>(
        valueListenable: editor.isDirty,
        builder: (context, dirty, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '${editor.uri.toFilePath()}${dirty ? ' — unsaved changes' : ''}',
            key: kitStatusLineKey,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    },
  );
}
