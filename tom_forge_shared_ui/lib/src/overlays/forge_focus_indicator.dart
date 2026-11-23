import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show ForgeComponent, ForgeKitState;

import '../forge_shell_theme.dart';

/// A wrapper that draws a visible focus ring around [child].
///
/// By default the ring shows only when the child gains focus via the
/// keyboard (not mouse clicks): [FocusableActionDetector] tracks hover and
/// focus state, and the ring is suppressed when focus was gained by a mouse
/// click (`focus-visible` equivalent).
///
/// [ForgeFocusIndicator.kit] follows the kit's focus instead: the ring shows
/// while [state]'s focused component ([ForgeKitState.focusedComponent]) is
/// [component], whoever moved the focus there.
class ForgeFocusIndicator extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double ringWidth;

  /// The kit state whose focus is followed ([ForgeFocusIndicator.kit]).
  final ForgeKitState? state;

  /// The component the ring stands for ([ForgeFocusIndicator.kit]).
  final ForgeComponent? component;

  const ForgeFocusIndicator({
    super.key,
    required this.child,
    this.borderRadius = 4,
    this.ringWidth = 2,
  }) : state = null,
       component = null;

  /// The ring while [component] has the kit's focus in [state].
  const ForgeFocusIndicator.kit({
    super.key,
    required ForgeKitState this.state,
    required ForgeComponent this.component,
    required this.child,
    this.borderRadius = 4,
    this.ringWidth = 2,
  });

  /// The decoration with the ring when [show] is true.
  BoxDecoration _decoration(BuildContext context, bool show) {
    if (!show) return const BoxDecoration();
    final shellTheme = Theme.of(context).extension<ForgeShellTheme>();
    final ringColor =
        shellTheme?.focusRing ?? Theme.of(context).colorScheme.primary;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: ringColor, width: ringWidth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    if (state != null) {
      return _KitFocusRing(
        state: state,
        component: component!,
        builder: (context, focused) => DecoratedBox(
          decoration: _decoration(context, focused),
          child: child,
        ),
      );
    }
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.basic,
      child: Builder(
        builder: (context) {
          final focusNode = Focus.of(context);
          final showFocus =
              focusNode.hasFocus &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional;
          return DecoratedBox(
            decoration: _decoration(context, showFocus),
            child: child,
          );
        },
      ),
    );
  }
}

/// Rebuilds when the kit's focus moves.
class _KitFocusRing extends StatefulWidget {
  const _KitFocusRing({
    required this.state,
    required this.component,
    required this.builder,
  });

  final ForgeKitState state;
  final ForgeComponent component;
  final Widget Function(BuildContext context, bool focused) builder;

  @override
  State<_KitFocusRing> createState() => _KitFocusRingState();
}

class _KitFocusRingState extends State<_KitFocusRing> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.state.onFocusChanged.listen((_) => _changed());
  }

  @override
  void didUpdateWidget(_KitFocusRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.state, widget.state)) {
      _subscription?.cancel();
      _subscription = widget.state.onFocusChanged.listen((_) => _changed());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    identical(widget.state.focusedComponent, widget.component),
  );
}
