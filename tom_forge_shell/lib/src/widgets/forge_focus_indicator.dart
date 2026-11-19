import 'package:flutter/material.dart';

import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart';

/// A wrapper that draws a visible focus ring only when the child gains focus
/// via the keyboard (not mouse clicks).
///
/// Uses [FocusableActionDetector] to track hover and focus state,
/// and suppresses the focus ring when focus was gained by a mouse
/// click (`focus-visible` equivalent).
class ForgeFocusIndicator extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double ringWidth;

  const ForgeFocusIndicator({
    super.key,
    required this.child,
    this.borderRadius = 4,
    this.ringWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.basic,
      child: Builder(
        builder: (context) {
          final focusNode = Focus.of(context);
          final showFocus = focusNode.hasFocus &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional;
          final shellTheme = Theme.of(context).extension<ForgeShellTheme>();
          final ringColor =
              shellTheme?.focusRing ?? Theme.of(context).colorScheme.primary;

          return DecoratedBox(
            decoration: showFocus
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    border: Border.all(color: ringColor, width: ringWidth),
                  )
                : const BoxDecoration(),
            child: child,
          );
        },
      ),
    );
  }
}
