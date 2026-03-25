/// Pure-Dart reactive value primitives equivalent to Flutter's
/// `ValueListenable` and `ValueNotifier`.
///
/// These allow service implementations to expose reactive state
/// without depending on Flutter.
library;

/// Callback type for change listeners.
typedef ForgeVoidCallback = void Function();

/// A read-only interface that holds a value and notifies listeners.
abstract class ForgeValueListenable<T> {
  /// The current value.
  T get value;

  /// Register a callback that is called when [value] changes.
  void addListener(ForgeVoidCallback listener);

  /// Remove a previously registered listener.
  void removeListener(ForgeVoidCallback listener);
}

/// A mutable [ForgeValueListenable] that notifies listeners on changes.
class ForgeValueNotifier<T> implements ForgeValueListenable<T> {
  T _value;
  final List<ForgeVoidCallback> _listeners = [];

  ForgeValueNotifier(this._value);

  @override
  T get value => _value;

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    _notifyListeners();
  }

  @override
  void addListener(ForgeVoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(ForgeVoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  /// Release resources. After calling dispose, listeners are cleared.
  void dispose() {
    _listeners.clear();
  }
}
