import 'package:tom_forge_core/src/types/forge_enums.dart';

/// Event fired when focus changes between components.
class FocusChangeEvent {
  /// The previously focused component (null if none was focused).
  final Object? previous;

  /// The newly focused component (null if focus was lost).
  final Object? current;

  const FocusChangeEvent({this.previous, this.current});
}

/// Event fired when an editor's dirty state changes.
class DirtyStateEvent {
  /// The editor whose dirty state changed.
  final Object editor;

  /// The new dirty state.
  final bool isDirty;

  const DirtyStateEvent({required this.editor, required this.isDirty});
}

/// Event fired when diagnostics change.
class DiagnosticChangeEvent {
  /// URIs with changed diagnostics.
  final List<Uri> uris;

  const DiagnosticChangeEvent({required this.uris});
}

/// Event fired when the open editor list changes.
class EditorListChangeEvent {
  /// Editors that were opened.
  final List<Object> opened;

  /// Editors that were closed.
  final List<Object> closed;

  const EditorListChangeEvent({
    this.opened = const [],
    this.closed = const [],
  });
}

/// Event fired when the window gains or loses OS focus.
class WindowFocusEvent {
  /// Whether the window is now focused.
  final bool focused;

  const WindowFocusEvent({required this.focused});
}

/// Event fired when the layout changes.
class LayoutChangeEvent {
  /// The type of layout change.
  final LayoutChangeType type;

  /// The affected panel (if applicable).
  final ForgePanelLocation? panel;

  const LayoutChangeEvent({required this.type, this.panel});
}

/// Event fired when a file changes on the file system.
class FileChangeEvent {
  /// The URI that changed.
  final Uri uri;

  /// The type of change.
  final FileChangeType type;

  const FileChangeEvent({required this.uri, required this.type});
}

/// Event fired before a file is saved. Listeners can modify content.
class WillSaveEvent {
  /// The URI being saved.
  final Uri uri;

  /// The content to be saved. Listeners can modify this.
  String content;

  /// Reason for the save.
  final SaveReason reason;

  WillSaveEvent({required this.uri, required this.content, required this.reason});
}

/// Event fired when a configuration value changes.
class ConfigChangeEvent {
  /// Key path of the changed configuration.
  final String key;

  /// The new value (null if deleted).
  final Object? newValue;

  /// The previous value (null if newly added).
  final Object? oldValue;

  const ConfigChangeEvent({required this.key, this.newValue, this.oldValue});
}

/// Event fired when a secret is stored or deleted.
class SecretChangeEvent {
  /// The secret key.
  final String key;

  /// True if the secret was deleted, false if stored/updated.
  final bool deleted;

  const SecretChangeEvent({required this.key, required this.deleted});
}

/// Event fired when the active application changes.
class ApplicationChangeEvent {
  /// The previously active application (null if first activation).
  final Object? previous;

  /// The newly active application.
  final Object current;

  /// Whether this is the initial activation (no previous app).
  final bool isInitial;

  const ApplicationChangeEvent({
    this.previous,
    required this.current,
    this.isInitial = false,
  });
}
