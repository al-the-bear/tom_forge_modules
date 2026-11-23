import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

// The default services a host that is not the panel shell uses too — the
// shortcut manager, the module storage, the file decorations — are the kit's
// (package:tom_forge_kit); the shell keeps the ones only it offers.

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
