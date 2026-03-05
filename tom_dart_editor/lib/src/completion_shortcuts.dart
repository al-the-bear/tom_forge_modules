enum CompletionShortcutAction {
  none,
  triggerCompletion,
  openReference,
  undo,
  redo,
}

class CompletionShortcutResolver {
  static CompletionShortcutAction resolve({
    required bool autoCompleteEnabled,
    required bool isControlPressed,
    required bool isMetaPressed,
    required bool isAltPressed,
    required bool isShiftPressed,
    required bool isSpace,
    required bool isKeyI,
    required bool isKeyR,
    required bool isKeyZ,
    required bool isKeyY,
  }) {
    if (isSpace) {
      if (autoCompleteEnabled && isControlPressed && !isMetaPressed) {
        return CompletionShortcutAction.triggerCompletion;
      }
      if (autoCompleteEnabled &&
          isAltPressed &&
          !isMetaPressed &&
          !isControlPressed) {
        return CompletionShortcutAction.triggerCompletion;
      }
    }

    if (autoCompleteEnabled && isKeyI && isControlPressed && !isMetaPressed) {
      return CompletionShortcutAction.triggerCompletion;
    }

    if (isKeyR && isControlPressed && !isMetaPressed) {
      return CompletionShortcutAction.openReference;
    }

    if (isKeyZ && (isMetaPressed || isControlPressed) && !isShiftPressed) {
      return CompletionShortcutAction.undo;
    }

    if ((isKeyZ && (isMetaPressed || isControlPressed) && isShiftPressed) ||
        (isKeyY && isControlPressed)) {
      return CompletionShortcutAction.redo;
    }

    return CompletionShortcutAction.none;
  }
}
