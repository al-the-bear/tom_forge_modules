import '../actions/status_bar_item.dart';

/// Status bar control interface.
abstract class ForgeStatusBarController {
  List<StatusBarItem> get items;
}
