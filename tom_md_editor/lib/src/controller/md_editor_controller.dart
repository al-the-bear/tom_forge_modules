import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show TextSelection;
import 'package:tom_editors_shared/tom_editors_shared.dart';

import '../debug/md_editor_debug.dart';
import '../events/md_events.dart';
import '../models/md_document.dart';
import '../models/md_parser.dart';
import '../models/md_search_result.dart';
import '../models/md_section.dart';
import '../providers/md_document_provider.dart';
import '../schema/md_schema_support.dart';
import 'md_line_edit.dart';

/// Controller for the markdown editor.
///
/// Manages document state, undo/redo, section operations, and search.
/// Fires [notifyListeners] on every state change so widgets can rebuild.
///
/// The document's one history keeps the Forge history contract (tom_forge_ui's
/// `editor_history_contract.md`): a [ForgeTextHistory] over the markdown and
/// the cursor. Typing ([edit], and a section's text through
/// [updateSectionText]) is one entry per gesture; every other operation — a
/// rename, an insert, a move, a replace, [applyEdit] — is its own entry; an
/// operation that changes nothing is none; undo and redo put the cursor back
/// where it was before, or after, the edit. Typing a view has not handed over
/// yet is flushed first ([pendingEditFlusher]). Dirty is measured against the
/// saved markdown ([isDirty]).
class MdEditorController extends ChangeNotifier {
  MdEditorController({
    String? initialMarkdown,
    this.eventHandlers,
    this.uri,
    int maxUndoHistory = ForgeTextDefaults.defaultMaxUndoHistory,
  }) : _history = ForgeTextHistory(
         ForgeTextState.atEnd(initialMarkdown ?? ''),
         maxEntries: maxUndoHistory,
       ),
       _saved = ForgeSavedMarker(initialMarkdown ?? '') {
    if (initialMarkdown != null) {
      _setMarkdownInternal(initialMarkdown);
    }
    _cursorOffset = _markdown.length;
  }

  // ── Forge integration ──

  /// Optional URI associated with this editor's document.
  ///
  /// Used by forge shell adapters to identify the file being edited.
  Uri? uri;

  /// Cursor position as a [ValueNotifier] for forge shell observation.
  ///
  /// Updated whenever the cursor offset changes.
  final ValueNotifier<int> cursorPositionNotifier = ValueNotifier(0);

  /// Selection range as a [ValueNotifier] for forge shell observation.
  ///
  /// Holds (start, end) offsets, or null when no selection is active.
  final ValueNotifier<({int start, int end})?> selectionNotifier =
      ValueNotifier(null);

  /// Visible line range as a [ValueNotifier] for forge shell observation.
  ///
  /// Holds (firstLine, lastLine) currently visible in the viewport.
  final ValueNotifier<({int firstLine, int lastLine})> visibleRangeNotifier =
      ValueNotifier((firstLine: 0, lastLine: 20));

  /// Active decoration ranges keyed by decoration type string.
  ///
  /// Used by forge shell adapters to apply diagnostic highlights,
  /// search results, or other visual markers.
  final Map<String, List<({int start, int end})>> _decorations = {};

  /// Set decoration ranges for a given [type] key.
  ///
  /// Replaces any existing ranges for that type and notifies listeners.
  void setDecorations(String type, List<({int start, int end})> ranges) {
    _decorations[type] = List.unmodifiable(ranges);
    notifyListeners();
  }

  /// Clear decoration ranges for a given [type] key.
  void clearDecorations(String type) {
    if (_decorations.remove(type) != null) {
      notifyListeners();
    }
  }

  /// Get all active decoration ranges.
  Map<String, List<({int start, int end})>> get decorations =>
      Map.unmodifiable(_decorations);

  @override
  void dispose() {
    _history.dispose();
    _saved.dispose();
    cursorPositionNotifier.dispose();
    selectionNotifier.dispose();
    visibleRangeNotifier.dispose();
    super.dispose();
  }

  // ── Public state ──

  /// Raw markdown string.
  String get markdown => _markdown;
  String _markdown = '';

  /// Parsed document model.
  MdDocument get document => _document;
  MdDocument _document = MdDocument(sections: []);

  /// Currently selected section.
  MdSection? get selectedSection => _selectedSection;
  MdSection? _selectedSection;

  /// Validation errors (from schema, if any).
  List<ValidationError> get validationErrors =>
      List.unmodifiable(_validationErrors);
  final List<ValidationError> _validationErrors = [];

  /// Cursor offset in the raw markdown source.
  ///
  /// Set by the raw editor when the cursor moves, or by the preview panel
  /// when the user clicks a section/heading. Both panels observe this to
  /// stay in sync.
  int get cursorOffset => _cursorOffset;
  int _cursorOffset = 0;

  /// Update the cursor offset and notify listeners.
  ///
  /// Set [notify] to `false` when the caller is about to notify anyway
  /// (e.g., during a batch update).
  ///
  /// A cursor move is a history boundary: the typing gesture in progress
  /// ends.
  void setCursorOffset(int offset, {bool notify = true}) {
    _cursorOffset = offset.clamp(0, _markdown.length);
    cursorPositionNotifier.value = _cursorOffset;
    _history.selected(TextSelection.collapsed(offset: _cursorOffset));
    if (notify) notifyListeners();
  }

  /// Scroll so that the given 1-based [line] is visible and place the cursor
  /// at the beginning of that line.
  void revealLine(int line) {
    final lines = _markdown.split('\n');
    int offset = 0;
    for (int i = 0; i < (line - 1).clamp(0, lines.length - 1); i++) {
      offset += lines[i].length + 1; // +1 for newline
    }
    setCursorOffset(offset);
  }

  /// Schema ID detected from document.
  String? get schemaId => _document.schemaId;

  /// Event handlers for intercepting operations.
  MdEditorEventHandlers? eventHandlers;

  /// The document schema the editor works with ([MdSchemaSupport]), set by a
  /// schema plugin (`tom_md_docspecs`); null without one.
  MdSchemaSupport? get schemaSupport => _schemaSupport;
  MdSchemaSupport? _schemaSupport;

  /// Whether a schema is attached.
  bool get hasSchema => _schemaSupport != null;

  /// Attach [support] for document validation and the schema's features.
  ///
  /// Once set, validation runs automatically on every content change
  /// and fires [MdEditorEventHandlers.onValidationChanged].
  void setSchemaSupport(MdSchemaSupport support) {
    _schemaSupport = support;
    _runSchemaValidation();
    notifyListeners();
  }

  /// Clear the schema, removing all validation errors.
  void clearSchema() {
    _schemaSupport = null;
    _validationErrors.clear();
    eventHandlers?.onValidationChanged?.call(
      ValidationChangedEvent(errors: const []),
    );
    notifyListeners();
  }

  /// Whether undo is available.
  bool get canUndo => _history.canUndo || _hasPendingEdit;

  /// Whether redo is available.
  bool get canRedo => _history.canRedo && !_hasPendingEdit;

  /// Current search results.
  List<MdSearchResult> get searchResults =>
      List.unmodifiable(_searchResults);
  List<MdSearchResult> _searchResults = [];

  /// Current search match index.
  int get currentSearchIndex => _currentSearchIndex;
  int _currentSearchIndex = 0;

  // ── Private state ──

  /// The document's one history, over the markdown and the cursor.
  final ForgeTextHistory _history;

  /// Dirty against the saved markdown.
  final ForgeSavedMarker<String> _saved;

  /// Whether the markdown differs from the saved markdown.
  ValueListenable<bool> get isDirty => _saved.isDirty;

  /// The markdown as it is now is saved: the gesture in progress ends and
  /// the saved marker moves. The history stays.
  void markSaved() {
    flush();
    _saved.markSaved(_markdown);
  }

  /// A view's typing it has not handed over yet (a debounced raw editor)
  /// — called before every history boundary, so typing undone within the
  /// debounce is undone, never lost or applied late. The view registers it
  /// while it has pending typing to hand over, and clears it.
  VoidCallback? pendingEditFlusher;

  /// Whether a view says it holds typing not handed over yet.
  bool Function()? hasPendingEdit;

  bool get _hasPendingEdit => hasPendingEdit?.call() ?? false;

  /// Ends the typing gesture in progress, the view's pending typing first.
  void flush() {
    pendingEditFlusher?.call();
    _history.flush();
  }

  // ── Content manipulation ──

  /// Typing in a view changed the whole markdown to [value] (the edit
  /// applied); [cursor] is where the view's cursor is now. One history entry
  /// per gesture.
  void edit(String value, {int? cursor}) {
    try {
      final oldMd = _markdown;
      _setMarkdownInternal(value);
      _refreshSelectedSection();
      _recordTyping(oldMd, cursor);
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error setting markdown', e, st);
    }
  }

  /// A programmatic change of the whole markdown (a format, a preview
  /// action, a table or code-block edit): its own history entry.
  void applyEdit(String value, {int? cursor}) {
    try {
      final oldMd = _markdown;
      _setMarkdownInternal(value);
      _refreshSelectedSection();
      if (cursor != null) _cursorOffset = cursor.clamp(0, _markdown.length);
      _pushUndoWithStates(oldMd, _markdown, 'Edit');
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error setting markdown', e, st);
    }
  }

  /// Content arrived from outside the history — a reload, an external change
  /// taken, a revision restore: the document becomes [value] and the history
  /// is cleared (an entry made against the old text would apply to text it
  /// was not made on).
  void replaceContent(String value) {
    _setMarkdownInternal(value);
    _refreshSelectedSection();
    _cursorOffset = _cursorOffset.clamp(0, _markdown.length);
    _history.replace(
      ForgeTextState(value, TextSelection.collapsed(offset: _cursorOffset)),
    );
    _saved.markSaved(value);
    notifyListeners();
  }

  // ── Guarded line edits ──
  //
  // An edit of lines guarded by the text the reader was shown (a review's
  // edits are made of these, `tom_md_review`): one history entry; a refusal
  // changes nothing.

  /// Applies [edit] — lines `startLine..endLine` replaced while they still
  /// hold what was shown — as one history entry.
  MdLineEditResult applyLineEdit(MdLineEdit edit) {
    flush();
    final result = mdApplyLineEdit(_markdown, edit);
    if (result case MdLineEditApplied(:final text)) applyEdit(text);
    return result;
  }

  /// How many edits the history keeps (`ForgeTextSettings.maxUndoHistory`).
  int get maxUndoHistory => _history.maxEntries;
  set maxUndoHistory(int value) => _history.maxEntries = value;

  /// Load content from a provider.
  Future<void> loadFromProvider(MdDocumentProvider provider) async {
    try {
      MdEditorDebug.logger.info('Loading from provider');
      final content = await provider.load();
      // A load is content from outside: saved, and nothing to undo.
      _setMarkdownInternal(content);
      _cursorOffset = 0;
      _history.replace(
        ForgeTextState(content, const TextSelection.collapsed(offset: 0)),
      );
      _saved.markSaved(content);
      final meta = provider.metadata;
      if (meta != null) {
        _document.path = meta.path;
        _document.lastModified = meta.lastModified;
      }
      eventHandlers?.onLoaded?.call(
        DocumentLoadedEvent(document: _document),
      );
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error loading from provider', e, st);
    }
  }

  /// Save content to a provider.
  Future<void> saveToProvider(MdDocumentProvider provider) async {
    try {
      if (!provider.canSave) return;
      MdEditorDebug.logger.info('Saving to provider');

      flush();
      var mdToSave = _markdown;

      if (eventHandlers?.onBeforeSave != null) {
        final event = await eventHandlers!.onBeforeSave!(
          DocumentSaveEvent(markdown: mdToSave),
        );
        mdToSave = event.markdown;
      }

      await provider.save(mdToSave);
      _saved.markSaved(mdToSave);

      eventHandlers?.onSaved?.call(const DocumentSavedEvent());
    } catch (e, st) {
      if (e is MdOperationBlockedException) rethrow;
      MdEditorDebug.logger.error('Error saving to provider', e, st);
    }
  }

  // ── Section operations ──

  /// Select a section and notify listeners.
  void selectSection(MdSection? section) {
    try {
      _selectedSection = section;
      if (section != null) {
        eventHandlers?.onSectionSelected?.call(
          SectionSelectedEvent(section: section),
        );
      }
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error selecting section', e, st);
    }
  }

  /// Update the text of a section.
  ///
  /// [typing] is a view's typing: one history entry per gesture. Otherwise
  /// (a toolbar action, an insert) the change is its own entry. [cursor] is
  /// where the view's cursor is now, in the whole markdown.
  Future<void> updateSectionText(
    MdSection section,
    String newText, {
    int? cursor,
    bool typing = false,
  }) async {
    try {
      MdEditorDebug.logger.info(
        'Updating text for "${section.headline}"',
      );
      var event = TextChangeEvent(
        section: section,
        oldText: section.text,
        newText: newText,
      );

      if (eventHandlers?.onBeforeTextChange != null) {
        event = await eventHandlers!.onBeforeTextChange!(event);
      }

      final oldMd = _markdown;
      section.text = event.newText;
      _rebuildMarkdown();
      if (typing) {
        _recordTyping(oldMd, cursor);
      } else {
        if (cursor != null) _cursorOffset = cursor.clamp(0, _markdown.length);
        _pushUndoWithStates(oldMd, _markdown, 'Update text');
      }

      eventHandlers?.onTextChanged?.call(
        TextChangedEvent(section: section),
      );
      notifyListeners();
    } catch (e, st) {
      if (e is MdOperationBlockedException) rethrow;
      MdEditorDebug.logger.error('Error updating section text', e, st);
    }
  }

  /// Update the headline of a section.
  Future<void> updateSectionHeadline(
    MdSection section,
    String newHeadline,
  ) async {
    try {
      MdEditorDebug.logger.info(
        'Updating headline: "${section.headline}" → "$newHeadline"',
      );
      var event = HeadlineChangeEvent(
        section: section,
        oldHeadline: section.headline,
        newHeadline: newHeadline,
      );

      if (eventHandlers?.onBeforeHeadlineChange != null) {
        event = await eventHandlers!.onBeforeHeadlineChange!(event);
      }

      final oldMd = _markdown;
      section.headline = event.newHeadline;
      _rebuildMarkdown();
      _pushUndoWithStates(oldMd, _markdown, 'Rename: ${section.headline}');

      eventHandlers?.onHeadlineChanged?.call(
        HeadlineChangedEvent(section: section),
      );
      notifyListeners();
    } catch (e, st) {
      if (e is MdOperationBlockedException) rethrow;
      MdEditorDebug.logger.error('Error updating headline', e, st);
    }
  }

  /// Insert a new section.
  Future<MdSection?> insertSection({
    MdSection? parent,
    int index = 0,
    required int level,
    required String headline,
    String? id,
    String? text,
  }) async {
    try {
      MdEditorDebug.logger.info('Inserting section: $headline');
      var event = SectionCreateEvent(
        parent: parent,
        index: index,
        level: level,
        headline: headline,
        text: text,
      );

      if (eventHandlers?.onBeforeSectionCreate != null) {
        event = await eventHandlers!.onBeforeSectionCreate!(event);
      }

      final oldMd = _markdown;

      final section = MdSection(
        headline: event.headline,
        level: event.level,
        id: id,
        text: event.text ?? '',
      );

      final siblings = parent?.subsections ?? _document.sections;
      final insertIdx = index.clamp(0, siblings.length);
      siblings.insert(insertIdx, section);
      _rebuildMarkdown();
      _pushUndoWithStates(oldMd, _markdown, 'Insert: ${event.headline}');

      eventHandlers?.onSectionCreated?.call(
        SectionCreatedEvent(section: section),
      );
      notifyListeners();
      return section;
    } catch (e, st) {
      if (e is MdOperationBlockedException) rethrow;
      MdEditorDebug.logger.error('Error inserting section', e, st);
      return null;
    }
  }

  /// Delete a section and all its subsections.
  Future<void> deleteSection(MdSection section) async {
    try {
      MdEditorDebug.logger.info('Deleting section: ${section.headline}');

      if (eventHandlers?.onBeforeSectionDelete != null) {
        await eventHandlers!.onBeforeSectionDelete!(
          SectionDeleteEvent(section: section),
        );
      }

      final oldMd = _markdown;
      _removeSectionFromTree(section, _document.sections);
      if (_selectedSection == section) _selectedSection = null;
      _rebuildMarkdown();
      _pushUndoWithStates(oldMd, _markdown, 'Delete: ${section.headline}');

      eventHandlers?.onSectionDeleted?.call(
        SectionDeletedEvent(headline: section.headline),
      );
      notifyListeners();
    } catch (e, st) {
      if (e is MdOperationBlockedException) rethrow;
      MdEditorDebug.logger.error('Error deleting section', e, st);
    }
  }

  /// Move a section to a new position.
  Future<void> moveSection(
    MdSection section, {
    MdSection? newParent,
    required int newIndex,
  }) async {
    try {
      MdEditorDebug.logger.info(
        'Moving section: ${section.headline} to index $newIndex',
      );

      var event = SectionMoveEvent(
        section: section,
        fromParent: _findParent(section),
        fromIndex: _findIndex(section),
        toParent: newParent,
        toIndex: newIndex,
      );

      if (eventHandlers?.onBeforeSectionMove != null) {
        event = await eventHandlers!.onBeforeSectionMove!(event);
      }

      final oldMd = _markdown;
      _removeSectionFromTree(section, _document.sections);

      final targetList = event.toParent?.subsections ?? _document.sections;
      final idx = event.toIndex.clamp(0, targetList.length);
      targetList.insert(idx, section);
      _rebuildMarkdown();
      _pushUndoWithStates(oldMd, _markdown, 'Move: ${section.headline}');

      eventHandlers?.onSectionMoved?.call(
        SectionMovedEvent(section: section),
      );
      notifyListeners();
    } catch (e, st) {
      if (e is MdOperationBlockedException) rethrow;
      MdEditorDebug.logger.error('Error moving section', e, st);
    }
  }

  /// Add a section immediately after [afterSection] at the same tree level.
  Future<MdSection?> addSectionAfter({
    required MdSection afterSection,
    required int level,
    required String headline,
    String? id,
    String? text,
  }) async {
    final parent = _findParent(afterSection);
    final siblings = parent?.subsections ?? _document.sections;
    final idx = _indexIn(afterSection, siblings);
    return insertSection(
      parent: parent,
      index: idx >= 0 ? idx + 1 : siblings.length,
      level: level,
      headline: headline,
      id: id,
      text: text,
    );
  }

  /// Update the ID of a section.
  Future<void> updateSectionId(MdSection section, String? newId) async {
    try {
      MdEditorDebug.logger.info(
        'Updating section ID: "${section.id}" → "$newId"',
      );
      final oldMd = _markdown;
      section.id = newId;
      _rebuildMarkdown();
      _pushUndoWithStates(oldMd, _markdown, 'Set ID: ${section.headline}');
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error updating section ID', e, st);
    }
  }

  /// Update the comment metadata of a section.
  Future<void> updateCommentMetadata(
    MdSection section,
    Map<String, String> newMetadata,
  ) async {
    try {
      MdEditorDebug.logger.info(
        'Updating comment metadata for "${section.headline}"',
      );
      final oldMd = _markdown;
      section.commentMetadata = newMetadata;
      _rebuildMarkdown();
      _pushUndoWithStates(
        oldMd,
        _markdown,
        'Update metadata: ${section.headline}',
      );
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error updating comment metadata', e, st);
    }
  }

  /// Merge [section] with the next sibling at the same level.
  ///
  /// The merged section keeps the headline and ID of the first section.
  /// The body text of the second section (and its subsections' markdown) is
  /// appended to the first section's text.
  Future<void> mergeSectionWithNext(MdSection section) async {
    try {
      final parent = _findParent(section);
      final siblings = parent?.subsections ?? _document.sections;
      final idx = _indexIn(section, siblings);
      if (idx < 0 || idx + 1 >= siblings.length) return;

      final next = siblings[idx + 1];
      MdEditorDebug.logger.info(
        'Merging "${section.headline}" with "${next.headline}"',
      );
      final oldMd = _markdown;

      // Append the next section's full markdown (text + subsections) to
      // this section's text.
      final appendix = next.toMarkdown();
      final currentText = section.text;
      final separator = currentText.endsWith('\n') ? '\n' : '\n\n';
      section.text = '$currentText$separator$appendix';

      // Absorb the next section's direct subsections.
      section.subsections.addAll(next.subsections);
      siblings.removeAt(idx + 1);

      _rebuildMarkdown();
      _pushUndoWithStates(
        oldMd,
        _markdown,
        'Merge: ${section.headline} + ${next.headline}',
      );
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error merging sections', e, st);
    }
  }

  /// Compute the hierarchical numbering for a section (e.g. "1.2.3").
  String computeSectionNumber(MdSection target) {
    final path = <int>[];
    bool findPath(List<MdSection> siblings, MdSection t) {
      for (var i = 0; i < siblings.length; i++) {
        if (identical(siblings[i], t)) {
          path.add(i + 1);
          return true;
        }
        if (findPath(siblings[i].subsections, t)) {
          path.insert(0, i + 1);
          return true;
        }
      }
      return false;
    }
    findPath(_document.sections, target);
    return path.join('.');
  }

  /// Compute the full hierarchical ID chain for [target].
  ///
  /// Walks from the root to [target] collecting each ancestor's ID and
  /// joins them with `-`. Returns an empty string when no ancestor has an ID.
  String computeHierarchicalId(MdSection target) {
    final ids = <String>[];
    bool collect(List<MdSection> siblings, MdSection t) {
      for (final s in siblings) {
        if (identical(s, t)) {
          if (s.id != null) ids.add(s.id!);
          return true;
        }
        if (collect(s.subsections, t)) {
          if (s.id != null) ids.insert(0, s.id!);
          return true;
        }
      }
      return false;
    }
    collect(_document.sections, target);
    return ids.join('-');
  }

  /// Promote a section by decreasing its heading level (e.g. `###` → `##`).
  ///
  /// Level 1 is already the highest and cannot be promoted further.
  /// Subsections are adjusted proportionally.
  Future<void> promoteSection(MdSection section) async {
    try {
      if (section.level <= 1) return;
      MdEditorDebug.logger.info(
        'Promoting section: "${section.headline}" from level ${section.level}',
      );
      final oldMd = _markdown;
      _adjustLevels(section, -1);
      _rebuildMarkdown();
      _pushUndoWithStates(
        oldMd,
        _markdown,
        'Promote: ${section.headline}',
      );
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error promoting section', e, st);
    }
  }

  /// Demote a section by increasing its heading level (e.g. `##` → `###`).
  ///
  /// Level 6 is already the lowest and cannot be demoted further.
  /// Subsections are adjusted proportionally.
  Future<void> demoteSection(MdSection section) async {
    try {
      if (section.level >= 6) return;
      MdEditorDebug.logger.info(
        'Demoting section: "${section.headline}" from level ${section.level}',
      );
      final oldMd = _markdown;
      _adjustLevels(section, 1);
      _rebuildMarkdown();
      _pushUndoWithStates(
        oldMd,
        _markdown,
        'Demote: ${section.headline}',
      );
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error demoting section', e, st);
    }
  }

  /// Move a section up among its siblings.
  Future<void> moveSectionUp(MdSection section) async {
    try {
      final parent = _findParent(section);
      final siblings = parent?.subsections ?? _document.sections;
      final idx = _indexIn(section, siblings);
      if (idx <= 0) return;
      await moveSection(section, newParent: parent, newIndex: idx - 1);
    } catch (e, st) {
      MdEditorDebug.logger.error('Error moving section up', e, st);
    }
  }

  /// Move a section down among its siblings.
  Future<void> moveSectionDown(MdSection section) async {
    try {
      final parent = _findParent(section);
      final siblings = parent?.subsections ?? _document.sections;
      final idx = _indexIn(section, siblings);
      if (idx < 0 || idx >= siblings.length - 1) return;
      // After removal the target index is idx+1, but moveSection removes first
      // so the effective insert position is idx+1.
      await moveSection(section, newParent: parent, newIndex: idx + 1);
    } catch (e, st) {
      MdEditorDebug.logger.error('Error moving section down', e, st);
    }
  }

  // ── Undo / Redo ──

  /// Takes back the newest entry — typing a view still holds first — and
  /// puts the cursor where it was before the edit.
  void undo() {
    try {
      flush();
      if (_history.undo(_restore)) notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error during undo', e, st);
    }
  }

  /// Puts the newest undone entry back, the cursor where it was after it.
  void redo() {
    try {
      flush();
      if (_history.redo(_restore)) notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error during redo', e, st);
    }
  }

  /// Puts [state] back. The selected section stays selected: matched by
  /// headline and level, else — a rename undone — by its place.
  void _restore(ForgeTextState state) {
    final selected = _selectedSection;
    final index = selected == null
        ? -1
        : _document.allSections.indexWhere((s) => identical(s, selected));
    _setMarkdownInternal(state.text);
    _refreshSelectedSection();
    if (selected != null && _selectedSection == null && index >= 0) {
      final all = _document.allSections;
      if (index < all.length) _selectedSection = all[index];
    }
    _cursorOffset = state.selection.baseOffset.clamp(0, _markdown.length);
    cursorPositionNotifier.value = _cursorOffset;
    _saved.compare(_markdown);
  }

  // ── Search ──

  /// Search the document for a query.
  void search(String query, {bool caseSensitive = false, bool regex = false}) {
    try {
      if (query.isEmpty) {
        _searchResults = [];
        _currentSearchIndex = 0;
        notifyListeners();
        return;
      }

      MdEditorDebug.logger.info('Searching for: $query');
      final results = <MdSearchResult>[];
      final pattern =
          regex
              ? RegExp(query, caseSensitive: caseSensitive)
              : RegExp(
                RegExp.escape(query),
                caseSensitive: caseSensitive,
              );

      final lines = _markdown.split('\n');
      for (final match in pattern.allMatches(_markdown)) {
        // Find line number.
        var lineNum = 0;
        var charCount = 0;
        for (var i = 0; i < lines.length; i++) {
          if (charCount + lines[i].length >= match.start) {
            lineNum = i;
            break;
          }
          charCount += lines[i].length + 1; // +1 for newline
        }

        // Find containing section.
        var sectionHeadline = '(document)';
        for (final s in _document.allSections) {
          if (s.sourceLineStart != null && s.sourceLineStart! <= lineNum) {
            sectionHeadline = s.headline;
          }
        }

        // Extract context.
        final contextStart = (match.start - 20).clamp(0, _markdown.length);
        final contextEnd =
            (match.end + 20).clamp(0, _markdown.length);

        results.add(MdSearchResult(
          sectionHeadline: sectionHeadline,
          matchText: match.group(0)!,
          contextBefore: _markdown.substring(contextStart, match.start),
          contextAfter: _markdown.substring(match.end, contextEnd),
          lineNumber: lineNum,
          offset: match.start,
          length: match.end - match.start,
        ));
      }

      _searchResults = results;
      _currentSearchIndex = results.isNotEmpty ? 0 : -1;
      MdEditorDebug.logger.info('Found ${results.length} matches');
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error during search', e, st);
    }
  }

  /// Move to next search result.
  void nextSearchResult() {
    if (_searchResults.isEmpty) return;
    _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    notifyListeners();
  }

  /// Move to previous search result.
  void previousSearchResult() {
    if (_searchResults.isEmpty) return;
    _currentSearchIndex =
        (_currentSearchIndex - 1 + _searchResults.length) %
        _searchResults.length;
    notifyListeners();
  }

  /// Replace current search match.
  void replaceCurrentMatch(String replacement) {
    try {
      if (_searchResults.isEmpty || _currentSearchIndex < 0) return;
      final match = _searchResults[_currentSearchIndex];
      final oldMd = _markdown;
      final newMd =
          _markdown.substring(0, match.offset) +
          replacement +
          _markdown.substring(match.offset + match.length);
      _setMarkdownInternal(newMd);
      _pushUndoWithStates(oldMd, _markdown, 'Replace');
      notifyListeners();
    } catch (e, st) {
      MdEditorDebug.logger.error('Error replacing match', e, st);
    }
  }

  // ── Conversion ──

  /// Export to markdown string.
  String toMarkdown({bool preserveIds = true}) => _markdown;

  /// All sections as a flat list.
  List<MdSection> get allSections => _document.allSections;

  /// Find section by ID.
  MdSection? findSectionById(String id) => _document.findById(id);

  /// Find the parent of a section.
  MdSection? findParent(MdSection target) => _findParent(target);

  /// Find the index of a section among its siblings.
  int findIndex(MdSection target) => _findIndex(target);

  // ── Structural edits ──

  /// Changes the section tree as one history entry: [edit] changes
  /// [document]'s sections in place and answers whether it changed anything;
  /// the markdown is then written from the tree. What a plugin's structural
  /// edits go through (a schema's scaffolding, `tom_md_docspecs`).
  bool editStructure(
    String description,
    bool Function(MdDocument document) edit,
  ) {
    final oldMd = _markdown;
    if (!edit(_document)) return false;
    _rebuildMarkdown();
    _pushUndoWithStates(oldMd, _markdown, description);
    notifyListeners();
    return true;
  }

  /// Get validation errors for a specific section.
  List<ValidationError> getErrorsForSection(MdSection section) {
    final sectionId =
        section.id ?? section.headline.toLowerCase().replaceAll(' ', '-');
    return _validationErrors.where((e) {
      // Match by path (set by _convertError from sectionId)
      if (e.path.isNotEmpty) {
        final firstPath = e.path.first.toString().toLowerCase();
        if (firstPath == sectionId.toLowerCase()) return true;
        if (firstPath == section.headline.toLowerCase()) return true;
      }
      return false;
    }).toList();
  }

  // ── Private helpers ──

  void _setMarkdownInternal(String value) {
    _markdown = value;
    _document = MdParser.parse(value);
    _runSchemaValidation();
  }

  /// Re-resolve _selectedSection against the new document after re-parsing.
  void _refreshSelectedSection() {
    final old = _selectedSection;
    if (old == null) return;
    // Find the matching section by level + headline in the new document.
    final match = _document.allSections.where(
      (s) => s.level == old.level && s.headline == old.headline,
    );
    _selectedSection = match.isNotEmpty ? match.first : null;
  }

  /// Run schema validation against the current document.
  void _runSchemaValidation() {
    final support = _schemaSupport;
    if (support == null) return;
    try {
      _validationErrors
        ..clear()
        ..addAll(support.validate(_document));
      eventHandlers?.onValidationChanged?.call(
        ValidationChangedEvent(errors: validationErrors),
      );
    } catch (e, st) {
      MdEditorDebug.logger.error('Schema validation failed', e, st);
    }
  }

  void _rebuildMarkdown() {
    _markdown = MdParser.toMarkdown(_document);
    // Re-parse to update line numbers etc.
    _document = MdParser.parse(_markdown);
    _relinkSelectedSection();
    // Re-validate against schema so errors stay current after edits.
    _runSchemaValidation();
  }

  /// After re-parsing, the old _selectedSection is orphaned.
  /// Find the matching section in the new document tree by headline + level.
  void _relinkSelectedSection() {
    if (_selectedSection == null) return;
    final old = _selectedSection!;
    final allNew = _document.allSections;
    // Try exact match by headline and level.
    final match = allNew.where(
      (s) => s.headline == old.headline && s.level == old.level,
    );
    _selectedSection = match.isNotEmpty ? match.first : null;
  }

  /// Records an operation that changed the markdown from [oldMd] to [newMd]
  /// as its own history entry — none when it changed nothing.
  void _pushUndoWithStates(String oldMd, String newMd, String description) {
    _saved.compare(newMd);
    if (oldMd == newMd) return;
    _history.flush();
    _history.edited(
      ForgeTextState(
        newMd,
        TextSelection.collapsed(offset: _cursorOffset.clamp(0, newMd.length)),
      ),
    );
    _history.flush();
  }

  /// Records typing that changed the markdown from [oldMd] to what it is now,
  /// with the view's cursor at [cursor]: merged into the gesture in progress.
  void _recordTyping(String oldMd, int? cursor) {
    _saved.compare(_markdown);
    if (oldMd == _markdown) return;
    if (cursor != null) {
      _cursorOffset = cursor.clamp(0, _markdown.length);
      cursorPositionNotifier.value = _cursorOffset;
    }
    _history.edited(
      ForgeTextState(
        _markdown,
        TextSelection.collapsed(offset: _cursorOffset.clamp(0, _markdown.length)),
      ),
    );
  }

  bool _removeSectionFromTree(MdSection section, List<MdSection> siblings) {
    for (var i = 0; i < siblings.length; i++) {
      if (identical(siblings[i], section)) {
        siblings.removeAt(i);
        return true;
      }
      if (_removeSectionFromTree(section, siblings[i].subsections)) {
        return true;
      }
    }
    return false;
  }

  MdSection? _findParent(MdSection target) {
    MdSection? findIn(List<MdSection> siblings, MdSection? parent) {
      for (final s in siblings) {
        if (identical(s, target)) return parent;
        final found = findIn(s.subsections, s);
        if (found != null) return found;
      }
      return null;
    }
    return findIn(_document.sections, null);
  }

  int _findIndex(MdSection target) {
    final parent = _findParent(target);
    final siblings = parent?.subsections ?? _document.sections;
    return _indexIn(target, siblings);
  }

  int _indexIn(MdSection target, List<MdSection> siblings) {
    for (var i = 0; i < siblings.length; i++) {
      if (identical(siblings[i], target)) return i;
    }
    return -1;
  }

  /// Adjust heading level of [section] and all descendants by [delta].
  void _adjustLevels(MdSection section, int delta) {
    section.level = (section.level + delta).clamp(1, 6);
    for (final sub in section.subsections) {
      _adjustLevels(sub, delta);
    }
  }

  /// Format a section name from kebab-case to title case.
  /// Export the document as a JSON map for serialization.
  ///
  /// Structure: `{ title, sections: [ { id, headline, level, text, subsections } ] }`
  Map<String, dynamic> toJson() {
    Map<String, dynamic> sectionToJson(MdSection s) {
      return {
        'id': s.id,
        'headline': s.headline,
        'level': s.level,
        'text': s.text,
        if (s.subsections.isNotEmpty)
          'subsections': s.subsections.map(sectionToJson).toList(),
      };
    }

    return {
      if (_document.title != null) 'title': _document.title,
      'sections': _document.sections.map(sectionToJson).toList(),
    };
  }

  /// Export markdown with optional whitespace normalization.
  ///
  /// When [normalizeWhitespace] is true, collapses multiple blank lines
  /// and trims trailing whitespace from each line.
  String toMarkdownString({bool normalizeWhitespace = false}) {
    final md = _markdown;
    if (!normalizeWhitespace) return md;
    final lines = md.split('\n').map((l) => l.trimRight());
    final buf = StringBuffer();
    var prevBlank = false;
    for (final line in lines) {
      final isBlank = line.isEmpty;
      if (isBlank && prevBlank) continue;
      buf.writeln(line);
      prevBlank = isBlank;
    }
    return buf.toString().trimRight();
  }
}
