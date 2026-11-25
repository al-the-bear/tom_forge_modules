import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_forge_ui/tom_forge_ui.dart';
import 'package:tom_forge_ui_testing/tom_forge_ui_testing.dart';

/// A tool whose detection answers from fixed copies.
class _FakeTool extends ForgeExternalTool {
  _FakeTool({
    required this.id,
    required this.name,
    this.order = 100,
    this.searchResult = const ForgeToolCopy.missing(),
    this.detected = const [],
  });

  @override
  final String id;

  @override
  final String name;

  @override
  final int order;

  @override
  String get pathHint => '$name.app';

  @override
  bool get pathIsDirectory => true;

  @override
  String? get downloadUrl => 'https://example.org/$id';

  /// What a search (no path) finds.
  ForgeToolCopy searchResult;

  /// What auto-detect finds.
  List<ForgeToolCopy> detected;

  /// The paths [check] was called with.
  final checks = <String?>[];

  int autoDetects = 0;

  @override
  Future<ForgeToolCopy> check(String? path) async {
    checks.add(path);
    if (path == null) return searchResult;
    for (final c in detected) {
      if (c.path == path) return c;
    }
    return ForgeToolCopy(
      path: path,
      state: ForgeToolState.damaged,
      reason: 'not a $name bundle',
    );
  }

  @override
  Future<List<ForgeToolCopy>> autoDetect() async {
    autoDetects++;
    return detected;
  }
}

/// A tool with help for a copy that is not usable; its help's button
/// checks the row again.
class _HelpfulTool extends _FakeTool {
  _HelpfulTool() : super(id: 'pandoc', name: 'Pandoc');

  @override
  Widget? buildHelp(
    BuildContext context,
    ForgeToolCopy copy, {
    required Future<void> Function() checkAgain,
  }) => TextButton(
    key: const ValueKey('pandoc-help'),
    onPressed: checkAgain,
    child: Text('Install Pandoc (${copy.state.name})'),
  );
}

const _apps = ForgeToolCopy(
  path: '/Applications/Office.app',
  state: ForgeToolState.found,
  version: '26.8.3.1',
);
const _old = ForgeToolCopy(
  path: '/Users/me/Applications/Office 7.app',
  state: ForgeToolState.tooOld,
  version: '7.6.4.1',
  reason: 'older than 26.8',
);

void main() {
  late ForgePreferencesService prefs;
  late _FakeTool office;
  late _FakeTool pandoc;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = ForgePreferencesService();
    await prefs.load();
    office = _FakeTool(
      id: 'office',
      name: 'Office',
      order: 0,
      searchResult: _apps,
      detected: [_apps, _old],
    );
    pandoc = _FakeTool(id: 'pandoc', name: 'Pandoc');
  });

  Future<void> pump(WidgetTester tester, {String? Function()? pick}) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeExternalToolsSection(
            // Registered out of order: the section sorts by `order`.
            tools: [pandoc, office],
            preferencesService: prefs,
            pickPath: pick == null ? null : (_) async => pick(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('FT-1: every registered tool has a row, by order; each is '
      'checked with its saved path (none: search) and shows version and '
      'state', (tester) async {
    await pump(tester);
    final officeRow = tester.getTopLeft(
      find.byKey(const ValueKey('forge-tool-office')),
    );
    final pandocRow = tester.getTopLeft(
      find.byKey(const ValueKey('forge-tool-pandoc')),
    );
    expect(officeRow.dy, lessThan(pandocRow.dy));
    expect(office.checks, [null]);
    expect(pandoc.checks, [null]);
    expect(find.text('26.8.3.1'), findsOneWidget);
    expect(find.text('Found: /Applications/Office.app'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('forge-tool-pandoc-state')),
        matching: find.text('Not found'),
      ),
      findsOneWidget,
    );
    expect(find.text('Download: https://example.org/pandoc'), findsOneWidget);
  });

  testWidgets('FT-7: a tool\'s help shows under its row while its copy is '
      'not usable, instead of the download line; its checkAgain checks the '
      'row again, and the help goes once the copy is found', (tester) async {
    final helpful = _HelpfulTool();
    pandoc = helpful;
    await pump(tester);
    expect(
      find.byKey(const ValueKey('forge-tool-pandoc-help')),
      findsOneWidget,
    );
    expect(find.text('Install Pandoc (missing)'), findsOneWidget);
    expect(find.textContaining('Download: '), findsNothing);
    expect(
      find.byKey(const ValueKey('forge-tool-office-help')),
      findsNothing,
      reason: 'a found copy, and the base tool gives no help',
    );
    helpful.searchResult = const ForgeToolCopy(
      path: '/opt/homebrew/bin/pandoc',
      state: ForgeToolState.found,
      version: '3.6',
    );
    await tester.tap(find.byKey(const ValueKey('pandoc-help')));
    await tester.pumpAndSettle();
    expect(helpful.checks, [null, null]);
    expect(find.byKey(const ValueKey('pandoc-help')), findsNothing);
    expect(find.text('3.6'), findsOneWidget);
  });

  testWidgets('FT-2: a path typed and saved goes to forge.tools.<id>.path '
      'and is checked; an empty path clears the setting (search)', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('forge-tool-office-path')),
      '/Users/me/Applications/Office 7.app',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('forge-tool-office-save')));
    await tester.pumpAndSettle();
    final stored = await SharedPreferences.getInstance();
    expect(
      stored.getString('forge.tools.office.path'),
      '/Users/me/Applications/Office 7.app',
    );
    expect(
      prefs.externalToolPath('office'),
      '/Users/me/Applications/Office 7.app',
    );
    expect(office.checks.last, '/Users/me/Applications/Office 7.app');
    expect(find.text('Too old'), findsOneWidget);
    expect(find.text('older than 26.8'), findsOneWidget);
    // A new service reads it back.
    final again = ForgePreferencesService();
    await again.load();
    expect(
      again.externalToolPath('office'),
      '/Users/me/Applications/Office 7.app',
    );

    await tester.enterText(
      find.byKey(const ValueKey('forge-tool-office-path')),
      '',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('forge-tool-office-save')));
    await tester.pumpAndSettle();
    expect(stored.getString('forge.tools.office.path'), isNull);
    expect(prefs.externalToolPath('office'), isNull);
    expect(office.checks.last, isNull);
  });

  testWidgets('FT-3: Check again runs the detection again and shows what it '
      'finds now', (tester) async {
    await pump(tester);
    expect(find.text('Not found'), findsOneWidget);
    pandoc.searchResult = const ForgeToolCopy(
      path: '/opt/homebrew/bin/pandoc',
      state: ForgeToolState.found,
      version: '3.6',
    );
    await tester.tap(find.byKey(const ValueKey('forge-tool-pandoc-check')));
    await tester.pumpAndSettle();
    expect(pandoc.checks, [null, null]);
    expect(find.text('3.6'), findsOneWidget);
    expect(find.text('Found: /opt/homebrew/bin/pandoc'), findsOneWidget);
  });

  testWidgets('FT-4: Auto-detect lists every copy with version and state; '
      'Use sets the path and checks it', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('forge-tool-office-detect')));
    await tester.pumpAndSettle();
    expect(office.autoDetects, 1);
    final first = find.byKey(const ValueKey('forge-tool-office-found-0'));
    final second = find.byKey(const ValueKey('forge-tool-office-found-1'));
    expect(
      find.descendant(of: first, matching: find.text('26.8.3.1 · Found')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: second,
        matching: find.text('7.6.4.1 · Too old · older than 26.8'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('forge-tool-office-use-0')));
    await tester.pumpAndSettle();
    expect(prefs.externalToolPath('office'), '/Applications/Office.app');
    expect(office.checks.last, '/Applications/Office.app');
    expect(first, findsNothing, reason: 'the list closes after the pick');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('forge-tool-office-path')),
          )
          .controller!
          .text,
      '/Applications/Office.app',
    );
    // Nothing found says so.
    await tester.tap(find.byKey(const ValueKey('forge-tool-pandoc-detect')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('forge-tool-pandoc-none-found')),
      findsOneWidget,
    );
  });

  testWidgets('FT-5: Choose… saves the picked path', (tester) async {
    await pump(tester, pick: () => '/Applications/Office.app');
    await tester.tap(find.byKey(const ValueKey('forge-tool-office-choose')));
    await tester.pumpAndSettle();
    expect(prefs.externalToolPath('office'), '/Applications/Office.app');
    expect(find.text('/Applications/Office.app'), findsWidgets);
  });

  testWidgets('FT-6: the Configuration panel has the External Tools section '
      'with the tools it is given', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final expand = ValueNotifier<int?>(null);
    addTearDown(expand.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeConfigurationPanel(
            preferencesService: prefs,
            externalTools: [office],
            expandSection: expand,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('External Tools'), findsOneWidget);
    expand.value = 8;
    await tester.pumpAndSettle();
    // A described section now: the tool's path setting in a tile.
    expect(
      find.byKey(const ValueKey('forge.configuration.tile.forge.tools/tools')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey(
          'forge.configuration.setting.'
          '${ForgeExternalToolsConfiguration.settingOf(office).storage.location}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('26.8.3.1'), findsWidgets);
  });

  test(
    'FT-7: modules register no tools unless they override externalTools',
    () {
      expect(ForgeTestModule().externalTools, isEmpty);
    },
  );
}
