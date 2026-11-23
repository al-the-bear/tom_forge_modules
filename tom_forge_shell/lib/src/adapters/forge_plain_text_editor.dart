import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_file_session/tom_file_session.dart';
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';

import '../module/forge_module.dart';
import 'tom_forge_shell_module.dart';

/// Adapter that provides a plain text editor for unknown file types.
///
/// The file is a [ForgeFileSession]: its text, its one history (typing
/// merged per burst, a caret move or a blur ending the burst), dirty as the
/// text against the saved text, the encoding it was read in, and a save that
/// checks the disk first and never writes over a file changed elsewhere. The
/// editor saves its own file (Forge's owned-save path), so the shell writes
/// nothing for it. Every view — the main view and a split copy — edits the
/// one session.
class ForgePlainTextEditor extends ForgeTextEditor
    implements ForgeEditorOfType {
  @override
  String get editorTypeId => 'plaintext';

  /// The file this editor edits.
  final ForgeFileSession session;
  final ForgeModule _module;
  final _title = ValueNotifier<String>('Text');
  final _titleExtension = ValueNotifier<String?>(null);
  final _isDirty = ValueNotifier<bool>(false);
  final _cursorPos = ValueNotifier<ForgeTextPosition>(const ForgeTextPosition.zero());
  final _selection = ValueNotifier<ForgeTextRange?>(null);
  final _selections = ValueNotifier<List<ForgeTextRange>>([]);
  final _visibleRange =
      ValueNotifier<ForgeTextRange>(const ForgeTextRange.empty());
  final _stateChanged = StreamController<void>.broadcast();

  /// A selection the editor's API asks the views to show (an offset range).
  final _requestedSelection = ValueNotifier<TextSelection?>(null);

  late PositionConverter _positionConverter;
  late final _PlainTextForgeDocument _document;
  ForgeTextEditorOptions _options;
  ShellEditorIntegration? _integration;
  VoidCallback? _stopFollowingDepth;
  Timer? _typingPause;
  String _lastText;

  /// Decoration state.
  final Map<String, List<ForgeDecorationRange>> _decorationMap = {};

  /// Creates an editor over [session] (loading or loaded).
  ForgePlainTextEditor({
    required this.session,
    required ForgeModule module,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(
      fontFamily: 'monospace',
    ),
  })  : _module = module,
        _options = options,
        _lastText = session.text {
    _positionConverter = PositionConverter(session.text);
    _document = _PlainTextForgeDocument(session.uri, this, _positionConverter);
    session.addListener(_onSessionChanged);
    final segments = session.uri.pathSegments;
    if (segments.isNotEmpty) _title.value = segments.last;
  }

  /// An editor for the file at [uri] in [fileSystem]; the file is read now.
  factory ForgePlainTextEditor.forFile({
    required TomFileSystem fileSystem,
    required Uri uri,
    required ForgeModule module,
  }) {
    final path = fileSystem.pathOf(uri);
    if (path == null) {
      throw ArgumentError.value(uri, 'uri', 'is outside the file system');
    }
    final session = ForgeFileSession(fileSystem: fileSystem, path: path);
    unawaited(session.load());
    return ForgePlainTextEditor(session: session, module: module);
  }

  /// An editor for [content] that lives in memory under [uri]'s name — an
  /// untitled buffer, a file outside the workspace, a test.
  factory ForgePlainTextEditor.fromContent({
    required String content,
    required Uri uri,
    required ForgeModule module,
  }) {
    final name =
        uri.pathSegments.isEmpty ? 'untitled.txt' : uri.pathSegments.last;
    final fileSystem = TomMemoryFileSystem(seed: {name: content});
    final session = ForgeFileSession(fileSystem: fileSystem, path: name)
      ..adoptText(content);
    return ForgePlainTextEditor(session: session, module: module);
  }

  /// Known plain text file extensions.
  static bool isPlainTextExtension(String extension) {
    const plainTextExtensions = {
      'txt', 'text', 'log', 'cfg', 'conf', 'ini', 'env', 'sh', 'bash',
      'zsh', 'fish', 'ps1', 'bat', 'cmd', 'gitignore', 'gitattributes',
      'editorconfig', 'properties', 'toml', 'dockerfile', 'makefile',
      'license', 'readme', 'changelog', 'todo', 'authors', 'contributors',
    };
    return plainTextExtensions.contains(extension.toLowerCase());
  }

  // ── ForgeComponent ──

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => const IconData(0xe873, fontFamily: 'MaterialIcons'); // text_snippet

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  ForgeModule get module => _module;

  // ── EditorActionProvider ──

  @override
  Set<String> get supportedActionIds => const {
    StandardEditingActions.undoActionId,
    StandardEditingActions.redoActionId,
    StandardEditingActions.saveActionId,
  };

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
    hasTextBuffer: true,
    supportsUndoRedo: true,
    supportsClipboard: false,
    supportsLineEditing: false,
    supportsSelection: true,
  );

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
    hasSelection: hasSelection,
    hasContent: session.text.isNotEmpty,
    isEditable: session.readOnlyReason == null,
    canUndo: session.canUndo,
    canRedo: session.canRedo,
    isTextMode: true,
  );

  @override
  bool isActionEnabled(String actionId) => switch (actionId) {
    StandardEditingActions.undoActionId => session.canUndo,
    StandardEditingActions.redoActionId => session.canRedo,
    StandardEditingActions.saveActionId =>
      session.state == ForgeFileSessionState.ready &&
          session.readOnlyReason == null,
    _ => false,
  };

  @override
  bool executeAction(String actionId) {
    if (!isActionEnabled(actionId)) return false;
    switch (actionId) {
      case StandardEditingActions.undoActionId:
        unawaited(session.undo());
      case StandardEditingActions.redoActionId:
        unawaited(session.redo());
      case StandardEditingActions.saveActionId:
        unawaited(_save());
    }
    return true;
  }

  /// Saves through the session; a file changed on disk is not written over —
  /// the view then asks the user to keep their text or take the disk's.
  Future<void> _save() async {
    final outcome = await session.save();
    if (outcome == ForgeFileSaveOutcome.conflict) _stateChanged.add(null);
  }

  @override
  Stream<void> get onStateChanged => _stateChanged.stream;

  @override
  Widget buildMain(BuildContext context) {
    if (_module case final TomForgeShellModule shellModule) {
      _integration ??= ShellEditorIntegration(
        shellApi: shellModule.shellApi,
        editorId: 'plaintext-editor-${uri.hashCode}',
        editorTypeId: 'plaintext',
      )..descriptors = StandardEditingActions.descriptors;
      // The one undo depth setting bounds the session's history.
      _stopFollowingDepth ??= forgeFollowUndoDepth(
        _integration!,
        (depth) => session.historyDepth = depth,
      );
    }
    final ext = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last.split('.').last.toLowerCase()
        : '';
    return _PlainTextEditorWidget(
      editor: this,
      fileExtension: ext,
      integration: _integration,
    );
  }

  /// A split copy edits the same session: one text, one history.
  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  /// Content from outside (a revision restore): the session adopts it as the
  /// saved text and clears the history; every view shows it.
  @override
  bool replaceContent(String content) {
    session.adoptText(content);
    return true;
  }

  // ── ForgeEditor ──

  @override
  Uri get uri => session.uri;

  @override
  FileHandlingResult canHandle(Uri uri) {
    // Plain text editor is a fallback, so it rejects by default.
    // It should only be used explicitly via the layout controller.
    return FileHandlingResult.reject;
  }

  /// The session's text against its saved text: clicking, scrolling or
  /// selecting never makes it dirty, and undoing back to the saved text makes
  /// it clean.
  @override
  ValueListenable<bool> get isDirty => _isDirty;

  /// The editor saves its own file ([StandardEditingActions.saveActionId]);
  /// the shell never marks it clean, so there is nothing to do here.
  @override
  void markClean() {}

  /// Null: the editor saves its own file through the session, keeping its
  /// encoding and checking the disk first.
  @override
  String? getContent() => null;

  @override
  Map<String, dynamic>? saveState() {
    final cursor = _cursorPos.value;
    final sel = _selection.value;
    final visible = _visibleRange.value;
    return {
      'cursorLine': cursor.line,
      'cursorColumn': cursor.column,
      if (sel != null) 'selection': {
        'startLine': sel.start.line,
        'startColumn': sel.start.column,
        'endLine': sel.end.line,
        'endColumn': sel.end.column,
      },
      'visibleStartLine': visible.start.line,
      'visibleEndLine': visible.end.line,
    };
  }

  @override
  void restoreState(Map<String, dynamic> state) {
    final line = state['cursorLine'] as int?;
    final col = state['cursorColumn'] as int?;
    if (line != null && col != null) {
      setCursorPosition(ForgeTextPosition(line: line, column: col));
    }
    final selMap = state['selection'] as Map<String, dynamic>?;
    if (selMap != null) {
      setSelection(ForgeTextRange(
        start: ForgeTextPosition(
          line: selMap['startLine'] as int,
          column: selMap['startColumn'] as int,
        ),
        end: ForgeTextPosition(
          line: selMap['endLine'] as int,
          column: selMap['endColumn'] as int,
        ),
      ));
    }
  }

  // ── ForgeTextEditor ──

  @override
  ForgeDocument get document => _document;

  @override
  ValueListenable<ForgeTextPosition> get cursorPosition => _cursorPos;

  @override
  ValueListenable<ForgeTextRange?> get selection => _selection;

  @override
  ValueListenable<List<ForgeTextRange>> get selections => _selections;

  @override
  void setSelections(List<ForgeTextRange> ranges) {
    _selections.value = List.unmodifiable(ranges);
    if (ranges.isNotEmpty) {
      setSelection(ranges.first);
    } else {
      _selection.value = null;
    }
  }

  @override
  String get selectedText {
    final sel = _selection.value;
    if (sel == null || sel.isEmpty) return '';
    final text = session.text;
    final startOffset = _positionConverter.positionToOffset(sel.start);
    final endOffset = _positionConverter.positionToOffset(sel.end);
    if (startOffset < 0 || endOffset > text.length) return '';
    return text.substring(startOffset, endOffset);
  }

  @override
  bool get hasSelection {
    final sel = _selection.value;
    return sel != null && !sel.isEmpty;
  }

  @override
  ValueListenable<ForgeTextRange> get visibleRange => _visibleRange;

  /// A programmatic edit: its own history entry.
  void _applyEdit(String text, {int? caret}) {
    session.endGesture();
    session.edit(text, 'Edit');
    session.endGesture();
    if (caret != null) {
      _requestedSelection.value = TextSelection.collapsed(offset: caret);
    }
  }

  @override
  void insertText(String text) {
    final code = session.text;
    final offset = _positionConverter.positionToOffset(_cursorPos.value);
    _applyEdit(
      code.substring(0, offset) + text + code.substring(offset),
      caret: offset + text.length,
    );
  }

  @override
  void replaceRange(ForgeTextRange range, String replacement) {
    final startOffset = _positionConverter.positionToOffset(range.start);
    final endOffset = _positionConverter.positionToOffset(range.end);
    final current = session.text;
    _applyEdit(
      current.substring(0, startOffset) +
          replacement +
          current.substring(endOffset),
      caret: startOffset + replacement.length,
    );
  }

  @override
  void deleteRange(ForgeTextRange range) => replaceRange(range, '');

  @override
  void setCursorPosition(ForgeTextPosition position) {
    final offset = _positionConverter.positionToOffset(position);
    _requestedSelection.value = TextSelection.collapsed(offset: offset);
  }

  @override
  void setSelection(ForgeTextRange range) {
    _requestedSelection.value = TextSelection(
      baseOffset: _positionConverter.positionToOffset(range.start),
      extentOffset: _positionConverter.positionToOffset(range.end),
    );
  }

  @override
  void selectAll() {
    _requestedSelection.value = TextSelection(
      baseOffset: 0,
      extentOffset: session.text.length,
    );
  }

  @override
  void revealPosition(ForgeTextPosition position) => setCursorPosition(position);

  @override
  void revealRange(ForgeTextRange range) => setSelection(range);

  @override
  List<ForgeTextRange> findAll(Pattern pattern) {
    final text = session.text;
    return pattern.allMatches(text).map((m) {
      return ForgeTextRange(
        start: _positionConverter.offsetToPosition(m.start),
        end: _positionConverter.offsetToPosition(m.end),
      );
    }).toList();
  }

  @override
  int replaceAll(Pattern pattern, String replacement) {
    final text = session.text;
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) return 0;
    // Apply replacements in reverse order.
    var result = text;
    for (final m in matches.reversed) {
      result =
          result.substring(0, m.start) + replacement + result.substring(m.end);
    }
    _applyEdit(result);
    return matches.length;
  }

  @override
  ForgeTextEditorOptions get options => _options;

  @override
  void updateOptions(ForgeTextEditorOptions options) => _options = options;

  @override
  void setDecorations(
      ForgeDecorationType type, List<ForgeDecorationRange> ranges) {
    _decorationMap[type.key] = List.unmodifiable(ranges);
  }

  @override
  void clearDecorations(ForgeDecorationType type) {
    _decorationMap.remove(type.key);
  }

  // ── The views report ──

  /// A view typed: one burst until the typing pause ends it (or a caret
  /// move, a blur, an undo).
  void _typed(String text) {
    session.edit(text, 'Typing', group: 'typing');
    _typingPause?.cancel();
    _typingPause = Timer(forgeTypingPause, session.endGesture);
  }

  /// A view's selection changed (its text is the session's).
  void _viewSelected(TextSelection selection) {
    _positionConverter = PositionConverter(session.text);
    _cursorPos.value = _positionConverter.offsetToPosition(
      selection.extentOffset.clamp(0, session.text.length),
    );
    if (selection.isCollapsed) {
      _selection.value = null;
      _selections.value = [];
    } else {
      final range = ForgeTextRange(
        start: _positionConverter.offsetToPosition(selection.start),
        end: _positionConverter.offsetToPosition(selection.end),
      );
      _selection.value = range;
      _selections.value = [range];
    }
    _stateChanged.add(null);
  }

  void _onSessionChanged() {
    _isDirty.value = session.dirty;
    if (session.text != _lastText) {
      _lastText = session.text;
      _positionConverter = PositionConverter(session.text);
      _document.updateConverter(_positionConverter);
      _document.notifyContentChanged();
    }
    _stateChanged.add(null);
  }

  /// Release listeners.
  void dispose() {
    _stopFollowingDepth?.call();
    _typingPause?.cancel();
    session.removeListener(_onSessionChanged);
    session.dispose();
    _integration?.dispose();
    _document.dispose();
    _stateChanged.close();
    _requestedSelection.dispose();
    _title.dispose();
    _titleExtension.dispose();
    _isDirty.dispose();
    _cursorPos.dispose();
    _selection.dispose();
    _selections.dispose();
    _visibleRange.dispose();
  }
}

/// [ForgeDocument] backed by the editor's session.
class _PlainTextForgeDocument extends ForgeDocumentAdapter {
  final ForgePlainTextEditor _editor;
  PositionConverter _converter;

  _PlainTextForgeDocument(super.uri, this._editor, this._converter);

  /// Update the position converter after content changes.
  void updateConverter(PositionConverter converter) {
    _converter = converter;
  }

  /// Notify that the document content has changed.
  void notifyContentChanged() {
    markDirty();
    fireChange([]);
  }

  @override
  String get text => _editor.session.text;

  @override
  int get lineCount => _converter.lineCount;

  @override
  String lineAt(int line) => _converter.lineAt(line);

  @override
  String textInRange(ForgeTextRange range) => _converter.textInRange(range);

  @override
  String get languageId => 'plaintext';

  @override
  Encoding get encoding => utf8;

  @override
  bool get isUntitled => _editor.session.fileSystem is TomMemoryFileSystem;
}

// ──────────────────────────────────────────────────────────────────
// Plain text editor widget with syntax-aware colorization
// ──────────────────────────────────────────────────────────────────

/// Intent for plain text editor shortcut actions.
class _PlainTextActionIntent extends Intent {
  final String actionId;
  const _PlainTextActionIntent(this.actionId);
}

/// A view of the editor's session: line numbers and optional syntax
/// highlighting for common file formats (JSON, XML, etc.).
class _PlainTextEditorWidget extends StatefulWidget {
  final ForgePlainTextEditor editor;
  final String fileExtension;
  final ForgeEditorIntegration? integration;

  const _PlainTextEditorWidget({
    required this.editor,
    required this.fileExtension,
    this.integration,
  });

  @override
  State<_PlainTextEditorWidget> createState() => _PlainTextEditorWidgetState();
}

class _PlainTextEditorWidgetState extends State<_PlainTextEditorWidget> {
  late _HighlightTextController _textController;
  late ScrollController _scrollController;
  late ScrollController _gutterScrollController;
  final FocusNode _focusNode = FocusNode();

  /// True while this view shows text the session already has.
  bool _syncing = false;

  // Shortcuts map
  Map<ShortcutActivator, Intent> _shortcuts = {};

  ForgeFileSession get _session => widget.editor.session;

  @override
  void initState() {
    super.initState();
    _textController = _HighlightTextController(
      text: _session.text,
      language: widget.fileExtension,
    );
    _scrollController = ScrollController();
    _gutterScrollController = ScrollController();
    _scrollController.addListener(_syncScroll);
    _textController.addListener(_onFieldChanged);
    _session.addListener(_onSessionChanged);
    widget.editor._requestedSelection.addListener(_onSelectionRequested);
    _focusNode.addListener(_onFocusChanged);
    _registerActions();
  }

  void _registerActions() {
    final integration = widget.integration;
    if (integration == null) return;
    integration.registerAction(
      StandardEditingActions.undoActionId,
      () => widget.editor.executeAction(StandardEditingActions.undoActionId),
      isEnabled: () => _session.canUndo,
    );
    integration.registerAction(
      StandardEditingActions.redoActionId,
      () => widget.editor.executeAction(StandardEditingActions.redoActionId),
      isEnabled: () => _session.canRedo,
    );
    _buildShortcutMap();
    integration.shortcutBindings.addListener(_onBindingsChanged);
  }

  /// The local key map from the integration's bindings — the shell's
  /// binding table — through [buildEditorShortcutMap]; above EditableText,
  /// so the undo and redo keys reach the session's history.
  void _buildShortcutMap() {
    final integration = widget.integration;
    _shortcuts = integration == null
        ? <ShortcutActivator, Intent>{}
        : {
            for (final entry in buildEditorShortcutMap(integration).entries)
              entry.key: _PlainTextActionIntent(entry.value),
          };
  }

  void _onBindingsChanged() {
    if (mounted) setState(_buildShortcutMap);
  }

  @override
  void dispose() {
    widget.integration?.shortcutBindings.removeListener(_onBindingsChanged);
    _session.removeListener(_onSessionChanged);
    widget.editor._requestedSelection.removeListener(_onSelectionRequested);
    _focusNode.removeListener(_onFocusChanged);
    _textController.removeListener(_onFieldChanged);
    _scrollController.removeListener(_syncScroll);
    _textController.dispose();
    _scrollController.dispose();
    _gutterScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncScroll() {
    if (_gutterScrollController.hasClients) {
      _gutterScrollController.jumpTo(_scrollController.offset);
    }
  }

  /// The field changed: typing goes into the session as one burst; a caret
  /// move ends the burst and is reported to the editor — and never makes
  /// the file dirty.
  void _onFieldChanged() {
    if (_syncing) return;
    final text = _textController.text;
    if (text != _session.text) {
      if (_session.readOnlyReason != null ||
          _session.state != ForgeFileSessionState.ready) {
        _show(_session.text, _textController.selection);
        return;
      }
      widget.editor._typed(text);
    } else {
      _session.endGesture();
    }
    widget.editor._viewSelected(_textController.selection);
  }

  /// The session changed — loaded, undone, redone, edited in another view,
  /// adopted: show its text, the caret at the change.
  void _onSessionChanged() {
    final text = _session.text;
    if (text != _textController.text) {
      _show(text, forgeCaretAtChange(_textController.text, text));
    }
    if (mounted) setState(() {});
  }

  void _onSelectionRequested() {
    final selection = widget.editor._requestedSelection.value;
    if (selection == null) return;
    final length = _textController.text.length;
    if (selection.end > length) return;
    _textController.selection = selection;
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _session.endGesture();
  }

  void _show(String text, TextSelection selection) {
    _syncing = true;
    _textController.value = TextEditingValue(
      text: text,
      selection: selection.end <= text.length
          ? selection
          : TextSelection.collapsed(offset: text.length),
    );
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
    );

    switch (_session.state) {
      case ForgeFileSessionState.loading:
        return const Center(child: CircularProgressIndicator());
      case ForgeFileSessionState.missing:
        return const Center(child: Text('This file does not exist.'));
      case ForgeFileSessionState.refused:
        return Center(child: Text(_session.refusal ?? 'Not opened.'));
      case ForgeFileSessionState.ready:
        break;
    }

    final lineCount = '\n'.allMatches(_textController.text).length + 1;

    Widget editor = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line number gutter
        SizedBox(
          width: 52,
          child: ListView.builder(
            controller: _gutterScrollController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lineCount,
            itemBuilder: (context, index) {
              return SizedBox(
                height: monoStyle.fontSize! * monoStyle.height!,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${index + 1}',
                      style: monoStyle.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        // Text editor: the session keeps the history; Flutter's own text
        // undo is off.
        Expanded(
          child: ForgeEditorOwnsUndo(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              scrollController: _scrollController,
              readOnly: _session.readOnlyReason != null,
              maxLines: null,
              expands: true,
              style: monoStyle.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );

    if (_shortcuts.isNotEmpty) {
      editor = Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            _PlainTextActionIntent:
                CallbackAction<_PlainTextActionIntent>(
              onInvoke: (intent) {
                widget.integration?.executeAction(intent.actionId);
                return null;
              },
            ),
          },
          child: editor,
        ),
      );
    }

    final external = _session.external;
    final notice = _session.readOnlyReason;
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(notice, style: theme.textTheme.bodySmall),
            ),
          if (external != null)
            // The file changed on disk while there are unsaved edits: the
            // user chooses; nothing is written over the other change.
            Material(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        external.deleted
                            ? 'This file was deleted on disk.'
                            : 'This file changed on disk.',
                      ),
                    ),
                    TextButton(
                      onPressed: _session.keepMine,
                      child: const Text('Keep mine'),
                    ),
                    if (!external.deleted)
                      TextButton(
                        onPressed: _session.takeTheirs,
                        child: const Text('Take theirs'),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(child: editor),
        ],
      ),
    );
  }
}

/// A [TextEditingController] that applies syntax highlighting via
/// [buildTextSpan] based on the file type.
class _HighlightTextController extends TextEditingController {
  final String language;

  _HighlightTextController({
    required String text,
    required this.language,
  }) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final rules = _rulesForLanguage(language);
    if (rules.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final isDark =
        Theme.of(context).colorScheme.brightness == Brightness.dark;
    final spans = _buildHighlightedSpans(text, rules, style, isDark);
    return TextSpan(children: spans, style: style);
  }

  static List<_HighlightRule> _rulesForLanguage(String lang) {
    return switch (lang) {
      'json' => _jsonRules,
      'xml' || 'html' || 'svg' || 'xhtml' => _xmlRules,
      'css' => _cssRules,
      'sql' => _sqlRules,
      _ => const [],
    };
  }

  static List<TextSpan> _buildHighlightedSpans(
    String text,
    List<_HighlightRule> rules,
    TextStyle? baseStyle,
    bool isDark,
  ) {
    // Build colored regions from regex matches.
    final regions = <_Region>[];
    for (final rule in rules) {
      for (final match in rule.pattern.allMatches(text)) {
        regions.add(_Region(match.start, match.end, rule.colorDark(isDark)));
      }
    }
    regions.sort((a, b) => a.start.compareTo(b.start));

    // Merge into non-overlapping TextSpans.
    final spans = <TextSpan>[];
    var pos = 0;
    for (final region in regions) {
      if (region.start < pos) continue; // skip overlapping
      if (region.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, region.start)));
      }
      spans.add(TextSpan(
        text: text.substring(region.start, region.end),
        style: TextStyle(color: region.color),
      ));
      pos = region.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    return spans;
  }

  // ── JSON rules ──
  static final _jsonRules = <_HighlightRule>[
    _HighlightRule(
      RegExp(r'//.*$', multiLine: true),
      dark: const Color(0xFF7F848E),
      light: const Color(0xFF6A737D),
    ),
    _HighlightRule(
      RegExp(r'"(?:[^"\\]|\\.)*"\s*(?=:)'),
      dark: const Color(0xFF7DCFFF),
      light: const Color(0xFF005CC5),
    ),
    _HighlightRule(
      RegExp(r'"(?:[^"\\]|\\.)*"'),
      dark: const Color(0xFF98C379),
      light: const Color(0xFF116329),
    ),
    _HighlightRule(
      RegExp(r'\b(?:true|false|null)\b'),
      dark: const Color(0xFF56B6C2),
      light: const Color(0xFF1B7F83),
    ),
    _HighlightRule(
      RegExp(r'-?\b\d+\.?\d*(?:[eE][+-]?\d+)?\b'),
      dark: const Color(0xFFD19A66),
      light: const Color(0xFF9A6700),
    ),
  ];

  // ── XML rules ──
  static final _xmlRules = <_HighlightRule>[
    _HighlightRule(
      RegExp(r'<!--[\s\S]*?-->'),
      dark: const Color(0xFF7F848E),
      light: const Color(0xFF6A737D),
    ),
    _HighlightRule(
      RegExp(r'</?[\w:-]+'),
      dark: const Color(0xFFC678DD),
      light: const Color(0xFF6F42C1),
    ),
    _HighlightRule(
      RegExp(r'\b[\w:-]+(?==)'),
      dark: const Color(0xFF7DCFFF),
      light: const Color(0xFF005CC5),
    ),
    _HighlightRule(
      RegExp(r'"[^"]*"|' "'" r"[^']*'"),
      dark: const Color(0xFF98C379),
      light: const Color(0xFF116329),
    ),
    _HighlightRule(
      RegExp(r'/?>'),
      dark: const Color(0xFFC678DD),
      light: const Color(0xFF6F42C1),
    ),
  ];

  // ── CSS rules ──
  static final _cssRules = <_HighlightRule>[
    _HighlightRule(
      RegExp(r'/\*[\s\S]*?\*/'),
      dark: const Color(0xFF7F848E),
      light: const Color(0xFF6A737D),
    ),
    _HighlightRule(
      RegExp(r'[.#][\w-]+'),
      dark: const Color(0xFFC678DD),
      light: const Color(0xFF6F42C1),
    ),
    _HighlightRule(
      RegExp(r'[\w-]+(?=\s*:)'),
      dark: const Color(0xFF7DCFFF),
      light: const Color(0xFF005CC5),
    ),
    _HighlightRule(
      RegExp(r'"[^"]*"|' "'" r"[^']*'"),
      dark: const Color(0xFF98C379),
      light: const Color(0xFF116329),
    ),
    _HighlightRule(
      RegExp(r'-?\b\d+\.?\d*(?:px|em|rem|%|vh|vw|s|ms)?\b'),
      dark: const Color(0xFFD19A66),
      light: const Color(0xFF9A6700),
    ),
  ];

  // ── SQL rules ──
  static final _sqlRules = <_HighlightRule>[
    _HighlightRule(
      RegExp(r'--.*$', multiLine: true),
      dark: const Color(0xFF7F848E),
      light: const Color(0xFF6A737D),
    ),
    _HighlightRule(
      RegExp(
        r'\b(?:SELECT|FROM|WHERE|INSERT|INTO|UPDATE|SET|DELETE|CREATE|DROP|'
        r'ALTER|TABLE|INDEX|VIEW|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|NOT|'
        r'NULL|IS|IN|LIKE|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|AS|DISTINCT|'
        r'COUNT|SUM|AVG|MIN|MAX|VALUES|PRIMARY|KEY|FOREIGN|REFERENCES|'
        r'CONSTRAINT|EXISTS|UNION|ALL|CASE|WHEN|THEN|ELSE|END|BEGIN|'
        r'COMMIT|ROLLBACK)\b',
        caseSensitive: false,
      ),
      dark: const Color(0xFFC678DD),
      light: const Color(0xFF6F42C1),
    ),
    _HighlightRule(
      RegExp(r"'(?:[^'\\]|\\.)*'"),
      dark: const Color(0xFF98C379),
      light: const Color(0xFF116329),
    ),
    _HighlightRule(
      RegExp(r'-?\b\d+\.?\d*\b'),
      dark: const Color(0xFFD19A66),
      light: const Color(0xFF9A6700),
    ),
  ];
}

class _HighlightRule {
  final RegExp pattern;
  final Color _dark;
  final Color _light;

  const _HighlightRule(this.pattern, {required Color dark, required Color light})
      : _dark = dark,
        _light = light;

  Color colorDark(bool isDark) => isDark ? _dark : _light;
}

class _Region {
  final int start;
  final int end;
  final Color color;
  const _Region(this.start, this.end, this.color);
}
