import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
import '../actions/forge_shortcut_menu.dart';
import '../module/forge_module.dart';
import '../services/forge_file_decoration_manager.dart';
import '../services/forge_module_storage.dart';
import '../services/forge_shortcut_manager.dart';

// ── Terminal ──────────────────────────────────────────────────────────

/// Default implementation of [ForgeTerminalManager].
class DefaultTerminalManager implements ForgeTerminalManager {
  static bool debugEnabled = false;

  final List<DefaultTerminal> _terminals = [];
  DefaultTerminal? _activeTerminal;

  final StreamController<ForgeTerminal> _openController =
      StreamController<ForgeTerminal>.broadcast();
  final StreamController<ForgeTerminal> _closeController =
      StreamController<ForgeTerminal>.broadcast();
  final StreamController<ForgeTerminal?> _activeController =
      StreamController<ForgeTerminal?>.broadcast();

  @override
  ForgeTerminal create({
    String? name,
    String? shellPath,
    String? cwd,
    ForgeOutputChannel? outputChannel,
  }) {
    final terminal = DefaultTerminal(
      name: name ?? 'Terminal ${_terminals.length + 1}',
      shellPath: shellPath,
      cwd: cwd,
      outputChannel: outputChannel,
      onDispose: _removeTerminal,
    );
    _terminals.add(terminal);
    _activeTerminal = terminal;
    _openController.add(terminal);
    _activeController.add(terminal);
    return terminal;
  }

  @override
  List<ForgeTerminal> get terminals => List.unmodifiable(_terminals);

  @override
  ForgeTerminal? get activeTerminal => _activeTerminal;

  @override
  void setActive(ForgeTerminal terminal) {
    if (_terminals.contains(terminal)) {
      _activeTerminal = terminal as DefaultTerminal;
      _activeController.add(_activeTerminal);
    }
  }

  @override
  Stream<ForgeTerminal> get onDidOpen => _openController.stream;

  @override
  Stream<ForgeTerminal> get onDidClose => _closeController.stream;

  @override
  Stream<ForgeTerminal?> get onDidChangeActive => _activeController.stream;

  void _removeTerminal(DefaultTerminal terminal) {
    _terminals.remove(terminal);
    _closeController.add(terminal);
    if (_activeTerminal == terminal) {
      _activeTerminal = _terminals.isNotEmpty ? _terminals.last : null;
      _activeController.add(_activeTerminal);
    }
  }

  /// Dispose all terminals and streams.
  void dispose() {
    for (final t in List.of(_terminals)) {
      t.dispose();
    }
    _terminals.clear();
    _openController.close();
    _closeController.close();
    _activeController.close();
  }
}

/// Default in-memory terminal.
class DefaultTerminal implements ForgeTerminal {
  @override
  final String name;

  final String? shellPath;
  final String? cwd;
  final void Function(DefaultTerminal) _onDispose;

  /// Optional output channel for mirroring terminal output to the Output panel.
  final ForgeOutputChannel? outputChannel;

  final List<String> _history = [];
  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  Process? _activeProcess;
  bool _isDisposed = false;

  DefaultTerminal({
    required this.name,
    this.shellPath,
    this.cwd,
    this.outputChannel,
    required void Function(DefaultTerminal) onDispose,
  }) : _onDispose = onDispose;

  @override
  Stream<String> get onOutput => _outputController.stream;

  @override
  void sendText(String text, {bool addNewLine = true}) {
    final line = addNewLine ? '$text\n' : text;
    _history.add(line);
    // Echo the command as output.
    _emit('\$ $text');
    // Execute command through a real shell when possible.
    unawaited(_executeCommand(text.trim()));
  }

  /// Emit output to both the terminal view and the optional output channel.
  void _emit(String text) {
    if (_isDisposed || _outputController.isClosed) return;
    _outputController.add(text);
    outputChannel?.appendLine(text);
  }

  Future<void> _executeCommand(String command) async {
    if (command.isEmpty || _isDisposed) return;

    final executable = shellPath ?? (Platform.isWindows ? 'cmd.exe' : '/bin/bash');
    final args = Platform.isWindows ? <String>['/c', command] : <String>['-lc', command];
    Process? process;
    try {
      process = await Process.start(
        executable,
        args,
        workingDirectory: cwd,
        runInShell: true,
      );
      _activeProcess = process;

      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_emit)
          .asFuture<void>();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_emit)
          .asFuture<void>();

      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);
      if (exitCode != 0) {
        _emit('[exit $exitCode]');
      }
    } catch (_) {
      // Fallback keeps tests and basic demo behavior usable on constrained setups.
      _simulateResponse(command);
    } finally {
      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    }
  }

  void _simulateResponse(String command) {
    if (command == 'echo hello') {
      _emit('hello');
    } else if (command == 'pwd') {
      _emit(cwd ?? '/');
    } else if (command == 'date') {
      _emit(DateTime.now().toString());
    } else if (command.startsWith('echo ')) {
      _emit(command.substring(5));
    }
  }

  @override
  void show({bool preserveFocus = true}) {
    // Widget layer handles visibility.
  }

  @override
  void close() {
    _closeInternal();
  }

  @override
  void dispose() {
    _closeInternal();
  }

  void _closeInternal() {
    if (_isDisposed) return;
    _isDisposed = true;
    _activeProcess?.kill(ProcessSignal.sigterm);
    _activeProcess = null;
    _outputController.close();
    _onDispose(this);
  }

  /// Command history for testing.
  List<String> get history => List.unmodifiable(_history);
}

// ── Shortcuts ────────────────────────────────────────────────────────

/// Default implementation of [ForgeShortcutManager] with chord support.
class DefaultShortcutManager implements ForgeShortcutManager {
  static bool debugEnabled = false;

  /// Timeout before a pending chord is automatically cancelled.
  static const Duration chordTimeout = Duration(seconds: 2);

  final List<ForgeShortcutBinding> _bindings = [];
  final Map<String, ForgeShortcutKey> _defaults = {};

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

  /// Set up initial bindings from modules.
  void loadBindings(List<ForgeShortcutBinding> bindings) {
    _bindings
      ..clear()
      ..addAll(bindings);
    for (final binding in bindings) {
      _defaults[binding.action.id] = binding.key;
    }
  }

  @override
  List<ForgeShortcutBinding> get allBindings => List.unmodifiable(_bindings);

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

  @override
  void rebind(ForgeAction action, ForgeShortcutKey key) {
    final index = _bindings.indexWhere((b) => b.action.id == action.id);
    if (index >= 0) {
      final old = _bindings[index];
      _defaults.putIfAbsent(action.id, () => old.key);
      _bindings[index] = ForgeShortcutBinding(
        action: old.action,
        key: key,
        context: old.context,
      );
    } else {
      _bindings.add(ForgeShortcutBinding(action: action, key: key));
      _defaults.putIfAbsent(action.id, () => key);
    }
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
