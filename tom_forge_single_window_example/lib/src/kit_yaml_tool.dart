import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:tom_editors_shared/tom_editors_shared.dart'
    show StandardEditingActions;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_yaml_editor/tom_forge_yaml_editor.dart';

import 'single_window_host.dart';

/// The id of the example's Save action (File > Save, the toolbar's first
/// button, the primary modifier + S).
const String kitSaveActionId = 'kitExample.file.save';

/// The standard editing actions the Edit menu lists, in order, in two groups:
/// the history, then the clipboard.
const List<String> kitHistoryActionIds = [
  StandardEditingActions.undoActionId,
  StandardEditingActions.redoActionId,
];

/// The clipboard actions of the Edit menu and the toolbar.
const List<String> kitClipboardActionIds = [
  StandardEditingActions.cutActionId,
  StandardEditingActions.copyActionId,
  StandardEditingActions.pasteActionId,
];

/// The window's toolbar as data: Save; Undo, Redo; Cut, Copy, Paste. The
/// labels, icons, keys and whether each can run come from the kit.
const ForgeActionBarModel kitToolbarModel = ForgeActionBarModel(
  sections: [
    ForgeActionBarSection(id: 'kitExample.file', actionIds: [kitSaveActionId]),
    ForgeActionBarSection(
      id: 'kitExample.history',
      actionIds: kitHistoryActionIds,
    ),
    ForgeActionBarSection(
      id: 'kitExample.clipboard',
      actionIds: kitClipboardActionIds,
    ),
  ],
);

/// The menus the window shows, in order: File and Edit, each a
/// [ForgeMenuModel] of the actions placed there.
const List<ForgeMenuLocation> kitMenuLocations = [
  ForgeMenuLocation.file,
  ForgeMenuLocation.edit,
];

/// The example's own module: it places Save in the File menu and the
/// standard editing actions in the Edit menu, with their keys.
///
/// The standard editing actions keep their ids, so the kit routes them to
/// the active editor (`DefaultKitApi.executeAction`); the module only says
/// where they appear. Save writes the editor's content through the kit's
/// file system and marks the editor clean.
class KitToolModule extends ForgeKitModule {
  KitToolModule();

  ForgeKitApi? _api;

  @override
  String get displayName => 'Single-window YAML tool';

  @override
  void activate(ForgeKitApi api) => _api = api;

  @override
  void deactivate() => _api = null;

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  late final List<ForgeAction> actions = [
    ForgeAction(
      id: kitSaveActionId,
      label: 'Save',
      icon: Icons.save_outlined,
      menu: ForgeMenuLocation.file,
      execute: (_) async {
        await save();
        return null;
      },
      isEnabled: () => _api?.state.activeEditor?.isDirty.value ?? false,
      isVisible: () => true,
      defaultShortcut: ForgeShortcutKey(
        key: LogicalKeyboardKey.keyS,
        primaryModifier: true,
      ),
    ),
    for (final (group, ids) in [
      ('history', kitHistoryActionIds),
      ('clipboard', kitClipboardActionIds),
    ])
      for (final (index, id) in ids.indexed) _editAction(id, group, index),
  ];

  ForgeAction _editAction(String id, String group, int priority) {
    final descriptor = StandardEditingActions.descriptors.firstWhere(
      (d) => d.id == id,
    );
    return ForgeAction(
      id: id,
      label: descriptor.label,
      icon: descriptor.icon,
      menu: ForgeMenuLocation.edit,
      group: group,
      priority: priority,
      // Never called for a standard id: the kit routes it to the editor.
      execute: (_) async {
        _api?.executeAction(id);
        return null;
      },
      isEnabled: () => _api?.isActionEnabled(id) ?? false,
      isVisible: () => true,
      defaultShortcut: StandardEditingActions.defaultShortcuts[id],
    );
  }

  @override
  List<ForgeShortcutBinding> get shortcuts => [
    for (final action in actions)
      if (action.defaultShortcut case final key?)
        ForgeShortcutBinding(action: action, key: key),
  ];

  /// Saves the active editor: an editor that owns its saving saves itself;
  /// otherwise its content is written to its file and the editor marked
  /// clean. Answers whether something was saved (or a save started).
  Future<bool> save() async {
    final api = _api;
    final editor = api?.state.activeEditor;
    if (api == null || editor == null || !editor.isDirty.value) return false;
    if (saveOwnedEditor(editor) case final started?) return started;
    final content = editor.getContent();
    if (content == null) return false;
    final fileSystem = api.fileSystem;
    await fileSystem.writeText(editor.uri, content);
    await fileSystem.save(editor.uri);
    editor.markClean();
    return true;
  }
}

/// The single-window YAML tool: a [DefaultKitApi] over [fileSystem] with
/// the example's [SingleWindowEditorHost] (the YAML editor type,
/// [forgeYamlEditorType]) and its [KitToolModule]. No panel shell.
class KitYamlTool {
  KitYamlTool._(this.api, this.host, this.module);

  /// Composes the tool over [fileSystem].
  ///
  /// [stateStore] keeps the kit's preferences (default: the platform's
  /// shared preferences); a test gives a [ForgeMemoryStateStore].
  /// [clipboard] is the kit's clipboard (default: the system's).
  factory KitYamlTool.compose({
    required TomFileSystem fileSystem,
    ForgeStateStore? stateStore,
    ForgeClipboard? clipboard,
  }) {
    final host = SingleWindowEditorHost(editorTypes: [forgeYamlEditorType]);
    final api = DefaultKitApi(
      editorHost: host,
      fileSystem: fileSystem,
      stateStore: stateStore ?? ForgeSharedPreferencesStateStore(),
      clipboard: clipboard,
      editorTypes: [forgeYamlEditorType],
    );
    host.attach(api);
    final module = KitToolModule();
    api.registerModule(module);
    installForgeStandardEditingActions(api);
    return KitYamlTool._(api, host, module);
  }

  /// The kit: the actions, the editor's state, the file system.
  final DefaultKitApi api;

  /// Where the editor appears: the window's one editor.
  final SingleWindowEditorHost host;

  /// The example's module: Save and the menus' placement of the standard
  /// editing actions.
  final KitToolModule module;

  /// The editor the window shows; null before a file is open.
  ForgeEditor? get editor => host.current.value;

  /// Opens [uri] in the window; answers the editor, null when the window
  /// cannot show it (no editor type opens it).
  Future<ForgeEditor?> open(Uri uri) => host.openEditorFor(uri);

  /// Restores the kit's preferences (shortcut overrides, settings).
  Future<void> restore() => api.restore();

  void dispose() {
    unawaited(api.flushed().whenComplete(api.dispose));
    host.dispose();
  }
}
