/// A bare kit for the element tests: a `DefaultKitApi` over a
/// `ForgeMemoryStateStore` and an in-memory file system, with an in-memory
/// clipboard and an editor host that only reports to the kit state — no
/// shell, no layout.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuContribution;
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

/// The kit's clipboard, in memory.
class MemoryClipboard implements ForgeClipboard {
  String text = '';

  @override
  Future<String> readText() async => text;

  @override
  Future<void> writeText(String text) async => this.text = text;
}

/// An editor host with no place of its own: it reports what it is asked to
/// the kit state.
class StateOnlyEditorHost implements ForgeEditorHost {
  DefaultKitState? state;

  @override
  Future<void> showEditor(ForgeEditor editor, {bool focus = true}) async {
    state?.addOpenEditor(editor);
    if (focus) state?.setActiveEditor(editor);
  }

  @override
  Future<bool> closeEditor(ForgeEditor editor) async {
    state?.removeOpenEditor(editor);
    return true;
  }

  @override
  void bringToFront(ForgeEditor editor) => state?.setActiveEditor(editor);

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri) async => null;
}

/// A bare [DefaultKitApi]: memory store, memory file system, memory
/// clipboard. It is not disposed: the widgets of a test leave the tree after
/// its tear-downs, and they report to the kit state on their way out.
DefaultKitApi bareKit({MemoryClipboard? clipboard}) {
  final host = StateOnlyEditorHost();
  final api = DefaultKitApi(
    editorHost: host,
    fileSystem: TomMemoryFileSystem(),
    stateStore: ForgeMemoryStateStore(),
    clipboard: clipboard ?? MemoryClipboard(),
  );
  host.state = api.state;
  return api;
}

/// An action that records its runs in [runs].
ForgeAction recordingAction(
  String id,
  List<String> runs, {
  String? label,
  IconData? icon,
  ForgeMenuLocation menu = ForgeMenuLocation.commandPalette,
  String? group,
  int priority = 0,
  bool Function()? isEnabled,
  bool Function()? isVisible,
}) => ForgeAction(
  id: id,
  label: label ?? id,
  icon: icon,
  menu: menu,
  group: group,
  priority: priority,
  execute: (_) async {
    runs.add(id);
    return null;
  },
  isEnabled: isEnabled ?? () => true,
  isVisible: isVisible ?? () => true,
);

/// A module contributing [contributions] (and nothing else).
class ContributingModule extends ForgeKitModule {
  ContributingModule(this.contributions);

  final List<ForgeContextMenuContribution> contributions;

  @override
  String get displayName => 'Contributions';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeContextMenuContribution> get contextMenus => contributions;
}

/// A component the focus indicator stands for.
class PlainComponent extends ForgeComponent {
  PlainComponent(this.name);

  final String name;

  @override
  bool get isEditor => false;

  @override
  ValueListenable<String> get title => ValueNotifier(name);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => Icons.circle;

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => Text(name);

  @override
  Widget buildCopy(BuildContext context) => Text(name);
}

/// [child] in Forge's theme, without a shell.
Widget themed(Widget child) => MaterialApp(
  theme: forgeThemeData(Brightness.dark),
  home: Scaffold(body: child),
);
