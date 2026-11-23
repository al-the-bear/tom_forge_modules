/// tom_dart_editor_bundler — Tool definition (tom_build_base v2).
///
/// Declares the CLI surface (name, version, options, help) that the
/// [ToolRunner] in `bin/dart_editor_bundler.dart` drives. The actual bundle
/// generation (config parsing, `.sum` emission, helper writing) is implemented
/// incrementally in later plan items (2–6); this file owns only the tool's
/// command-line contract.
library;

import 'package:tom_build_base/tom_build_base_v2.dart';

import 'version.versioner.dart';

// =============================================================================
// Tool-specific options
// =============================================================================

/// Global options for the bundler.
///
/// `--config` selects an explicit config file; when omitted the bundler reads
/// the `dart-editor-bundler` block from the project's `buildkit.yaml`.
/// `--bundle` restricts a run to a single named bundle.
const bundlerOptions = <OptionDefinition>[
  OptionDefinition.option(
    name: 'config',
    abbr: 'c',
    description:
        'Path to the bundler config (defaults to the project buildkit.yaml '
        'dart-editor-bundler block)',
    valueName: 'path',
  ),
  OptionDefinition.option(
    name: 'bundle',
    abbr: 'b',
    description: 'Generate only the named bundle instead of all bundles',
    valueName: 'name',
  ),
];

// =============================================================================
// Tool definition
// =============================================================================

/// The `dart-editor-bundler` tool definition.
///
/// The tool name matches the buildkit config key (`dart-editor-bundler`) so the
/// executor can resolve its configuration section by the tool's own name.
final dartEditorBundlerTool = ToolDefinition(
  name: 'dart-editor-bundler',
  description:
      'Builds summary .sum bundles and the generated scope-init helper for the '
      'tom_dart_editor embedded code editor',
  version: DartEditorBundlerVersionInfo.version,
  versionString:
      'tom_dart_editor_bundler ${DartEditorBundlerVersionInfo.versionLong}',
  mode: ToolMode.singleCommand,
  worksWithNatures: {DartProjectFolder},
  features: const NavigationFeatures(
    projectTraversal: false,
    gitTraversal: false,
    recursiveScan: false,
    interactiveMode: false,
    dryRun: true,
    jsonOutput: false,
    verbose: true,
  ),
  globalOptions: bundlerOptions,
  helpFooter: '''
Configuration:
  Reads a `dart-editor-bundler` block from the consuming app's buildkit.yaml:

  dart-editor-bundler:
    out-dir: assets/summaries
    generated-helper: lib/src/summary_scopes.g.dart
    sdk-summary: sdk_summary.sum
    bundles:
      - name: dart-plain
        sdk-only: true
      - name: d4rt-flutter
        packages: [tom_d4rt_flutter]

Options:
  --config <path>   Use an explicit config file (default: project buildkit.yaml)
  --bundle <name>   Build only the named scope (the shared SDK summary is still
                    emitted, since every scope depends on it)
  --verbose         Print per-step progress

Output:
  - <out-dir>/<sdk-summary>            (one SDK summary, reused if present)
  - <out-dir>/<name>/packages.sum      (one grouped bundle per non sdk-only bundle)
  - <generated-helper>                 (SummaryScopes registrar Dart file)

Status:
  Generates the `.sum` asset set and the generated-helper Dart file
  (`SummaryScopes` registrar). The helper registers every declared scope via
  `tom_dart_analysis`'s SummaryScopeRegistry.
''',
);
