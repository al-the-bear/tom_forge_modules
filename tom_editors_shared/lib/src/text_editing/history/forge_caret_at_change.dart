import 'package:flutter/services.dart';

/// Where the caret goes when a field's text is replaced from outside — an
/// undo or redo of the document's history reaching a field that shows one
/// value: at the end of the changed part of [newText].
///
/// For an edit that inserted or removed one run of characters this is the
/// caret the edit itself had — before it after an undo, after it after a
/// redo — which is the caret the history contract asks for, worked out from
/// the two texts alone.
TextSelection forgeCaretAtChange(String oldText, String newText) {
  var start = 0;
  final shorter = oldText.length < newText.length
      ? oldText.length
      : newText.length;
  while (start < shorter && oldText[start] == newText[start]) {
    start++;
  }
  var oldEnd = oldText.length;
  var newEnd = newText.length;
  while (oldEnd > start &&
      newEnd > start &&
      oldText[oldEnd - 1] == newText[newEnd - 1]) {
    oldEnd--;
    newEnd--;
  }
  return TextSelection.collapsed(offset: newEnd);
}
