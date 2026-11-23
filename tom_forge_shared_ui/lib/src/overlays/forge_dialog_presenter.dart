import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show DefaultDialogManager, ForgeDialogManager, ForgeQuickPickItem;

import 'forge_input_box_overlay.dart';
import 'forge_quick_pick_overlay.dart';

/// Draws the kit's quick pick and input box requests: bound to a
/// [DefaultDialogManager] ([attach]), every `showQuickPick` and
/// `showInputBox` of the manager — `api.dialogs` — becomes a
/// [ForgeQuickPickOverlay] or a [ForgeInputBoxOverlay] handed to [show]; when
/// the user answers or dismisses it, [show] is called with null.
///
/// The overlay is the application's to place ([show]); [ForgeDialogLayer]
/// places it over a child. The file dialogs (`showOpenDialog`,
/// `showSaveDialog`) are not drawn here: they are the platform's.
class ForgeDialogPresenter {
  ForgeDialogPresenter({required this.show});

  /// Places the overlay of the current request; null removes it.
  final void Function(Widget? overlay) show;

  DefaultDialogManager? _dialogs;

  /// Draws [dialogs]' quick pick and input box requests from now on. A
  /// presenter attached elsewhere is detached first.
  void attach(DefaultDialogManager dialogs) {
    detach();
    _dialogs = dialogs;
    dialogs
      ..onQuickPick = _quickPick
      ..onInputBox = _inputBox;
  }

  /// Stops drawing the requests: the manager's callbacks are cleared unless
  /// someone else bound their own since.
  void detach() {
    final dialogs = _dialogs;
    if (dialogs == null) return;
    // Tear-offs of one method of one object are equal, not identical.
    if (dialogs.onQuickPick == _quickPick) dialogs.onQuickPick = null;
    if (dialogs.onInputBox == _inputBox) dialogs.onInputBox = null;
    _dialogs = null;
  }

  /// Shows [items] in a [ForgeQuickPickOverlay]; completes with the chosen
  /// item's value, null when dismissed.
  Future<T?> _quickPick<T>(
    List<ForgeQuickPickItem<T>> items, {
    String? placeholder,
    bool canSelectMany = false,
  }) {
    final completer = Completer<T?>();
    show(
      ForgeQuickPickOverlay<T>(
        items: items,
        placeholder: placeholder,
        canSelectMany: canSelectMany,
        completer: completer,
      ),
    );
    completer.future.whenComplete(() => show(null));
    return completer.future;
  }

  /// Asks for a line of text in a [ForgeInputBoxOverlay]; completes with it,
  /// null when dismissed.
  Future<String?> _inputBox({
    String? prompt,
    String? value,
    String? placeholder,
    String? Function(String)? validateInput,
  }) {
    final completer = Completer<String?>();
    show(
      ForgeInputBoxOverlay(
        prompt: prompt,
        value: value,
        placeholder: placeholder,
        validateInput: validateInput,
        completer: completer,
      ),
    );
    completer.future.whenComplete(() => show(null));
    return completer.future;
  }
}

/// Draws the kit's quick pick and input box requests over [child]: while it
/// is in the tree, [dialogs] (`api.dialogs`, a [DefaultDialogManager]) shows
/// them here through a [ForgeDialogPresenter]. Another [ForgeDialogManager]
/// draws its dialogs itself, and the layer shows only [child].
class ForgeDialogLayer extends StatefulWidget {
  const ForgeDialogLayer({
    super.key,
    required this.dialogs,
    required this.child,
  });

  final ForgeDialogManager dialogs;
  final Widget child;

  @override
  State<ForgeDialogLayer> createState() => _ForgeDialogLayerState();
}

class _ForgeDialogLayerState extends State<ForgeDialogLayer> {
  late final ForgeDialogPresenter _presenter = ForgeDialogPresenter(
    show: (overlay) {
      if (mounted) setState(() => _overlay = overlay);
    },
  );
  Widget? _overlay;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(ForgeDialogLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.dialogs, widget.dialogs)) _attach();
  }

  @override
  void dispose() {
    _presenter.detach();
    super.dispose();
  }

  void _attach() {
    final dialogs = widget.dialogs;
    if (dialogs is DefaultDialogManager) {
      _presenter.attach(dialogs);
    } else {
      _presenter.detach();
    }
  }

  @override
  Widget build(BuildContext context) =>
      Stack(fit: StackFit.passthrough, children: [widget.child, ?_overlay]);
}
