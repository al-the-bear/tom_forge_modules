import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

import '../components/forge_text_editor.dart';
import '../components/forge_component.dart';
import '../integrations/shell_editor_integration.dart';
import '../module/forge_module.dart';
import 'tom_forge_shell_module.dart';

/// Adapter that provides a plain text editor for unknown file types.
///
/// Uses [MdEditorController] under the hood but configured for raw-only mode
/// with monospace font, suitable for editing plain text, config files, or
/// any file type that lacks a specialized editor.
class ForgePlainTextEditor extends ForgeTextEditor {
  final MdEditorController controller;
  final ForgeModule _module;
  final _title = ValueNotifier<String>('Text');
  final _titleExtension = ValueNotifier<String?>(null);
  final _isDirty = ValueNotifier<bool>(false);
  final _cursorPos = ValueNotifier<ForgeTextPosition>(const ForgeTextPosition.zero());
  final _selection = ValueNotifier<ForgeTextRange?>(null);
  final _selections = ValueNotifier<List<ForgeTextRange>>([]);
  final _visibleRange =
      ValueNotifier<ForgeTextRange>(const ForgeTextRange.empty());

  late PositionConverter _positionConverter;
  late final _PlainTextForgeDocument _document;
  ForgeTextEditorOptions _options;
  ShellEditorIntegration? _integration;

  /// Decoration state.
  final Map<String, List<ForgeDecorationRange>> _decorationMap = {};

  /// Create a plain text editor with a pre-existing controller.
  ForgePlainTextEditor({
    required this.controller,
    required ForgeModule module,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(
      fontFamily: 'monospace',
    ),
  })  : _module = module,
        _options = options {
    _positionConverter = PositionConverter(controller.markdown);
    _document = _PlainTextForgeDocument(
      controller.uri ?? Uri.parse('untitled:text'),
      controller,
      _positionConverter,
    );

    // Observe cursor.
    controller.cursorPositionNotifier.addListener(_onCursorChanged);
    // Observe selection.
    controller.selectionNotifier.addListener(_onSelectionChanged);
    // Observe visible range.
    controller.visibleRangeNotifier.addListener(_onVisibleRangeChanged);
    // Observe content.
    controller.addListener(_onContentChanged);

    // Set initial title from URI.
    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
  }

  /// Create a plain text editor from content and URI.
  factory ForgePlainTextEditor.fromContent({
    required String content,
    required Uri uri,
    required ForgeModule module,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(
      fontFamily: 'monospace',
    ),
  }) {
    final controller = MdEditorController(
      initialMarkdown: content,
      uri: uri,
    );
    return ForgePlainTextEditor(
      controller: controller,
      module: module,
      options: options,
    );
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

  @override
  Widget buildMain(BuildContext context) {
    if (_module case final TomForgeShellModule shellModule) {
      _integration ??= ShellEditorIntegration(
        shellApi: shellModule.shellApi,
        editorId: 'plaintext-editor-${uri.hashCode}',
        editorTypeId: 'plaintext',
      )..descriptors = StandardEditingActions.descriptors;
    }
    final ext = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last.split('.').last.toLowerCase()
        : '';
    return _PlainTextEditorWidget(
      initialText: controller.markdown,
      fileExtension: ext,
      integration: _integration,
      onChanged: (text) {
        controller.markdown = text;
      },
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  // ── ForgeEditor ──

  @override
  Uri get uri => controller.uri ?? Uri.parse('untitled:text');

  @override
  FileHandlingResult canHandle(Uri uri) {
    // Plain text editor is a fallback, so it rejects by default.
    // It should only be used explicitly via the layout controller.
    return FileHandlingResult.reject;
  }

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  @override
  void markClean() {
    _isDirty.value = false;
  }

  @override
  String? getContent() => controller.markdown;

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
    final visStartLine = state['visibleStartLine'] as int?;
    if (visStartLine != null) {
      revealPosition(ForgeTextPosition(line: visStartLine, column: 0));
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
      _selection.value = ranges.first;
      setCursorPosition(ranges.first.start);
    } else {
      _selection.value = null;
    }
  }

  @override
  String get selectedText {
    final sel = _selection.value;
    if (sel == null || sel.isEmpty) return '';
    final text = controller.markdown;
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

  @override
  void insertText(String text) {
    final code = controller.markdown;
    final offset = _positionConverter.positionToOffset(_cursorPos.value);
    controller.markdown =
        code.substring(0, offset) + text + code.substring(offset);
  }

  @override
  void replaceRange(ForgeTextRange range, String replacement) {
    final startOffset = _positionConverter.positionToOffset(range.start);
    final endOffset = _positionConverter.positionToOffset(range.end);
    final current = controller.markdown;
    final newText = current.substring(0, startOffset) +
        replacement +
        current.substring(endOffset);
    controller.markdown = newText;
  }

  @override
  void deleteRange(ForgeTextRange range) => replaceRange(range, '');

  @override
  void setCursorPosition(ForgeTextPosition position) {
    final offset = _positionConverter.positionToOffset(position);
    controller.setCursorOffset(offset);
  }

  @override
  void setSelection(ForgeTextRange range) {
    setCursorPosition(range.start);
    _selection.value = range;
    _selections.value = [range];
  }

  @override
  void selectAll() {
    final text = controller.markdown;
    controller.setCursorOffset(0);
    _selection.value = ForgeTextRange(
      start: const ForgeTextPosition.zero(),
      end: _positionConverter.offsetToPosition(text.length),
    );
  }

  @override
  void revealPosition(ForgeTextPosition position) {
    setCursorPosition(position);
    controller.revealLine(position.line);
  }

  @override
  void revealRange(ForgeTextRange range) {
    setCursorPosition(range.start);
    controller.revealLine(range.start.line);
  }

  @override
  List<ForgeTextRange> findAll(Pattern pattern) {
    final text = controller.markdown;
    final matches = pattern.allMatches(text);
    return matches.map((m) {
      return ForgeTextRange(
        start: _positionConverter.offsetToPosition(m.start),
        end: _positionConverter.offsetToPosition(m.end),
      );
    }).toList();
  }

  @override
  int replaceAll(Pattern pattern, String replacement) {
    final text = controller.markdown;
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) return 0;
    // Apply replacements in reverse order.
    var result = text;
    for (final m in matches.reversed) {
      result =
          result.substring(0, m.start) + replacement + result.substring(m.end);
    }
    controller.markdown = result;
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
    controller.setDecorations(
      type.key,
      ranges
          .map((r) => (
                start: _positionConverter.positionToOffset(r.range.start),
                end: _positionConverter.positionToOffset(r.range.end),
              ))
          .toList(),
    );
  }

  @override
  void clearDecorations(ForgeDecorationType type) {
    _decorationMap.remove(type.key);
    controller.clearDecorations(type.key);
  }

  // ── Internal listeners ──

  void _onCursorChanged() {
    final offset = controller.cursorPositionNotifier.value;
    _positionConverter = PositionConverter(controller.markdown);
    _cursorPos.value = _positionConverter.offsetToPosition(offset);
  }

  void _onSelectionChanged() {
    final range = controller.selectionNotifier.value;
    _positionConverter = PositionConverter(controller.markdown);
    if (range == null) {
      _selection.value = null;
      _selections.value = [];
    } else {
      final forgeRange = ForgeTextRange(
        start: _positionConverter.offsetToPosition(range.start),
        end: _positionConverter.offsetToPosition(range.end),
      );
      _selection.value = forgeRange;
      _selections.value = [forgeRange];
    }
  }

  void _onVisibleRangeChanged() {
    final raw = controller.visibleRangeNotifier.value;
    _positionConverter = PositionConverter(controller.markdown);
    _visibleRange.value = ForgeTextRange(
      start: ForgeTextPosition(line: raw.firstLine, column: 0),
      end: ForgeTextPosition(line: raw.lastLine, column: 0),
    );
  }

  void _onContentChanged() {
    _positionConverter = PositionConverter(controller.markdown);
    _document.updateConverter(_positionConverter);
    _isDirty.value = true;
    _document.notifyContentChanged();
    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
  }

  /// Release listeners.
  void dispose() {
    _integration?.dispose();
    _document.dispose();
    controller.cursorPositionNotifier.removeListener(_onCursorChanged);
    controller.selectionNotifier.removeListener(_onSelectionChanged);
    controller.visibleRangeNotifier.removeListener(_onVisibleRangeChanged);
    controller.removeListener(_onContentChanged);
    _title.dispose();
    _titleExtension.dispose();
    _isDirty.dispose();
    _cursorPos.dispose();
    _selection.dispose();
    _selections.dispose();
    _visibleRange.dispose();
  }
}

/// [ForgeDocument] backed by [MdEditorController] for plain text.
class _PlainTextForgeDocument extends ForgeDocumentAdapter {
  final MdEditorController _controller;
  PositionConverter _converter;

  _PlainTextForgeDocument(super.uri, this._controller, this._converter);

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
  String get text => _controller.markdown;

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
  bool get isUntitled => _controller.uri == null;
}

// ──────────────────────────────────────────────────────────────────
// Plain text editor widget with syntax-aware colorization
// ──────────────────────────────────────────────────────────────────

/// Intent for plain text editor shortcut actions.
class _PlainTextActionIntent extends Intent {
  final String actionId;
  const _PlainTextActionIntent(this.actionId);
}

/// A lightweight text editor widget with line numbers and optional syntax
/// highlighting for common file formats (JSON, XML, etc.).
class _PlainTextEditorWidget extends StatefulWidget {
  final String initialText;
  final String fileExtension;
  final ForgeEditorIntegration? integration;
  final ValueChanged<String> onChanged;

  const _PlainTextEditorWidget({
    required this.initialText,
    required this.fileExtension,
    this.integration,
    required this.onChanged,
  });

  @override
  State<_PlainTextEditorWidget> createState() => _PlainTextEditorWidgetState();
}

class _PlainTextEditorWidgetState extends State<_PlainTextEditorWidget> {
  late _HighlightTextController _textController;
  late ScrollController _scrollController;
  late ScrollController _gutterScrollController;
  final FocusNode _focusNode = FocusNode();

  // Undo/redo state
  final ForgeUndoStack<_TextChange> _history =
      ForgeUndoStack(maxEntries: _maxUndoStackSize);
  String _lastSavedText = '';
  TextSelection _lastSavedSelection = const TextSelection.collapsed(offset: 0);
  Timer? _undoDebounceTimer;
  static const _undoDebounceDuration = Duration(milliseconds: 300);
  static const int _maxUndoStackSize = 100;

  // Shortcuts map
  Map<ShortcutActivator, Intent> _shortcuts = {};

  @override
  void initState() {
    super.initState();
    _textController = _HighlightTextController(
      text: widget.initialText,
      language: widget.fileExtension,
    );
    _scrollController = ScrollController();
    _gutterScrollController = ScrollController();
    _scrollController.addListener(_syncScroll);
    _textController.addListener(_onTextChanged);
    _lastSavedText = widget.initialText;

    _registerActions();
  }

  void _registerActions() {
    final integration = widget.integration;
    if (integration == null) return;

    integration.registerAction(
      StandardEditingActions.undoActionId,
      _undo,
      isEnabled: () => _history.canUndo,
    );
    integration.registerAction(
      StandardEditingActions.redoActionId,
      _redo,
      isEnabled: () => _history.canRedo,
    );

    _shortcuts = <ShortcutActivator, Intent>{};
    for (final action in integration.supportedActions) {
      final key = integration.getShortcutForAction(action.id);
      if (key != null) {
        _shortcuts[key.toActivator()] = _PlainTextActionIntent(action.id);
      }
    }
  }

  @override
  void dispose() {
    _undoDebounceTimer?.cancel();
    _textController.removeListener(_onTextChanged);
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

  void _onTextChanged() {
    final newText = _textController.text;
    widget.onChanged(newText);
    _scheduleUndoSave(newText);
  }

  // ── Undo/Redo ──

  void _scheduleUndoSave(String newText) {
    _undoDebounceTimer?.cancel();
    _undoDebounceTimer = Timer(_undoDebounceDuration, _flushPendingUndoSave);
  }

  /// Records the typing since the last entry as one change, at once — before
  /// an undo, so the undo takes back what is on screen rather than the entry
  /// before it.
  void _flushPendingUndoSave() {
    _undoDebounceTimer?.cancel();
    final text = _textController.text;
    if (_lastSavedText == text) return;
    _history.push(
      _TextChange(
        before: _UndoState(text: _lastSavedText, selection: _lastSavedSelection),
        after: _UndoState(text: text, selection: _textController.selection),
      ),
    );
    _lastSavedText = text;
    _lastSavedSelection = _textController.selection;
    widget.integration?.notifyTextEdit(label: 'Text edit');
  }

  void _undo() {
    _flushPendingUndoSave();
    _history.undo((change) => _applyState(change.before));
  }

  void _redo() => _history.redo((change) => _applyState(change.after));

  void _applyState(_UndoState state) {
    _textController.removeListener(_onTextChanged);
    _textController.text = state.text;
    _textController.selection = state.selection;
    _lastSavedText = state.text;
    _lastSavedSelection = state.selection;
    widget.onChanged(state.text);
    _textController.addListener(_onTextChanged);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
    );

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
        // Text editor
        Expanded(
          child: TextField(
            controller: _textController,
            focusNode: _focusNode,
            scrollController: _scrollController,
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

    return Container(
      color: theme.colorScheme.surface,
      child: editor,
    );
  }
}

/// Undo state snapshot.
class _UndoState {
  final String text;
  final TextSelection selection;
  const _UndoState({required this.text, required this.selection});
}

/// One undoable change: the text and selection before and after it.
class _TextChange {
  final _UndoState before;
  final _UndoState after;
  const _TextChange({required this.before, required this.after});
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
