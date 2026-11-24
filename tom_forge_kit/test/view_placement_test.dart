// Contributed views: a module lists its views and hands their layout-free
// placement hints over as an extra; the kit answers every registered
// module's views with their hints, and the active editor as a listenable.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show FileHandlingResult;
import 'package:tom_forge_kit/tom_forge_kit.dart';

class _View extends ForgeView {
  _View(this.name);

  final String name;

  @override
  ValueListenable<String> get title => ValueNotifier(name);

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => const IconData(0xe000);

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => Text(name);

  @override
  Widget buildCopy(BuildContext context) => Text(name);
}

class _Editor extends ForgeEditor {
  _Editor(this.uri);

  @override
  final Uri uri;

  @override
  ValueListenable<bool> get isDirty => ValueNotifier(false);

  @override
  void markClean() {}

  @override
  ValueListenable<String> get title => ValueNotifier('e');

  @override
  ValueListenable<String?> get titleExtension => ValueNotifier(null);

  @override
  IconData get icon => const IconData(0xe000);

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) => const SizedBox();

  @override
  Widget buildCopy(BuildContext context) => const SizedBox();

  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.accept;
}

class _Host implements ForgeEditorHost {
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
  Future<ForgeEditor?> openEditorFor(Uri uri, {Object? placement}) async =>
      null;
}

class _ViewsModule extends ForgeKitModule implements ForgeModuleExtrasProvider {
  _ViewsModule(this.views, this.contributions);

  @override
  final List<ForgeView> views;
  final List<ForgeViewContribution> contributions;

  @override
  String get displayName => 'Views';

  @override
  void activate(ForgeKitApi api) {}

  @override
  void deactivate() {}

  @override
  List<ForgeEditor> get editors => const [];

  @override
  List<ForgeAction> get actions => const [];

  @override
  List<ForgeShortcutBinding> get shortcuts => const [];

  @override
  List<ForgeModuleExtra> get ownExtras => [
    ForgeViewContributionsExtra(contributions),
  ];
}

void main() {
  test('every registered module\'s views come with the hints it gives', () {
    final api = DefaultKitApi(
      editorHost: _Host(),
      fileSystem: TomMemoryFileSystem(),
      stateStore: ForgeMemoryStateStore(),
    );
    addTearDown(api.dispose);
    expect(forgeContributedViews(api.modules), isEmpty);

    final placed = _View('placed');
    final unplaced = _View('unplaced');
    const hint = ForgeViewPlacementHint(
      id: 'test.placed',
      role: ForgeViewRole.details,
      group: 'Group',
      order: 3,
    );
    api.registerModule(
      _ViewsModule(
        [placed, unplaced],
        [
          ForgeViewContribution(view: placed, hint: hint),
          // A hint for a view the module does not list is ignored.
          ForgeViewContribution(
            view: _View('foreign'),
            hint: const ForgeViewPlacementHint(
              id: 'test.foreign',
              role: ForgeViewRole.navigation,
            ),
          ),
        ],
      ),
    );

    final contributed = forgeContributedViews(api.modules);
    expect(contributed.map((c) => c.view), [placed, unplaced]);
    expect(contributed.first.hint, same(hint));
    expect(contributed.last.hint, isNull);
    expect(contributed.first.module, isA<_ViewsModule>());
    expect(forgeContributedViewById(api.modules, 'test.placed'), placed);
    expect(forgeContributedViewById(api.modules, 'test.foreign'), isNull);
  });

  test('the kit state reports every change of its active editor', () {
    final state = DefaultKitState();
    final ForgeActiveEditorListenable listenable = state;
    final seen = <ForgeEditor?>[];
    void record() => seen.add(listenable.activeEditorListenable.value);
    listenable.activeEditorListenable.addListener(record);

    final a = _Editor(Uri.file('/a'));
    final b = _Editor(Uri.file('/b'));
    state
      ..addOpenEditor(a)
      ..setActiveEditor(a)
      ..addOpenEditor(b)
      ..setActiveEditor(b)
      ..removeOpenEditor(b)
      ..setActiveEditor(null);
    expect(seen, [a, b, a, null]);

    listenable.activeEditorListenable.removeListener(record);
    state.dispose();
  });
}
