// Tests for the dedicated config rail (`tom_specs_editor_specification.md` §12,
// step 18 #3 / OE-16).
//
// The rail is a left-panel view listing every config editor as a one-tap
// launcher. These tests drive: (1) the rail view renders one keyed launcher per
// editor and routes a tap to its `onOpen`; (2) the module builds the rail over
// all seven editors on activate (and not before); (3) the shell module hosts it
// as the DocSpecs left panel's "Config" tab.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_file_system/tom_file_system.dart';

import 'package:tom_core_agentic/tom_core_agentic.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart' show DefaultShellApi;
import 'package:tom_specs_editor/src/config/config_editors.dart';
import 'package:tom_specs_editor/src/config/config_rail_view.dart';
import 'package:tom_specs_editor/src/config/config_specs.dart';
import 'package:tom_specs_editor/src/config/editor_preferences.dart';
import 'package:tom_specs_editor/src/config/raw_file_module.dart';
import 'package:tom_specs_editor/src/config/specs_config_module.dart';
import 'package:tom_specs_editor/src/specs_shell_module.dart';

/// A [SpecsConfigSpecs] whose every store lives in a fresh in-memory
/// workspace, so no real workspace file is touched.
SpecsConfigSpecs _specs() =>
    SpecsConfigSpecs(fileSystem: TomMemoryFileSystem());

/// A [SpecsConfigModule] over [_specs], so activating it touches no real
/// workspace file.
SpecsConfigModule _module() => SpecsConfigModule(
  specs: _specs(),
  rawFileModule: RawFileModule(),
  preferencesStore: EditorPreferencesStore.resolveDefault(
    TomMemoryFileSystem(),
  ),
  preferences: const EditorPreferences(),
  settings: const AgentSettings(),
);

DefaultShellApi _shell() => DefaultShellApi.withDefaults(
  fileSystemSeed: const {},
  appName: 'TomSpecs Editor',
  navigatorKey: GlobalKey<NavigatorState>(),
);

Future<void> _pump(WidgetTester tester, Widget body) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: body)));
}

void main() {
  group('config rail view (tom_specs_editor_specification.md §12 step 18 #3 / '
      'OE-16)', () {
    testWidgets('lists one keyed launcher per editor and routes taps', (
      tester,
    ) async {
      final specs = _specs();
      final editors = <ForgeEditor>[
        ConfigListEditor(spec: specs.queueSpec(), onOpenRawFile: (_) async {}),
        ConfigObjectEditor(
          spec: specs.agentSettingsSpec(),
          onOpenRawFile: (_) async {},
        ),
      ];
      ForgeEditor? opened;
      final rail = ConfigRailView(editors: editors, onOpen: (e) => opened = e);
      await _pump(tester, Builder(builder: rail.buildMain));

      expect(
        find.byKey(const ValueKey('config-rail-entry-/queue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('config-rail-entry-/agent-settings')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('config-rail-entry-/queue')));
      await tester.pump();
      expect(opened, same(editors.first));
    });

    testWidgets('renders an empty hint when there are no editors', (
      tester,
    ) async {
      final rail = ConfigRailView(editors: const [], onOpen: (_) {});
      await _pump(tester, Builder(builder: rail.buildMain));
      expect(find.text('No config editors'), findsOneWidget);
    });
  });

  group('SpecsConfigModule rail (tom_specs_editor_specification.md §12 step 18 '
      '#3 / OE-16)', () {
    test('the rail is null before activation and covers all editors after', () {
      final module = _module();
      expect(
        module.configRailView,
        isNull,
        reason: 'no rail before the editors are built',
      );

      module.activate(_shell());
      final rail = module.configRailView;
      expect(rail, isNotNull);
      expect(module.editors, hasLength(7));
      expect(rail!.editors, hasLength(7));
      // The rail is also advertised through the module's views.
      expect(module.views, contains(rail));
    });

    test('deactivation clears the rail', () {
      final module = _module()..activate(_shell());
      expect(module.configRailView, isNotNull);
      module.deactivate();
      expect(module.configRailView, isNull);
      expect(module.views, isEmpty);
    });
  });

  group('SpecsShellModule config tab (tom_specs_editor_specification.md §12 '
      'step 18 #3 / OE-16)', () {
    test('hosts the injected rail as the DocSpecs left panel "Config" tab', () {
      final rail = ConfigRailView(editors: const [], onOpen: (_) {});
      final module = SpecsShellModule(configRailView: rail);
      module.activate(_shell());

      final leftTabs = module.docSpecs.panelLayout.leftPanel.tabs;
      final configTab = leftTabs.where((t) => t.title == 'Config').toList();
      expect(configTab, hasLength(1));
      expect(configTab.single.sections, contains(rail));
    });

    test('omits the Config tab when no rail is injected', () {
      final module = SpecsShellModule()..activate(_shell());
      final titles = module.docSpecs.panelLayout.leftPanel.tabs
          .map((t) => t.title)
          .toList();
      expect(titles, isNot(contains('Config')));
    });
  });
}
