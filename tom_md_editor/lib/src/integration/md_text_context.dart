import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../controller/md_editor_controller.dart';
import 'editor_trail.dart';

/// [ForgeTextContext] implementation for the markdown editor.
///
/// Bridges the [MdEditorController] state into the unified
/// [ForgeTextContext] interface for shell integration.
///
/// The context fires change notifications via [onContextChanged] whenever
/// the controller notifies listeners (text or selection changes).
///
/// ```dart
/// final context = MdTextContext(
///   controller: mdController,
///   isDirtyFn: () => _hasUnsavedChanges,
/// );
/// ```
class MdTextContext implements ForgeTextContext {
  /// The markdown editor controller.
  final MdEditorController controller;

  /// Callback to query whether the document has unsaved changes.
  final bool Function() isDirtyFn;

  final StreamController<ForgeTextContext> _contextController =
      StreamController<ForgeTextContext>.broadcast();

  /// Creates a markdown text context.
  MdTextContext({
    required this.controller,
    required this.isDirtyFn,
  }) {
    controller.addListener(_onChanged);
    trailEvent('MdTextContext created');
  }

  void _onChanged() {
    try {
      _contextController.add(this);
    } catch (e) {
      trailEvent('MdTextContext._onChanged error: $e');
    }
  }

  /// Notify the context stream of an external state change
  /// (e.g. save completed, so dirty flag changed).
  void notifyExternalChange() {
    _onChanged();
  }

  @override
  String get text => controller.markdown;

  @override
  List<TextSelection> get selections {
    final offset = controller.cursorOffset;
    return [TextSelection.collapsed(offset: offset)];
  }

  @override
  int? get cursorOffset => controller.cursorOffset;

  @override
  int? get currentLine {
    final offset = cursorOffset;
    if (offset == null) return null;
    final md = controller.markdown;
    final clampedOffset = offset.clamp(0, md.length);
    return '\n'.allMatches(md.substring(0, clampedOffset)).length;
  }

  @override
  int? get currentColumn {
    final offset = cursorOffset;
    if (offset == null) return null;
    final md = controller.markdown;
    final clampedOffset = offset.clamp(0, md.length);
    if (clampedOffset == 0) return 0;
    final lastNewline = md.lastIndexOf('\n', clampedOffset - 1);
    return lastNewline == -1 ? clampedOffset : clampedOffset - lastNewline - 1;
  }

  @override
  bool get isDirty => isDirtyFn();

  @override
  bool get canUndo => controller.canUndo;

  @override
  bool get canRedo => controller.canRedo;

  @override
  Stream<ForgeTextContext> get onContextChanged => _contextController.stream;

  /// Dispose resources (removes listener and closes stream).
  void dispose() {
    trailEvent('MdTextContext disposing');
    controller.removeListener(_onChanged);
    _contextController.close();
  }
}
