import 'package:flutter/widgets.dart';

/// An entry in the undo history for text editing operations.
///
/// Stores both the old and new state to enable bidirectional traversal
/// (undo and redo).
///
/// ```dart
/// final entry = TextUndoEntry(
///   oldText: 'Hello',
///   newText: 'Hello World',
///   oldSelection: TextSelection.collapsed(offset: 5),
///   newSelection: TextSelection.collapsed(offset: 11),
///   description: 'Typed " World"',
/// );
/// ```
class TextUndoEntry {
  /// Text content before the change.
  final String oldText;

  /// Text content after the change.
  final String newText;

  /// Selection before the change.
  final TextSelection? oldSelection;

  /// Selection after the change.
  final TextSelection? newSelection;

  /// Optional human-readable description of the change.
  final String? description;

  /// When this change was made.
  final DateTime timestamp;

  /// Creates a text undo entry recording a state transition.
  TextUndoEntry({
    required this.oldText,
    required this.newText,
    this.oldSelection,
    this.newSelection,
    this.description,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Creates an entry for an insert operation.
  factory TextUndoEntry.insert({
    required String text,
    required int offset,
    required String insertedText,
    TextSelection? oldSelection,
    TextSelection? newSelection,
  }) {
    return TextUndoEntry(
      oldText: text,
      newText: text.substring(0, offset) +
          insertedText +
          text.substring(offset),
      oldSelection: oldSelection,
      newSelection: newSelection,
      description: 'Insert "${_truncate(insertedText)}"',
    );
  }

  /// Creates an entry for a delete operation.
  factory TextUndoEntry.delete({
    required String text,
    required int start,
    required int end,
    TextSelection? oldSelection,
    TextSelection? newSelection,
  }) {
    final deletedText = text.substring(start, end);
    return TextUndoEntry(
      oldText: text,
      newText: text.substring(0, start) + text.substring(end),
      oldSelection: oldSelection,
      newSelection: newSelection,
      description: 'Delete "${_truncate(deletedText)}"',
    );
  }

  /// Creates an entry for a replace operation.
  factory TextUndoEntry.replace({
    required String oldText,
    required String newText,
    TextSelection? oldSelection,
    TextSelection? newSelection,
    String? description,
  }) {
    return TextUndoEntry(
      oldText: oldText,
      newText: newText,
      oldSelection: oldSelection,
      newSelection: newSelection,
      description: description ?? 'Replace text',
    );
  }

  /// Truncates text for display in descriptions.
  static String _truncate(String text, {int maxLength = 20}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  String toString() => 'TextUndoEntry(${description ?? "change"}, '
      '${oldText.length} -> ${newText.length} chars)';
}
