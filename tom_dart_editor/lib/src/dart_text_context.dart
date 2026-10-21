import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import 'dart_code_editor.dart';
import 'editor_trail.dart';

/// [ForgeTextContext] implementation for the Dart code editor.
///
/// Bridges the [DartCodeController] and [TextEditingController] state into
/// the unified [ForgeTextContext] interface for shell integration.
///
/// The context fires change notifications via [onContextChanged] whenever
/// the text or selection changes.
///
/// ```dart
/// final context = DartTextContext(
///   codeController: controller,
///   textController: textEditingController,
///   isDirtyFn: () => _hasUnsavedChanges,
///   canUndoFn: () => _history.canUndo,
///   canRedoFn: () => _history.canRedo,
/// );
/// ```
class DartTextContext implements ForgeTextContext {
  /// The Dart code controller (manages user code, implicit imports, etc).
  final DartCodeController codeController;

  /// The raw text editing controller (provides selection/cursor state).
  final TextEditingController textController;

  /// Callback to query whether the document has unsaved changes.
  final bool Function() isDirtyFn;

  /// Callback to query whether undo is available.
  final bool Function() canUndoFn;

  /// Callback to query whether redo is available.
  final bool Function() canRedoFn;

  final StreamController<ForgeTextContext> _contextController =
      StreamController<ForgeTextContext>.broadcast();

  /// Creates a Dart text context.
  DartTextContext({
    required this.codeController,
    required this.textController,
    required this.isDirtyFn,
    required this.canUndoFn,
    required this.canRedoFn,
  }) {
    textController.addListener(_onChanged);
    trailEvent('DartTextContext created');
  }

  void _onChanged() {
    try {
      _contextController.add(this);
    } catch (e) {
      trailEvent('DartTextContext._onChanged error: $e');
    }
  }

  /// Notify the context stream of an external state change
  /// (e.g. undo/redo availability changed).
  void notifyExternalChange() {
    _onChanged();
  }

  @override
  String get text => codeController.userCode;

  @override
  List<TextSelection> get selections {
    final selection = textController.selection;
    return (selection.isValid) ? [selection] : [];
  }

  @override
  int? get cursorOffset {
    final selection = textController.selection;
    return (selection.isValid) ? selection.baseOffset : null;
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

  @override
  bool get isDirty => isDirtyFn();

  @override
  bool get canUndo => canUndoFn();

  @override
  bool get canRedo => canRedoFn();

  @override
  Stream<ForgeTextContext> get onContextChanged => _contextController.stream;

  /// Dispose resources (removes listener and closes stream).
  void dispose() {
    trailEvent('DartTextContext disposing');
    textController.removeListener(_onChanged);
    _contextController.close();
  }
}
