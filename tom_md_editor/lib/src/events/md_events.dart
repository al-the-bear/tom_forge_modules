import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../models/md_document.dart';
import '../models/md_section.dart';

/// Base class for all markdown editor events.
abstract class MdEvent {
  const MdEvent();
}

/// Thrown to block an operation in a before-handler.
class MdOperationBlockedException implements Exception {
  const MdOperationBlockedException({
    required this.message,
    this.showToUser = false,
  });

  final String message;
  final bool showToUser;

  @override
  String toString() => 'MdOperationBlockedException: $message';
}

// ── Section events ──

class SectionCreateEvent extends MdEvent {
  SectionCreateEvent({
    this.parent,
    required this.index,
    required this.level,
    required this.headline,
    this.text,
  });

  final MdSection? parent;
  final int index;
  final int level;
  String headline;
  String? text;

  SectionCreateEvent copyWith({String? headline, String? text, int? level}) =>
      SectionCreateEvent(
        parent: parent,
        index: index,
        level: level ?? this.level,
        headline: headline ?? this.headline,
        text: text ?? this.text,
      );
}

class SectionCreatedEvent extends MdEvent {
  const SectionCreatedEvent({required this.section});
  final MdSection section;
}

class SectionDeleteEvent extends MdEvent {
  const SectionDeleteEvent({required this.section});
  final MdSection section;
}

class SectionDeletedEvent extends MdEvent {
  const SectionDeletedEvent({required this.headline});
  final String headline;
}

class SectionMoveEvent extends MdEvent {
  SectionMoveEvent({
    required this.section,
    this.fromParent,
    required this.fromIndex,
    this.toParent,
    required this.toIndex,
  });

  final MdSection section;
  final MdSection? fromParent;
  final int fromIndex;
  MdSection? toParent;
  int toIndex;
}

class SectionMovedEvent extends MdEvent {
  const SectionMovedEvent({required this.section});
  final MdSection section;
}

class HeadlineChangeEvent extends MdEvent {
  HeadlineChangeEvent({
    required this.section,
    required this.oldHeadline,
    required this.newHeadline,
  });

  final MdSection section;
  final String oldHeadline;
  String newHeadline;

  HeadlineChangeEvent copyWith({String? newHeadline}) => HeadlineChangeEvent(
    section: section,
    oldHeadline: oldHeadline,
    newHeadline: newHeadline ?? this.newHeadline,
  );
}

class HeadlineChangedEvent extends MdEvent {
  const HeadlineChangedEvent({required this.section});
  final MdSection section;
}

class TextChangeEvent extends MdEvent {
  TextChangeEvent({
    required this.section,
    required this.oldText,
    required this.newText,
  });

  final MdSection section;
  final String oldText;
  String newText;

  TextChangeEvent copyWith({String? newText}) => TextChangeEvent(
    section: section,
    oldText: oldText,
    newText: newText ?? this.newText,
  );
}

class TextChangedEvent extends MdEvent {
  const TextChangedEvent({required this.section});
  final MdSection section;
}

class SectionSelectedEvent extends MdEvent {
  const SectionSelectedEvent({required this.section});
  final MdSection section;
}

class DocumentSavedEvent extends MdEvent {
  const DocumentSavedEvent();
}

/// Fired when validation errors change after a content or schema update.
class ValidationChangedEvent extends MdEvent {
  const ValidationChangedEvent({required this.errors});

  /// Current validation errors.
  final List<ValidationError> errors;
}

/// Fired after a document is loaded from a provider.
class DocumentLoadedEvent extends MdEvent {
  const DocumentLoadedEvent({required this.document});

  /// The loaded document model.
  final MdDocument document;
}

/// Fired before a save operation — handlers can inspect/modify the markdown.
class DocumentSaveEvent extends MdEvent {
  DocumentSaveEvent({required this.markdown});

  /// The markdown to be saved; handlers may replace it.
  String markdown;

  DocumentSaveEvent copyWith({String? markdown}) =>
      DocumentSaveEvent(markdown: markdown ?? this.markdown);
}

// ── Handler types ──

/// Async handler that may modify or block an event.
typedef MdEventHandler<T extends MdEvent> = Future<T> Function(T event);

/// Simple callback fired after an event occurred.
typedef MdEventCallback<T extends MdEvent> = void Function(T event);

/// Collection of all event handlers for the markdown editor.
class MdEditorEventHandlers {
  const MdEditorEventHandlers({
    this.onBeforeSectionCreate,
    this.onSectionCreated,
    this.onBeforeSectionDelete,
    this.onSectionDeleted,
    this.onBeforeSectionMove,
    this.onSectionMoved,
    this.onBeforeHeadlineChange,
    this.onHeadlineChanged,
    this.onBeforeTextChange,
    this.onTextChanged,
    this.onSectionSelected,
    this.onBeforeSave,
    this.onSaved,
    this.onValidationChanged,
    this.onLoaded,
  });

  final MdEventHandler<SectionCreateEvent>? onBeforeSectionCreate;
  final MdEventCallback<SectionCreatedEvent>? onSectionCreated;
  final MdEventHandler<SectionDeleteEvent>? onBeforeSectionDelete;
  final MdEventCallback<SectionDeletedEvent>? onSectionDeleted;
  final MdEventHandler<SectionMoveEvent>? onBeforeSectionMove;
  final MdEventCallback<SectionMovedEvent>? onSectionMoved;
  final MdEventHandler<HeadlineChangeEvent>? onBeforeHeadlineChange;
  final MdEventCallback<HeadlineChangedEvent>? onHeadlineChanged;
  final MdEventHandler<TextChangeEvent>? onBeforeTextChange;
  final MdEventCallback<TextChangedEvent>? onTextChanged;
  final MdEventCallback<SectionSelectedEvent>? onSectionSelected;
  final MdEventHandler<DocumentSaveEvent>? onBeforeSave;
  final MdEventCallback<DocumentSavedEvent>? onSaved;
  final MdEventCallback<ValidationChangedEvent>? onValidationChanged;
  final MdEventCallback<DocumentLoadedEvent>? onLoaded;
}
