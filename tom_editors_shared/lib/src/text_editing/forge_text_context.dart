import 'dart:async';

import 'package:flutter/widgets.dart';

/// Whether debug logging is enabled for forge_text_context operations.
bool kForgeTextContextDebug = false;

void _log(String message) {
  if (kForgeTextContextDebug) {
    // ignore: avoid_print
    print('[ForgeTextContext] $message');
  }
}

/// Interface for discovering text editing context.
///
/// Implemented by editors to expose their state to the shell.
/// The shell can use this to:
/// - Display cursor position in the status bar
/// - Show document state (dirty indicator)
/// - Enable/disable undo/redo buttons
/// - Provide selection information to other components
///
/// ```dart
/// class MyTextContext implements ForgeTextContext {
///   final TextEditingController controller;
///
///   MyTextContext(this.controller);
///
///   @override
///   String get text => controller.text;
///
///   @override
///   int get cursorOffset => controller.selection.baseOffset;
///
///   // ... other implementations
/// }
/// ```
abstract interface class ForgeTextContext {
  /// Current text content.
  String get text;

  /// Current selection(s). Multiple for column/block selection.
  List<TextSelection> get selections;

  /// Primary cursor position (character offset), or null if unavailable.
  int? get cursorOffset;

  /// Current line number (0-based), or null if unavailable.
  int? get currentLine;

  /// Current column number (0-based), or null if unavailable.
  int? get currentColumn;

  /// Whether the document has been modified since last save.
  bool get isDirty;

  /// Whether undo is available.
  bool get canUndo;

  /// Whether redo is available.
  bool get canRedo;

  /// Stream of context changes.
  ///
  /// Fires whenever any context property changes (cursor, selection, etc.)
  Stream<ForgeTextContext> get onContextChanged;
}

/// A concrete implementation of [ForgeTextContext] backed by a
/// [TextEditingController].
///
/// Useful as a base class or for simple text editing scenarios.
class TextEditingContextImpl implements ForgeTextContext {
  final TextEditingController? _controller;
  final String? _text;
  final List<TextSelection>? _selections;
  final bool Function() _isDirtyGetter;
  final bool Function() _canUndoGetter;
  final bool Function() _canRedoGetter;

  final _contextController = StreamController<ForgeTextContext>.broadcast();

  /// Creates a context backed by a TextEditingController.
  TextEditingContextImpl({
    required TextEditingController controller,
    required bool Function() isDirty,
    required bool Function() canUndo,
    required bool Function() canRedo,
  })  : _controller = controller,
        _text = null,
        _selections = null,
        _isDirtyGetter = isDirty,
        _canUndoGetter = canUndo,
        _canRedoGetter = canRedo {
    controller.addListener(_notifyContextChanged);
    _log('Created TextEditingContextImpl with controller');
  }

  /// Private constructor for withValues factory.
  TextEditingContextImpl._withStaticValues({
    required String text,
    required List<TextSelection> selections,
    required bool Function() isDirty,
    required bool Function() canUndo,
    required bool Function() canRedo,
  })  : _controller = null,
        _text = text,
        _selections = selections,
        _isDirtyGetter = isDirty,
        _canUndoGetter = canUndo,
        _canRedoGetter = canRedo {
    _log('Created TextEditingContextImpl with static values');
  }

  /// Creates a context with static values (for testing or snapshots).
  factory TextEditingContextImpl.withValues({
    required String text,
    required List<TextSelection> selections,
    bool isDirty = false,
    bool canUndo = false,
    bool canRedo = false,
  }) {
    return TextEditingContextImpl._withStaticValues(
      text: text,
      selections: selections,
      isDirty: () => isDirty,
      canUndo: () => canUndo,
      canRedo: () => canRedo,
    );
  }

  void _notifyContextChanged() {
    _log('Context changed: line=$currentLine, col=$currentColumn');
    _contextController.add(this);
  }

  /// Call this when external state changes (dirty, undo/redo availability).
  void notifyExternalChange() {
    _notifyContextChanged();
  }

  /// Dispose resources.
  void dispose() {
    _log('Disposing TextEditingContextImpl');
    _controller?.removeListener(_notifyContextChanged);
    _contextController.close();
  }

  @override
  String get text => _controller?.text ?? _text ?? '';

  @override
  List<TextSelection> get selections {
    final sels = _selections;
    if (sels != null) return sels;
    final selection = _controller?.selection;
    return (selection != null && selection.isValid) ? [selection] : [];
  }

  @override
  int? get cursorOffset {
    final sels = _selections;
    if (sels != null && sels.isNotEmpty) {
      return sels.first.baseOffset;
    }
    final selection = _controller?.selection;
    return (selection != null && selection.isValid) ? selection.baseOffset : null;
  }

  @override
  int? get currentLine {
    final offset = cursorOffset;
    if (offset == null) return null;
    final clampedOffset = offset.clamp(0, text.length);
    return '\n'.allMatches(text.substring(0, clampedOffset)).length;
  }

  @override
  int? get currentColumn {
    final offset = cursorOffset;
    if (offset == null) return null;
    final clampedOffset = offset.clamp(0, text.length);
    if (clampedOffset == 0) return 0;
    final lastNewline = text.lastIndexOf('\n', clampedOffset - 1);
    return lastNewline == -1 ? clampedOffset : clampedOffset - lastNewline - 1;
  }

  /// Returns the number of characters in the text.
  int get textLength => text.length;

  /// Returns the number of lines in the text.
  int get lineCount => text.isEmpty ? 1 : text.split('\n').length;

  /// Whether there is a non-collapsed selection.
  bool get hasSelection {
    for (final selection in selections) {
      if (selection.isValid && !selection.isCollapsed) {
        return true;
      }
    }
    return false;
  }

  /// Returns the text of the current line.
  String? get currentLineText {
    final line = currentLine;
    if (line == null) return null;
    final lines = text.split('\n');
    if (line < lines.length) {
      return lines[line];
    }
    return null;
  }

  /// Returns the currently selected text.
  String get selectedText {
    if (selections.isEmpty) return '';
    final selection = selections.first;
    if (!selection.isValid || selection.isCollapsed) return '';
    return text.substring(selection.start, selection.end);
  }

  @override
  bool get isDirty => _isDirtyGetter();

  @override
  bool get canUndo => _canUndoGetter();

  @override
  bool get canRedo => _canRedoGetter();

  @override
  Stream<ForgeTextContext> get onContextChanged => _contextController.stream;

  @override
  String toString() => 'TextEditingContextImpl(${text.length} chars, '
      '${selections.length} selections, cursor=$cursorOffset)';
}
