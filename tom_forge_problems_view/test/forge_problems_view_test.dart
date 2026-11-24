// The Problems view on a bare kit: a DefaultKitApi with no shell, the view
// contributed by its module with its placement hint, listing the
// diagnostics and opening one where it is — at its position when the
// application is a ForgeFileNavigator, else through ForgeKitApi.openFile.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_problems_view/tom_forge_problems_view.dart';

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

/// A kit API that opens files at a position, as the panel shell's does.
class _NavigatingApi extends DefaultKitApi implements ForgeFileNavigator {
  _NavigatingApi({required super.editorHost, required super.fileSystem});

  final positions = <(Uri, int?, int?)>[];

  @override
  void openFileAt(Uri uri, {int? line, int? column}) =>
      positions.add((uri, line, column));
}

final _uri = Uri.file('/w/lib/a.dart');

ForgeDiagnostic _diagnostic(String message, ForgeSeverity severity, int line) =>
    ForgeDiagnostic(
      uri: _uri,
      range: ForgeTextRange(
        start: ForgeTextPosition(line: line, column: 4),
        end: ForgeTextPosition(line: line, column: 9),
      ),
      message: message,
      severity: severity,
      source: 'analyzer',
    );

void _report(ForgeKitApi api) {
  (api.diagnostics as DefaultDiagnosticManager)
      .createCollection('test')
      .set(_uri, [
        _diagnostic('Undefined name x', ForgeSeverity.error, 2),
        _diagnostic('Unused import', ForgeSeverity.warning, 0),
      ]);
}

Future<void> _show(WidgetTester tester, ForgeView view) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 400,
        child: Builder(builder: view.buildMain),
      ),
    ),
  ),
);

void main() {
  late _Host host;
  late DefaultKitApi api;
  late ForgeProblemsViewModule module;

  setUp(() {
    host = _Host();
    api = DefaultKitApi(editorHost: host, fileSystem: TomMemoryFileSystem());
    module = forgeProblemsViewModule();
    api.registerModule(module);
  });

  tearDown(() => api.dispose());

  test('the module contributes the view with its placement hint', () {
    final contributed = forgeContributedViews(api.modules);
    expect(contributed, hasLength(1));
    expect(contributed.single.view, isA<ForgeProblemsView>());
    expect(contributed.single.hint, same(forgeProblemsViewPlacement));
    expect(contributed.single.hint!.role, ForgeViewRole.messages);
    expect(contributed.single.hint!.group, 'Problems');
    expect(
      forgeContributedViewById(api.modules, forgeProblemsViewId),
      same(module.view),
    );
    module.deactivate();
    expect(module.views, isEmpty);
    expect(forgeContributedViews(api.modules), isEmpty);
  });

  testWidgets('lists the diagnostics and opens one through the kit', (
    tester,
  ) async {
    final view = module.view!;
    await _show(tester, view);
    expect(find.text('No problems detected'), findsOneWidget);
    expect(view.titleExtension.value, isNull);

    _report(api);
    await tester.pumpAndSettle();

    expect(find.text('No problems detected'), findsNothing);
    expect(find.text('Undefined name x'), findsOneWidget);
    expect(find.text('Unused import'), findsOneWidget);
    expect(view.titleExtension.value, '(2)');

    await tester.tap(find.text('Undefined name x'));
    await tester.pumpAndSettle();
    expect(host.opened, [_uri]);
  });

  testWidgets('opens a diagnostic at its position with a file navigator', (
    tester,
  ) async {
    final navigating = _NavigatingApi(
      editorHost: host,
      fileSystem: TomMemoryFileSystem(),
    );
    addTearDown(navigating.dispose);
    final navigatingModule = forgeProblemsViewModule();
    navigating.registerModule(navigatingModule);
    _report(navigating);

    await _show(tester, navigatingModule.view!);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undefined name x'));
    await tester.pumpAndSettle();

    expect(navigating.positions, [(_uri, 2, 4)]);
    expect(host.opened, isEmpty);
  });
}
