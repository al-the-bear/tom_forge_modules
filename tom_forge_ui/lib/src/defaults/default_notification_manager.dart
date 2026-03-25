import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/forge_notification_manager.dart';

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
/// Maintains a list of active notifications via [ValueNotifier]
/// for UI rendering. Auto-dismisses after [autoDismissDuration].
class DefaultNotificationManager implements ForgeNotificationManager {
  static bool debugEnabled = false;

  /// Duration before auto-dismissal (default 4 seconds).
  final Duration autoDismissDuration;

  final ValueNotifier<List<NotificationItem>> _notifications =
      ValueNotifier([]);

  DefaultNotificationManager({
    this.autoDismissDuration = const Duration(seconds: 4),
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
  ValueListenable<List<NotificationItem>> get notifications =>
      _notifications;

  /// Remove a specific notification.
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

  /// Dispose resources.
  void dispose() {
    for (final n in _notifications.value) {
      n.dismiss();
    }
    _notifications.dispose();
  }
}
