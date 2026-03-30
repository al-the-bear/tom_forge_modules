import 'dart:async';

/// Batches and throttles a stream of events within a configurable window.
///
/// Events arriving within [window] are collected and delivered as a single
/// list after the window closes. This prevents UI and I/O thrashing from
/// rapid-fire events (e.g. file-system watchers).
class EventBatcher<T> {
  final Duration window;
  final void Function(List<T> batch)? onBatch;

  Timer? _timer;
  List<T> _pending = [];
  final _controller = StreamController<List<T>>.broadcast();

  EventBatcher({
    this.window = const Duration(milliseconds: 50),
    this.onBatch,
  });

  /// Stream of batched event lists.
  Stream<List<T>> get batched => _controller.stream;

  /// Add a single event to the current batch window.
  void add(T event) {
    _pending.add(event);
    _timer?.cancel();
    _timer = Timer(window, _flush);
  }

  /// Flush any pending events immediately.
  void flush() {
    _timer?.cancel();
    _flush();
  }

  void _flush() {
    if (_pending.isEmpty) return;
    final batch = _pending;
    _pending = [];
    _controller.add(batch);
    onBatch?.call(batch);
  }

  /// Whether there are pending un-flushed events.
  bool get hasPending => _pending.isNotEmpty;

  /// Number of pending events.
  int get pendingCount => _pending.length;

  /// Dispose resources.
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}
