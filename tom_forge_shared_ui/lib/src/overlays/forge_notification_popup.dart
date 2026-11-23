import 'package:flutter/material.dart';

import 'package:tom_forge_core/tom_forge_core.dart'
    show DefaultNotificationManager, NotificationItem, NotificationSeverity;
import 'package:tom_forge_kit/tom_forge_kit.dart' show ForgeKitApi;

import 'forge_notification_overlay.dart' show forgeNotificationManagerOf;

/// Popup panel anchored above the status bar, showing notification history.
///
/// Triggered by clicking the notification count in the status bar.
/// Shows recent notifications with severity icons and timestamps.
class ForgeNotificationPopup extends StatefulWidget {
  final DefaultNotificationManager manager;
  final VoidCallback onClose;

  const ForgeNotificationPopup({
    super.key,
    required this.manager,
    required this.onClose,
  });

  /// The history of the kit's notifications (`api.notifications`,
  /// [forgeNotificationManagerOf]).
  ForgeNotificationPopup.forApi({
    super.key,
    required ForgeKitApi api,
    required this.onClose,
  }) : manager = forgeNotificationManagerOf(api);

  @override
  State<ForgeNotificationPopup> createState() =>
      _ForgeNotificationPopupState();
}

class _ForgeNotificationPopupState extends State<ForgeNotificationPopup> {
  List<NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _items = widget.manager.history.value;
    widget.manager.history.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ForgeNotificationPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) {
      oldWidget.manager.history.removeListener(_onChanged);
      widget.manager.history.addListener(_onChanged);
      _items = widget.manager.history.value;
    }
  }

  @override
  void dispose() {
    widget.manager.history.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _items = widget.manager.history.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildPopup(context, _items);
  }

  Widget _buildPopup(BuildContext context, List<NotificationItem> items) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(6),
      color: theme.colorScheme.surfaceContainer,
      child: SizedBox(
        width: 380,
        height: items.isEmpty ? 80 : (items.length * 42.0).clamp(80, 320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, items.length),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No notifications',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          _buildItem(context, items[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text(
              '($count)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
          const Spacer(),
          if (count > 0)
            InkWell(
              onTap: () {
                widget.manager.clearHistory();
              },
              child: Tooltip(
                message: 'Clear all',
                child: Icon(
                  Icons.delete_sweep,
                  size: 14,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          const SizedBox(width: 8),
          InkWell(
            onTap: widget.onClose,
            child: Icon(
              Icons.close,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, NotificationItem item) {
    final theme = Theme.of(context);
    final iconData = switch (item.severity) {
      NotificationSeverity.info => Icons.info_outline,
      NotificationSeverity.warning => Icons.warning_amber,
      NotificationSeverity.error => Icons.error_outline,
    };
    final iconColor = switch (item.severity) {
      NotificationSeverity.info => theme.colorScheme.primary,
      NotificationSeverity.warning => Colors.orange,
      NotificationSeverity.error => theme.colorScheme.error,
    };

    final age = DateTime.now().difference(item.createdAt);
    final ageText = age.inMinutes < 1
        ? 'now'
        : age.inMinutes < 60
            ? '${age.inMinutes}m ago'
            : age.inHours < 24
                ? '${age.inHours}h ago'
                : '${age.inDays}d ago';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(iconData, size: 14, color: iconColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.message,
              style: theme.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ageText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
