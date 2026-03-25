import 'package:flutter/material.dart';

import '../defaults/default_notification_manager.dart';

/// Notification toast overlay positioned in the top-right.
///
/// Reads from [DefaultNotificationManager] and auto-dismisses
/// notifications after 4 seconds.
class ForgeNotificationOverlay extends StatefulWidget {
  final DefaultNotificationManager manager;

  const ForgeNotificationOverlay({super.key, required this.manager});

  @override
  State<ForgeNotificationOverlay> createState() =>
      _ForgeNotificationOverlayState();
}

class _ForgeNotificationOverlayState extends State<ForgeNotificationOverlay> {
  List<NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _items = widget.manager.notifications.value;
    widget.manager.notifications.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(ForgeNotificationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) {
      oldWidget.manager.notifications.removeListener(_onChanged);
      widget.manager.notifications.addListener(_onChanged);
      _items = widget.manager.notifications.value;
    }
  }

  @override
  void dispose() {
    widget.manager.notifications.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _items = widget.manager.notifications.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: 40,
      right: 12,
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final item in _items) _buildToast(context, item),
        ],
      ),
    );
  }

  Widget _buildToast(BuildContext context, NotificationItem item) {
    final theme = Theme.of(context);
    final iconData = switch (item.severity) {
      NotificationSeverity.info => Icons.info_outline,
      NotificationSeverity.warning => Icons.warning_amber_outlined,
      NotificationSeverity.error => Icons.error_outline,
    };
    final iconColor = switch (item.severity) {
      NotificationSeverity.info => theme.colorScheme.primary,
      NotificationSeverity.warning => Colors.orange,
      NotificationSeverity.error => theme.colorScheme.error,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.message,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                InkWell(
                  onTap: () => widget.manager.remove(item),
                  child: Icon(Icons.close, size: 14,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5)),
                ),
              ],
            ),
            if (item.actions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final action in item.actions)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: TextButton(
                        onPressed: () => item.dismiss(action),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(action),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
