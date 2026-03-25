import '../actions/status_bar_item.dart';
import '../shell/forge_status_bar_controller.dart';
import 'default_module_registry.dart';

/// Default implementation of [ForgeStatusBarController].
///
/// Aggregates [StatusBarItem]s from all registered modules,
/// sorted by priority (highest first).
class DefaultStatusBarController implements ForgeStatusBarController {
  final DefaultModuleRegistry _registry;

  DefaultStatusBarController({required DefaultModuleRegistry registry})
      : _registry = registry;

  @override
  List<StatusBarItem> get items {
    final allItems = <StatusBarItem>[];
    for (final module in _registry.allModules) {
      allItems.addAll(module.statusBarItems);
    }
    allItems.sort((a, b) => b.priority.compareTo(a.priority));
    return allItems;
  }
}
