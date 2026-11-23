import '../actions/status_bar_item.dart';
import '../model/forge_application.dart';
import '../module/forge_module.dart';
import '../shell/forge_status_bar_controller.dart';
import 'default_module_registry.dart';

/// Default implementation of [ForgeStatusBarController].
///
/// Aggregates [StatusBarItem]s from all registered modules (a kit module's
/// through its extras, [forgeModuleStatusItems]) and from the
/// active application, sorted by priority (highest first).
class DefaultStatusBarController implements ForgeStatusBarController {
  final DefaultModuleRegistry _registry;
  final ForgeApplicationRegistry _applications;

  DefaultStatusBarController({
    required DefaultModuleRegistry registry,
    required ForgeApplicationRegistry applications,
  }) : _registry = registry,
       _applications = applications;

  @override
  List<StatusBarItem> get items {
    final allItems = <StatusBarItem>[];
    for (final module in _registry.allKitModules) {
      allItems.addAll(forgeModuleStatusItems(module));
    }
    allItems.addAll(
      _applications.active?.contributions.statusBarItems ?? const [],
    );
    allItems.sort((a, b) => b.priority.compareTo(a.priority));
    return allItems;
  }
}
