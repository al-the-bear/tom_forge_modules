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
class ForgeEditorOwnsUndo extends StatelessWidget {
  const ForgeEditorOwnsUndo({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: <Type, Action<Intent>>{
      // Typed per intent: UndoHistory casts the override to its intent.
      UndoTextIntent: CallbackAction<UndoTextIntent>(onInvoke: (_) => null),
      RedoTextIntent: CallbackAction<RedoTextIntent>(onInvoke: (_) => null),
    },
    child: child,
  );
}
