import 'dart:async';

/// Policy for retrying failed operations with backoff or immediate retry.
class ForgeRetryPolicy {
  /// Execute [operation] with exponential backoff.
  ///
  /// Retries up to [maxAttempts] times. The delay between retries starts at
  /// [initialDelay] and is multiplied by [backoffMultiplier] after each
  /// attempt. If [shouldRetry] is provided, only errors for which it returns
  /// `true` are retried; all others rethrow immediately.
  static Future<T> withBackoff<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffMultiplier = 2.0,
    bool Function(Object error)? shouldRetry,
  }) async {
    var delay = initialDelay;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        if (shouldRetry != null && !shouldRetry(e)) rethrow;
        await Future<void>.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
        );
      }
    }
    // Unreachable – the loop always returns or rethrows.
    throw StateError('ForgeRetryPolicy.withBackoff: unreachable');
  }

  /// Execute [operation] with immediate retry on specific error types.
  ///
  /// Retries up to [maxAttempts] times without any delay. Only errors whose
  /// runtime type is in [retryableErrors] are retried.
  static Future<T> withImmediateRetry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 2,
    Set<Type> retryableErrors = const {TimeoutException},
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        if (!retryableErrors.contains(e.runtimeType)) rethrow;
      }
    }
    throw StateError('ForgeRetryPolicy.withImmediateRetry: unreachable');
  }
}
