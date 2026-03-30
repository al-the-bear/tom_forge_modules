/// Quality gate contracts for the Tom Forge build and test pipeline.
///
/// Defines test strategy taxonomy, coverage targets per layer,
/// promotion gate checks, and merge-gate criteria. Used by both
/// the shell runtime (for self-diagnostics) and the CI pipeline
/// (for automated gate enforcement).
library;

/// Test layers that form the Forge testing strategy.
enum ForgeTestLayer {
  /// Pure-Dart logic tests (services, types, config).
  unit,

  /// Flutter widget-level render/interaction tests.
  widget,

  /// Shell-to-editor wiring and service integration tests.
  integration,

  /// Full user-workflow tests (file open → edit → save → verify).
  e2e,

  /// Visual regression tests using `matchesGoldenFile`.
  golden,
}

/// Coverage targets per test layer.
///
/// Defines minimum acceptable coverage percentages for each
/// [ForgeTestLayer]. Used by quality gates and CI checks.
class ForgeCoverageTargets {
  /// Minimum unit test coverage (default 90%).
  final double unitMinPercent;

  /// Minimum widget test coverage (default 80%).
  final double widgetMinPercent;

  /// Minimum integration test coverage (default 70%).
  final double integrationMinPercent;

  /// Minimum E2E test coverage (default 50%).
  final double e2eMinPercent;

  /// Whether golden tests are required for promotion.
  final bool goldenRequired;

  const ForgeCoverageTargets({
    this.unitMinPercent = 90.0,
    this.widgetMinPercent = 80.0,
    this.integrationMinPercent = 70.0,
    this.e2eMinPercent = 50.0,
    this.goldenRequired = true,
  });

  /// Returns the target for [layer], or 0 for golden (binary gate).
  double targetFor(ForgeTestLayer layer) => switch (layer) {
        ForgeTestLayer.unit => unitMinPercent,
        ForgeTestLayer.widget => widgetMinPercent,
        ForgeTestLayer.integration => integrationMinPercent,
        ForgeTestLayer.e2e => e2eMinPercent,
        ForgeTestLayer.golden => 0.0,
      };
}

/// Result of a single quality gate check.
class ForgeGateResult {
  /// Human-readable description of what was checked.
  final String description;

  /// Whether the check passed.
  final bool passed;

  /// Optional detail message (reason for failure, etc.).
  final String? detail;

  const ForgeGateResult({
    required this.description,
    required this.passed,
    this.detail,
  });

  @override
  String toString() => '${passed ? '✓' : '✗'} $description'
      '${detail != null ? ' ($detail)' : ''}';
}

/// A quality gate that aggregates multiple checks.
///
/// Used for staging gates, merge gates, and promotion gates.
class ForgeQualityGate {
  /// Gate name (e.g., "Staging Gate", "Promotion Gate").
  final String name;

  /// Individual check results.
  final List<ForgeGateResult> results;

  const ForgeQualityGate({required this.name, required this.results});

  /// Whether all checks passed.
  bool get passed => results.every((r) => r.passed);

  /// Number of checks that passed.
  int get passedCount => results.where((r) => r.passed).length;

  /// Number of checks that failed.
  int get failedCount => results.where((r) => !r.passed).length;

  /// Summary string for display.
  String get summary => '$name: $passedCount/${results.length} passed'
      '${passed ? ' ✓' : ' ✗'}';

  /// Returns only the failed results.
  List<ForgeGateResult> get failures =>
      results.where((r) => !r.passed).toList();
}

/// Defines a promotion gate checklist for staging-to-production
/// transitions.
///
/// Each item must pass before the application can be promoted from
/// the staging runtime (`tom_forge_ui_test`) to the production
/// runtime (`tom_forge_app`).
class ForgePromotionGate {
  /// The targets to evaluate against.
  final ForgeCoverageTargets targets;

  const ForgePromotionGate({
    this.targets = const ForgeCoverageTargets(),
  });

  /// Evaluates the gate with the provided metrics.
  ForgeQualityGate evaluate({
    required bool analyzerClean,
    required bool allTestsPass,
    required Map<ForgeTestLayer, double> coverageByLayer,
    required bool goldenFilesPresent,
    required bool noRegressions,
    required bool integrationMatrixReady,
  }) {
    final results = <ForgeGateResult>[
      ForgeGateResult(
        description: 'dart analyze reports zero errors/warnings',
        passed: analyzerClean,
      ),
      ForgeGateResult(
        description: 'All tests pass (unit + widget + integration)',
        passed: allTestsPass,
      ),
      for (final layer in [
        ForgeTestLayer.unit,
        ForgeTestLayer.widget,
        ForgeTestLayer.integration,
        ForgeTestLayer.e2e,
      ])
        ForgeGateResult(
          description:
              '${layer.name} coverage ≥ ${targets.targetFor(layer)}%',
          passed: (coverageByLayer[layer] ?? 0.0) >=
              targets.targetFor(layer),
          detail:
              '${(coverageByLayer[layer] ?? 0.0).toStringAsFixed(1)}%',
        ),
      ForgeGateResult(
        description: 'Golden regression files present and up-to-date',
        passed: !targets.goldenRequired || goldenFilesPresent,
      ),
      ForgeGateResult(
        description: 'No regressions from previous staging baseline',
        passed: noRegressions,
      ),
      ForgeGateResult(
        description: 'Integration matrix readiness confirmed',
        passed: integrationMatrixReady,
      ),
    ];
    return ForgeQualityGate(name: 'Promotion Gate', results: results);
  }
}

/// Defines merge-gate criteria for expansion-cycle merges.
///
/// Expansion cycles (Phase D) must pass this gate before the
/// changes are merged into the staging branch.
class ForgeMergeGate {
  /// Evaluates merge readiness.
  ForgeQualityGate evaluate({
    required bool analyzerClean,
    required bool allTestsPass,
    required bool noEditorRegressions,
    required bool noCommandRegressions,
    required bool noShortcutRegressions,
  }) {
    return ForgeQualityGate(
      name: 'Merge Gate',
      results: [
        ForgeGateResult(
          description: 'dart analyze reports zero errors/warnings',
          passed: analyzerClean,
        ),
        ForgeGateResult(
          description: 'All tests pass (no new failures)',
          passed: allTestsPass,
        ),
        ForgeGateResult(
          description: 'No editor regressions (open/edit/save cycle)',
          passed: noEditorRegressions,
        ),
        ForgeGateResult(
          description: 'No command/action regressions',
          passed: noCommandRegressions,
        ),
        ForgeGateResult(
          description: 'No shortcut binding regressions',
          passed: noShortcutRegressions,
        ),
      ],
    );
  }
}

/// Milestone command gate — defines the required commands
/// for each project milestone checkpoint.
class ForgeMilestoneGate {
  /// Package path to check.
  final String packagePath;

  /// Commands that must succeed for this milestone.
  final List<ForgeMilestoneCommand> commands;

  const ForgeMilestoneGate({
    required this.packagePath,
    required this.commands,
  });

  /// Default milestone gates for the Tom Forge workspace.
  static const List<ForgeMilestoneGate> forgeWorkspace = [
    ForgeMilestoneGate(
      packagePath: 'tom_forge_core',
      commands: [
        ForgeMilestoneCommand.analyze,
        ForgeMilestoneCommand.test,
      ],
    ),
    ForgeMilestoneGate(
      packagePath: 'tom_forge_ui',
      commands: [
        ForgeMilestoneCommand.analyze,
        ForgeMilestoneCommand.test,
      ],
    ),
    ForgeMilestoneGate(
      packagePath: 'tom_forge_ui_test',
      commands: [
        ForgeMilestoneCommand.analyze,
        ForgeMilestoneCommand.test,
      ],
    ),
    ForgeMilestoneGate(
      packagePath: 'tom_forge_app',
      commands: [
        ForgeMilestoneCommand.analyze,
        ForgeMilestoneCommand.test,
      ],
    ),
  ];
}

/// A mandatory command for a milestone gate.
enum ForgeMilestoneCommand {
  /// `dart analyze` — must exit with zero issues.
  analyze,

  /// `flutter test` — all tests must pass.
  test,
}

/// Contract formalising `tom_forge_ui_test` as the staging runtime.
///
/// The staging runtime is the gated environment where features are
/// validated before promotion to the production app (`tom_forge_app`).
/// It provides:
/// - Full shell scaffold with all modules loaded.
/// - In-memory workspace seed for deterministic testing.
/// - Quality gate checks via [ForgePromotionGate] before promotion.
///
/// Use [verify] to assert that a staging harness meets the contract.
class ForgeStagingRuntimeContract {
  const ForgeStagingRuntimeContract();

  /// Verifies that the staging runtime meets its contract.
  ///
  /// [hasShell], [hasModuleRegistry], [hasFileSystem], [hasWorkspaceSeed],
  /// and [hasQualityGateIntegration] must all be true for the staging
  /// runtime to be considered functional.
  ForgeQualityGate verify({
    required bool hasShell,
    required bool hasModuleRegistry,
    required bool hasFileSystem,
    required bool hasWorkspaceSeed,
    required bool hasQualityGateIntegration,
  }) {
    return ForgeQualityGate(
      name: 'Staging Runtime Contract',
      results: [
        ForgeGateResult(
          description: 'Shell scaffold available with all service bindings',
          passed: hasShell,
        ),
        ForgeGateResult(
          description: 'Module registry populated with shell + test modules',
          passed: hasModuleRegistry,
        ),
        ForgeGateResult(
          description: 'In-memory file system seeded with workspace files',
          passed: hasFileSystem,
        ),
        ForgeGateResult(
          description: 'Workspace seed provides deterministic test data',
          passed: hasWorkspaceSeed,
        ),
        ForgeGateResult(
          description: 'Quality gate integration validates before promotion',
          passed: hasQualityGateIntegration,
        ),
      ],
    );
  }
}
