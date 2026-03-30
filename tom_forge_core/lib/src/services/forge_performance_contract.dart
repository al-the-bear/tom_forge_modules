import 'dart:async';

/// Performance strategy contracts for the Tom Forge shell.
///
/// Defines explicit budgets for memory, lazy loading thresholds,
/// virtualization targets, and resource monitoring. Every subsystem
/// can reference these contracts to ensure consistent performance
/// behavior across the IDE.

/// Memory and resource budgets for the Forge shell.
class ForgePerformanceConfig {
  /// Maximum number of editors open before LRU eviction triggers.
  final int maxOpenEditors;

  /// Maximum number of file-system watcher paths before consolidation
  /// to parent-directory watchers kicks in.
  final int maxWatcherPaths;

  /// Search result cache budget in bytes.
  final int searchCacheBudgetBytes;

  /// Image preview cache budget in bytes.
  final int imageCacheBudgetBytes;

  /// Maximum entries in the search result LRU cache.
  final int searchCacheMaxEntries;

  /// Maximum entries in the image preview LRU cache.
  final int imageCacheMaxEntries;

  /// File-watcher event batching window.
  final Duration watcherBatchWindow;

  /// Diagnostic refresh debounce window.
  final Duration diagnosticDebounceWindow;

  /// Autosave debounce applied uniformly across editors.
  final Duration autosaveDebounce;

  /// Target for diagnostic subsystem scalability.
  final int diagnosticScalabilityTarget;

  /// Maximum concurrent file-system operations.
  final int maxConcurrentFileOps;

  const ForgePerformanceConfig({
    this.maxOpenEditors = 20,
    this.maxWatcherPaths = 1000,
    this.searchCacheBudgetBytes = 50 * 1024 * 1024, // 50 MB
    this.imageCacheBudgetBytes = 100 * 1024 * 1024, // 100 MB
    this.searchCacheMaxEntries = 200,
    this.imageCacheMaxEntries = 100,
    this.watcherBatchWindow = const Duration(milliseconds: 50),
    this.diagnosticDebounceWindow = const Duration(milliseconds: 100),
    this.autosaveDebounce = const Duration(milliseconds: 1000),
    this.diagnosticScalabilityTarget = 10000,
    this.maxConcurrentFileOps = 10,
  });
}

/// Tracks the resource usage of a particular subsystem and signals
/// when usage approaches or exceeds the budget.
class ForgeResourceBudget {
  /// Human-readable name of the tracked resource.
  final String name;

  /// Maximum budget (in abstract units — bytes, count, etc.).
  final int budget;

  int _usage = 0;
  final _controller = StreamController<ForgeResourceEvent>.broadcast();

  ForgeResourceBudget({required this.name, required this.budget});

  /// Current usage.
  int get usage => _usage;

  /// Usage as a fraction of budget (0.0–1.0+).
  double get utilizationRatio =>
      budget > 0 ? _usage / budget : 0.0;

  /// Whether current usage exceeds the budget.
  bool get isOverBudget => _usage > budget;

  /// Whether usage is above 80% of budget ("high usage" threshold).
  bool get isHighUsage => _usage > (budget * 0.8).round();

  /// Stream of resource events (high-usage warnings, over-budget, eviction).
  Stream<ForgeResourceEvent> get onEvent => _controller.stream;

  /// Record an increase in usage.
  void allocate(int amount) {
    _usage += amount;
    _checkThresholds();
  }

  /// Record a decrease in usage.
  void release(int amount) {
    _usage = (_usage - amount).clamp(0, _usage);
  }

  /// Reset usage to zero.
  void reset() {
    _usage = 0;
  }

  void _checkThresholds() {
    if (isOverBudget) {
      _controller.add(ForgeResourceEvent(
        budget: this,
        type: ForgeResourceEventType.overBudget,
      ));
    } else if (isHighUsage) {
      _controller.add(ForgeResourceEvent(
        budget: this,
        type: ForgeResourceEventType.highUsage,
      ));
    }
  }

  void dispose() {
    _controller.close();
  }
}

/// Types of resource budget events.
enum ForgeResourceEventType {
  /// Usage exceeds 80% of budget.
  highUsage,

  /// Usage exceeds 100% of budget.
  overBudget,

  /// Forced eviction was triggered to bring usage below budget.
  eviction,
}

/// Event emitted by [ForgeResourceBudget].
class ForgeResourceEvent {
  final ForgeResourceBudget budget;
  final ForgeResourceEventType type;

  ForgeResourceEvent({required this.budget, required this.type});

  @override
  String toString() =>
      'ForgeResourceEvent(${budget.name}: ${type.name}, '
      '${budget.usage}/${budget.budget})';
}

/// Aggregates multiple [ForgeResourceBudget] instances and provides
/// a unified monitoring surface.
class ForgeResourceMonitor {
  final Map<String, ForgeResourceBudget> _budgets = {};
  final _controller = StreamController<ForgeResourceEvent>.broadcast();
  final List<StreamSubscription<ForgeResourceEvent>> _subscriptions = [];

  /// Register a budget for monitoring.
  void register(ForgeResourceBudget budget) {
    _budgets[budget.name] = budget;
    final sub = budget.onEvent.listen((event) {
      _controller.add(event);
    });
    _subscriptions.add(sub);
  }

  /// Get a registered budget by name.
  ForgeResourceBudget? getBudget(String name) => _budgets[name];

  /// All registered budgets.
  Iterable<ForgeResourceBudget> get budgets => _budgets.values;

  /// Unified event stream across all budgets.
  Stream<ForgeResourceEvent> get onEvent => _controller.stream;

  /// Snapshot of all budget utilizations.
  Map<String, double> get utilizationSnapshot => {
        for (final b in _budgets.values) b.name: b.utilizationRatio,
      };

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    for (final budget in _budgets.values) {
      budget.dispose();
    }
    _controller.close();
  }
}
