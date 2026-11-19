import 'package:flutter/foundation.dart';

/// A [ValueListenable] whose value never changes: for an item whose state is
/// known when it is built (an action enabled now, a status item always
/// shown). Listeners are accepted and never called.
class ForgeFixedListenable<T> implements ValueListenable<T> {
  const ForgeFixedListenable(this.value);

  @override
  final T value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
