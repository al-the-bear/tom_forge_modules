import 'dart:async';

import '../components/forge_editor.dart';
import '../services/forge_disposable.dart';
import '../services/forge_outline_manager.dart';

/// Default implementation of [ForgeOutlineManager].
///
/// Maintains a list of registered outline providers and dispatches
/// outline requests to matching providers.
class DefaultOutlineManager implements ForgeOutlineManager {
  static bool debugEnabled = false;

  final List<ForgeOutlineProvider> _providers = [];

  @override
  ForgeDisposable registerProvider(ForgeOutlineProvider provider) {
    _providers.add(provider);
    return _ProviderDisposable(() => _providers.remove(provider));
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
}

class _ProviderDisposable implements ForgeDisposable {
  final void Function() _onDispose;

  _ProviderDisposable(this._onDispose);

  @override
  void dispose() => _onDispose();
}
