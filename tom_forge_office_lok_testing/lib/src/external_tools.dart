import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shell/tom_forge_shell.dart'
    show
        ForgeExternalToolsSection,
        ForgePreferencesService,
        forgeModuleExternalTools;

/// The external tools the panel shell shows for [module] in its External
/// Tools section (`forgeModuleExternalTools`: a kit module's
/// `ForgeExternalToolsExtra`s).
List<ForgeExternalTool> forgeShellExternalToolsOf(ForgeKitModule module) =>
    forgeModuleExternalTools(module);

/// Pumps the panel shell's External Tools section with [tools] over fresh
/// preferences (an empty in-memory store), as the Configuration panel shows
/// it.
Future<void> pumpForgeExternalToolsSection(
  WidgetTester tester,
  List<ForgeExternalTool> tools,
) async {
  final prefs = ForgePreferencesService(stateStore: ForgeMemoryStateStore());
  await prefs.load();
  await tester.binding.setSurfaceSize(const Size(900, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ForgeExternalToolsSection(
          tools: tools,
          preferencesService: prefs,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
