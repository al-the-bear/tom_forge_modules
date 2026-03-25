import 'forge_component.dart';

/// A non-closable view component (explorer, output, terminal panel, etc.).
abstract class ForgeView extends ForgeComponent {
  @override
  bool get isEditor => false;
}
