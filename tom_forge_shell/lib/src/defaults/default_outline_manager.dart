import 'dart:async';

import '../components/forge_editor.dart';
import '../services/forge_disposable.dart';
import '../services/forge_outline_manager.dart';

/// Default implementation of [ForgeOutlineManager].
///
/// Maintains a list of registered outline providers, dispatches outline
/// requests to matching providers, and aggregates provider change events
/// into a merged [onDidChange] stream.
class DefaultOutlineManager implements ForgeOutlineManager {
  static bool debugEnabled = false;

  final List<ForgeOutlineProvider> _providers = [];
  final Map<ForgeOutlineProvider, StreamSubscription<void>> _subscriptions = {};
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  /// Fires when any registered provider signals outline invalidation.
  Stream<void> get onDidChange => _changeController.stream;

  @override
  ForgeDisposable registerProvider(ForgeOutlineProvider provider) {
    _providers.add(provider);
    // Subscribe to provider's change stream and forward events.
    final sub = provider.onDidChange.listen((_) => _changeController.add(null));
    _subscriptions[provider] = sub;
    // Signal refresh when a new provider is added.
    _changeController.add(null);
    return _ProviderDisposable(() {
      _subscriptions[provider]?.cancel();
      _subscriptions.remove(provider);
      _providers.remove(provider);
      // Signal refresh when provider is removed.
      _changeController.add(null);
    });
  }

  /// Get outline items for the given editor from the first matching provider.
  Future<List<ForgeOutlineItem>> provideOutline(ForgeEditor editor) async {
    try {
      for (final provider in _providers) {
        if (provider.canProvide(editor)) {
          return await provider.provideOutline(editor);
        }
      }
      return [];
    } catch (e) {
      if (debugEnabled) {
        // ignore: avoid_print
        print('[DefaultOutlineManager] provideOutline error: $e');
      }
      return [];
    }
  }

  /// All registered providers.
  List<ForgeOutlineProvider> get providers => List.unmodifiable(_providers);

  /// Release resources.
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    _changeController.close();
  }
}

class _ProviderDisposable implements ForgeDisposable {
  final void Function() _onDispose;

  _ProviderDisposable(this._onDispose);

  @override
  void dispose() => _onDispose();
}
