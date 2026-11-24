// Quick open on a bare kit: a DefaultKitApi with no shell, the overlay
// contributed by its module, listing the kit's actions (also a module's not
// yet in the action registry) and finding a workspace file it opens through
// ForgeKitApi.openFile.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_quick_open/tom_forge_quick_open.dart';

/// An editor host that is no layout: it records what it is asked to open.
class _Host implements ForgeEditorHost {
  final opened = <Uri>[];

  @override
  Future<void> showEditor(
    ForgeEditor editor, {
    bool focus = true,
    Object? placement,
  }) async {}

  @override
  Future<bool> closeEditor(ForgeEditor editor) async => true;

  @override
  void bringToFront(ForgeEditor editor) {}

  @override
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async {
    opened.add(uri);
    return null;
  }
}

/// A module with one action of its own, never put into the action registry.
class _ActionModule extends ForgeKitModule {
  _ActionModule(this.action);

  final ForgeAction action;

  @override
  String get displayName => 'Actions';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeView> get views => const [];

  @override
  List<ForgeAction> get actions => [action];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];
}

ForgeAction _action(String id, String label, List<String> ran) => ForgeAction(
  id: id,
  label: label,
  execute: (_) async {
    ran.add(id);
    return null;
  },
  isEnabled: () => true,
  isVisible: () => true,
);

/// Hosts the search field the way an application does and shows the
/// contributed quick open below it.
class _Overlay extends StatefulWidget {
  const _Overlay({required this.api, required this.mode});

  final ForgeKitApi api;
  final ForgeQuickOpenMode mode;

  @override
  State<_Overlay> createState() => _OverlayState();
}

class _OverlayState extends State<_Overlay> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  bool open = true;

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builder = forgeQuickOpenBuilderFor(
      forgeKitModulesOf(widget.api)!,
      widget.mode,
    );
    return Column(
      children: [
        TextField(controller: controller, focusNode: focusNode),
        if (open && builder != null)
          SizedBox(
            width: 400,
            height: 500,
            child: builder(
              null,
              ForgeQuickOpenRequest(
                api: widget.api,
                mode: widget.mode,
                onDismiss: () => setState(() => open = false),
                searchController: controller,
                searchFocusNode: focusNode,
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _show(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  late _Host host;
  late DefaultKitApi api;

  setUp(() {
    host = _Host();
    api = DefaultKitApi(
      editorHost: host,
      fileSystem: TomMemoryFileSystem(
        seed: {'/lib/alpha_widget.dart': 'void main() {}\n', '/README.md': '#'},
      ),
    );
  });

  tearDown(() => api.dispose());

  test('the module contributes quick open for every mode', () {
    for (final mode in ForgeQuickOpenMode.values) {
      expect(forgeQuickOpenBuilderFor(api.modules, mode), isNull);
    }
    api.registerModule(forgeQuickOpenModule());
    for (final mode in ForgeQuickOpenMode.values) {
      expect(forgeQuickOpenBuilderFor(api.modules, mode), isNotNull);
    }
    expect(forgeKitModulesOf(api), same(api.modules));
  });

  testWidgets('lists the actions, a module\'s too, and runs the one picked', (
    tester,
  ) async {
    final ran = <String>[];
    api.actionRegistry.registerAction(
      _action('test.registered', 'Registered Thing', ran),
    );
    api
      ..registerModule(forgeQuickOpenModule())
      ..registerModule(
        _ActionModule(_action('test.module', 'Module Thing', ran)),
      );

    await _show(tester, _Overlay(api: api, mode: ForgeQuickOpenMode.actions));
    expect(find.byType(ForgeQuickOpen), findsOneWidget);
    expect(find.text('Registered Thing'), findsOneWidget);
    expect(find.text('Module Thing'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Module');
    // The search waits for the typing to pause.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('Registered Thing'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ForgeQuickOpen), findsNothing);
    expect(ran, ['test.module']);
  });

  testWidgets('finds a workspace file and opens it through the kit', (
    tester,
  ) async {
    api.registerModule(forgeQuickOpenModule());
    await _show(tester, _Overlay(api: api, mode: ForgeQuickOpenMode.all));

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('alpha_widget.dart'), findsOneWidget);
    expect(find.text('README.md'), findsNothing);

    await tester.tap(find.text('alpha_widget.dart'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgeQuickOpen), findsNothing);
    expect(host.opened, [Uri.file('/lib/alpha_widget.dart')]);
  });
}
