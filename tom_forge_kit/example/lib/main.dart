import 'package:flutter/material.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeContextMenuContribution;
import 'package:tom_forge_kit/tom_forge_kit.dart';

/// A minimal host of the kit: one window without editors that builds a
/// [DefaultKitApi] over a [ForgeMemoryStateStore] and an in-memory file
/// system, registers a module and lists the kit's actions as text.
void main() => runApp(const KitExampleApp());

/// An editor host for a window that shows no editors: it only tells the
/// kit state what was asked.
class NoEditorHost implements ForgeEditorHost {
  NoEditorHost(this.state);

  final DefaultKitState state;

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {
    state.addOpenEditor(editor);
    if (focus) state.setActiveEditor(editor);
  }

  @override
  Future<bool> closeEditor(ForgeEditor editor) async {
    state.removeOpenEditor(editor);
    return true;
  }

  @override
  void bringToFront(ForgeEditor editor) => state.setActiveEditor(editor);

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async =>
      null;
}

/// A module contributing two actions.
class GreetingModule extends ForgeKitModule {
  final List<String> log = [];

  late final List<ForgeAction> _actions = [
    for (final id in ['example.hello', 'example.goodbye'])
      ForgeAction(
        id: id,
        label: id == 'example.hello' ? 'Say hello' : 'Say goodbye',
        execute: (_) async {
          log.add(id);
          return null;
        },
        isEnabled: () => true,
        isVisible: () => true,
      ),
  ];

  @override
  String get displayName => 'Greetings';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => _actions;

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeContextMenuContribution> get contextMenus => const [];
}

class KitExampleApp extends StatefulWidget {
  const KitExampleApp({super.key});

  @override
  State<KitExampleApp> createState() => _KitExampleAppState();
}

class _KitExampleAppState extends State<KitExampleApp> {
  final DefaultKitState _state = DefaultKitState();
  final ForgeMemoryStateStore _store = ForgeMemoryStateStore();
  late final DefaultKitApi _api = DefaultKitApi(
    editorHost: NoEditorHost(_state),
    fileSystem: TomMemoryFileSystem(seed: const {'/notes.txt': 'notes'}),
    stateStore: _store,
    state: _state,
  );
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _api.registerModule(GreetingModule());
    _api.restore().then((_) {
      if (mounted) setState(() => _restored = true);
    });
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _api.actionRegistry.allActions;
    return MaterialApp(
      title: 'Tom Forge Kit',
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Tom Forge Kit: ${actions.length} actions'
                '${_restored ? '' : ' (restoring)'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final action in actions)
                Text(
                  '${action.id}: ${action.label}'
                  '${_api.isActionEnabled(action.id) ? '' : ' (disabled)'}',
                  key: ValueKey(action.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
