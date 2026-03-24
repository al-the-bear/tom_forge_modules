# Tom Forge Panel Shell — Implementation Specification

**Version:** 1.0  
**Date:** 2026-03-24  
**Companion:** [forge_panel_shell_concept.md](forge_panel_shell_concept.md)

---

## Table of Contents

1. [Purpose and Scope](#1-purpose-and-scope)
2. [Widget Implementation Details](#2-widget-implementation-details)
3. [Error Handling Patterns](#3-error-handling-patterns)
4. [Performance Strategies](#4-performance-strategies)
5. [Accessibility Implementation](#5-accessibility-implementation)
6. [State Persistence Formats](#6-state-persistence-formats)
7. [Event Ordering and Lifecycle](#7-event-ordering-and-lifecycle)
8. [Test Strategy](#8-test-strategy)
9. [Cross-Reference Matrix](#9-cross-reference-matrix)
10. [Test Modules Specification](#10-test-modules-specification)
11. [Editor Integration Requirements](#11-editor-integration-requirements)
12. [Cross-Reference Updates](#12-cross-reference-updates)

---

## 1. Purpose and Scope

This document provides implementation-level specifications for the Tom Forge Panel Shell. It complements the [Concept Document](forge_panel_shell_concept.md) by specifying:

- **Concrete behaviors** — animations, timing, dimensions
- **Error scenarios** — failure modes, user feedback, recovery
- **Performance contracts** — memory budgets, lazy loading, virtualization
- **Accessibility** — keyboard navigation, screen reader support
- **Persistence formats** — JSON schemas for state files
- **Lifecycle guarantees** — event ordering, async operation sequencing
- **Test coverage** — unit, widget, integration, and E2E strategies

### Document Conventions

- **[Concept §X.Y]** — Reference to concept document section
- **MUST** / **MUST NOT** — Absolute requirements
- **SHOULD** / **SHOULD NOT** — Strong recommendations
- **MAY** — Optional behaviors

---

## 2. Widget Implementation Details

### 2.1 Animation Timing

All animations use Flutter's standard curves and consistent durations:

| Animation | Duration | Curve | Notes |
|-----------|----------|-------|-------|
| Panel collapse/expand | 200ms | `Curves.easeOutCubic` | Accordeon sections |
| Panel resize (drag) | 0ms | — | Real-time, no animation |
| Panel resize (double-click reset) | 150ms | `Curves.easeOut` | Snap to default size |
| Tab bar reorder | 150ms | `Curves.easeOut` | During drag |
| Tab insert/remove | 200ms | `Curves.easeInOut` | Fade + slide |
| Drop zone highlight | 100ms | `Curves.linear` | Fade in/out |
| Shortcut popup appear | 150ms | `Curves.easeOutBack` | Slight overshoot |
| Shortcut popup dismiss | 100ms | `Curves.easeIn` | Fast dismiss |
| Notification toast appear | 200ms | `Curves.easeOutCubic` | Slide + fade |
| Notification toast dismiss | 150ms | `Curves.easeIn` | — |
| Progress indicator pulse | 1000ms | `Curves.easeInOut` | Loop, indeterminate |

**Implementation:**

```dart
class ForgeAnimations {
  static const Duration panelTransition = Duration(milliseconds: 200);
  static const Duration tabTransition = Duration(milliseconds: 150);
  static const Duration dropZoneFade = Duration(milliseconds: 100);
  static const Duration shortcutPopupIn = Duration(milliseconds: 150);
  static const Duration shortcutPopupOut = Duration(milliseconds: 100);
  static const Duration notificationIn = Duration(milliseconds: 200);
  static const Duration notificationOut = Duration(milliseconds: 150);
  
  static const Curve panelCurve = Curves.easeOutCubic;
  static const Curve tabCurve = Curves.easeOut;
  static const Curve popupCurve = Curves.easeOutBack;
}
```

### 2.2 Dimension Constants

**Reference:** [Concept §2, §3]

| Element | Dimension | Min | Max | Default |
|---------|-----------|-----|-----|---------|
| Left panel width | pixels | 180 | 600 | 280 |
| Right panel width | pixels | 180 | 600 | 280 |
| Bottom panel height | pixels | 100 | 500 | 200 |
| Side panel tab bar | pixels | — | — | 48 (collapsed) / 200 (expanded with text) |
| Middle panel min width | pixels | 200 | — | — |
| Accordeon section header | pixels | — | — | 32 |
| Tab bar height | pixels | — | — | 36 |
| Status bar height | pixels | — | — | 24 |
| Title bar height | pixels | — | — | 48 |
| Menu bar height | pixels | — | — | 32 |
| Divider drag zone | pixels | — | — | 8 (hit target) / 1 (visual) |
| Icon size (tabs) | pixels | — | — | 20 |
| Icon size (toolbar) | pixels | — | — | 18 |

**Implementation:**

```dart
class ForgeDimensions {
  // Panels
  static const double leftPanelMinWidth = 180;
  static const double leftPanelMaxWidth = 600;
  static const double leftPanelDefaultWidth = 280;
  static const double rightPanelMinWidth = 180;
  static const double rightPanelMaxWidth = 600;
  static const double rightPanelDefaultWidth = 280;
  static const double bottomPanelMinHeight = 100;
  static const double bottomPanelMaxHeight = 500;
  static const double bottomPanelDefaultHeight = 200;
  static const double middlePanelMinWidth = 200;
  
  // Fixed elements
  static const double titleBarHeight = 48;
  static const double menuBarHeight = 32;
  static const double statusBarHeight = 24;
  static const double tabBarHeight = 36;
  static const double sectionHeaderHeight = 32;
  static const double sideTabBarCollapsed = 48;
  static const double sideTabBarExpanded = 200;
  
  // Interactive
  static const double dividerHitTarget = 8;
  static const double dividerVisual = 1;
  
  // Icons
  static const double iconTab = 20;
  static const double iconToolbar = 18;
}
```

### 2.3 Theme Integration

**Reference:** [Concept §16]

The shell MUST respect the application's `ThemeData` and provide shell-specific extensions:

```dart
/// Shell-specific theme extension.
class ForgeShellTheme extends ThemeExtension<ForgeShellTheme> {
  // Panel colors
  final Color panelBackground;
  final Color panelBorder;
  final Color panelHeaderBackground;
  final Color panelHeaderForeground;
  
  // Tab bar
  final Color tabBarBackground;
  final Color tabActive;
  final Color tabInactive;
  final Color tabHover;
  final Color tabIndicator;
  
  // Drop zones
  final Color dropZoneHighlight;
  final Color dropZoneValid;
  final Color dropZoneInvalid;
  
  // Focus
  final Color focusRing;
  final double focusRingWidth;
  
  // Status bar
  final Color statusBarBackground;
  final Color statusBarForeground;
  final Color statusBarItemHover;
  
  // Accordeon
  final Color sectionHeaderExpanded;
  final Color sectionHeaderCollapsed;
  final Color sectionDivider;
  
  // Shortcuts
  final Color shortcutPopupBackground;
  final Color shortcutPopupForeground;
  final Color shortcutKeyBackground;
  
  // Notifications
  final Color notificationInfo;
  final Color notificationWarning;
  final Color notificationError;
}
```

**Default Light Theme Values:**

```dart
ForgeShellTheme.light() = ForgeShellTheme(
  panelBackground: Color(0xFFF5F5F5),
  panelBorder: Color(0xFFE0E0E0),
  panelHeaderBackground: Color(0xFFEEEEEE),
  panelHeaderForeground: Color(0xFF424242),
  tabBarBackground: Color(0xFFFAFAFA),
  tabActive: Color(0xFF1976D2),
  tabInactive: Color(0xFF757575),
  tabHover: Color(0xFFE3F2FD),
  tabIndicator: Color(0xFF1976D2),
  dropZoneHighlight: Color(0x401976D2),
  dropZoneValid: Color(0x4043A047),
  dropZoneInvalid: Color(0x40E53935),
  focusRing: Color(0xFF1976D2),
  focusRingWidth: 2.0,
  statusBarBackground: Color(0xFF1976D2),
  statusBarForeground: Colors.white,
  statusBarItemHover: Color(0x20FFFFFF),
  sectionHeaderExpanded: Color(0xFFE3F2FD),
  sectionHeaderCollapsed: Colors.transparent,
  sectionDivider: Color(0xFFE0E0E0),
  shortcutPopupBackground: Color(0xFF424242),
  shortcutPopupForeground: Colors.white,
  shortcutKeyBackground: Color(0xFF616161),
  notificationInfo: Color(0xFF1976D2),
  notificationWarning: Color(0xFFFFA000),
  notificationError: Color(0xFFD32F2F),
);
```

### 2.4 Focus Management

**Reference:** [Concept §4.2, §10.2]

**Focus Ring Specification:**

- Focus ring MUST be visible on all interactive elements when focused via keyboard
- Focus ring uses `focusRing` color from theme at `focusRingWidth` (default 2px)
- Focus ring MUST be inside the element bounds (no overflow)
- Mouse focus SHOULD NOT show focus ring (use `:focus-visible` equivalent)

**Focus Order:**

```
1. Title bar: Nav buttons → Search field → Application dropdown
2. Menu bar: Menu items (left to right)
3. Left panel: Tab bar → Active tab content (sections top to bottom)
4. Middle panels: Tab bar → Active editor content
5. Right panel: Active tab content → Tab bar
6. Bottom panel: Tab bar → Active tab content
7. Status bar: Items (left to right)
```

**Focus Trapping:**

- Modal dialogs MUST trap focus
- Shortcut popup MUST trap focus while visible
- Quick pick MUST trap focus until dismissed

**Implementation:**

```dart
class ForgeFocusManager {
  /// Focus the next panel in the cycle.
  void focusNextPanel();
  
  /// Focus the previous panel in the cycle.
  void focusPreviousPanel();
  
  /// Focus the active component in the currently focused panel.
  void focusActiveComponent();
  
  /// Move focus to a specific component.
  void focusComponent(ForgeComponent component);
  
  /// Current keyboard-focused element.
  FocusNode? get currentFocus;
  
  /// Whether the shell is currently trapping focus (modal open).
  bool get isFocusTrapped;
}
```

### 2.5 Scroll Behaviors

**Reference:** [Concept §4.4]

| Context | Behavior |
|---------|----------|
| Accordeon sections | `ClampingScrollPhysics`, no overscroll glow |
| Explorer tree | `ClampingScrollPhysics`, keyboard scroll by line |
| Editor content | Platform default (bouncing on macOS, clamping on others) |
| Terminal | `NeverScrollableScrollPhysics` (PTY handles scrollback) |
| Output view | Auto-scroll to bottom when at bottom; stay in place otherwise |
| Tab bars | Horizontal scroll with mouse wheel; show arrows at overflow |

**Output View Auto-Scroll Logic:**

```dart
class OutputScrollBehavior {
  bool _wasAtBottom = true;
  
  void onScroll(ScrollController controller) {
    _wasAtBottom = controller.position.pixels >= 
        controller.position.maxScrollExtent - 10;
  }
  
  void onNewContent(ScrollController controller) {
    if (_wasAtBottom) {
      controller.jumpTo(controller.position.maxScrollExtent);
    }
  }
}
```

### 2.6 Drag and Drop Visual Feedback

**Reference:** [Concept §5]

**Drag Proxy:**

- Drag proxy MUST be a semi-transparent (opacity 0.8) snapshot of the tab/header
- Proxy size: actual size of the dragged element
- Proxy follows cursor with 8px offset (down-right)
- Cursor changes to `SystemMouseCursors.grabbing` during drag

**Drop Zones:**

- Drop zones appear after 100ms of hover over a valid target
- Drop zone highlight: 40% opacity of `dropZoneHighlight` color
- Valid drop: brief (100ms) `dropZoneValid` flash before accepting
- Invalid drop: brief (100ms) `dropZoneInvalid` flash, then snap back

**SHIFT+Drag Indicator:**

- When SHIFT is held, show "+" badge on drag proxy (top-right corner)
- Badge: 16x16 circle, solid accent color, white "+" icon

---

## 3. Error Handling Patterns

### 3.1 Error Categories

| Category | Severity | User Feedback | Recovery |
|----------|----------|---------------|----------|
| **File not found** | Warning | Inline banner in editor area | Offer to create or close |
| **File read/write error** | Error | Modal dialog | Retry or cancel |
| **Network timeout** | Warning | Status bar indicator + toast | Auto-retry 3x |
| **Module activation failed** | Error | Problems view entry | Disable module, allow retry |
| **Configuration parse error** | Warning | Toast + fallback to defaults | Edit config manually |
| **Out of memory** | Critical | Modal dialog | Close editors, clear caches |
| **Extension crash** | Error | Toast + Problems entry | Restart extension |

### 3.2 Error UI Components

**Inline Error Banner:**

```dart
class ForgeErrorBanner extends StatelessWidget {
  final String message;
  final ForgeSeverity severity;
  final List<ForgeErrorAction> actions;
  final VoidCallback? onDismiss;
  
  // Height: 32px
  // Background: severity-based color at 10% opacity
  // Left border: 3px solid severity color
  // Icon: severity icon (16px)
  // Text: ellipsized, single line
  // Actions: text buttons, right-aligned
}

class ForgeErrorAction {
  final String label;
  final VoidCallback onPressed;
}
```

**Error Toast:**

```dart
class ForgeToast {
  static void show({
    required String message,
    ForgeSeverity severity = ForgeSeverity.info,
    Duration duration = const Duration(seconds: 4),
    List<String> actions = const [],
    void Function(String action)? onAction,
  });
}
```

Toast placement: bottom-right corner, 16px margin, stacked vertically (max 3 visible).

**Error Modal:**

```dart
class ForgeErrorDialog {
  static Future<ForgeErrorDialogResult> show({
    required String title,
    required String message,
    String? details,  // Expandable "Show Details" section
    required List<ForgeDialogButton> buttons,
  });
}

enum ForgeErrorDialogResult { primaryAction, secondaryAction, dismissed }
```

### 3.3 File Operation Errors

**Reference:** [Concept §10.4 ForgeFileSystem]

| Operation | Error | Behavior |
|-----------|-------|----------|
| `read()` | FileNotFound | Throw `ForgeFileNotFoundException` |
| `read()` | PermissionDenied | Throw `ForgePermissionException`, show toast |
| `write()` | Disk full | Throw `ForgeDiskFullException`, show modal |
| `write()` | Permission denied | Throw `ForgePermissionException`, offer "Save As" |
| `save()` | Conflict (modified externally) | Show merge dialog with options |
| `delete()` | File in use | Toast warning, retry after 1s |
| `watch()` | Too many watchers | Consolidate into parent directory watch |

**File Conflict Resolution:**

```dart
enum ForgeConflictResolution {
  overwrite,      // Discard external changes
  merge,          // Open diff view
  reload,         // Discard local changes
  saveAs,         // Save to different location
  cancel,         // Keep both, do nothing
}

class ForgeConflictDialog {
  static Future<ForgeConflictResolution> show({
    required Uri uri,
    required DateTime localModified,
    required DateTime externalModified,
    String? previewLocal,
    String? previewExternal,
  });
}
```

### 3.4 Module Error Handling

**Reference:** [Concept §8]

Module errors are isolated — one failing module MUST NOT crash the shell.

**Activation Failure:**

```dart
try {
  await module.activate(api);
} catch (e, stack) {
  // 1. Log to output channel "Tom Forge Shell"
  api.output.getChannel('Tom Forge Shell').appendLine(
    'Module ${module.runtimeType} failed to activate: $e\n$stack'
  );
  
  // 2. Add diagnostic
  api.diagnostics.report(
    ForgeDiagnostic(
      uri: Uri.parse('forge://modules/${module.id}'),
      range: TextRange.empty,
      message: 'Module failed to activate: $e',
      severity: ForgeSeverity.error,
      source: 'Shell',
    ),
  );
  
  // 3. Mark module as errored
  _moduleStates[module] = ModuleState.error;
  
  // 4. Show toast
  api.notifications.showError(
    'Failed to activate ${module.displayName}. See Problems view.',
  );
}
```

### 3.5 Retry Strategies

```dart
class ForgeRetryPolicy {
  /// Execute with exponential backoff.
  static Future<T> withBackoff<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffMultiplier = 2.0,
    bool Function(Object error)? shouldRetry,
  });
  
  /// Execute with immediate retry on specific errors.
  static Future<T> withImmediateRetry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 2,
    Set<Type> retryableErrors = const {TimeoutException},
  });
}
```

---

## 4. Performance Strategies

### 4.1 Memory Budgets

| Resource | Budget | Action When Exceeded |
|----------|--------|---------------------|
| Open editors | 50 simultaneous | LRU close least-recently-focused |
| Undo stack per editor | 100 entries / 10MB | Prune oldest entries |
| File watchers | 1000 paths | Consolidate to parent directories |
| Output channel lines | 10,000 per channel | Ring buffer, prune oldest |
| Revision history | 100 revisions per file | Prune oldest beyond 7 days |
| Search results cache | 50MB | LRU eviction |
| Image preview cache | 100MB | LRU eviction |

**Memory Monitor:**

```dart
class ForgeMemoryMonitor {
  /// Current memory usage in bytes.
  int get currentUsage;
  
  /// Memory budget in bytes (from config).
  int get budget;
  
  /// Usage ratio (0.0 to 1.0+).
  double get usageRatio;
  
  /// Fires when usage exceeds 80% of budget.
  Stream<void> get onHighMemory;
  
  /// Request garbage collection (advisory).
  void requestGC();
  
  /// Force eviction of cached resources.
  Future<void> evictCaches({double targetRatio = 0.6});
}
```

### 4.2 Virtualization Requirements

**Reference:** [Concept §14]

| View | Virtualization | Threshold |
|------|----------------|-----------|
| Explorer tree | `SliverList` with `findChildIndexCallback` | Always |
| Search results | `ListView.builder` | Always |
| Problems list | `ListView.builder` | Always |
| Outline tree | `SliverList` | Always |
| Output view | Ring buffer + `ListView.builder` | Always |
| Terminal | PTY buffer with viewport | Always |
| Tab bar (horizontal) | Scroll with `SingleChildScrollView` | > 10 tabs |

**Tree Virtualization Pattern:**

```dart
class VirtualizedTreeView extends StatelessWidget {
  final TreeNode root;
  final double itemHeight = 24;
  
  @override
  Widget build(BuildContext context) {
    final flatList = _flattenVisibleNodes(root);
    return ListView.builder(
      itemCount: flatList.length,
      itemExtent: itemHeight,  // Fixed height enables efficient layout
      itemBuilder: (context, index) => _buildNode(flatList[index]),
    );
  }
  
  List<TreeNode> _flattenVisibleNodes(TreeNode root) {
    // Only include nodes whose ancestors are all expanded
    // Cache this list, invalidate on expand/collapse
  }
}
```

### 4.3 Lazy Loading

**Deferred Loading Points:**

| Resource | Load Trigger | Preload Window |
|----------|--------------|----------------|
| Editor content | Editor opened | — |
| Module code | First access | — |
| View content | Tab selected | Next tab in each panel |
| Search index | First search | On workspace open (low priority) |
| File metadata | Directory expanded | Immediate children only |
| Diagnostics | File opened | — |

**Lazy Component Pattern:**

```dart
class LazyComponent extends StatefulWidget {
  final WidgetBuilder builder;
  final WidgetBuilder placeholder;
  
  @override
  State<LazyComponent> createState() => _LazyComponentState();
}

class _LazyComponentState extends State<LazyComponent> {
  bool _loaded = false;
  Widget? _content;
  
  @override
  void initState() {
    super.initState();
    // Defer build to next frame for non-visible content
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _content = widget.builder(context);
          _loaded = true;
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return _loaded ? _content! : widget.placeholder(context);
  }
}
```

### 4.4 Caching Strategies

**File Content Cache:**

```dart
class ForgeFileCache {
  final int maxEntries = 100;
  final int maxSizeBytes = 50 * 1024 * 1024;  // 50MB
  
  /// Get file content, reading from disk if not cached.
  Future<Uint8List> get(Uri uri);
  
  /// Invalidate cache entry.
  void invalidate(Uri uri);
  
  /// Invalidate all entries under a directory.
  void invalidateDirectory(Uri directory);
  
  /// Clear entire cache.
  void clear();
}
```

**Computed Property Cache:**

Expensive computations (outline, diagnostics, symbols) use a generation-based cache:

```dart
class ComputedCache<T> {
  int _generation = 0;
  T? _cached;
  int _cachedGeneration = -1;
  
  T get(T Function() compute) {
    if (_cachedGeneration != _generation) {
      _cached = compute();
      _cachedGeneration = _generation;
    }
    return _cached as T;
  }
  
  void invalidate() {
    _generation++;
  }
}
```

### 4.5 Debouncing and Throttling

| Event | Strategy | Delay |
|-------|----------|-------|
| Search input | Debounce | 200ms |
| Explorer file filter | Debounce | 150ms |
| Config change notification | Debounce | 100ms |
| Layout persistence | Debounce | 500ms |
| Auto-save | Debounce | configurable (default 1000ms) |
| Diagnostic refresh | Throttle | 100ms min between |
| File watcher events | Batch + throttle | 50ms batch window |

```dart
class ForgeDebouncer {
  Timer? _timer;
  final Duration delay;
  
  ForgeDebouncer(this.delay);
  
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }
  
  void cancel() {
    _timer?.cancel();
  }
}

class ForgeThrottler {
  DateTime? _lastRun;
  final Duration minInterval;
  
  ForgeThrottler(this.minInterval);
  
  bool tryRun(VoidCallback action) {
    final now = DateTime.now();
    if (_lastRun == null || now.difference(_lastRun!) >= minInterval) {
      _lastRun = now;
      action();
      return true;
    }
    return false;
  }
}
```

---

## 5. Accessibility Implementation

### 5.1 Keyboard Navigation

**Reference:** [Concept §11]

**Global Navigation:**

| Shortcut | Action |
|----------|--------|
| `F6` | Focus next panel |
| `Shift+F6` | Focus previous panel |
| `Ctrl+Tab` | Next editor |
| `Ctrl+Shift+Tab` | Previous editor |
| `Escape` | Close popup / Clear selection / Exit mode |
| `F1` | Open command palette |

**Panel-Specific Navigation:**

| Context | Key | Action |
|---------|-----|--------|
| Tree view | `↑` / `↓` | Move selection |
| Tree view | `←` | Collapse or go to parent |
| Tree view | `→` | Expand or go to first child |
| Tree view | `Enter` | Activate (open file, expand) |
| Tree view | `Space` | Toggle selection (multi-select) |
| Tab bar | `←` / `→` | Move between tabs |
| Tab bar | `Enter` | Activate tab |
| Tab bar | `Delete` | Close tab |
| Accordeon | `↑` / `↓` | Move between sections |
| Accordeon | `Enter` / `Space` | Toggle section |
| Text editor | Standard | Platform text editing |

### 5.2 Screen Reader Support

**ARIA-like Semantics:**

```dart
class ForgeSemantics {
  // Panel announcements
  static const String panelRole = 'region';
  static const String tabListRole = 'tablist';
  static const String tabRole = 'tab';
  static const String tabPanelRole = 'tabpanel';
  
  // Tree
  static const String treeRole = 'tree';
  static const String treeItemRole = 'treeitem';
  
  // Alerts
  static const String alertRole = 'alert';
  static const String statusRole = 'status';
}
```

**Live Region Updates:**

| Event | Announcement |
|-------|--------------|
| File saved | "File saved: {filename}" |
| Error occurred | "Error: {message}" |
| Search completed | "{count} results found" |
| Build started | "Build started" |
| Build completed | "Build {succeeded/failed}" |
| Tab opened | "Opened {filename}" |
| Tab closed | "Closed {filename}" |

**Implementation:**

```dart
class ForgeAnnouncer {
  static void announce(String message, {
    Assertiveness assertiveness = Assertiveness.polite,
  }) {
    SemanticsService.announce(message, TextDirection.ltr,
      assertiveness: assertiveness,
    );
  }
  
  static void announceUrgent(String message) {
    announce(message, assertiveness: Assertiveness.assertive);
  }
}
```

### 5.3 High Contrast Mode

The shell MUST support high contrast themes:

```dart
ForgeShellTheme.highContrast() = ForgeShellTheme(
  panelBackground: Colors.black,
  panelBorder: Colors.white,
  panelHeaderBackground: Colors.black,
  panelHeaderForeground: Colors.white,
  tabBarBackground: Colors.black,
  tabActive: Colors.yellow,
  tabInactive: Colors.white,
  tabHover: Color(0xFF333333),
  tabIndicator: Colors.yellow,
  dropZoneHighlight: Color(0x80FFFF00),
  dropZoneValid: Color(0x8000FF00),
  dropZoneInvalid: Color(0x80FF0000),
  focusRing: Colors.yellow,
  focusRingWidth: 3.0,  // Thicker for visibility
  statusBarBackground: Color(0xFF333333),
  statusBarForeground: Colors.white,
  // ... remaining high contrast values
);
```

### 5.4 Reduced Motion

When `MediaQuery.of(context).disableAnimations` is true:

- All animation durations become 0ms
- Transitions are instant
- Progress indicators use static updates instead of animation

```dart
Duration getAnimationDuration(BuildContext context, Duration normal) {
  return MediaQuery.of(context).disableAnimations ? Duration.zero : normal;
}
```

---

## 6. State Persistence Formats

### 6.1 Layout State Schema

**File:** `.forge/state/layout.json`

```json
{
  "$schema": "forge://schemas/layout-state.json",
  "version": 1,
  "panels": {
    "left": {
      "visible": true,
      "width": 280,
      "activeTabId": "explorer",
      "tabs": [
        {
          "id": "explorer",
          "icon": "folder",
          "sections": [
            {"id": "files", "expanded": true, "height": 300},
            {"id": "outline", "expanded": false, "height": 200}
          ]
        }
      ]
    },
    "right": {
      "visible": false,
      "width": 280,
      "activeTabId": null,
      "tabs": []
    },
    "bottom": {
      "visible": true,
      "height": 200,
      "activeTabId": "terminal",
      "tabs": [
        {"id": "terminal", "icon": "terminal", "label": "Terminal"},
        {"id": "output", "icon": "output", "label": "Output"},
        {"id": "problems", "icon": "warning", "label": "Problems"}
      ]
    },
    "middle": {
      "orientation": "horizontal",
      "panels": [
        {
          "weight": 0.6,
          "activeTabIndex": 0,
          "tabs": [
            {"uri": "file:///project/src/main.dart", "editorType": "text"},
            {"uri": "file:///project/lib/widget.dart", "editorType": "text"}
          ]
        },
        {
          "weight": 0.4,
          "activeTabIndex": 0,
          "tabs": [
            {"uri": "file:///project/README.md", "editorType": "text"}
          ]
        }
      ]
    }
  },
  "statusBar": {
    "visible": true
  },
  "menuBar": {
    "visible": true
  }
}
```

### 6.2 Editor State Schema

**File:** `.forge/state/editors/{uri-hash}.json`

```json
{
  "$schema": "forge://schemas/editor-state.json",
  "version": 1,
  "uri": "file:///project/src/main.dart",
  "editorType": "text",
  "scrollPosition": {
    "x": 0,
    "y": 1250
  },
  "selection": {
    "start": {"line": 45, "column": 12},
    "end": {"line": 45, "column": 20}
  },
  "selections": [],
  "folds": [
    {"startLine": 10, "endLine": 25},
    {"startLine": 100, "endLine": 150}
  ],
  "viewState": {}
}
```

### 6.3 Undo Stack Schema

**File:** `.forge/undo/{uri-hash}.json`

```json
{
  "$schema": "forge://schemas/undo-stack.json",
  "version": 1,
  "uri": "file:///project/src/main.dart",
  "undoStack": [
    {
      "id": "uuid-1",
      "timestamp": "2026-03-24T10:30:00Z",
      "label": "Insert text",
      "type": "text-edit",
      "data": {
        "range": {"start": {"line": 10, "column": 0}, "end": {"line": 10, "column": 0}},
        "oldText": "",
        "newText": "// Comment\n"
      }
    }
  ],
  "redoStack": [],
  "savedAtId": "uuid-1"
}
```

### 6.4 Configuration Schema

**File:** `.forge/config.json`

```json
{
  "$schema": "forge://schemas/config.json",
  "version": 1,
  "general": {
    "theme": "light",
    "fontSize": 14,
    "fontFamily": "JetBrains Mono",
    "tabSize": 2,
    "insertSpaces": true,
    "wordWrap": "bounded",
    "wordWrapColumn": 80
  },
  "autoSave": {
    "enabled": true,
    "delay": 1000,
    "onFocusLoss": true,
    "onWindowChange": true
  },
  "files": {
    "exclude": ["**/.git", "**/node_modules", "**/.dart_tool"],
    "watcherExclude": ["**/build/**"],
    "associations": {
      "*.config": "json"
    }
  },
  "shortcuts": {
    "overrides": {
      "editor.save": "Cmd+S",
      "editor.saveAll": "Cmd+Shift+S"
    }
  },
  "modules": {
    "disabled": [],
    "config": {
      "git": {"autoFetch": false},
      "dart": {"formatOnSave": true}
    }
  },
  "layout": {
    "showMenuBar": true,
    "showStatusBar": true,
    "sideBarPosition": "left"
  }
}
```

### 6.5 Revision Storage Schema

**File:** `.forge/revisions/{uri-hash}/{timestamp}.json`

```json
{
  "$schema": "forge://schemas/revision.json",
  "version": 1,
  "uri": "file:///project/src/main.dart",
  "timestamp": "2026-03-24T10:30:00Z",
  "reason": "auto-save",
  "contentHash": "sha256:abc123...",
  "size": 4096,
  "encoding": "utf-8"
}
```

Content stored as: `.forge/revisions/{uri-hash}/{timestamp}.content`

---

## 7. Event Ordering and Lifecycle

### 7.1 Shell Lifecycle

```
1. Shell constructor
   └─ Initialize controllers (sync)
   
2. Shell.initState()
   └─ Load configuration (async, shows splash)
   └─ Initialize file system
   └─ Load layout state
   └─ Register built-in views
   
3. Modules registration (sync)
   └─ For each module: instantiate, store in registry
   
4. Modules activation (async, sequential)
   └─ For each module in dependency order:
       └─ module.activate(api)
       └─ Collect actions, views, editors
       └─ Register shortcuts
   
5. Layout restoration
   └─ Restore panel configuration
   └─ Open editors from state
   └─ Restore scroll/selection state
   
6. Ready
   └─ Fire onReady event
   └─ Process command-line arguments (open files)
   
7. Running
   └─ Normal operation
   
8. Shutdown request (window close)
   └─ For each dirty editor:
       └─ Prompt save/discard/cancel
   └─ If cancelled: abort shutdown
   
9. Shutdown
   └─ Save layout state
   └─ Save editor states
   └─ Modules deactivation (async, reverse order)
       └─ module.deactivate()
   └─ Flush pending writes
   └─ Exit
```

### 7.2 Editor Lifecycle

```
1. openEditor(uri) called
   └─ If editor for URI exists:
       └─ Focus existing editor
       └─ Return existing
   
2. File resolution (two-phase)
   └─ Collect candidate editors (canHandle)
   └─ For each candidate: canHandleContent
   └─ If multiple: show "Open with" dialog
   └─ Select primary editor
   
3. Editor instantiation
   └─ Create editor instance
   └─ Load content: api.fileSystem.read(uri)
   
4. Editor registration
   └─ Add to openEditors list
   └─ Fire EditorListChangeEvent(opened: [editor])
   └─ Create tab in active middle panel
   
5. Content loaded
   └─ Restore editor state (scroll, selection)
   └─ Register file watcher
   └─ Fire FocusChangeEvent
   
6. Editing
   └─ Track dirty state
   └─ Auto-save (if enabled)
   
7. Save requested
   └─ Fire WillSaveEvent
   └─ Create revision (if changed)
   └─ Write to file system
   └─ Clear dirty state
   └─ Fire FileChangeEvent
   
8. Close requested
   └─ If dirty: prompt save/discard/cancel
   └─ If cancelled: abort
   └─ Unregister file watcher
   └─ Remove from openEditors
   └─ Fire EditorListChangeEvent(closed: [editor])
   └─ Dispose editor
```

### 7.3 Event Ordering Guarantees

**Synchronous Events:**

- `FocusChangeEvent`: Fires synchronously when focus changes
- `DirtyStateEvent`: Fires synchronously when dirty state changes
- `SelectionChangeEvent`: Fires synchronously when selection changes

**Asynchronous Events:**

- `FileChangeEvent`: Fires after file operation completes
- `WillSaveEvent`: Fires before save, allows modifications
- `ConfigChangeEvent`: Fires after config is persisted

**Ordering Rules:**

1. Events for the same resource fire in causal order
2. `WillSaveEvent` always precedes `FileChangeEvent` for saves
3. `EditorListChangeEvent(opened)` fires before `FocusChangeEvent` for new editors
4. `FocusChangeEvent` fires before `EditorListChangeEvent(closed)` for closing editors

### 7.4 Async Operation Sequencing

**File Operations:**

```dart
class ForgeOperationQueue {
  final _queues = <Uri, Queue<_Operation>>{};
  
  /// Queue an operation for a URI. Operations on the same URI
  /// execute sequentially; different URIs execute in parallel.
  Future<T> enqueue<T>(Uri uri, Future<T> Function() operation);
}
```

**Configuration Updates:**

```dart
class ForgeConfigManager {
  final _pendingWrites = <String, Object?>{};
  Timer? _writeTimer;
  
  void set(String key, Object? value) {
    _pendingWrites[key] = value;
    _scheduleWrite();
  }
  
  void _scheduleWrite() {
    _writeTimer?.cancel();
    _writeTimer = Timer(const Duration(milliseconds: 100), _flush);
  }
  
  Future<void> _flush() async {
    final batch = Map.of(_pendingWrites);
    _pendingWrites.clear();
    await _writeConfig(batch);
    for (final key in batch.keys) {
      _fireChangeEvent(key);
    }
  }
}
```

---

## 8. Test Strategy

### 8.1 Test Categories

| Category | Scope | Tools | Coverage Target |
|----------|-------|-------|-----------------|
| **Unit** | Individual classes, functions | `package:test` | 90%+ |
| **Widget** | UI components in isolation | `package:flutter_test` | 80%+ |
| **Integration** | Multiple components together | `package:flutter_test` + mocks | 70%+ |
| **E2E** | Complete user flows | `package:integration_test` | Critical paths |
| **Golden** | Visual regression | `matchesGoldenFile` | Key screens |

### 8.2 Unit Test Patterns

#### Service Tests

```dart
// test/services/layout_persistence_test.dart

void main() {
  group('LayoutPersistence', () {
    late LayoutPersistence persistence;
    late MockForgeFileSystem fileSystem;
    
    setUp(() {
      fileSystem = MockForgeFileSystem();
      persistence = LayoutPersistence(fileSystem);
    });
    
    test('saves layout state to correct path', () async {
      final state = LayoutState(/* ... */);
      
      await persistence.save(state);
      
      verify(fileSystem.write(
        Uri.file('.forge/state/layout.json'),
        any,
      )).called(1);
    });
    
    test('restores layout state from JSON', () async {
      when(fileSystem.read(any)).thenAnswer((_) async => 
        Uint8List.fromList(utf8.encode('{"version":1,...}')));
      
      final state = await persistence.load();
      
      expect(state.version, 1);
    });
    
    test('returns default state when file not found', () async {
      when(fileSystem.read(any))
        .thenThrow(ForgeFileNotFoundException(Uri.file('test')));
      
      final state = await persistence.load();
      
      expect(state, LayoutState.defaultState);
    });
  });
}
```

#### State Machine Tests

```dart
// test/models/editor_lifecycle_test.dart

void main() {
  group('EditorLifecycle', () {
    test('transitions: New -> Loading -> Ready', () async {
      final editor = TestTextEditor();
      
      expect(editor.state, EditorState.created);
      
      final loadFuture = editor.load();
      expect(editor.state, EditorState.loading);
      
      await loadFuture;
      expect(editor.state, EditorState.ready);
    });
    
    test('transitions: Ready -> Dirty on edit', () {
      final editor = TestTextEditor()..state = EditorState.ready;
      
      editor.insert(TextPosition(line: 0, column: 0), 'x');
      
      expect(editor.state, EditorState.dirty);
    });
    
    test('transitions: Dirty -> Ready on save', () async {
      final editor = TestTextEditor()..state = EditorState.dirty;
      
      await editor.save();
      
      expect(editor.state, EditorState.ready);
    });
  });
}
```

### 8.3 Widget Test Patterns

#### Component Tests

```dart
// test/widgets/accordeon_section_test.dart

void main() {
  group('AccordeonSection', () {
    testWidgets('expands on header tap', (tester) async {
      bool expanded = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: AccordeonSection(
            title: 'Test Section',
            expanded: expanded,
            onToggle: () => expanded = !expanded,
            child: const Text('Content'),
          ),
        ),
      );
      
      expect(find.text('Content'), findsNothing);
      
      await tester.tap(find.text('Test Section'));
      await tester.pumpAndSettle();
      
      expect(expanded, isTrue);
    });
    
    testWidgets('respects pinned state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccordeonSection(
            title: 'Pinned',
            expanded: true,
            pinned: true,
            onToggle: () {},
            child: const Text('Content'),
          ),
        ),
      );
      
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });
  });
}
```

#### Interaction Tests

```dart
// test/widgets/drag_drop_test.dart

void main() {
  group('Drag and Drop', () {
    testWidgets('drag tab to different panel', (tester) async {
      final controller = MockForgeShellController();
      
      await tester.pumpWidget(
        ForgeShell(controller: controller),
      );
      
      final tab = find.byKey(const Key('tab-main.dart'));
      final dropTarget = find.byKey(const Key('right-panel-drop-zone'));
      
      await tester.drag(tab, tester.getCenter(dropTarget) - tester.getCenter(tab));
      await tester.pumpAndSettle();
      
      verify(controller.moveComponent(any, PanelLocation.right)).called(1);
    });
    
    testWidgets('SHIFT+drag creates copy', (tester) async {
      final controller = MockForgeShellController();
      
      await tester.pumpWidget(
        ForgeShell(controller: controller),
      );
      
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      
      final tab = find.byKey(const Key('tab-main.dart'));
      final dropTarget = find.byKey(const Key('right-panel-drop-zone'));
      
      await tester.drag(tab, tester.getCenter(dropTarget) - tester.getCenter(tab));
      await tester.pumpAndSettle();
      
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      
      verify(controller.copyComponent(any, PanelLocation.right)).called(1);
    });
  });
}
```

### 8.4 Integration Test Patterns

#### Service Integration

```dart
// test/integration/file_save_flow_test.dart

void main() {
  group('File Save Flow', () {
    late ForgeShellApi api;
    late TestDirectory testDir;
    
    setUp(() async {
      testDir = await TestDirectory.create();
      api = await ForgeTestHarness.createApi(workspaceUri: testDir.uri);
    });
    
    tearDown(() async {
      await testDir.delete();
    });
    
    test('save creates revision and updates file', () async {
      // Setup
      final uri = testDir.file('test.txt');
      await api.fileSystem.write(uri, utf8.encode('original'));
      
      final editor = await api.editors.open(uri) as ForgeTextEditor;
      editor.document.replaceAll('modified');
      
      // Act
      await editor.save();
      
      // Assert
      final content = await api.fileSystem.read(uri);
      expect(utf8.decode(content), 'modified');
      
      final revisions = await api.revisions.list(uri);
      expect(revisions, hasLength(1));
    });
    
    test('WillSaveEvent allows modification before save', () async {
      final uri = testDir.file('test.txt');
      await api.fileSystem.write(uri, utf8.encode('original'));
      
      final editor = await api.editors.open(uri) as ForgeTextEditor;
      
      // Listen for save event
      api.fileSystem.onWillSave.listen((event) {
        if (event.uri == uri) {
          // Append timestamp
          event.content = '${event.content}\n// Saved at ${DateTime.now()}';
        }
      });
      
      editor.document.replaceAll('modified');
      await editor.save();
      
      final content = await api.fileSystem.read(uri);
      expect(content, contains('Saved at'));
    });
  });
}
```

### 8.5 E2E Test Scenarios

| Scenario | Steps | Assertions |
|----------|-------|------------|
| **Startup** | Launch → Select workspace → Wait ready | Shell visible, explorer shows files |
| **Open file** | Double-click file in explorer | Editor opens, tab created, content shown |
| **Edit and save** | Type in editor → Cmd+S | Dirty indicator clears, file updated |
| **Undo/redo** | Edit → Cmd+Z → Cmd+Shift+Z | Changes reverted then restored |
| **Split editor** | Drag tab to split zone | Two panels, same file |
| **Search** | Cmd+Shift+F → type → Enter | Results shown, click navigates |
| **Problems** | Open file with errors → View Problems | Diagnostics listed, click navigates |
| **Terminal** | Open terminal → type command | Output appears |
| **Module error** | Activate bad module | Error toast, Problems entry, other modules work |
| **Close dirty** | Edit file → Close tab | Prompt appears, options work |

### 8.6 Golden Tests

```dart
// test/golden/shell_layout_test.dart

void main() {
  group('Shell Layout Goldens', () {
    testWidgets('default layout', (tester) async {
      await tester.pumpWidget(
        ForgeShellGoldenHarness(
          state: ForgeTestState.defaultLayout,
        ),
      );
      
      await expectLater(
        find.byType(ForgeShell),
        matchesGoldenFile('goldens/shell_default.png'),
      );
    });
    
    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        ForgeShellGoldenHarness(
          state: ForgeTestState.defaultLayout,
          theme: ForgeShellTheme.dark(),
        ),
      );
      
      await expectLater(
        find.byType(ForgeShell),
        matchesGoldenFile('goldens/shell_dark.png'),
      );
    });
    
    testWidgets('high contrast', (tester) async {
      await tester.pumpWidget(
        ForgeShellGoldenHarness(
          state: ForgeTestState.defaultLayout,
          theme: ForgeShellTheme.highContrast(),
        ),
      );
      
      await expectLater(
        find.byType(ForgeShell),
        matchesGoldenFile('goldens/shell_high_contrast.png'),
      );
    });
  });
}
```

### 8.7 Service-Specific Test Requirements

**Reference:** [Concept §10.4]

| Service | Unit Tests | Integration Tests | Key Scenarios |
|---------|------------|-------------------|---------------|
| `ForgeFileSystem` | Read/write/delete ops, path normalization | Multi-file operations, concurrent access | File conflict, permission errors |
| `ForgeLayoutController` | Panel operations, resize bounds | Layout persistence → restore | Complex nested layout |
| `ForgeDiagnosticManager` | CRUD operations, severity filtering | Multiple providers | Performance with 10K diagnostics |
| `ForgeOutputChannelManager` | Channel lifecycle, line appending | Ring buffer limits | High-throughput logging |
| `ForgeShortcutManager` | Registration, conflict detection | Trigger key popup | Overlapping shortcuts |
| `ForgeConfigManager` | Get/set/delete, defaults | Nested keys, type coercion | Config corruption recovery |
| `ForgeUndoManager` | Push/undo/redo, limits | Cross-editor operations | Memory limits |
| `ForgeTerminalManager` | Create/dispose, I/O | PTY interaction | Long-running commands |
| `ForgeSecretStorage` | Store/get/delete | Keychain integration | Secure storage |
| `ForgeSearchManager` | Query parsing, result ranking | File system integration | Large workspace search |
| `ForgeOutlineManager` | Provider registration | Editor ↔ outline sync | Provider errors |

### 8.8 Mock Factories

```dart
// test/mocks/factories.dart

class ForgeMocks {
  static MockForgeFileSystem fileSystem() {
    final mock = MockForgeFileSystem();
    when(mock.read(any)).thenAnswer((_) async => Uint8List(0));
    when(mock.write(any, any)).thenAnswer((_) async {});
    when(mock.exists(any)).thenAnswer((_) async => true);
    return mock;
  }
  
  static MockForgeShellApi api({
    MockForgeFileSystem? fileSystem,
    MockForgeConfigManager? config,
  }) {
    final mock = MockForgeShellApi();
    when(mock.fileSystem).thenReturn(fileSystem ?? ForgeMocks.fileSystem());
    when(mock.config).thenReturn(config ?? ForgeMocks.config());
    // ... other services
    return mock;
  }
  
  static ForgeTestEditor textEditor({
    required Uri uri,
    String content = '',
    bool dirty = false,
  }) {
    return ForgeTestEditor(
      uri: uri,
      initialContent: content,
      initialDirty: dirty,
    );
  }
}
```

### 8.9 Test Coverage Requirements

**Minimum Coverage by Package Area:**

| Area | Line Coverage | Branch Coverage |
|------|---------------|-----------------|
| `shell/` | 85% | 80% |
| `panels/` | 80% | 75% |
| `components/` | 85% | 80% |
| `modules/` | 80% | 75% |
| `services/` | 90% | 85% |
| `models/` | 95% | 90% |
| `config/` | 85% | 80% |
| `views/` | 75% | 70% |

**CI Requirements:**

- All tests must pass before merge
- Coverage must not decrease
- Golden tests auto-update requires manual approval
- Performance tests must not regress > 10%

---

## 9. Cross-Reference Matrix

### 9.1 Concept Section to Spec Section

| Concept Section | Spec Sections |
|-----------------|---------------|
| §1 Overview | §1, §7.1 |
| §2 Window Structure | §2.2, §2.3, §6.1 |
| §3 Accordeon Layout | §2.1, §2.2, §2.5, §5.1 |
| §4 Components | §2.4, §3.3, §7.2, §8.3 |
| §5 Drag and Drop | §2.6, §8.3 |
| §6 Application Model | §6.1, §7.1 |
| §7 Menu System | §5.1, §8.4 |
| §8 Module System | §3.4, §7.1, §8.7 |
| §9 Configuration System | §6.4, §7.4, §8.7 |
| §10 System State API | §7.3, §8.2, §8.7 |
| §11 Keyboard Shortcuts | §5.1, §8.7 |
| §12 Auto-Save/Revisioning | §4.1, §6.5, §7.2, §8.4 |
| §13 Startup Dialog | §7.1, §8.5 |
| §14 Built-In Views | §4.2, §5.2, §8.5 |
| §15 Status Bar | §2.2, §5.2 |
| §16 Application Setup | §2.3, §6.4 |
| §17 Implementation Architecture | §8.1, §8.8 |
| §18 Implementation Phases | §8.7 |

### 9.2 Spec Section to Concept Section

| Spec Section | Concept Sections |
|--------------|------------------|
| §2 Widget Implementation | §2, §3, §4, §5, §15 |
| §3 Error Handling | §8, §10.4, §12 |
| §4 Performance | §14, §10.4 |
| §5 Accessibility | §4, §7, §11, §14 |
| §6 State Persistence | §2, §4, §9, §12 |
| §7 Event Ordering | §4, §8, §10, §12 |
| §8 Test Strategy | All sections |

### 9.3 API to Test Location Matrix

| API (Concept §10.4) | Test File |
|---------------------|-----------|
| `ForgeFileSystem` | `test/services/file_system_test.dart` |
| `ForgeLayoutController` | `test/services/layout_controller_test.dart` |
| `ForgeOutputChannelManager` | `test/services/output_channel_test.dart` |
| `ForgeDiagnosticManager` | `test/services/diagnostic_manager_test.dart` |
| `ForgeUndoManager` | `test/services/undo_manager_test.dart` |
| `ForgeShortcutManager` | `test/services/shortcut_manager_test.dart` |
| `ForgeModuleRegistry` | `test/modules/module_registry_test.dart` |
| `ForgeConfigManager` | `test/services/config_manager_test.dart` |
| `ForgeStatusBarController` | `test/services/status_bar_test.dart` |
| `ForgeNotificationManager` | `test/services/notification_manager_test.dart` |
| `ForgeProgressManager` | `test/services/progress_manager_test.dart` |
| `ForgeDialogManager` | `test/services/dialog_manager_test.dart` |
| `ForgeTerminalManager` | `test/services/terminal_manager_test.dart` |
| `ForgeClipboard` | `test/services/clipboard_test.dart` |
| `ForgeEnvironment` | `test/services/environment_test.dart` |
| `ForgeModuleStorage` | `test/services/module_storage_test.dart` |
| `ForgeSecretStorage` | `test/services/secret_storage_test.dart` |
| `ForgeFileDecorationManager` | `test/services/file_decoration_test.dart` |
| `ForgeVirtualDocumentManager` | `test/services/virtual_document_test.dart` |
| `ForgeOutlineManager` | `test/services/outline_manager_test.dart` |
| `ForgeSearchManager` | `test/services/search_manager_test.dart` |
| `ForgeSystemState` | `test/services/system_state_test.dart` |

---

## Appendix A: Constants Reference

```dart
// lib/src/constants/forge_constants.dart

/// All shell constants in one file for easy reference.
library forge_constants;

export 'forge_animations.dart';
export 'forge_dimensions.dart';
export 'forge_durations.dart';
export 'forge_keys.dart';

// forge_durations.dart
class ForgeDurations {
  static const Duration autoSaveDefault = Duration(seconds: 1);
  static const Duration searchDebounce = Duration(milliseconds: 200);
  static const Duration configDebounce = Duration(milliseconds: 100);
  static const Duration layoutPersistDebounce = Duration(milliseconds: 500);
  static const Duration fileWatcherBatch = Duration(milliseconds: 50);
  static const Duration retryInitialDelay = Duration(milliseconds: 500);
  static const Duration shortcutTriggerTimeout = Duration(seconds: 2);
  static const Duration notificationDuration = Duration(seconds: 4);
  static const Duration tooltipDelay = Duration(milliseconds: 500);
}

// forge_keys.dart
class ForgeStorageKeys {
  static const String layoutState = 'layout';
  static const String configVersion = 'config_version';
  static const String recentWorkspaces = 'recent_workspaces';
  static const String lastOpenedFiles = 'last_opened_files';
}
```

---

## Appendix B: Error Codes

| Code | Category | Message Template |
|------|----------|------------------|
| `FS001` | File System | File not found: {uri} |
| `FS002` | File System | Permission denied: {uri} |
| `FS003` | File System | Disk full |
| `FS004` | File System | File modified externally: {uri} |
| `FS005` | File System | Too many file watchers |
| `MD001` | Module | Module failed to activate: {module} |
| `MD002` | Module | Module dependency not found: {dep} |
| `MD003` | Module | Module threw exception: {module} |
| `CF001` | Config | Configuration parse error |
| `CF002` | Config | Invalid configuration value: {key} |
| `CF003` | Config | Configuration schema mismatch |
| `ED001` | Editor | Editor failed to load: {uri} |
| `ED002` | Editor | No editor available for: {uri} |
| `ED003` | Editor | Editor crashed: {editor} |
| `SH001` | Shortcut | Shortcut conflict: {shortcut} |
| `SH002` | Shortcut | Invalid shortcut: {shortcut} |
| `UI001` | UI | Layout restoration failed |
| `UI002` | UI | Drag operation failed |

---

## 10. Test Modules Specification

This section defines the test modules used to validate the shell implementation and integrate existing editor components. The goal is to exercise all shell services comprehensively while exposing any weaknesses in current editor implementations.

### 10.1 Test Module Architecture

```
tom_forge_ui/
  lib/
    src/
      testing/
        test_module.dart              # ForgeTestModule — test harness module
        test_text_editor.dart         # Minimal ForgeTextEditor implementation
        test_visual_editor.dart       # Minimal ForgeVisualEditor implementation
        mock_services.dart            # In-memory mock implementations
        test_workspace.dart           # Test file structure generator
  test/
    shell_test_harness.dart           # Complete shell test setup
    integration/
      editor_integration_test.dart    # Editor adapter validation
```

### 10.2 ForgeTestModule

A minimal module providing test components for shell validation:

```dart
class ForgeTestModule extends ForgeModule {
  @override
  String get id => 'test';
  
  @override
  String get displayName => 'Test Module';
  
  // Test editors
  late final testTextEditor = ForgeTestTextEditor(this);
  late final testVisualEditor = ForgeTestVisualEditor(this);
  
  @override
  List<ForgeEditor> get editors => [testTextEditor, testVisualEditor];
  
  @override
  List<ForgeView> get views => [testInfoView];
  
  @override
  List<ForgeAction> get actions => [
    ForgeAction(
      id: 'test.insertText',
      label: 'Insert Test Text',
      execute: (_) async {
        final editor = api.systemState.activeEditor;
        if (editor is ForgeTextEditor) {
          editor.insertText('[TEST]');
        }
      },
    ),
    ForgeAction(
      id: 'test.triggerError',
      label: 'Trigger Test Error',
      execute: (_) async {
        api.notifications.showError('Test error triggered');
      },
    ),
    ForgeAction(
      id: 'test.createDiagnostics',
      label: 'Create Test Diagnostics',
      execute: (_) async {
        _testDiagnostics.clear();
        _testDiagnostics.add(ForgeDiagnostic(
          uri: api.systemState.activeEditor?.uri ?? Uri.parse('test://file'),
          range: TextRange(
            start: TextPosition(line: 0, column: 0),
            end: TextPosition(line: 0, column: 10),
          ),
          message: 'Test diagnostic',
          severity: ForgeSeverity.warning,
          source: 'TestModule',
        ));
      },
    ),
  ];
  
  late final ForgeDiagnosticCollection _testDiagnostics;
  
  @override
  Future<void> activate(ForgeShellApi api) async {
    await super.activate(api);
    _testDiagnostics = api.diagnostics.createCollection('test');
  }
  
  @override
  Future<void> deactivate() async {
    _testDiagnostics.dispose();
    await super.deactivate();
  }
}
```

### 10.3 ForgeTestTextEditor

Minimal text editor implementation for testing `ForgeTextEditor` contract:

```dart
class ForgeTestTextEditor extends ForgeTextEditor {
  final ForgeModule _module;
  final _document = ForgeTestDocument();
  final _cursorPosition = ValueNotifier(TextPosition(line: 0, column: 0));
  final _selection = ValueNotifier<TextRange?>(null);
  final _selections = ValueNotifier<List<TextRange>>([]);
  final _visibleRange = ValueNotifier(TextRange(
    start: TextPosition(line: 0, column: 0),
    end: TextPosition(line: 20, column: 0),
  ));
  final _isDirty = ValueNotifier(false);
  final _decorations = <String, List<ForgeDecorationRange>>{};
  var _options = ForgeTextEditorOptions();
  
  ForgeTestTextEditor(this._module);
  
  @override
  ForgeModule get module => _module;
  
  @override
  Uri get uri => _document.uri;
  
  @override
  FileHandlingResult canHandle(Uri uri) {
    // Accept .test files
    return uri.path.endsWith('.test') 
        ? FileHandlingResult.accept 
        : FileHandlingResult.reject;
  }
  
  @override
  ForgeDocument get document => _document;
  
  @override
  ValueListenable<TextPosition> get cursorPosition => _cursorPosition;
  
  @override
  ValueListenable<TextRange?> get selection => _selection;
  
  @override
  ValueListenable<List<TextRange>> get selections => _selections;
  
  @override
  void setSelections(List<TextRange> ranges) {
    _selections.value = ranges;
    if (ranges.isNotEmpty) {
      _selection.value = ranges.first;
    }
  }
  
  @override
  String get selectedText {
    final sel = _selection.value;
    if (sel == null || sel.isEmpty) return '';
    return _document.textInRange(sel);
  }
  
  @override
  bool get hasSelection => _selection.value != null && !_selection.value!.isEmpty;
  
  @override
  ValueListenable<TextRange> get visibleRange => _visibleRange;
  
  @override
  ValueListenable<bool> get isDirty => _isDirty;
  
  @override
  void insertText(String text) {
    final pos = _cursorPosition.value;
    _document.insert(pos, text);
    _isDirty.value = true;
  }
  
  @override
  void replaceRange(TextRange range, String replacement) {
    _document.replace(range, replacement);
    _isDirty.value = true;
  }
  
  @override
  void deleteRange(TextRange range) {
    _document.replace(range, '');
    _isDirty.value = true;
  }
  
  @override
  void setCursorPosition(TextPosition position) {
    _cursorPosition.value = position;
  }
  
  @override
  void setSelection(TextRange range) {
    _selection.value = range;
    _selections.value = [range];
  }
  
  @override
  void selectAll() {
    setSelection(TextRange(
      start: TextPosition(line: 0, column: 0),
      end: TextPosition(
        line: _document.lineCount - 1,
        column: _document.lineAt(_document.lineCount - 1).length,
      ),
    ));
  }
  
  @override
  void revealPosition(TextPosition position) {
    // Test implementation — just update visible range
    _visibleRange.value = TextRange(
      start: TextPosition(line: max(0, position.line - 10), column: 0),
      end: TextPosition(line: position.line + 10, column: 0),
    );
  }
  
  @override
  void revealRange(TextRange range) {
    revealPosition(range.start);
  }
  
  @override
  List<TextRange> findAll(Pattern pattern) {
    return _document.findAll(pattern);
  }
  
  @override
  int replaceAll(Pattern pattern, String replacement) {
    return _document.replaceAll(pattern, replacement);
  }
  
  @override
  ForgeTextEditorOptions get options => _options;
  
  @override
  void updateOptions(ForgeTextEditorOptions options) {
    _options = options;
  }
  
  @override
  void setDecorations(ForgeDecorationType type, List<ForgeDecorationRange> ranges) {
    _decorations[type.key] = ranges;
  }
  
  @override
  void clearDecorations(ForgeDecorationType type) {
    _decorations.remove(type.key);
  }
  
  @override
  Widget build(BuildContext context) {
    // Minimal test UI
    return Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          Text('Test Editor: ${uri.path}'),
          Expanded(child: Text(_document.text)),
        ],
      ),
    );
  }
  
  @override
  String get title => uri.pathSegments.last;
  
  @override
  IconData get icon => Icons.text_fields;
}
```

### 10.4 ForgeTestDocument

Minimal `ForgeDocument` implementation:

```dart
class ForgeTestDocument implements ForgeDocument {
  final Uri _uri;
  final List<String> _lines = [''];
  final _isDirty = ValueNotifier(false);
  final _changeController = StreamController<DocumentChangeEvent>.broadcast();
  int _version = 0;
  
  ForgeTestDocument({Uri? uri}) : _uri = uri ?? Uri.parse('test://untitled');
  
  @override
  Uri get uri => _uri;
  
  @override
  String get text => _lines.join('\n');
  
  @override
  int get lineCount => _lines.length;
  
  @override
  String lineAt(int line) => _lines[line];
  
  @override
  String textInRange(TextRange range) {
    if (range.start.line == range.end.line) {
      return _lines[range.start.line].substring(range.start.column, range.end.column);
    }
    final buffer = StringBuffer();
    buffer.write(_lines[range.start.line].substring(range.start.column));
    for (var i = range.start.line + 1; i < range.end.line; i++) {
      buffer.write('\n');
      buffer.write(_lines[i]);
    }
    buffer.write('\n');
    buffer.write(_lines[range.end.line].substring(0, range.end.column));
    return buffer.toString();
  }
  
  @override
  String get languageId => 'plaintext';
  
  @override
  Encoding get encoding => utf8;
  
  @override
  int get version => _version;
  
  @override
  bool get isUntitled => _uri.scheme == 'test';
  
  @override
  ValueListenable<bool> get isDirty => _isDirty;
  
  @override
  Stream<DocumentChangeEvent> get onDidChange => _changeController.stream;
  
  void insert(TextPosition pos, String text) {
    final line = _lines[pos.line];
    _lines[pos.line] = line.substring(0, pos.column) + text + line.substring(pos.column);
    _version++;
    _isDirty.value = true;
    _fireChange([TextRange(start: pos, end: pos)]);
  }
  
  void replace(TextRange range, String text) {
    // Simplified single-line replace for testing
    if (range.start.line == range.end.line) {
      final line = _lines[range.start.line];
      _lines[range.start.line] = 
        line.substring(0, range.start.column) + text + line.substring(range.end.column);
    }
    _version++;
    _isDirty.value = true;
    _fireChange([range]);
  }
  
  List<TextRange> findAll(Pattern pattern) {
    final results = <TextRange>[];
    for (var lineNum = 0; lineNum < _lines.length; lineNum++) {
      for (final match in pattern.allMatches(_lines[lineNum])) {
        results.add(TextRange(
          start: TextPosition(line: lineNum, column: match.start),
          end: TextPosition(line: lineNum, column: match.end),
        ));
      }
    }
    return results;
  }
  
  int replaceAll(Pattern pattern, String replacement) {
    var count = 0;
    for (var i = 0; i < _lines.length; i++) {
      final newLine = _lines[i].replaceAll(pattern, replacement);
      if (newLine != _lines[i]) {
        count += pattern.allMatches(_lines[i]).length;
        _lines[i] = newLine;
      }
    }
    if (count > 0) {
      _version++;
      _isDirty.value = true;
    }
    return count;
  }
  
  void _fireChange(List<TextRange> changes) {
    _changeController.add(DocumentChangeEvent(changes: changes, document: this));
  }
}
```

### 10.5 Test Workspace Generator

Generates a test file structure for integration tests:

```dart
class ForgeTestWorkspace {
  final Directory root;
  
  ForgeTestWorkspace(this.root);
  
  static Future<ForgeTestWorkspace> create() async {
    final dir = await Directory.systemTemp.createTemp('forge_test_');
    final workspace = ForgeTestWorkspace(dir);
    await workspace._populate();
    return workspace;
  }
  
  Future<void> _populate() async {
    // Test files
    await _createFile('readme.md', '# Test Workspace\n\nThis is a test.');
    await _createFile('config.yaml', 'name: test\nversion: 1');
    await _createFile('main.dart', 'void main() {\n  print("Hello");\n}');
    await _createFile('data.json', '{"key": "value"}');
    await _createFile('sample.test', 'Test file content');
    
    // Nested structure
    await _createFile('src/lib.dart', 'library test;');
    await _createFile('src/utils.dart', '// Utils');
    await _createFile('docs/guide.md', '# Guide');
    
    // Schema files
    await _createFile('schema/form.yaml', '# schema: form-v2\nfields: []');
    await _createFile('schema/workflow.yaml', '# schema: workflow\nsteps: []');
  }
  
  Future<void> _createFile(String path, String content) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }
  
  Uri get rootUri => root.uri;
  
  Future<void> dispose() async {
    await root.delete(recursive: true);
  }
}
```

---

## 11. Editor Integration Requirements

This section specifies the modifications required to integrate existing Tom Forge editor components (`tom_md_editor`, `tom_dart_editor`, `tom_yaml_editor`) with the Panel Shell's `ForgeTextEditor` and `ForgeSchemaEditor` contracts.

**Critical:** These modifications MUST be completed before the editors can be used within the shell. Each gap is classified by priority and implementation complexity.

### 11.1 Integration Gap Summary

| Editor | Target Contract | Gaps | Priority | Effort |
|--------|-----------------|------|----------|--------|
| `tom_md_editor` | `ForgeTextEditor` | 8 gaps | High | Medium |
| `tom_dart_editor` | `ForgeTextEditor` | 9 gaps | High | Medium |
| `tom_yaml_editor` | `ForgeSchemaEditor` | 6 gaps | Medium | Low |

### 11.2 tom_md_editor Adaptation

**Current:** `MdEditor` widget with `MdEditorController`, standalone usage pattern.

**Target:** `ForgeMdEditor extends ForgeTextEditor` with shell integration.

#### Gap Analysis

| # | Gap | Current State | Required Change | Effort |
|---|-----|---------------|-----------------|--------|
| 1 | **URI association** | Uses `markdown: String` or `MdDocumentProvider` | Add `uri` property, associate with file path | Low |
| 2 | **canHandle/canHandleContent** | Not implemented | Accept `.md`, `.markdown`; inspect for DocSpec schema | Low |
| 3 | **ForgeDocument interface** | Has `MdDocument` (section-based) | Create `ForgeMdDocument` adapter wrapping `MdDocument` | Medium |
| 4 | **ValueListenable pattern** | Uses callbacks (`onChanged`, `onSectionSelected`) | Expose `ValueNotifier<T>` for cursor, selection | Medium |
| 5 | **Multi-selection** | Not supported | Add `selections` property (may be single-selection only) | Low |
| 6 | **visibleRange** | Not exposed | Expose scroll viewport as `ValueListenable<TextRange>` | Medium |
| 7 | **Decorations API** | Has `TextMarker` internally | Adapt to `setDecorations(type, ranges)` | Medium |
| 8 | **ForgeTextEditorOptions** | Uses `MdEditorSettings` | Map to/from `ForgeTextEditorOptions` | Low |

#### Adapter Implementation

```dart
/// Shell adapter for MdEditor, implementing ForgeTextEditor.
class ForgeMdEditor extends ForgeTextEditor {
  final MdEditorController _controller;
  final ForgeMdDocument _document;
  final ValueNotifier<TextPosition> _cursorPosition;
  final ValueNotifier<TextRange?> _selection;
  final ValueNotifier<List<TextRange>> _selections;
  final ValueNotifier<TextRange> _visibleRange;
  
  ForgeMdEditor({
    required ForgeModule module,
    required Uri uri,
    String? initialContent,
  }) : _controller = MdEditorController(initialMarkdown: initialContent),
       _document = ForgeMdDocument(uri),
       _cursorPosition = ValueNotifier(TextPosition(line: 0, column: 0)),
       _selection = ValueNotifier(null),
       _selections = ValueNotifier([]),
       _visibleRange = ValueNotifier(/* default */),
       super(module);
  
  @override
  Uri get uri => _document.uri;
  
  @override
  FileHandlingResult canHandle(Uri uri) {
    final ext = uri.pathSegments.last.split('.').last.toLowerCase();
    return ['md', 'markdown'].contains(ext) 
        ? FileHandlingResult.accept 
        : FileHandlingResult.reject;
  }
  
  @override
  ForgeDocument get document => _document;
  
  // ... implement remaining ForgeTextEditor methods by delegating to _controller
  
  @override
  Widget build(BuildContext context) {
    return MdEditor(
      controller: _controller,
      onChanged: (md) => _document._updateContent(md),
      // Wire up cursor/selection change callbacks to ValueNotifiers
    );
  }
}

/// ForgeDocument adapter for MdDocument.
class ForgeMdDocument implements ForgeDocument {
  final Uri _uri;
  MdDocument _mdDocument;
  final _isDirty = ValueNotifier(false);
  final _changeController = StreamController<DocumentChangeEvent>.broadcast();
  int _version = 0;
  
  ForgeMdDocument(this._uri) : _mdDocument = MdDocument(sections: []);
  
  @override
  Uri get uri => _uri;
  
  @override
  String get text => _mdDocument.toMarkdown();
  
  @override
  int get lineCount => text.split('\n').length;
  
  @override
  String lineAt(int line) => text.split('\n')[line];
  
  @override
  String textInRange(TextRange range) {
    // Convert TextRange to string range and extract
    final lines = text.split('\n');
    // ... implementation
  }
  
  @override
  String get languageId => 'markdown';
  
  @override
  Encoding get encoding => utf8;
  
  @override
  int get version => _version;
  
  @override
  bool get isUntitled => false;
  
  @override
  ValueListenable<bool> get isDirty => _isDirty;
  
  @override
  Stream<DocumentChangeEvent> get onDidChange => _changeController.stream;
  
  void _updateContent(String markdown) {
    _mdDocument = MdParser().parse(markdown);
    _version++;
    _isDirty.value = true;
    _changeController.add(DocumentChangeEvent(
      changes: [/* full document change */],
      document: this,
    ));
  }
}
```

#### Required Changes to `tom_md_editor`

| File | Change | Description |
|------|--------|-------------|
| `md_raw_text_editor.dart` | Expose scroll position | Add callback/notifier for visible line range |
| `md_editor_controller.dart` | Expose cursor position | Add `ValueNotifier<int> cursorOffset` |
| `md_editor_controller.dart` | Selection tracking | Add `ValueNotifier<(int start, int end)?> selection` |
| `md_editor.dart` | Decoration support | Add `setDecorations` method that maps to `TextMarker` |

### 11.3 tom_dart_editor Adaptation

**Current:** `DartCodeEditor` widget with `DartCodeController`, standalone usage.

**Target:** `ForgeDartEditor extends ForgeTextEditor` with shell integration.

#### Gap Analysis

| # | Gap | Current State | Required Change | Effort |
|---|-----|---------------|-----------------|--------|
| 1 | **URI association** | Not present | Add `uri` property | Low |
| 2 | **canHandle/canHandleContent** | Not implemented | Accept `.dart` | Low |
| 3 | **ForgeDocument interface** | Has `DartCodeController.userCode` | Create `ForgeDartDocument` adapter | Medium |
| 4 | **ValueListenable for cursor** | Internal `_cursorPosition` | Expose as `ValueNotifier<TextPosition>` | Low |
| 5 | **ValueListenable for selection** | Internal `TextEditingController.selection` | Expose as `ValueNotifier<TextRange?>` | Low |
| 6 | **Multi-selection** | Not supported | Add minimal support (single selection okay) | Low |
| 7 | **visibleRange** | Not exposed | Expose from `ScrollController` | Medium |
| 8 | **Decorations API** | Has error highlighting, bracket matching | Generalize to `setDecorations(type, ranges)` | Medium |
| 9 | **ForgeTextEditorOptions** | Uses `DartEditorTheme` | Map to `ForgeTextEditorOptions` | Low |

#### Adapter Implementation

```dart
/// Shell adapter for DartCodeEditor, implementing ForgeTextEditor.
class ForgeDartEditor extends ForgeTextEditor {
  final DartCodeController _controller;
  final ForgeDartDocument _document;
  final ValueNotifier<TextPosition> _cursorPosition;
  final ValueNotifier<TextRange?> _selection;
  final ValueNotifier<List<TextRange>> _selections;
  final ValueNotifier<TextRange> _visibleRange;
  final Map<String, List<ForgeDecorationRange>> _decorations = {};
  
  ForgeDartEditor({
    required ForgeModule module,
    required Uri uri,
    String? initialContent,
  }) : _controller = DartCodeController(initialCode: initialContent ?? ''),
       _document = ForgeDartDocument(uri),
       _cursorPosition = ValueNotifier(TextPosition(line: 0, column: 0)),
       _selection = ValueNotifier(null),
       _selections = ValueNotifier([]),
       _visibleRange = ValueNotifier(/* default */),
       super(module);
  
  @override
  Uri get uri => _document.uri;
  
  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri.path.endsWith('.dart') 
        ? FileHandlingResult.accept 
        : FileHandlingResult.reject;
  }
  
  @override
  ForgeDocument get document => _document;
  
  @override
  void setDecorations(ForgeDecorationType type, List<ForgeDecorationRange> ranges) {
    _decorations[type.key] = ranges;
    // Map to DartCodeEditor's error/highlight system
    if (type.key == 'diagnostics') {
      // Convert ranges to CodeError format for internal rendering
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return DartCodeEditor(
      controller: _controller,
      errors: _mapDecorationsToErrors(),
      onChanged: (code) => _document._updateContent(code),
      onCursorChanged: (pos) => _cursorPosition.value = _toTextPosition(pos),
      onSelectionChanged: (sel) => _selection.value = _toTextRange(sel),
    );
  }
}
```

#### Required Changes to `tom_dart_editor`

| File | Change | Description |
|------|--------|-------------|
| `dart_code_editor.dart` | Add cursor callback | `onCursorChanged: (int offset)` |
| `dart_code_editor.dart` | Add selection callback | `onSelectionChanged: (int start, int end)` |
| `dart_code_editor.dart` | Expose scroll position | `onVisibleRangeChanged: (int startLine, int endLine)` |
| `dart_code_editor.dart` | Generalize decorations | Replace hardcoded error styling with decoration key system |

### 11.4 tom_yaml_editor Adaptation

**Current:** `YamlSchemaEditor` widget with `YamlEditorController`, tree-based editing.

**Target:** `ForgeYamlEditor extends ForgeSchemaEditor` (not ForgeTextEditor — this is a schema-aware editor).

#### Gap Analysis

| # | Gap | Current State | Required Change | Effort |
|---|-----|---------------|-----------------|--------|
| 1 | **URI association** | Not present | Add `uri` property | Low |
| 2 | **canHandleContent** | Not implemented | Check for schema comments (`# schema:`) | Low |
| 3 | **schemaLabel** | Has `YamlSchema` but no display label | Add `schemaLabel` from schema definition | Low |
| 4 | **Text mode toggle** | Has `_textMode` internal state | Expose toggle; in text mode, implement ForgeTextEditor-like API | Medium |
| 5 | **ForgeDocument adapter** | Has `YamlDocumentModel` | Create adapter for YAML text access | Low |
| 6 | **Dirty tracking** | Internal undo history tracks changes | Expose as `ValueListenable<bool>` | Low |

#### Adapter Implementation

```dart
/// Shell adapter for YamlSchemaEditor, implementing ForgeSchemaEditor.
class ForgeYamlEditor extends ForgeSchemaEditor {
  final YamlEditorController _controller;
  final Uri _uri;
  final ValueNotifier<bool> _isDirty;
  
  ForgeYamlEditor({
    required ForgeModule module,
    required Uri uri,
    String? initialContent,
    YamlSchema? schema,
  }) : _uri = uri,
       _controller = YamlEditorController(
         initialYaml: initialContent ?? '',
         schema: schema,
       ),
       _isDirty = ValueNotifier(false),
       super(module) {
    _controller.addListener(() {
      _isDirty.value = _controller.canUndo;
    });
  }
  
  @override
  Uri get uri => _uri;
  
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.inspect;
  
  @override
  FileHandlingResult canHandleContent(Uri uri, Uint8List bytes) {
    final content = utf8.decode(bytes);
    // Check for schema comment in first 10 lines
    final lines = content.split('\n').take(10);
    for (final line in lines) {
      if (line.startsWith('# schema:') || line.startsWith('#schema:')) {
        // Extract schema ID and check if we support it
        final schemaId = line.split(':').last.trim();
        if (_supportedSchemas.contains(schemaId)) {
          return FileHandlingResult.accept;
        }
      }
    }
    return FileHandlingResult.reject;
  }
  
  @override
  String get schemaLabel => _controller.schema?.title ?? 'YAML Schema';
  
  @override
  ValueListenable<bool> get isDirty => _isDirty;
  
  @override
  Widget build(BuildContext context) {
    return YamlSchemaEditor(
      controller: _controller,
      onChanged: (_) => _isDirty.value = true,
    );
  }
  
  @override
  String get title => uri.pathSegments.last;
  
  @override
  IconData get icon => Icons.data_object;
  
  static const _supportedSchemas = {'form-v2', 'workflow', 'config'};
}
```

#### Required Changes to `tom_yaml_editor`

| File | Change | Description |
|------|--------|-------------|
| `yaml_editor_controller.dart` | Dirty state notifier | Add `ValueListenable<bool> isDirty` computed from undo state |
| `yaml_schema_editor.dart` | URI property | Add `Uri? uri` parameter/property |
| `yaml_schema.dart` | Schema label | Ensure `YamlSchema.title` is populated |

### 11.5 tom_editors_shared Requirements

The shared library needs these additions to support shell integration:

| Addition | Description | Used By |
|----------|-------------|---------|
| `ForgeDocumentAdapter` | Base class for adapting editor documents to `ForgeDocument` | All editors |
| `ForgeValidationBridge` | Convert `ValidationError` to `ForgeDiagnostic` | YAML, Markdown editors |
| `PositionConverter` | Convert between offset-based and line/column positions | All text editors |

```dart
/// Base adapter class for bridging editor documents to ForgeDocument.
abstract class ForgeDocumentAdapter implements ForgeDocument {
  final Uri _uri;
  final ValueNotifier<bool> _isDirty = ValueNotifier(false);
  final StreamController<DocumentChangeEvent> _changes = 
      StreamController.broadcast();
  int _version = 0;
  
  ForgeDocumentAdapter(this._uri);
  
  @override
  Uri get uri => _uri;
  
  @override
  int get version => _version;
  
  @override
  ValueListenable<bool> get isDirty => _isDirty;
  
  @override
  Stream<DocumentChangeEvent> get onDidChange => _changes.stream;
  
  @protected
  void markDirty() {
    _version++;
    _isDirty.value = true;
  }
  
  @protected
  void markClean() {
    _isDirty.value = false;
  }
  
  @protected
  void fireChange(List<TextRange> changes) {
    _changes.add(DocumentChangeEvent(changes: changes, document: this));
  }
  
  void dispose() {
    _changes.close();
  }
}

/// Converts ValidationError to ForgeDiagnostic.
class ForgeValidationBridge {
  static List<ForgeDiagnostic> convert(
    List<ValidationError> errors,
    Uri uri,
    String Function(List<Object> path) pathToRange,
  ) {
    return errors.map((e) => ForgeDiagnostic(
      uri: uri,
      range: _parseRange(pathToRange(e.path)),
      message: e.message,
      severity: _mapSeverity(e.severity),
      source: 'Schema',
      code: e.code,
    )).toList();
  }
  
  static ForgeSeverity _mapSeverity(ValidationSeverity severity) {
    return switch (severity) {
      ValidationSeverity.error => ForgeSeverity.error,
      ValidationSeverity.warning => ForgeSeverity.warning,
      ValidationSeverity.info => ForgeSeverity.info,
    };
  }
}
```

### 11.6 Integration Test Scenarios

These scenarios validate that adapted editors work correctly within the shell:

| # | Scenario | Editors | Services Tested |
|---|----------|---------|-----------------|
| 1 | Open `.md` file | ForgeMdEditor | FileSystem, Layout, SystemState |
| 2 | Open `.dart` file | ForgeDartEditor | FileSystem, Layout, SystemState |
| 3 | Open schema YAML | ForgeYamlEditor | FileSystem, Layout, canHandleContent |
| 4 | Edit and save | All | FileSystem, UndoManager, Dirty tracking |
| 5 | Multi-editor split | All | Layout, Focus, Multi-render |
| 6 | Cross-editor diagnostics | Dart, YAML | DiagnosticManager, Problems view |
| 7 | Search across files | All | SearchManager, EditorList |
| 8 | Undo/redo | All | UndoManager, ComponentHistory |
| 9 | Copy/paste | All | Clipboard, insertText |
| 10 | Find in editor | Text editors | findAll, setDecorations (search highlight) |

```dart
// test/integration/editor_integration_test.dart

void main() {
  group('Editor Integration', () {
    late ForgeTestWorkspace workspace;
    late ForgeShellTestHarness harness;
    
    setUp(() async {
      workspace = await ForgeTestWorkspace.create();
      harness = ForgeShellTestHarness(workspaceUri: workspace.rootUri);
      await harness.start();
    });
    
    tearDown(() async {
      await harness.stop();
      await workspace.dispose();
    });
    
    test('opens markdown file with ForgeMdEditor', () async {
      final uri = workspace.rootUri.resolve('readme.md');
      
      final editor = await harness.openEditor(uri);
      
      expect(editor, isA<ForgeMdEditor>());
      expect(editor.uri, uri);
      expect(editor.document.languageId, 'markdown');
    });
    
    test('opens dart file with ForgeDartEditor', () async {
      final uri = workspace.rootUri.resolve('main.dart');
      
      final editor = await harness.openEditor(uri);
      
      expect(editor, isA<ForgeDartEditor>());
      expect(editor.document.text, contains('void main()'));
    });
    
    test('opens schema YAML with ForgeYamlEditor', () async {
      final uri = workspace.rootUri.resolve('schema/form.yaml');
      
      final editor = await harness.openEditor(uri);
      
      expect(editor, isA<ForgeYamlEditor>());
      expect((editor as ForgeYamlEditor).schemaLabel, 'form-v2');
    });
    
    test('edit triggers dirty state', () async {
      final uri = workspace.rootUri.resolve('main.dart');
      final editor = await harness.openEditor(uri) as ForgeDartEditor;
      
      expect(editor.isDirty.value, isFalse);
      
      editor.insertText('// comment\n');
      
      expect(editor.isDirty.value, isTrue);
    });
    
    test('save clears dirty state', () async {
      final uri = workspace.rootUri.resolve('main.dart');
      final editor = await harness.openEditor(uri) as ForgeDartEditor;
      
      editor.insertText('// comment\n');
      expect(editor.isDirty.value, isTrue);
      
      await harness.api.fileSystem.save(uri);
      
      expect(editor.isDirty.value, isFalse);
    });
    
    test('diagnostics appear in Problems view', () async {
      final uri = workspace.rootUri.resolve('main.dart');
      await harness.openEditor(uri);
      
      // Inject a test diagnostic
      harness.api.diagnostics.createCollection('test')
        .add(ForgeDiagnostic(
          uri: uri,
          range: TextRange(
            start: TextPosition(line: 0, column: 0),
            end: TextPosition(line: 0, column: 4),
          ),
          message: 'Test error',
          severity: ForgeSeverity.error,
          source: 'Test',
        ));
      
      await harness.pumpAndSettle();
      
      expect(harness.problemsView.diagnostics, hasLength(1));
    });
    
    test('two-phase file resolution prefers primary editor', () async {
      final uri = workspace.rootUri.resolve('config.yaml');
      
      // Both YamlSchemaEditor and a hypothetical generic YAML editor could handle .yaml
      // Schema editor should NOT claim it unless it has a schema comment
      
      final editor = await harness.openEditor(uri);
      
      // config.yaml has no schema comment, so generic editor should win
      expect(editor, isNot(isA<ForgeYamlEditor>()));
    });
    
    test('multi-editor split shares document state', () async {
      final uri = workspace.rootUri.resolve('readme.md');
      
      final editor1 = await harness.openEditor(uri);
      harness.splitMiddlePanel();
      final editor2 = await harness.openEditorInPanel(uri, 1);
      
      // Same document instance
      expect(editor1.document, same(editor2.document));
      
      // Edit in one, visible in other
      (editor1 as ForgeTextEditor).insertText('Added text');
      expect(editor2.document.text, contains('Added text'));
    });
  });
}
```

### 11.7 Implementation Checklist

**Phase 1: Adapter Layer (Week 1)**

- [ ] Create `ForgeDocumentAdapter` base class in `tom_editors_shared`
- [ ] Create `ForgeValidationBridge` in `tom_editors_shared`
- [ ] Create `PositionConverter` utility in `tom_editors_shared`
- [ ] Implement `ForgeMdEditor` adapter skeleton
- [ ] Implement `ForgeDartEditor` adapter skeleton
- [ ] Implement `ForgeYamlEditor` adapter skeleton

**Phase 2: Editor Modifications (Week 2)**

- [ ] `tom_md_editor`: Add cursor/selection/scroll notifiers
- [ ] `tom_md_editor`: Expose decoration API
- [ ] `tom_dart_editor`: Add cursor/selection callbacks
- [ ] `tom_dart_editor`: Expose scroll position
- [ ] `tom_dart_editor`: Generalize decoration system
- [ ] `tom_yaml_editor`: Add URI property
- [ ] `tom_yaml_editor`: Expose dirty state notifier

**Phase 3: Integration Tests (Week 3)**

- [ ] Set up test workspace generator
- [ ] Implement editor open tests
- [ ] Implement edit/save/dirty tests
- [ ] Implement diagnostics integration tests
- [ ] Implement multi-editor tests
- [ ] Implement two-phase resolution tests

**Phase 4: Shell Integration (Week 4)**

- [ ] Register adapted editors in `TomForgeShellModule`
- [ ] Wire up file resolution pipeline
- [ ] Test "Open with" dialog behavior
- [ ] Validate Problems view integration
- [ ] Validate Search view integration

---

## 12. Cross-Reference Updates

### 12.1 Concept to Spec Additions

| Concept Section | New Spec Sections |
|-----------------|-------------------|
| §4 Components | §10 Test Modules, §11 Editor Integration |
| §10.4 Service API | §10.2-10.5 Test implementations |
| §8 Module System | §10.2 ForgeTestModule |
| §17 Implementation | §11.7 Implementation Checklist |
| §18 Implementation Phases | §11.7 ties to Phase 3-4 |

### 12.2 Editor Package to Spec Mapping

| Package | Spec Sections |
|---------|---------------|
| `tom_md_editor` | §11.2 |
| `tom_dart_editor` | §11.3 |
| `tom_yaml_editor` | §11.4 |
| `tom_editors_shared` | §11.5 |
| `tom_forge_ui` (test) | §10 |

---

*End of Implementation Specification*
