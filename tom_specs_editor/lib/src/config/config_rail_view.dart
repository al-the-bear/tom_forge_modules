import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';

/// The dedicated **config rail** (`tom_specs_editor_specification.md` §12, step
/// 18 #3 / OE-16): a left-panel view that lists every config editor as a
/// one-tap launcher.
///
/// The config editors (`reject` in `canHandle`) are not file-resolved — they
/// open via the shell layout. Before this rail they were reachable only through
/// the Tools menu / command palette ([SpecsConfigModule.actions]); the rail
/// gives them a persistent home in the DocSpecs left panel. Tapping an entry
/// calls [onOpen], which the module wires to `shell.layout.openEditor`.
class ConfigRailView extends ForgeView {
  ConfigRailView({required this.editors, required this.onOpen})
      : _title = ValueNotifier<String>('Config'),
        _titleExtension = ValueNotifier<String?>(null);

  /// The config editors to surface, in display order.
  final List<ForgeEditor> editors;

  /// Opens [editor] in the active middle panel (wired to the shell layout).
  final void Function(ForgeEditor editor) onOpen;

  final ValueNotifier<String> _title;
  final ValueNotifier<String?> _titleExtension;

  @override
  IconData get icon => Icons.tune_outlined;

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) =>
      _ConfigRail(editors: editors, onOpen: onOpen);

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);
}

/// The rail's launcher list — one tile per editor, keyed by its URI path so the
/// launcher for a given editor is addressable from tests and the palette.
class _ConfigRail extends StatelessWidget {
  const _ConfigRail({required this.editors, required this.onOpen});

  final List<ForgeEditor> editors;
  final void Function(ForgeEditor editor) onOpen;

  @override
  Widget build(BuildContext context) {
    if (editors.isEmpty) {
      return const Center(child: Text('No config editors'));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final editor in editors)
          ListTile(
            key: ValueKey('config-rail-entry-${editor.uri.path}'),
            dense: true,
            leading: Icon(editor.icon, size: 18),
            title: Text(
              editor.title.value,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => onOpen(editor),
          ),
      ],
    );
  }
}
