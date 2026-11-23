import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_file_editors/tom_file_editors.dart'
    show TomFileEditorHost, TomTextFileEditor;
import 'package:tom_file_system/tom_file_system.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart';
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show ForgeSessionFileFrame;

import 'plain_text_highlighter.dart';

/// Any text file Forge has no other editor for, in tom_file_editors' text
/// file editor ([TomTextFileEditor]), as a Forge text editor over the kit.
///
/// The file is a [ForgeFileSession]: its text, its one history (typing
/// merged per burst — a caret move, leaving the source or the typing pause
/// ends the burst), dirty as the text against the saved text, the encoding
/// and line endings it was read in (the header names both), and a save that
/// checks the disk first and never writes over a file changed elsewhere
/// ([ForgeSessionFileFrame] offers Keep mine / Take theirs). The editor saves
/// its own file, so the application writes nothing for it. Every view — the
/// main view and a split copy — edits the one session.
///
/// With the application's [ForgeKitApi] (given as `api:`, else the one its
/// module was activated with, [forgeKitApiOf]) the undo, redo and save
/// actions and their keys go through the application's binding table
/// (`ShellEditorIntegration`), the application's find bar searches the text
/// ([findAll], [revealRange]) and the undo depth setting bounds the history;
/// without one the source answers the undo and redo keys and its own find
/// key itself.
class ForgePlainTextEditor extends ForgeTextEditor
    implements ForgeEditorOfType {
  /// Creates an editor over [session] (loading or loaded).
  ForgePlainTextEditor({
    required this.session,
    required ForgeKitModule module,
    ForgeKitApi? api,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(
      fontFamily: 'monospace',
    ),
  }) : _module = module,
       _api = api,
       _options = options,
       _lastText = session.text {
    _positionConverter = PositionConverter(session.text);
    _document = _PlainTextForgeDocument(session.uri, this, _positionConverter);
    _file = ForgeSessionFile(
      session: session,
      // The session is the editor's text: nothing to adopt or mark.
      textOf: () => session.text,
      adopt: (_) {},
      markSaved: () {},
    );
    session.addListener(_onSessionChanged);
    final segments = session.uri.pathSegments;
    if (segments.isNotEmpty) _title.value = segments.last;
    _isDirty.value = session.dirty;
  }

  /// An editor for the file at [uri] in [fileSystem]; the file is read now.
  factory ForgePlainTextEditor.forFile({
    required TomFileSystem fileSystem,
    required Uri uri,
    required ForgeKitModule module,
    ForgeKitApi? api,
  }) {
    final path = fileSystem.pathOf(uri);
    if (path == null) {
      throw ArgumentError.value(uri, 'uri', 'is outside the file system');
    }
    final session = ForgeFileSession(fileSystem: fileSystem, path: path);
    unawaited(session.load());
    return ForgePlainTextEditor(session: session, module: module, api: api);
  }

  /// An editor for [content] that lives in memory under [uri]'s name — an
  /// untitled buffer, a file outside the workspace, a test.
  factory ForgePlainTextEditor.fromContent({
    required String content,
    required Uri uri,
    required ForgeKitModule module,
    ForgeKitApi? api,
  }) {
    final name = uri.pathSegments.isEmpty
        ? 'untitled.txt'
        : uri.pathSegments.last;
    final fileSystem = TomMemoryFileSystem(seed: {name: content});
    final session = ForgeFileSession(fileSystem: fileSystem, path: name)
      ..adoptText(content);
    return ForgePlainTextEditor(session: session, module: module, api: api);
  }

  /// The editor type id: the text settings, the action bar and **Open With**
  /// know the editor by it.
  static const String typeId = 'plaintext';

  /// Known plain text file extensions.
  static bool isPlainTextExtension(String extension) {
    const plainTextExtensions = {
      'txt', 'text', 'log', 'cfg', 'conf', 'ini', 'env', 'sh', 'bash', //
      'zsh', 'fish', 'ps1', 'bat', 'cmd', 'gitignore', 'gitattributes',
      'editorconfig', 'properties', 'toml', 'dockerfile', 'makefile',
      'license', 'readme', 'changelog', 'todo', 'authors', 'contributors',
    };
    return plainTextExtensions.contains(extension.toLowerCase());
  }

  @override
  String get editorTypeId => typeId;

  /// The file this editor edits.
  final ForgeFileSession session;
  final ForgeKitModule _module;
  final ForgeKitApi? _api;
  final _title = ValueNotifier<String>('Text');
  final _titleExtension = ValueNotifier<String?>(null);
  final _isDirty = ValueNotifier<bool>(false);
  final _cursorPos = ValueNotifier<ForgeTextPosition>(
    const ForgeTextPosition.zero(),
  );
  final _selection = ValueNotifier<ForgeTextRange?>(null);
  final _selections = ValueNotifier<List<ForgeTextRange>>([]);
  final _visibleRange = ValueNotifier<ForgeTextRange>(
    const ForgeTextRange.empty(),
  );
  final _stateChanged = StreamController<void>.broadcast();

  /// A selection the editor's API asks the views to show (an offset range).
  final _requestedSelection = ValueNotifier<TextSelection?>(null);

  late PositionConverter _positionConverter;
  late final _PlainTextForgeDocument _document;

  /// The session's file as the frame shows its state.
  late final ForgeSessionFile _file;
  ForgeTextEditorOptions _options;
  ShellEditorIntegration? _integration;
  VoidCallback? _stopFollowingDepth;
  String _lastText;
  bool _disposed = false;

  /// Decoration state.
  final Map<String, List<ForgeDecorationRange>> _decorationMap = {};

  /// The module the editor belongs to.
  ForgeKitModule get module => _module;

  /// The application's API the editor reaches it through: the one given,
  /// else the one its module was activated with ([forgeKitApiOf]); null
  /// when there is none (the editor then works on its own).
  ForgeKitApi? get kitApi => _api ?? forgeKitApiOf(_module);

  /// The integration with the application's actions and keys, once a view
  /// was built with an application; null without one.
  @visibleForTesting
  ForgeEditorIntegration? get integration => _integration;

  // ── ForgeComponent ──

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => const IconData(0xe873, fontFamily: 'MaterialIcons'); // text_snippet

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

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
  /// the frame then asks the user to keep their text or take the disk's.
  Future<void> _save() async {
    final outcome = await session.save();
    if (outcome == ForgeFileSaveOutcome.conflict && !_disposed) {
      _stateChanged.add(null);
    }
  }

  @override
  Stream<void> get onStateChanged => _stateChanged.stream;

  /// The integration with the application, made once: the undo and redo
  /// actions registered with it, the undo depth setting followed.
  ShellEditorIntegration? _integrate() {
    final existing = _integration;
    if (existing != null) return existing;
    final api = kitApi;
    if (api == null) return null;
    final integration = ShellEditorIntegration(
      shellApi: api,
      editorId: 'plaintext-editor-${uri.hashCode}',
      editorTypeId: typeId,
    )..descriptors = StandardEditingActions.descriptors;
    integration.registerAction(
      StandardEditingActions.undoActionId,
      () => executeAction(StandardEditingActions.undoActionId),
      isEnabled: () => session.canUndo,
    );
    integration.registerAction(
      StandardEditingActions.redoActionId,
      () => executeAction(StandardEditingActions.redoActionId),
      isEnabled: () => session.canRedo,
    );
    // The one undo depth setting bounds the session's history.
    _stopFollowingDepth = forgeFollowUndoDepth(
      integration,
      (depth) => session.historyDepth = depth,
    );
    return _integration = integration;
  }

  @override
  Widget buildMain(BuildContext context) =>
      _PlainTextView(editor: this, integration: _integrate());

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

  /// The plain-text editor is the fallback: it rejects every file, and is
  /// made by the application that falls back to it.
  @override
  FileHandlingResult canHandle(Uri uri) => FileHandlingResult.reject;

  /// The session's text against its saved text: clicking, scrolling or
  /// selecting never makes it dirty, and undoing back to the saved text makes
  /// it clean.
  @override
  ValueListenable<bool> get isDirty => _isDirty;

  /// The editor saves its own file ([StandardEditingActions.saveActionId]);
  /// the application never marks it clean, so there is nothing to do here.
  @override
  void markClean() {}

  /// Null: the editor saves its own file through the session, keeping its
  /// encoding and line endings and checking the disk first.
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
      if (sel != null)
        'selection': {
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
      setSelection(
        ForgeTextRange(
          start: ForgeTextPosition(
            line: selMap['startLine'] as int,
            column: selMap['startColumn'] as int,
          ),
          end: ForgeTextPosition(
            line: selMap['endLine'] as int,
            column: selMap['endColumn'] as int,
          ),
        ),
      );
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
  void revealPosition(ForgeTextPosition position) =>
      setCursorPosition(position);

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
    ForgeDecorationType type,
    List<ForgeDecorationRange> ranges,
  ) {
    _decorationMap[type.key] = List.unmodifiable(ranges);
  }

  @override
  void clearDecorations(ForgeDecorationType type) {
    _decorationMap.remove(type.key);
  }

  /// The decorations set for [type] (none by default).
  List<ForgeDecorationRange> decorationsOf(ForgeDecorationType type) =>
      _decorationMap[type.key] ?? const [];

  // ── The views report ──

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
    if (_disposed) return;
    _disposed = true;
    _stopFollowingDepth?.call();
    session.removeListener(_onSessionChanged);
    _file.dispose();
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
  _PlainTextForgeDocument(super.uri, this._editor, this._converter);

  final ForgePlainTextEditor _editor;
  PositionConverter _converter;

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

/// Forge as the host of the text file editor: the session, its undo and
/// redo, notices to the application's notifications.
class _PlainTextHost implements TomFileEditorHost {
  _PlainTextHost(this.editor);

  final ForgePlainTextEditor editor;

  @override
  ForgeFileSession get session => editor.session;

  @override
  String get name {
    final segments = editor.uri.pathSegments;
    return segments.isEmpty ? session.path : segments.last;
  }

  @override
  String get filePath =>
      editor.uri.scheme == 'file' ? editor.uri.toFilePath() : session.path;

  @override
  Future<void> undo(BuildContext context) async {
    if (session.canUndo) await session.undo();
  }

  @override
  Future<void> redo(BuildContext context) async {
    if (session.canRedo) await session.redo();
  }

  @override
  void notice(BuildContext context, String message, {required String kind}) {
    final manager = editor.kitApi?.notifications;
    if (manager != null) {
      unawaited(manager.showInformation(message));
    } else {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// The text editor copies nothing protected; a plain copy.
  @override
  Future<void> copyProtected(String value) =>
      Clipboard.setData(ClipboardData(text: value));
}

/// Intent for the plain-text editor's key map.
class _PlainTextActionIntent extends Intent {
  const _PlainTextActionIntent(this.actionId);

  final String actionId;
}

/// One view of the editor's session: the file's state ([ForgeSessionFileFrame])
/// above the text file editor, the application's key map around it.
class _PlainTextView extends StatefulWidget {
  const _PlainTextView({required this.editor, this.integration});

  final ForgePlainTextEditor editor;
  final ForgeEditorIntegration? integration;

  @override
  State<_PlainTextView> createState() => _PlainTextViewState();
}

class _PlainTextViewState extends State<_PlainTextView> {
  late _PlainTextHost _host = _PlainTextHost(widget.editor);

  /// The local key map from the integration's bindings — the application's
  /// binding table — through [buildEditorShortcutMap]; above the source, so
  /// the undo and redo keys reach the session's history.
  Map<ShortcutActivator, Intent> _shortcuts = const {};

  @override
  void initState() {
    super.initState();
    _buildShortcutMap();
    widget.integration?.shortcutBindings.addListener(_onBindingsChanged);
  }

  /// The place shows another editor (or the same one with another
  /// integration): its host and its key map from now on.
  @override
  void didUpdateWidget(_PlainTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editor != widget.editor) {
      _host = _PlainTextHost(widget.editor);
    }
    if (oldWidget.integration != widget.integration) {
      oldWidget.integration?.shortcutBindings.removeListener(
        _onBindingsChanged,
      );
      widget.integration?.shortcutBindings.addListener(_onBindingsChanged);
      _buildShortcutMap();
    }
  }

  @override
  void dispose() {
    widget.integration?.shortcutBindings.removeListener(_onBindingsChanged);
    super.dispose();
  }

  void _buildShortcutMap() {
    final integration = widget.integration;
    _shortcuts = integration == null
        ? const <ShortcutActivator, Intent>{}
        : {
            for (final entry in buildEditorShortcutMap(integration).entries)
              entry.key: _PlainTextActionIntent(entry.value),
          };
  }

  void _onBindingsChanged() {
    if (mounted) setState(_buildShortcutMap);
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final integration = widget.integration;
    final segments = editor.uri.pathSegments;
    final name = segments.isEmpty ? '' : segments.last;
    final dot = name.lastIndexOf('.');
    final highlighter = ForgePlainTextHighlighter.forExtension(
      dot < 0 ? '' : name.substring(dot + 1),
      dark: Theme.of(context).colorScheme.brightness == Brightness.dark,
    );
    Widget view = TomTextFileEditor(
      // A source of its own per editor: its find, caret and typing pause.
      key: ObjectKey(editor),
      host: _host,
      highlighter: highlighter,
      onSelectionChanged: editor._viewSelected,
      selectionRequest: editor._requestedSelection,
      // With an application its key map routes the history keys and its
      // find bar takes the find key; without one the source answers both.
      handleHistoryKeys: integration == null,
      handleFindKey: integration == null,
      // The frame names why the file is read-only.
      showReadOnlyReason: false,
      typingPause: forgeTypingPause,
    );
    if (_shortcuts.isNotEmpty) {
      view = Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            _PlainTextActionIntent: CallbackAction<_PlainTextActionIntent>(
              onInvoke: (intent) {
                integration?.executeAction(intent.actionId);
                return null;
              },
            ),
          },
          child: view,
        ),
      );
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: ForgeSessionFileFrame(file: editor._file, child: view),
    );
  }
}
