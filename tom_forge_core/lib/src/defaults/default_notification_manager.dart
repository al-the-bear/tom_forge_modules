import 'dart:async';

import 'package:tom_forge_core/tom_forge_core.dart';

/// Severity level for notification display.
enum NotificationSeverity { info, warning, error }

/// A notification item with message, severity, and optional actions.
class NotificationItem {
  final String message;
  final NotificationSeverity severity;
  final List<String> actions;
  final Completer<String?> _completer;
  final DateTime createdAt;

  NotificationItem({
    required this.message,
    required this.severity,
    this.actions = const [],
    Completer<String?>? completer,
  })  : _completer = completer ?? Completer<String?>(),
        createdAt = DateTime.now();

  /// Future that completes when the user responds or the notification
  /// is dismissed.
  Future<String?> get response => _completer.future;

  /// Dismiss this notification with an optional action.
  void dismiss([String? action]) {
    if (!_completer.isCompleted) {
      _completer.complete(action);
    }
  }
}

/// Default implementation of [ForgeNotificationManager].
///
/// Maintains a list of active notifications via [ForgeValueNotifier]
/// for UI rendering. Auto-dismisses after [autoDismissDuration].
class DefaultNotificationManager implements ForgeNotificationManager {
  static bool debugEnabled = false;

  /// Duration before auto-dismissal (default 4 seconds).
  final Duration autoDismissDuration;

  /// Maximum number of history items to keep.
  final int maxHistory;

  final ForgeValueNotifier<List<NotificationItem>> _notifications =
      ForgeValueNotifier([]);

  /// Persistent history of all notifications (most recent first).
  final ForgeValueNotifier<List<NotificationItem>> _history =
      ForgeValueNotifier([]);

  /// Whether the notification popup is currently visible.
  final ForgeValueNotifier<bool> popupVisible = ForgeValueNotifier(false);

  DefaultNotificationManager({
    this.autoDismissDuration = const Duration(seconds: 4),
    this.maxHistory = 200,
  });

  @override
  Future<String?> showInformation(String message,
      {List<String> actions = const []}) {
    return _show(message, NotificationSeverity.info, actions);
  }

  @override
  Future<String?> showWarning(String message,
      {List<String> actions = const []}) {
    return _show(message, NotificationSeverity.warning, actions);
  }

  @override
  Future<String?> showError(String message,
      {List<String> actions = const []}) {
    return _show(message, NotificationSeverity.error, actions);
  }

  /// Reactive list of active notifications for UI.
  ForgeValueListenable<List<NotificationItem>> get notifications =>
      _notifications;

  /// Reactive notification history list (most recent first).
  ForgeValueListenable<List<NotificationItem>> get history => _history;

  /// Remove a specific notification from the active list.
  void remove(NotificationItem item) {
    item.dismiss();
    _notifications.value =
        _notifications.value.where((n) => n != item).toList();
  }

  Future<String?> _show(
    String message,
    NotificationSeverity severity,
    List<String> actions,
  ) {
    final item = NotificationItem(
      message: message,
      severity: severity,
      actions: actions,
    );
    _notifications.value = [..._notifications.value, item];

    // Add to persistent history (most recent first).
    final historyList = [item, ..._history.value];
    _history.value = historyList.length > maxHistory
        ? historyList.sublist(0, maxHistory)
        : historyList;

    if (debugEnabled) {
      // ignore: avoid_print
      print('[DefaultNotificationManager] $severity: $message');
    }

    // Auto-dismiss if no actions.
    if (actions.isEmpty) {
      Future.delayed(autoDismissDuration, () => remove(item));
    }

    return item.response;
  }

  /// Clear all history items.
  void clearHistory() {
    _history.value = [];
  }

  /// Dispose resources.
  void dispose() {
    for (final n in _notifications.value) {
      n.dismiss();
    }
    _notifications.dispose();
    _history.dispose();
    popupVisible.dispose();
  }
}
