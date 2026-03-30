import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

import '../actions/forge_action.dart';
import '../actions/forge_shortcut_binding.dart';
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
    // For the in-memory stub, simulate simple responses.
    _simulateResponse(text.trim());
  }

  /// Emit output to both the terminal view and the optional output channel.
  void _emit(String text) {
    _outputController.add(text);
    outputChannel?.appendLine(text);
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
    _outputController.close();
    _onDispose(this);
  }

  @override
  void dispose() {
    _outputController.close();
    _onDispose(this);
  }

  /// Command history for testing.
  List<String> get history => List.unmodifiable(_history);
}

// ── Shortcuts ────────────────────────────────────────────────────────

/// Default implementation of [ForgeShortcutManager].
class DefaultShortcutManager implements ForgeShortcutManager {
  static bool debugEnabled = false;

  final List<ForgeShortcutBinding> _bindings = [];
  final Map<String, ForgeShortcutKey> _defaults = {};

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
  void rebind(ForgeAction action, ForgeShortcutKey key) {
    final index = _bindings.indexWhere((b) => b.action.id == action.id);
    if (index >= 0) {
      final old = _bindings[index];
      _bindings[index] = ForgeShortcutBinding(
        action: old.action,
        key: key,
        context: old.context,
      );
    } else {
      _bindings.add(ForgeShortcutBinding(action: action, key: key));
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
class DefaultFileDecorationManager implements ForgeFileDecorationManager {
  final List<ForgeFileDecorationProvider> _providers = [];

  @override
  ForgeDisposable registerProvider(ForgeFileDecorationProvider provider) {
    _providers.add(provider);
    return _SimpleDisposable(() => _providers.remove(provider));
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
}

// ── Virtual Documents ────────────────────────────────────────────────

/// Default implementation of [ForgeVirtualDocumentManager].
class DefaultVirtualDocumentManager implements ForgeVirtualDocumentManager {
  final Map<String, ForgeVirtualDocumentProvider> _providers = {};

  @override
  ForgeDisposable registerProvider(
    String scheme,
    ForgeVirtualDocumentProvider provider,
  ) {
    _providers[scheme] = provider;
    return _SimpleDisposable(() => _providers.remove(scheme));
  }

  /// Resolve content for a virtual URI.
  Future<String?> resolveContent(Uri uri) async {
    final provider = _providers[uri.scheme];
    if (provider != null) {
      return await provider.provideContent(uri);
    }
    return null;
  }
}

// ── Shared ───────────────────────────────────────────────────────────

class _SimpleDisposable implements ForgeDisposable {
  final void Function() _onDispose;

  _SimpleDisposable(this._onDispose);

  @override
  void dispose() => _onDispose();
}
