import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

/// Base adapter class for bridging editor-specific document models
/// to the [ForgeDocument] contract.
///
/// Subclasses implement [text], [lineCount], [lineAt], [textInRange],
/// [languageId], [encoding], and [isUntitled]. This base provides
/// URI tracking, version management, dirty-state notification, and
/// change event broadcasting.
abstract class ForgeDocumentAdapter implements ForgeDocument {
  final Uri _uri;
  final ValueNotifier<bool> _isDirtyNotifier = ValueNotifier(false);
  final StreamController<DocumentChangeEvent> _changes =
      StreamController.broadcast();
  int _version = 0;

  ForgeDocumentAdapter(this._uri);

  @override
  Uri get uri => _uri;

  @override
  int get version => _version;

  /// Whether the document has been modified since last save.
  ValueListenable<bool> get isDirty => _isDirtyNotifier;

  @override
  Stream<DocumentChangeEvent> get onDidChange => _changes.stream;

  /// Mark the document as dirty and increment the version counter.
  @protected
  void markDirty() {
    _version++;
    _isDirtyNotifier.value = true;
  }

  /// Mark the document as clean (e.g., after save).
  @protected
  void markClean() {
    _isDirtyNotifier.value = false;
  }

  /// Fire a change event with the affected ranges.
  @protected
  void fireChange(List<ForgeTextRange> changes) {
    _changes.add(DocumentChangeEvent(changes: changes, document: this));
  }

  /// Release resources. Call when the document is no longer needed.
  void dispose() {
    _changes.close();
    _isDirtyNotifier.dispose();
  }
}
