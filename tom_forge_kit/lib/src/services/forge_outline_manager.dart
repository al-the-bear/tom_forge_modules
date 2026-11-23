import 'package:tom_forge_core/tom_forge_core.dart';

import '../components/forge_editor.dart';

/// Symbol kind for outline items.
enum ForgeSymbolKind {
  file,
  module,
  namespace,
  package,
  classKind,
  method,
  property,
  field,
  constructor,
  enumKind,
  interface,
  function,
  variable,
  constant,
  string,
  number,
  boolean,
  array,
  object,
  key,
  nullKind,
  enumMember,
  struct,
  event,
  operator,
  typeParameter,
  section,
}

/// An item in the outline tree.
class ForgeOutlineItem {
  final String label;
  final ForgeSymbolKind kind;
  final String? detail;
  final ForgeTextRange range;
  final ForgeTextRange selectionRange;
  final List<ForgeOutlineItem> children;

  const ForgeOutlineItem({
    required this.label,
    required this.kind,
    this.detail,
    required this.range,
    required this.selectionRange,
    this.children = const [],
  });
}

/// Provides outline data for an editor.
abstract class ForgeOutlineProvider {
  bool canProvide(ForgeEditor editor);
  Future<List<ForgeOutlineItem>> provideOutline(ForgeEditor editor);
  Stream<void> get onDidChange;
}

/// Registry for outline providers.
abstract class ForgeOutlineManager {
  ForgeDisposable registerProvider(ForgeOutlineProvider provider);
}
