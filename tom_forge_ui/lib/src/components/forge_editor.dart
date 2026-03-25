import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import 'component_history_manager.dart';
import 'forge_component.dart';

/// An editor component bound to a document URI.
///
/// Editors are closable, track dirty state, and participate in the
/// shell's file-handling resolution protocol (canHandle/canHandleContent).
abstract class ForgeEditor extends ForgeComponent {
  @override
  bool get isEditor => true;

  /// The URI this editor is associated with.
  Uri get uri;

  /// Phase 1: Whether this editor can handle the given URI.
  FileHandlingResult canHandle(Uri uri);

  /// Phase 2: Called only when canHandle returned [FileHandlingResult.inspect].
  FileHandlingResult canHandleContent(Uri uri, List<int> bytes) =>
      FileHandlingResult.accept;

  /// Whether this editor has unsaved changes.
  ValueListenable<bool> get isDirty;

  /// History manager for back/forward navigation. Null if unsupported.
  ComponentHistoryManager? get historyManager => null;
}
