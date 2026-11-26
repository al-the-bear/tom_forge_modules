import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart' show ForgeText;

import 'forge_text_scope.dart';

/// Hands a [ForgeTextScope] to the widgets below it, so a widget that shows
/// a [ForgeText] it was given (a configuration tile's labels, a menu built
/// from a module's actions) reads it under the scope of the component that
/// owns it: `ForgeTextScopeWidget.of(context).resolve(text)`, in `build`.
class ForgeTextScopeWidget extends InheritedWidget {
  const ForgeTextScopeWidget({
    super.key,
    required this.textScope,
    required super.child,
  });

  /// The text scope of the subtree.
  final ForgeTextScope textScope;

  /// The text scope above [context], or [ForgeTextScope.root] when none is.
  static ForgeTextScope of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ForgeTextScopeWidget>()
          ?.textScope ??
      ForgeTextScope.root;

  /// [text] resolved under the text scope above [context].
  static String resolve(BuildContext context, ForgeText text) =>
      of(context).resolve(text);

  /// [builder] for a route opened from [context] (a dialog, a sheet): its
  /// content is built below the text scope of [context], which a new route
  /// would otherwise leave behind.
  static WidgetBuilder keep(BuildContext context, WidgetBuilder builder) {
    final textScope = of(context);
    return (_) => ForgeTextScopeWidget(
      textScope: textScope,
      child: Builder(builder: builder),
    );
  }

  @override
  bool updateShouldNotify(ForgeTextScopeWidget oldWidget) =>
      !identical(oldWidget.textScope, textScope);
}
