/// Notification toast and dialog management.
abstract class ForgeNotificationManager {
  Future<String?> showInformation(
    String message, {
    List<String> actions = const [],
  });

  Future<String?> showWarning(
    String message, {
    List<String> actions = const [],
  });

  Future<String?> showError(
    String message, {
    List<String> actions = const [],
  });
}
