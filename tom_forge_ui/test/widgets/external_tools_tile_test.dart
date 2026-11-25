// The External Tools section is a configuration description
// (ForgeExternalToolsConfiguration): one tool path setting per registered
// tool, by order, in a tile; each tool's check is the setting's detector,
// its help the help panel (else where to get it), its path kept as
// forge.tools.<id>.path.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
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
  ForgeConfigurationValues? values;

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

  tearDown(() {
    values?.dispose();
    values = null;
  });

  Finder entry(String id) => find.byKey(
    ValueKey(
      'forge.configuration.setting.'
      '${ForgeExternalToolsSettingBinding.bindingId}:forge.tools.$id.path',
    ),
  );

  Finder pathField(String id) =>
      find.descendant(of: entry(id), matching: find.byType(TextField));

  Finder detect(String id) => find.descendant(
    of: find.byKey(ValueKey('forge.configuration.toolPath.detect.$id')),
    matching: find.byType(TextButton),
  );

  Finder stateLine(String id) =>
      find.byKey(ValueKey('forge.configuration.toolPath.state.$id'));

  Future<void> pump(WidgetTester tester, {String? Function()? pick}) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Registered out of order: the description sorts by `order`.
    final tools = <ForgeExternalTool>[pandoc, office];
    final opened = values = ForgeConfigurationValues(
      prefs.stateStore,
      descriptions: [ForgeExternalToolsConfiguration.description(tools)],
      bindings: [ForgeExternalToolsSettingBinding(prefs)],
      hooks: ForgeExternalToolsConfiguration.hooks(tools),
    );
    await tester.runAsync(opened.load);
    ForgeConfigurationLabels.ensureResources();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: forgeConfigurationTiles(
                opened,
                pickPath: pick == null ? null : (_, _) async => pick(),
                buildHelpPanel: (context, panelId, setting, recheck) =>
                    ForgeExternalToolsConfiguration.buildHelpPanel(
                      tools,
                      context,
                      panelId,
                      recheck,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lets a typed path reach the values service and the preferences, and
  /// its check run.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(values!.flushed);
    await tester.runAsync(prefs.flushed);
    await tester.pumpAndSettle();
  }

  testWidgets('FT-1: every registered tool has an entry, by order; each is '
      'checked with its saved path (none: search) and shows its state and '
      'version; a missing tool without help shows where to get it', (
    tester,
  ) async {
    await pump(tester);
    expect(
      tester.getTopLeft(entry('office')).dy,
      lessThan(tester.getTopLeft(entry('pandoc')).dy),
    );
    expect(office.checks, [null]);
    expect(pandoc.checks, [null]);
    expect(
      find.descendant(
        of: stateLine('office'),
        matching: find.textContaining('Found · Version 26.8.3.1'),
      ),
      findsOneWidget,
    );
    expect(find.text('/Applications/Office.app'), findsOneWidget);
    expect(
      find.descendant(
        of: stateLine('pandoc'),
        matching: find.textContaining('Not found'),
      ),
      findsOneWidget,
    );
    expect(find.text('Download: https://example.org/pandoc'), findsOneWidget);
    expect(find.textContaining('example.org/office'), findsNothing);
  });

  testWidgets('FT-7: a tool\'s help shows under its entry while its copy is '
      'not usable, instead of the download line; its checkAgain checks the '
      'entry again, and the help goes once the copy is found', (tester) async {
    final helpful = _HelpfulTool();
    pandoc = helpful;
    await pump(tester);
    expect(
      find.byKey(const ValueKey('forge.configuration.toolPath.help.pandoc')),
      findsOneWidget,
    );
    expect(find.text('Install Pandoc (missing)'), findsOneWidget);
    expect(find.textContaining('Download: '), findsNothing);
    expect(
      find.byKey(const ValueKey('forge.configuration.toolPath.help.office')),
      findsNothing,
      reason: 'a found copy',
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
    expect(find.textContaining('Version 3.6'), findsOneWidget);
  });

  testWidgets('FT-2: a path typed goes to forge.tools.<id>.path and is '
      'checked; an empty path clears the setting (search)', (tester) async {
    await pump(tester);
    await tester.enterText(
      pathField('office'),
      '/Users/me/Applications/Office 7.app',
    );
    await settle(tester);
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
    expect(
      find.descendant(
        of: stateLine('office'),
        matching: find.textContaining('Too old · older than 26.8'),
      ),
      findsOneWidget,
    );
    // A new service reads it back.
    final again = ForgePreferencesService();
    await tester.runAsync(again.load);
    expect(
      again.externalToolPath('office'),
      '/Users/me/Applications/Office 7.app',
    );

    await tester.enterText(pathField('office'), '');
    await settle(tester);
    expect(stored.getString('forge.tools.office.path'), isNull);
    expect(prefs.externalToolPath('office'), isNull);
    expect(office.checks.last, isNull);
  });

  testWidgets('FT-3: Check again runs the detection again and shows what it '
      'finds now', (tester) async {
    await pump(tester);
    expect(
      find.descendant(
        of: stateLine('pandoc'),
        matching: find.textContaining('Not found'),
      ),
      findsOneWidget,
    );
    pandoc.searchResult = const ForgeToolCopy(
      path: '/opt/homebrew/bin/pandoc',
      state: ForgeToolState.found,
      version: '3.6',
    );
    await tester.tap(
      find.byKey(const ValueKey('forge.configuration.toolPath.check.pandoc')),
    );
    await tester.pumpAndSettle();
    expect(pandoc.checks, [null, null]);
    expect(find.textContaining('Version 3.6'), findsOneWidget);
    expect(find.text('/opt/homebrew/bin/pandoc'), findsOneWidget);
  });

  testWidgets('FT-4: Detect lists every copy with version and state; Use '
      'sets the path and checks it', (tester) async {
    await pump(tester);
    await tester.tap(detect('office'));
    await tester.pumpAndSettle();
    expect(office.autoDetects, 1);
    final first = find.byKey(
      const ValueKey('forge.configuration.toolPath.candidate.0'),
    );
    final second = find.byKey(
      const ValueKey('forge.configuration.toolPath.candidate.1'),
    );
    expect(
      find.descendant(
        of: first,
        matching: find.text('Version 26.8.3.1 · Found'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: second,
        matching: find.text('Version 7.6.4.1 · Too old · older than 26.8'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: first, matching: find.byType(TextButton)),
    );
    await settle(tester);
    expect(prefs.externalToolPath('office'), '/Applications/Office.app');
    expect(office.checks.last, '/Applications/Office.app');
    expect(first, findsNothing, reason: 'the list closes after the pick');
    expect(
      tester.widget<TextField>(pathField('office')).controller!.text,
      '/Applications/Office.app',
    );
    // Nothing found says so.
    await tester.tap(detect('pandoc'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: entry('pandoc'),
        matching: find.text('Nothing found.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('FT-5: Browse… sets the picked path', (tester) async {
    await pump(tester, pick: () => '/Applications/Office.app');
    await tester.tap(
      find.descendant(
        of: entry('office'),
        matching: find.text(
          ForgeConfigurationLabels.resolve(ForgeConfigurationUiTexts.browse),
        ),
      ),
    );
    await settle(tester);
    expect(prefs.externalToolPath('office'), '/Applications/Office.app');
    expect(
      tester.widget<TextField>(pathField('office')).controller!.text,
      '/Applications/Office.app',
    );
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
