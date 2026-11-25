import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_configuration_ui/tom_configuration_ui.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        ForgeExternalToolsConfiguration,
        ForgeExternalToolsSettingBinding,
        ForgePreferencesService,
        forgeModuleExternalTools;

/// The external tools the panel shell shows for [module] in its External
/// Tools section (`forgeModuleExternalTools`: a kit module's
/// `ForgeExternalToolsExtra`s).
List<ForgeExternalTool> forgeShellExternalToolsOf(ForgeKitModule module) =>
    forgeModuleExternalTools(module);

/// Pumps the panel shell's External Tools tile with [tools] over fresh
/// preferences (an empty in-memory store), as the Configuration panel shows
/// it: the shell's description of the tools
/// (`ForgeExternalToolsConfiguration`), their paths kept through its binding,
/// each tool's check as the detector and its help as the help panel. Answers
/// the values service (disposed at the test's end).
Future<ForgeConfigurationValues> pumpForgeExternalToolsTile(
  WidgetTester tester,
  List<ForgeExternalTool> tools,
) async {
  final prefs = ForgePreferencesService(stateStore: ForgeMemoryStateStore());
  await prefs.load();
  final values = ForgeConfigurationValues(
    prefs.stateStore,
    descriptions: [ForgeExternalToolsConfiguration.description(tools)],
    bindings: [ForgeExternalToolsSettingBinding(prefs)],
    hooks: ForgeExternalToolsConfiguration.hooks(tools),
  );
  await values.load();
  addTearDown(values.dispose);
  ForgeConfigurationLabels.ensureResources();
  await tester.binding.setSurfaceSize(const Size(900, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: forgeConfigurationTiles(
              values,
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
  return values;
}

/// The External Tools tile's entry of the tool [toolId].
Finder forgeExternalToolEntry(String toolId) => find.byKey(
  ValueKey(
    'forge.configuration.setting.'
    '${ForgeExternalToolsSettingBinding.bindingId}:'
    '${ForgeKitPreferences.externalToolPathKey(toolId)}',
  ),
);

/// The help panel under the entry of the tool [toolId] (shown while its copy
/// is not usable).
Finder forgeExternalToolHelp(String toolId) =>
    find.byKey(ValueKey('forge.configuration.toolPath.help.$toolId'));

/// The *Check again* button of the tool [toolId].
Finder forgeExternalToolCheck(String toolId) =>
    find.byKey(ValueKey('forge.configuration.toolPath.check.$toolId'));
