import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../actions/forge_shortcut_menu.dart';
import '../module/forge_module.dart';
import '../services/forge_file_decoration_manager.dart';
import '../services/forge_module_storage.dart';
import '../services/forge_shortcut_manager.dart';

// Terminal classes extracted to default_terminal_manager.dart
export 'default_terminal_manager.dart';

// ── Shortcuts ────────────────────────────────────────────────────────

/// Default implementation of [ForgeShortcutManager] with chord support.
class DefaultShortcutManager implements ForgeShortcutManager {
  static bool debugEnabled = false;

  /// Timeout before a pending chord is automatically cancelled.
  static const Duration chordTimeout = Duration(seconds: 2);

  final List<ForgeShortcutBinding> _bindings = [];
  final Map<String, ForgeShortcutKey> _defaults = {};

  /// Infers context/scope from action ID prefix.
  ///
  /// Returns a human-readable scope label based on the action ID pattern:
  /// - `forge.edit.*` → "Standard" (standard editing actions)
  /// - `forge.*` → "Shell" (shell-level actions)
  /// - `dart.*` → "Dart Editor"
  /// - `yaml.*` → "YAML Editor"
  /// - `md.*` → "Markdown Editor"
  /// - Otherwise → "Global"
  static String _inferContext(String actionId) {
    if (actionId.startsWith('forge.edit.')) return 'Standard';
    if (actionId.startsWith('forge.')) return 'Shell';
    if (actionId.startsWith('dart.')) return 'Dart Editor';
    if (actionId.startsWith('yaml.')) return 'YAML Editor';
    if (actionId.startsWith('md.')) return 'Markdown Editor';
    return 'Global';
  }

  // Deferred overrides — applied when the action is first registered.
  final Map<String, ForgeShortcutKey> _deferredShortcutOverrides = {};
  final Map<String, ForgeChordKey> _deferredChordOverrides = {};

  // Actions the user explicitly deleted — suppress re-registration.
  final Set<String> _suppressedActions = {};

  // Chord state.
  ForgeShortcutKey? _pendingFirstKey;
  Timer? _chordTimer;
  final StreamController<ForgeChordEvent> _chordController =
      StreamController<ForgeChordEvent>.broadcast();

  // Menu state.
  final List<ForgeShortcutMenu> _menus = [];
  ForgeShortcutMenu? _activeMenu;
  final StreamController<ForgeShortcutMenuEvent> _menuController =
      StreamController<ForgeShortcutMenuEvent>.broadcast();

  final _bindingsChanged = _BindingsChanged();
  bool _bindingsChangePending = false;

  @override
  Listenable get onBindingsChanged => _bindingsChanged;

  /// Notifies [onBindingsChanged] once, after the current turn: modules
  /// register their actions in bursts, and editors rebuild their key maps on
  /// each notification.
  void _bindingsDidChange() {
    if (_bindingsChangePending) return;
    _bindingsChangePending = true;
    scheduleMicrotask(() {
      _bindingsChangePending = false;
      _bindingsChanged.fire();
    });
  }

  /// Set up initial bindings from modules.
  void loadBindings(List<ForgeShortcutBinding> bindings) {
    _bindings
      ..clear()
      ..addAll(bindings);
    for (final binding in bindings) {
      _defaults[binding.action.id] = binding.key;
    }
    _bindingsDidChange();
  }

  @override
  List<ForgeShortcutBinding> get allBindings {
    // Deduplicate by action.id — keep last-registered entry.
    final seen = <String, ForgeShortcutBinding>{};
    for (final binding in _bindings) {
      seen[binding.action.id] = binding;
    }
    return List.unmodifiable(seen.values);
  }

  @override
  List<ForgeShortcutBinding> get chordBindings =>
      _bindings.where((b) => b.isChord).toList(growable: false);

  @override
  bool get isChordPending => _pendingFirstKey != null;

  @override
  ForgeShortcutKey? get pendingChordFirstKey => _pendingFirstKey;

  @override
  List<ForgeShortcutBinding> get pendingChordCompletions {
    if (_pendingFirstKey == null) return const [];
    return _bindings
        .where((b) => b.isChord && b.chord!.firstKey == _pendingFirstKey)
        .toList(growable: false);
  }

  @override
  Stream<ForgeChordEvent> get onChordStateChanged => _chordController.stream;

  @override
  ForgeShortcutBinding? handleKeyForChord(ForgeShortcutKey key) {
    if (_pendingFirstKey != null) {
      // We're waiting for the second key.
      _chordTimer?.cancel();
      _chordTimer = null;

      // Look for a chord that matches first + second.
      for (final binding in _bindings) {
        if (binding.isChord &&
            binding.chord!.firstKey == _pendingFirstKey &&
            binding.chord!.secondKey == key) {
          _pendingFirstKey = null;
          _chordController.add(
            ForgeChordEvent(
              state: ForgeChordState.completed,
              executedBinding: binding,
            ),
          );
          return binding;
        }
      }

      // No match — cancel the chord.
      cancelChord();
      return null;
    }

    // Not in chord mode — check if this key starts a chord.
    final startsChord = _bindings.any(
      (b) => b.isChord && b.chord!.firstKey == key,
    );
    if (startsChord) {
      _pendingFirstKey = key;
      final completions = pendingChordCompletions;
      _chordController.add(
        ForgeChordEvent(
          state: ForgeChordState.entered,
          firstKey: key,
          completions: completions,
        ),
      );

      // Auto-cancel after timeout.
      _chordTimer?.cancel();
      _chordTimer = Timer(chordTimeout, cancelChord);
      return null;
    }

    return null;
  }

  @override
  void cancelChord() {
    if (_pendingFirstKey != null) {
      _pendingFirstKey = null;
      _chordTimer?.cancel();
      _chordTimer = null;
      _chordController.add(
        const ForgeChordEvent(state: ForgeChordState.cancelled),
      );
    }
  }

  /// Cancels the auto-close timer without cancelling the chord state.
  ///
  /// Used when the chord quick-open UI opens and takes over the chord
  /// lifecycle (user dismisses via ESC, click, or selection).
  void cancelChordTimer() {
    _chordTimer?.cancel();
    _chordTimer = null;
  }

  @override
  void rebind(ForgeAction action, ForgeShortcutKey key) {
    // Skip re-registration of actions the user explicitly deleted.
    if (_suppressedActions.contains(action.id)) return;

    // Check for deferred chord override first — takes priority.
    // Use bracket access (not .remove()) so the override persists for
    // re-application when modules re-register actions.
    final deferredChord = _deferredChordOverrides[action.id];
    if (deferredChord != null) {
      // Store the module's default key before redirecting to chord.
      _defaults.putIfAbsent(action.id, () => key);
      rebindChord(action, deferredChord);
      return;
    }

    // Check for deferred shortcut override. Use bracket access so the
    // override persists across module re-registrations.
    final effectiveKey = _deferredShortcutOverrides[action.id] ?? key;

    final index = _bindings.indexWhere((b) => b.action.id == action.id);
    if (index >= 0) {
      final old = _bindings[index];
      _defaults.putIfAbsent(action.id, () => old.key);
      _bindings[index] = ForgeShortcutBinding(
        action: old.action,
        key: effectiveKey,
        context: old.context,
      );
    } else {
      _bindings.add(ForgeShortcutBinding(
        action: action,
        key: effectiveKey,
        context: _inferContext(action.id),
      ));
      _defaults.putIfAbsent(action.id, () => key);
    }
    _bindingsDidChange();
  }

  @override
  void rebindChord(ForgeAction action, ForgeChordKey chord) {
    // Skip re-registration of actions the user explicitly deleted.
    if (_suppressedActions.contains(action.id)) return;

    final index = _bindings.indexWhere((b) => b.action.id == action.id);
    if (index >= 0) {
      final old = _bindings[index];
      _bindings[index] = ForgeShortcutBinding(
        action: old.action,
        key: chord.firstKey,
        chord: chord,
        context: old.context,
      );
    } else {
      _bindings.add(ForgeShortcutBinding(
        action: action,
        key: chord.firstKey,
        chord: chord,
        context: _inferContext(action.id),
      ));
    }
    _bindingsDidChange();
  }

  @override
  void removeBinding(String actionId) {
    _bindings.removeWhere((b) => b.action.id == actionId);
    _defaults.remove(actionId);
    _suppressedActions.add(actionId);
    _bindingsDidChange();
  }

  @override
  void unbind(String actionId) {
    final before = _bindings.length;
    _bindings.removeWhere((b) => b.action.id == actionId);
    if (_bindings.length != before) _bindingsDidChange();
  }

  /// Actions that should not be re-registered (user-deleted).
  Set<String> get suppressedActions => Set.unmodifiable(_suppressedActions);

  /// Mark an action as suppressed so future [rebind] calls are ignored.
  void suppressAction(String actionId) {
    _suppressedActions.add(actionId);
  }

  /// Remove suppression so the action can be re-registered.
  void unsuppressAction(String actionId) {
    _suppressedActions.remove(actionId);
  }

  /// Replace all suppressed action IDs (used when loading from preferences).
  void loadSuppressedActions(Set<String> actionIds) {
    _suppressedActions
      ..clear()
      ..addAll(actionIds);
  }

  @override
  void resetToDefault(ForgeAction action) {
    final defaultKey = _defaults[action.id];
    if (defaultKey != null) {
      rebind(action, defaultKey);
    }
  }

  @override
  ForgeShortcutBinding? conflictsWith(ForgeShortcutKey key) {
    for (final binding in _bindings) {
      if (binding.key == key) {
        return binding;
      }
    }
    return null;
  }

  @override
  ForgeShortcutBinding? getBinding(String actionId) {
    for (final binding in _bindings) {
      if (binding.action.id == actionId) {
        return binding;
      }
    }
    return null;
  }

  // ── Deferred overrides ──

  /// Clears all deferred overrides. Called before re-populating from
  /// current preferences so removed overrides don't linger.
  void clearDeferredOverrides() {
    _deferredShortcutOverrides.clear();
    _deferredChordOverrides.clear();
  }

  /// Stores a shortcut override to apply when the action is first registered
  /// via [rebind]. Used for editor-level actions that are not yet available
  /// at startup when preference overrides are restored.
  void setDeferredShortcutOverride(String actionId, ForgeShortcutKey key) {
    _deferredShortcutOverrides[actionId] = key;
  }

  /// Stores a chord override to apply when the action is first registered
  /// via [rebind]. Used for editor-level actions that are not yet available
  /// at startup when preference overrides are restored.
  void setDeferredChordOverride(String actionId, ForgeChordKey chord) {
    _deferredChordOverrides[actionId] = chord;
  }

  // ── Menu support ──

  @override
  List<ForgeShortcutMenu> get allMenus => List.unmodifiable(_menus);

  @override
  ForgeShortcutMenu? getMenuForTrigger(LogicalKeyboardKey triggerKey) {
    for (final menu in _menus) {
      if (menu.triggerKey == triggerKey) return menu;
    }
    return null;
  }

  @override
  void registerMenu(ForgeShortcutMenu menu) {
    // Replace existing menu with same trigger key.
    _menus.removeWhere((m) => m.triggerKey == menu.triggerKey);
    _menus.add(menu);
  }

  @override
  ForgeShortcutMenu? get activeMenu => _activeMenu;

  @override
  Stream<ForgeShortcutMenuEvent> get onMenuStateChanged =>
      _menuController.stream;

  @override
  bool openMenu(LogicalKeyboardKey triggerKey) {
    final menu = getMenuForTrigger(triggerKey);
    if (menu == null) return false;
    _activeMenu = menu;
    _menuController.add(
      ForgeShortcutMenuEvent(state: ForgeShortcutMenuState.opened, menu: menu),
    );
    return true;
  }

  @override
  ForgeShortcutMenuEntry? handleMenuKey(LogicalKeyboardKey key) {
    if (_activeMenu == null) return null;
    for (final entry in _activeMenu!.entries) {
      if (entry.key == key) {
        final selected = entry;
        _activeMenu = null;
        _menuController.add(
          ForgeShortcutMenuEvent(
            state: ForgeShortcutMenuState.selected,
            selectedEntry: selected,
          ),
        );
        return selected;
      }
    }
    // No match — close the menu.
    closeMenu();
    return null;
  }

  @override
  void closeMenu() {
    if (_activeMenu != null) {
      _activeMenu = null;
      _menuController.add(
        const ForgeShortcutMenuEvent(state: ForgeShortcutMenuState.closed),
      );
    }
  }

  /// Dispose resources.
  void dispose() {
    _chordTimer?.cancel();
    _chordController.close();
    _menuController.close();
  }
}

// ── Module Storage ───────────────────────────────────────────────────

/// Default implementation of [ForgeModuleStorage].
class DefaultModuleStorage implements ForgeModuleStorage {
  static bool debugEnabled = false;

  final Map<String, DefaultKeyValueStore> _stores = {};

  @override
  ForgeKeyValueStore forModule(ForgeModule module) {
    return _stores.putIfAbsent(
      module.displayName,
      () => DefaultKeyValueStore(),
    );
  }
}

/// Default in-memory implementation of [ForgeKeyValueStore].
class DefaultKeyValueStore implements ForgeKeyValueStore {
  final Map<String, Object?> _data = {};

  @override
  T? get<T>(String key) {
    final value = _data[key];
    return value is T ? value : null;
  }

  @override
  Future<void> set(String key, Object? value) async {
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }

  @override
  List<String> get keys => List.unmodifiable(_data.keys);
}

// ── Environment ──────────────────────────────────────────────────────

/// Default implementation of [ForgeEnvironment].
///
/// Tracks opened URIs for testability and optionally invokes a callback
/// for custom handling (e.g. logging to an output channel or launching
/// a browser).
class DefaultEnvironment implements ForgeEnvironment {
  @override
  final String appName;

  /// Callback invoked when [openExternal] is called.
  final Future<void> Function(Uri uri)? onOpenExternal;

  /// History of URIs opened via [openExternal], newest last.
  final List<Uri> openedUris = [];

  DefaultEnvironment({this.appName = 'Tom Forge', this.onOpenExternal});

  @override
  Future<void> openExternal(Uri uri) async {
    openedUris.add(uri);
    await onOpenExternal?.call(uri);
  }
}

// ── Secret Storage ───────────────────────────────────────────────────

/// Default in-memory implementation of [ForgeSecretStorage].
class DefaultSecretStorage implements ForgeSecretStorage {
  final Map<String, String> _secrets = {};
  final StreamController<SecretChangeEvent> _changeController =
      StreamController<SecretChangeEvent>.broadcast();

  @override
  Future<void> store(String key, String value) async {
    _secrets[key] = value;
    _changeController.add(SecretChangeEvent(key: key, deleted: false));
  }

  @override
  Future<String?> get(String key) async => _secrets[key];

  @override
  Future<void> delete(String key) async {
    _secrets.remove(key);
    _changeController.add(SecretChangeEvent(key: key, deleted: true));
  }

  @override
  Stream<SecretChangeEvent> get onDidChange => _changeController.stream;

  /// Dispose resources.
  void dispose() {
    _changeController.close();
  }
}

// ── File Decorations ─────────────────────────────────────────────────

/// Default implementation of [ForgeFileDecorationManager].
///
/// Aggregates decoration providers and exposes a merged [onDidChange] stream
/// that fires when any registered provider signals invalidation.
class DefaultFileDecorationManager implements ForgeFileDecorationManager {
  final List<ForgeFileDecorationProvider> _providers = [];
  final Map<ForgeFileDecorationProvider, StreamSubscription<Uri?>>
  _subscriptions = {};
  final StreamController<Uri?> _changeController =
      StreamController<Uri?>.broadcast();

  /// Fires when any provider signals decoration invalidation.
  ///
  /// The [Uri] indicates which resource changed, or `null` if all should
  /// be re-evaluated.
  Stream<Uri?> get onDidChange => _changeController.stream;

  @override
  ForgeDisposable registerProvider(ForgeFileDecorationProvider provider) {
    _providers.add(provider);
    // Subscribe to provider's change stream and forward events.
    final sub = provider.onDidChange.listen(_changeController.add);
    _subscriptions[provider] = sub;
    // Signal a full refresh when a new provider is added.
    _changeController.add(null);
    return _SimpleDisposable(() {
      _subscriptions[provider]?.cancel();
      _subscriptions.remove(provider);
      _providers.remove(provider);
      // Signal refresh when provider is removed.
      _changeController.add(null);
    });
  }

  /// Get all decorations for a URI.
  ForgeFileDecoration? getDecoration(Uri uri) {
    for (final provider in _providers) {
      final decoration = provider.provideDecoration(uri);
      if (decoration != null) return decoration;
    }
    return null;
  }

  /// All registered providers.
  List<ForgeFileDecorationProvider> get providers =>
      List.unmodifiable(_providers);

  /// Release resources.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _changeController.close();
  }
}

// ── Virtual Documents ────────────────────────────────────────────────

/// Default implementation of [ForgeVirtualDocumentManager].
///
/// Aggregates virtual document providers and exposes a merged [onDidChange]
/// stream that fires when any registered provider signals content invalidation.
class DefaultVirtualDocumentManager implements ForgeVirtualDocumentManager {
  final Map<String, ForgeVirtualDocumentProvider> _providers = {};
  final Map<String, StreamSubscription<Uri>> _subscriptions = {};
  final StreamController<Uri> _changeController =
      StreamController<Uri>.broadcast();

  /// Fires when any provider signals content invalidation.
  Stream<Uri> get onDidChange => _changeController.stream;

  /// All registered scheme names.
  Set<String> get registeredSchemes => _providers.keys.toSet();

  @override
  ForgeDisposable registerProvider(
    String scheme,
    ForgeVirtualDocumentProvider provider,
  ) {
    _providers[scheme] = provider;
    // Subscribe to provider's change stream and forward events.
    final sub = provider.onDidChange.listen(_changeController.add);
    _subscriptions[scheme] = sub;
    return _SimpleDisposable(() {
      _subscriptions[scheme]?.cancel();
      _subscriptions.remove(scheme);
      _providers.remove(scheme);
    });
  }

  /// Check if a scheme has a registered provider.
  bool hasProvider(String scheme) => _providers.containsKey(scheme);

  /// Resolve content for a virtual URI.
  Future<String?> resolveContent(Uri uri) async {
    final provider = _providers[uri.scheme];
    if (provider != null) {
      return await provider.provideContent(uri);
    }
    return null;
  }

  /// Release resources.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _changeController.close();
  }
}

// ── Shared ───────────────────────────────────────────────────────────

class _SimpleDisposable implements ForgeDisposable {
  final void Function() _onDispose;

  _SimpleDisposable(this._onDispose);

  @override
  void dispose() => _onDispose();
}

/// The notifier behind [DefaultShortcutManager.onBindingsChanged].
class _BindingsChanged extends ChangeNotifier {
  void fire() => notifyListeners();
}
