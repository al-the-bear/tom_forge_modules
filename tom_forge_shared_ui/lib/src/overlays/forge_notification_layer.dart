import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show DefaultNotificationManager;
import 'package:tom_forge_kit/tom_forge_kit.dart' show ForgeKitApi;

import '../forge_dimensions.dart';
import 'forge_notification_overlay.dart';
import 'forge_notification_popup.dart';

/// The kit's notifications over [child]: the toasts
/// ([ForgeNotificationOverlay]) and, while the manager's `popupVisible` is
/// set, the history ([ForgeNotificationPopup]) at the bottom right,
/// [popupBottom] above the bottom edge (by default above a status bar). Its
/// close button clears `popupVisible`.
class ForgeNotificationLayer extends StatefulWidget {
  const ForgeNotificationLayer({
    super.key,
    required this.manager,
    required this.child,
    this.popupBottom = ForgeDimensions.statusBarHeight + 4,
  });

  /// The layer of the kit's notifications (`api.notifications`,
  /// [forgeNotificationManagerOf]).
  ForgeNotificationLayer.forApi({
    super.key,
    required ForgeKitApi api,
    required this.child,
    this.popupBottom = ForgeDimensions.statusBarHeight + 4,
  }) : manager = forgeNotificationManagerOf(api);

  final DefaultNotificationManager manager;
  final Widget child;

  /// The history's distance from the bottom edge.
  final double popupBottom;

  @override
  State<ForgeNotificationLayer> createState() => _ForgeNotificationLayerState();
}

class _ForgeNotificationLayerState extends State<ForgeNotificationLayer> {
  late bool _popupVisible = widget.manager.popupVisible.value;

  @override
  void initState() {
    super.initState();
    widget.manager.popupVisible.addListener(_onPopupVisible);
  }

  @override
  void didUpdateWidget(ForgeNotificationLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.manager, widget.manager)) {
      oldWidget.manager.popupVisible.removeListener(_onPopupVisible);
      widget.manager.popupVisible.addListener(_onPopupVisible);
      _popupVisible = widget.manager.popupVisible.value;
    }
  }

  @override
  void dispose() {
    widget.manager.popupVisible.removeListener(_onPopupVisible);
    super.dispose();
  }

  void _onPopupVisible() {
    if (mounted) {
      setState(() => _popupVisible = widget.manager.popupVisible.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.manager;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        ForgeNotificationOverlay(manager: manager),
        if (_popupVisible)
          Positioned(
            bottom: widget.popupBottom,
            right: 12,
            child: ForgeNotificationPopup(
              manager: manager,
              onClose: () => manager.popupVisible.value = false,
            ),
          ),
      ],
    );
  }
}
