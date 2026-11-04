import 'package:flutter/widgets.dart';

/// Turns off Flutter's own text-field undo below it.
///
/// Every `TextField` and `EditableText` keeps an `UndoHistory` of its own and
/// answers the platform's undo keys with it (`UndoTextIntent`,
/// `RedoTextIntent`, from `DefaultTextEditingShortcuts` at the app's root).
/// An editor that keeps the document's history must not have a second one
/// running beside it: a key that missed the editor's own map — after the user
/// rebound undo, say — would otherwise undo the text field's typing behind the
/// document's back. `UndoHistory` lets an ancestor override both intents, and
/// this widget does, with an action that does nothing.
///
/// Wrap the editor's text field (outside the editor's own `Shortcuts`, so
/// its keys still reach its own history first).
///
/// [onUndo] and [onRedo] are for a field shown outside the editor's key map
/// — a popout route over the document — where the platform's undo keys
/// should still reach the document's history: the two intents then call them.
/// Without them the intents do nothing.
class ForgeEditorOwnsUndo extends StatelessWidget {
  const ForgeEditorOwnsUndo({
    super.key,
    required this.child,
    this.onUndo,
    this.onRedo,
  });

  final Widget child;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      // Typed per intent: UndoHistory casts the override to its intent.
      UndoTextIntent: CallbackAction<UndoTextIntent>(
        onInvoke: (_) {
          onUndo?.call();
          return null;
        },
      ),
      RedoTextIntent: CallbackAction<RedoTextIntent>(
        onInvoke: (_) {
          onRedo?.call();
          return null;
        },
      ),
    },
    child: child,
  );
}
