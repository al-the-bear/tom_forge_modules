import 'package:tom_forge_core/tom_forge_core.dart'
    show ForgeNotificationManager, ForgeText;

import 'forge_text_scope.dart';

/// Notifications worded by text references: the message and the action
/// labels resolved under the owning component's [ForgeTextScope] when they
/// are shown, and the chosen action answered as its [ForgeText].
extension ForgeNotificationTexts on ForgeNotificationManager {
  /// [message] as an information, resolved under [scope], offering
  /// [actions]; answers the chosen action, or null.
  Future<ForgeText?> showInformationText(
    ForgeTextScope scope,
    ForgeText message, {
    List<ForgeText> actions = const [],
  }) => _show(showInformation, scope, message, actions);

  /// [message] as a warning ([showInformationText]).
  Future<ForgeText?> showWarningText(
    ForgeTextScope scope,
    ForgeText message, {
    List<ForgeText> actions = const [],
  }) => _show(showWarning, scope, message, actions);

  /// [message] as an error ([showInformationText]).
  Future<ForgeText?> showErrorText(
    ForgeTextScope scope,
    ForgeText message, {
    List<ForgeText> actions = const [],
  }) => _show(showError, scope, message, actions);

  Future<ForgeText?> _show(
    Future<String?> Function(String message, {List<String> actions}) show,
    ForgeTextScope scope,
    ForgeText message,
    List<ForgeText> actions,
  ) async {
    final labels = [for (final action in actions) scope.resolve(action)];
    final chosen = await show(scope.resolve(message), actions: labels);
    final index = chosen == null ? -1 : labels.indexOf(chosen);
    return index < 0 ? null : actions[index];
  }
}
