import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import 'forge_component.dart';
import 'forge_editor.dart';

/// A **surface**: a component placed in a middle (editor) split that is not
/// bound to a document — a prompt queue, a prompt trail, an overview, a
/// configuration list that saves its own entries.
///
/// The shell puts only [ForgeEditor]s in the middle splits, so a surface is
/// one; what makes it a surface is that it holds no document: it declines
/// every file, so the shell never routes an opened document into it, and it
/// is never dirty, so nothing asks to save it. Its [uri] names it (a scheme
/// of its own, such as `agent:` or `specs:`), it is not a file.
///
/// A document editor extends [ForgeEditor] (or one of its kinds) instead and
/// meets the history contract (`tom_forge/_agent_guidelines/
/// editor_component_contract.md` §2).
abstract class ForgeSurfaceEditor extends ForgeEditor {
  final ValueNotifier<bool> _neverDirty = ValueNotifier<bool>(false);

  /// Declines every file.
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  /// Never dirty: a surface holds no document to save.
  @override
  ValueListenable<bool> get isDirty => _neverDirty;

  @override
  void markClean() {}

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();
}
