/// Dart code editor widget v4 with syntax highlighting, bracket matching,
/// error tooltips, and code completion.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_theme.dart';
import 'syntax_highlighter.dart';
import 'completion_provider.dart';

export 'editor_theme.dart';

/// Controller for managing Dart code state.
class DartCodeController extends ChangeNotifier {
  String _userCode = '';
  List<String> _implicitImports;

  DartCodeController({
    String initialCode = '',
    List<String> implicitImports = const [
      'dart:async',
      'dart:collection',
      'dart:math',
    ],
  })  : _userCode = initialCode,
        _implicitImports = implicitImports;

  /// The code as entered by the user (without implicit imports).
  String get userCode => _userCode;

  set userCode(String value) {
    if (_userCode != value) {
      _userCode = value;
      notifyListeners();
    }
  }

  /// Implicit imports that are prepended to the code for analysis.
  List<String> get implicitImports => List.unmodifiable(_implicitImports);

  set implicitImports(List<String> value) {
    _implicitImports = value;
    notifyListeners();
  }

  /// The number of lines added by implicit imports.
  int get lineOffset =>
      _implicitImports.isEmpty ? 0 : _implicitImports.length + 1;

  /// The full code with implicit imports prepended.
  String get fullCode {
    if (_implicitImports.isEmpty) {
      return _userCode;
    }
    final importLines = _implicitImports.map((i) => "import '$i';").join('\n');
    return '$importLines\n\n$_userCode';
  }

  /// Adjusts a line number from analysis to user display.
  /// Returns the raw adjusted value (negative or zero means implicit-import section).
  int adjustLineNumber(int analysisLine) => analysisLine - lineOffset;

  /// Number of lines in the user code.
  int get lineCount => '\n'.allMatches(_userCode).length + 1;
}

/// Represents a code error or warning.
class CodeError {
  final String message;
  final int line;
  final int column;
  final int offset;
  final int length;
  final String severity;
  final String code;

  const CodeError({
    required this.message,
    required this.line,
    required this.column,
    required this.offset,
    required this.length,
    required this.severity,
    required this.code,
  });

  bool get isError => severity.toUpperCase() == 'ERROR';
  bool get isWarning => severity.toUpperCase() == 'WARNING';
  bool get isInfo => severity.toUpperCase() == 'INFO';
}

/// Custom TextEditingController that applies syntax highlighting.
class _HighlightingTextController extends TextEditingController {
  final _SyntaxTheme _syntaxTheme;
  List<HighlightToken> _tokens = [];
  List<BracketPair> _bracketPairs = [];
  bool _needsRetokenize = true;
  int? _cursorBracketOffset;
  int? _matchingBracketOffset;

  _HighlightingTextController({
    required DartEditorTheme theme,
    String? initialText,
  })  : _syntaxTheme = _SyntaxTheme(theme),
        super(text: initialText);

  List<BracketPair> get bracketPairs {
    _retokenizeIfNeeded();
    return _bracketPairs;
  }

  @override
  set text(String newText) {
    _needsRetokenize = true;
    super.text = newText;
  }

  void invalidate() {
    _needsRetokenize = true;
  }

  void updateCursorPosition(int cursorOffset) {
    _cursorBracketOffset = null;
    _matchingBracketOffset = null;

    for (final pair in bracketPairs) {
      if (cursorOffset == pair.openOffset + 1 ||
          cursorOffset == pair.closeOffset + 1) {
        _cursorBracketOffset = cursorOffset == pair.openOffset + 1
            ? pair.openOffset
            : pair.closeOffset;
        _matchingBracketOffset = cursorOffset == pair.openOffset + 1
            ? pair.closeOffset
            : pair.openOffset;
        break;
      }
      if (cursorOffset == pair.openOffset || cursorOffset == pair.closeOffset) {
        _cursorBracketOffset = cursorOffset;
        _matchingBracketOffset = cursorOffset == pair.openOffset
            ? pair.closeOffset
            : pair.openOffset;
        break;
      }
    }
  }

  void _retokenizeIfNeeded() {
    if (_needsRetokenize) {
      _tokens = DartSyntaxHighlighter.tokenize(text);
      _bracketPairs = DartSyntaxHighlighter.extractBracketPairs(text);
      _needsRetokenize = false;
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    _retokenizeIfNeeded();

    if (text.isEmpty) {
      return TextSpan(text: '', style: style ?? _syntaxTheme.plainStyle);
    }

    final spans = _buildHighlightedSpans();

    if (_cursorBracketOffset != null && _matchingBracketOffset != null) {
      return TextSpan(style: style, children: _applyBracketHighlights(spans));
    }

    return TextSpan(style: style, children: spans);
  }

  List<TextSpan> _buildHighlightedSpans() {
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final token in _tokens) {
      if (token.offset >= text.length) continue;
      final tokenEnd = token.end.clamp(0, text.length);
      final tokenStart = token.offset.clamp(0, text.length);

      if (tokenStart > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, tokenStart),
            style: _syntaxTheme.plainStyle,
          ),
        );
      }

      if (tokenEnd > tokenStart) {
        var tokenStyle = _syntaxTheme.styleFor(token.type);

        if (_matchingBracketOffset != null &&
            token.offset == _matchingBracketOffset) {
          tokenStyle = tokenStyle.copyWith(
            backgroundColor: _syntaxTheme.matchingBracketBackground,
          );
        }

        spans.add(
          TextSpan(
            text: text.substring(tokenStart, tokenEnd),
            style: tokenStyle,
          ),
        );
      }

      lastEnd = tokenEnd;
    }

    if (lastEnd < text.length) {
      spans.add(
        TextSpan(text: text.substring(lastEnd), style: _syntaxTheme.plainStyle),
      );
    }

    return spans;
  }

  List<TextSpan> _applyBracketHighlights(List<TextSpan> spans) {
    if (_cursorBracketOffset == null && _matchingBracketOffset == null) {
      return spans;
    }

    final result = <TextSpan>[];
    var currentOffset = 0;

    for (final span in spans) {
      final spanText = span.text ?? '';
      final spanLength = spanText.length;
      final spanEnd = currentOffset + spanLength;

      bool needsHighlight = false;

      if (_cursorBracketOffset != null &&
          currentOffset <= _cursorBracketOffset! &&
          _cursorBracketOffset! < spanEnd) {
        needsHighlight = true;
      }
      if (_matchingBracketOffset != null &&
          currentOffset <= _matchingBracketOffset! &&
          _matchingBracketOffset! < spanEnd) {
        needsHighlight = true;
      }

      if (needsHighlight && spanLength == 1) {
        result.add(
          TextSpan(
            text: spanText,
            style: span.style?.copyWith(
              backgroundColor: _syntaxTheme.matchingBracketBackground,
            ),
          ),
        );
      } else {
        result.add(span);
      }

      currentOffset = spanEnd;
    }

    return result;
  }
}

/// Internal syntax theme adapter that builds TextStyles from DartEditorTheme.
class _SyntaxTheme {
  final DartEditorTheme theme;
  late final TextStyle _baseStyle;

  _SyntaxTheme(this.theme) {
    _baseStyle = theme.font.baseStyle;
  }

  TextStyle get plainStyle => _baseStyle.copyWith(color: theme.syntax.plain);

  Color get matchingBracketBackground => theme.editor.matchingBracketBackground;

  TextStyle styleFor(HighlightType type) {
    return switch (type) {
      HighlightType.keyword => _baseStyle.copyWith(
          color: theme.syntax.keyword,
          fontWeight: theme.font.keywordWeight,
        ),
      HighlightType.builtInKeyword => _baseStyle.copyWith(
          color: theme.syntax.builtInKeyword,
        ),
      HighlightType.controlKeyword => _baseStyle.copyWith(
          color: theme.syntax.controlKeyword,
          fontWeight: theme.font.keywordWeight,
        ),
      HighlightType.string => _baseStyle.copyWith(color: theme.syntax.string),
      HighlightType.number => _baseStyle.copyWith(color: theme.syntax.number),
      HighlightType.comment => _baseStyle.copyWith(
          color: theme.syntax.comment,
          fontStyle: FontStyle.italic,
        ),
      HighlightType.operator => _baseStyle.copyWith(
          color: theme.syntax.operator,
        ),
      HighlightType.punctuation => _baseStyle.copyWith(
          color: theme.syntax.punctuation,
        ),
      HighlightType.type => _baseStyle.copyWith(color: theme.syntax.type),
      HighlightType.className => _baseStyle.copyWith(
          color: theme.syntax.className,
          fontWeight: theme.font.keywordWeight,
        ),
      HighlightType.function => _baseStyle.copyWith(
          color: theme.syntax.function,
        ),
      HighlightType.methodCall => _baseStyle.copyWith(
          color: theme.syntax.methodCall,
        ),
      HighlightType.variable => _baseStyle.copyWith(
          color: theme.syntax.variable,
        ),
      HighlightType.parameter => _baseStyle.copyWith(
          color: theme.syntax.parameter,
        ),
      HighlightType.property => _baseStyle.copyWith(
          color: theme.syntax.property,
        ),
      HighlightType.constant => _baseStyle.copyWith(
          color: theme.syntax.constant,
        ),
      HighlightType.annotation => _baseStyle.copyWith(
          color: theme.syntax.annotation,
        ),
      HighlightType.thisKeyword => _baseStyle.copyWith(
          color: theme.syntax.thisKeyword,
          fontWeight: theme.font.keywordWeight,
        ),
      HighlightType.boolLiteral => _baseStyle.copyWith(
          color: theme.syntax.boolLiteral,
          fontWeight: theme.font.keywordWeight,
        ),
      HighlightType.nullLiteral => _baseStyle.copyWith(
          color: theme.syntax.nullLiteral,
          fontWeight: theme.font.keywordWeight,
        ),
      HighlightType.plain => plainStyle,
      // Bracket types with rainbow colors
      HighlightType.bracket0 => _baseStyle.copyWith(
          color: theme.brackets.colorForDepth(0),
        ),
      HighlightType.bracket1 => _baseStyle.copyWith(
          color: theme.brackets.colorForDepth(1),
        ),
      HighlightType.bracket2 => _baseStyle.copyWith(
          color: theme.brackets.colorForDepth(2),
        ),
      HighlightType.bracket3 => _baseStyle.copyWith(
          color: theme.brackets.colorForDepth(3),
        ),
      HighlightType.bracket4 => _baseStyle.copyWith(
          color: theme.brackets.colorForDepth(4),
        ),
      HighlightType.bracket5 => _baseStyle.copyWith(
          color: theme.brackets.colorForDepth(5),
        ),
    };
  }
}

/// Settings for controlling which features of [DartCodeEditor] are active.
///
/// Pass as [DartCodeEditor.settings] to configure the editor from the outside.
/// The editor shows a built-in toolbar (when [showToolbar] is true) where the
/// user can toggle feature settings interactively. Each toolbar section can be
/// shown or hidden individually.
class DartEditorSettings {
  // ── Editor chrome ──────────────────────────────────────────────────────────

  /// Whether the settings toolbar is visible at the top of the editor.
  final bool showToolbar;

  /// Whether the line-number gutter is shown on the left side.
  final bool showLineNumbers;

  // ── Completion ─────────────────────────────────────────────────────────────

  /// Whether auto-completion is triggered while typing.
  final bool autoCompleteEnabled;

  /// Maximum number of items visible in the completion popup at once.
  final int maxCompletionItems;

  // ── Diagnostics ────────────────────────────────────────────────────────────

  /// Whether hovering over an error squiggle shows a tooltip.
  final bool showErrorTooltips;

  /// Whether error squiggles and gutter icons are drawn for errors.
  final bool showErrorMarkers;

  /// Whether hovering over a warning squiggle shows a tooltip.
  final bool showWarningTooltips;

  /// Whether warning squiggles and gutter icons are drawn for warnings.
  final bool showWarningMarkers;

  /// Whether hovering over an info squiggle shows a tooltip.
  final bool showInfoTooltips;

  /// Whether info squiggles and gutter icons are drawn for info diagnostics.
  final bool showInfoMarkers;

  // ── Popup position ─────────────────────────────────────────────────────────

  /// Whether completion and parameter-help popups prefer to appear below
  /// the cursor. When `false` they prefer to appear above. Either way, the
  /// popup flips to the other side automatically when there is not enough
  /// screen space.
  final bool popupPreferBelow;

  // ── Toolbar section visibility ─────────────────────────────────────────────

  /// Whether the auto-complete toggle button is shown in the toolbar.
  final bool showAutoCompleteToggle;

  /// Whether the error marker/tooltip toggle buttons are shown in the toolbar.
  final bool showErrorToggles;

  /// Whether the warning marker/tooltip toggle buttons are shown in the toolbar.
  final bool showWarningToggles;

  /// Whether the info marker/tooltip toggle buttons are shown in the toolbar.
  final bool showInfoToggles;

  /// Whether the popup-position-preference toggle is shown in the toolbar.
  final bool showPopupPositionToggle;

  /// Whether the "Open Reference" button is shown in the toolbar.
  final bool showOpenReferenceButton;

  const DartEditorSettings({
    this.showToolbar = true,
    this.showLineNumbers = true,
    this.autoCompleteEnabled = true,
    this.maxCompletionItems = 8,
    this.showErrorTooltips = true,
    this.showErrorMarkers = true,
    this.showWarningTooltips = true,
    this.showWarningMarkers = true,
    this.showInfoTooltips = false,
    this.showInfoMarkers = false,
    this.popupPreferBelow = true,
    this.showAutoCompleteToggle = true,
    this.showErrorToggles = true,
    this.showWarningToggles = true,
    this.showInfoToggles = true,
    this.showPopupPositionToggle = true,
    this.showOpenReferenceButton = true,
  });

  /// Returns a copy with the given fields overridden.
  DartEditorSettings copyWith({
    bool? showToolbar,
    bool? showLineNumbers,
    bool? autoCompleteEnabled,
    int? maxCompletionItems,
    bool? showErrorTooltips,
    bool? showErrorMarkers,
    bool? showWarningTooltips,
    bool? showWarningMarkers,
    bool? showInfoTooltips,
    bool? showInfoMarkers,
    bool? popupPreferBelow,
    bool? showAutoCompleteToggle,
    bool? showErrorToggles,
    bool? showWarningToggles,
    bool? showInfoToggles,
    bool? showPopupPositionToggle,
    bool? showOpenReferenceButton,
  }) =>
      DartEditorSettings(
        showToolbar: showToolbar ?? this.showToolbar,
        showLineNumbers: showLineNumbers ?? this.showLineNumbers,
        autoCompleteEnabled: autoCompleteEnabled ?? this.autoCompleteEnabled,
        maxCompletionItems: maxCompletionItems ?? this.maxCompletionItems,
        showErrorTooltips: showErrorTooltips ?? this.showErrorTooltips,
        showErrorMarkers: showErrorMarkers ?? this.showErrorMarkers,
        showWarningTooltips: showWarningTooltips ?? this.showWarningTooltips,
        showWarningMarkers: showWarningMarkers ?? this.showWarningMarkers,
        showInfoTooltips: showInfoTooltips ?? this.showInfoTooltips,
        showInfoMarkers: showInfoMarkers ?? this.showInfoMarkers,
        popupPreferBelow: popupPreferBelow ?? this.popupPreferBelow,
        showAutoCompleteToggle:
            showAutoCompleteToggle ?? this.showAutoCompleteToggle,
        showErrorToggles: showErrorToggles ?? this.showErrorToggles,
        showWarningToggles: showWarningToggles ?? this.showWarningToggles,
        showInfoToggles: showInfoToggles ?? this.showInfoToggles,
        showPopupPositionToggle:
            showPopupPositionToggle ?? this.showPopupPositionToggle,
        showOpenReferenceButton:
            showOpenReferenceButton ?? this.showOpenReferenceButton,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DartEditorSettings &&
          showToolbar == other.showToolbar &&
          showLineNumbers == other.showLineNumbers &&
          autoCompleteEnabled == other.autoCompleteEnabled &&
          maxCompletionItems == other.maxCompletionItems &&
          showErrorTooltips == other.showErrorTooltips &&
          showErrorMarkers == other.showErrorMarkers &&
          showWarningTooltips == other.showWarningTooltips &&
          showWarningMarkers == other.showWarningMarkers &&
          showInfoTooltips == other.showInfoTooltips &&
          showInfoMarkers == other.showInfoMarkers &&
          popupPreferBelow == other.popupPreferBelow &&
          showAutoCompleteToggle == other.showAutoCompleteToggle &&
          showErrorToggles == other.showErrorToggles &&
          showWarningToggles == other.showWarningToggles &&
          showInfoToggles == other.showInfoToggles &&
          showPopupPositionToggle == other.showPopupPositionToggle &&
          showOpenReferenceButton == other.showOpenReferenceButton;

  @override
  int get hashCode => Object.hashAll([
        showToolbar,
        showLineNumbers,
        autoCompleteEnabled,
        maxCompletionItems,
        showErrorTooltips,
        showErrorMarkers,
        showWarningTooltips,
        showWarningMarkers,
        showInfoTooltips,
        showInfoMarkers,
        popupPreferBelow,
        showAutoCompleteToggle,
        showErrorToggles,
        showWarningToggles,
        showInfoToggles,
        showPopupPositionToggle,
        showOpenReferenceButton,
      ]);
}

/// A customizable Dart code editor with syntax highlighting, bracket matching,
/// error display, and code completion.
class DartCodeEditor extends StatefulWidget {
  final DartCodeController controller;
  final List<CodeError> errors;
  final bool readOnly;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final Function(CodeError)? onErrorTap;
  final DartEditorTheme theme;

  /// Initial (and externally-controlled) feature settings.
  /// Controls toolbar visibility, line numbers, completion, and more.
  final DartEditorSettings settings;

  /// Called whenever the user toggles a setting via the built-in toolbar.
  final ValueChanged<DartEditorSettings>? onSettingsChanged;

  /// Callback for getting additional completions from the analyzer.
  /// Called with (code, cursorOffset, prefix) and should return completions.
  final Future<List<CompletionItem>> Function(
    String code,
    int cursorOffset,
    String prefix,
  )? onCompletionRequest;

  DartCodeEditor({
    super.key,
    required this.controller,
    this.errors = const [],
    this.readOnly = false,
    this.placeholder,
    this.onChanged,
    this.onErrorTap,
    this.onCompletionRequest,
    this.settings = const DartEditorSettings(),
    this.onSettingsChanged,
    DartEditorTheme? theme,
  }) : theme = theme ?? DartEditorTheme.dark();

  @override
  State<DartCodeEditor> createState() => _DartCodeEditorState();
}

class _DartCodeEditorState extends State<DartCodeEditor> {
  late _HighlightingTextController _textController;
  late final ScrollController _scrollController;
  late final ScrollController _gutterScrollController;
  late final FocusNode _focusNode;
  OverlayEntry? _tooltipOverlay;

  // Completion state
  OverlayEntry? _completionOverlay;
  List<CompletionItem> _completionItems = [];
  int _selectedCompletionIndex = 0;
  Offset _completionPosition = Offset.zero;
  String _completionPrefix = '';

  // Undo/Redo state
  final List<_UndoState> _undoStack = [];
  final List<_UndoState> _redoStack = [];
  static const int _maxUndoStackSize = 100;
  String _lastSavedText = '';
  Timer? _undoDebounceTimer;
  static const _undoDebounceDuration = Duration(milliseconds: 300);

  // Auto-close brackets state
  String _previousText = '';
  bool _skipAutoClose = false;

  // Auto-completion debounce
  Timer? _completionDebounceTimer;
  static const _completionDebounceDuration = Duration(milliseconds: 250);

  // Parameter help state
  OverlayEntry? _parameterHelpOverlay;

  // Key for the editor text-area widget (Expanded below toolbar, right of gutter).
  // Used to convert local text coordinates to correct global screen coordinates.
  final _editorKey = GlobalKey();

  // Editor feature settings (mutable copy of widget.settings)
  late DartEditorSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _textController = _HighlightingTextController(
      theme: widget.theme,
      initialText: widget.controller.userCode,
    );
    _scrollController = ScrollController();
    _gutterScrollController = ScrollController();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);

    _scrollController.addListener(_syncScroll);
    _textController.addListener(_onSelectionChanged);
    // Dismiss popups when the editor loses focus (e.g. click outside)
    _focusNode.addListener(_onFocusChanged);

    // Initialize undo state
    _lastSavedText = widget.controller.userCode;
    _previousText = widget.controller.userCode;
  }

  @override
  void dispose() {
    _undoDebounceTimer?.cancel();
    _scrollController.removeListener(_syncScroll);
    _textController.removeListener(_onSelectionChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _scrollController.dispose();
    _gutterScrollController.dispose();
    _focusNode.dispose();
    _completionDebounceTimer?.cancel();
    _hideTooltip();
    _hideCompletion();
    _hideParameterHelp();
    _hideApiReference();
    super.dispose();
  }

  @override
  void didUpdateWidget(DartCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync settings when the external settings object changes.
    if (widget.settings != oldWidget.settings) {
      setState(() {
        _settings = widget.settings;
      });
    }
    // Theme change: recreate the highlighting controller and rebuild instantly.
    if (widget.theme != oldWidget.theme) {
      setState(() {
        final currentSelection = _textController.selection;
        final currentText = _textController.text;
        _textController.removeListener(_onSelectionChanged);
        _textController.dispose();
        _textController = _HighlightingTextController(
          theme: widget.theme,
          initialText: currentText,
        );
        _textController.selection = currentSelection;
        _textController.addListener(_onSelectionChanged);
      });
    }
  }

  /// Errors filtered by the current settings (markers on/off).
  List<CodeError> get _filteredErrors => widget.errors.where((e) {
        if (e.isError) return _settings.showErrorMarkers;
        if (e.isWarning) return _settings.showWarningMarkers;
        if (e.isInfo) return _settings.showInfoMarkers;
        return true;
      }).toList();

  /// Update settings locally and notify the host widget.
  void _updateSettings(DartEditorSettings newSettings) {
    setState(() => _settings = newSettings);
    widget.onSettingsChanged?.call(newSettings);
  }

  void _syncScroll() {
    if (_gutterScrollController.hasClients &&
        _scrollController.hasClients &&
        _gutterScrollController.offset != _scrollController.offset) {
      _gutterScrollController.jumpTo(_scrollController.offset);
    }
    // Rebuild to update error underlines position
    setState(() {});
  }

  void _onSelectionChanged() {
    final pos = _textController.selection.baseOffset;
    _textController.updateCursorPosition(pos);
    setState(() {});
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideCompletion();
      _hideParameterHelp();
    }
  }

  void _handleTextChange(String newText) {
    _textController.invalidate();

    // Capture previous length before any updates (for insertion detection)
    final prevLength = _previousText.length;

    // Auto-close brackets: detect single character insertion
    if (!_skipAutoClose && newText.length == _previousText.length + 1) {
      final cursorPos = _textController.selection.baseOffset;
      if (cursorPos > 0 && cursorPos <= newText.length) {
        final insertedChar = newText[cursorPos - 1];
        final closingBracket = switch (insertedChar) {
          '(' => ')',
          '{' => '}',
          '[' => ']',
          _ => null,
        };

        if (closingBracket != null) {
          // Insert closing bracket and position cursor between brackets
          final textWithClosing = newText.substring(0, cursorPos) +
              closingBracket +
              newText.substring(cursorPos);

          // Temporarily skip auto-close to prevent recursive call
          _skipAutoClose = true;
          _textController.text = textWithClosing;
          _textController.selection = TextSelection.collapsed(
            offset: cursorPos,
          );
          _skipAutoClose = false;

          newText = textWithClosing;
        }
      }
    }
    _previousText = newText;

    // Record undo state with debouncing
    _scheduleUndoSave(newText);

    widget.controller.userCode = newText;
    widget.onChanged?.call(newText);

    // Auto-trigger completion based on what was typed (insertion only)
    final cursorPos = _textController.selection.baseOffset;
    if (_settings.autoCompleteEnabled &&
        !_skipAutoClose &&
        newText.length > prevLength &&
        cursorPos > 0 &&
        cursorPos <= newText.length) {
      final insertedChar = newText[cursorPos - 1];
      if (insertedChar == '.') {
        // Dot: immediately trigger member completion
        _completionDebounceTimer?.cancel();
        _hideCompletion();
        _hideParameterHelp();
        _triggerCompletion();
        return;
      } else if (insertedChar == '(') {
        // Open paren: show parameter help
        _completionDebounceTimer?.cancel();
        _hideCompletion();
        _hideParameterHelp();
        _triggerCompletion();
        return;
      } else if (_isIdentifierChar(insertedChar)) {
        // Identifier char: debounced trigger (prefix builds up)
        _completionDebounceTimer?.cancel();
        _hideCompletion();
        _hideParameterHelp();
        _completionDebounceTimer = Timer(_completionDebounceDuration, () {
          if (mounted) _triggerCompletion();
        });
        return;
      }
    }

    // Hide completion on deletion or other changes
    _completionDebounceTimer?.cancel();
    if (_completionOverlay != null) {
      _hideCompletion();
    }

    // Hide parameter help if text changed
    if (_parameterHelpOverlay != null) {
      _hideParameterHelp();
    }
  }

  void _scheduleUndoSave(String newText) {
    _undoDebounceTimer?.cancel();
    _undoDebounceTimer = Timer(_undoDebounceDuration, () {
      if (_lastSavedText != newText) {
        _pushUndoState(_lastSavedText, _textController.selection);
        _lastSavedText = newText;
        // Clear redo stack on new edit
        _redoStack.clear();
      }
    });
  }

  void _pushUndoState(String text, TextSelection selection) {
    _undoStack.add(_UndoState(text: text, selection: selection));
    if (_undoStack.length > _maxUndoStackSize) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) return;

    // Save current state to redo stack
    _redoStack.add(
      _UndoState(
        text: _textController.text,
        selection: _textController.selection,
      ),
    );

    // Pop and apply undo state
    final state = _undoStack.removeLast();
    _applyUndoState(state);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;

    // Save current state to undo stack
    _undoStack.add(
      _UndoState(
        text: _textController.text,
        selection: _textController.selection,
      ),
    );

    // Pop and apply redo state
    final state = _redoStack.removeLast();
    _applyUndoState(state);
  }

  void _applyUndoState(_UndoState state) {
    _textController.text = state.text;
    _textController.selection = state.selection;
    _lastSavedText = state.text;
    widget.controller.userCode = state.text;
    widget.onChanged?.call(state.text);
    _textController.invalidate();
  }

  void _onHover(PointerHoverEvent event) {
    final error = _findErrorAtPosition(event.localPosition);
    if (error != null) {
      final tooltipEnabled = (error.isError && _settings.showErrorTooltips) ||
          (error.isWarning && _settings.showWarningTooltips) ||
          (error.isInfo && _settings.showInfoTooltips);
      if (tooltipEnabled) {
        _showTooltip(error, event.position);
      } else {
        _hideTooltip();
      }
    } else {
      _hideTooltip();
    }
  }

  void _onExit(PointerExitEvent event) {
    _hideTooltip();
  }

  CodeError? _findErrorAtPosition(Offset localPosition) {
    final fontSize = widget.theme.font.fontSize;
    final lineHeight = _lineHeight;
    final charWidth = fontSize * widget.theme.font.charWidthRatio;
    final padding = widget.theme.editor.contentPadding;
    final scrollOffset = _scrollOffset;

    final adjustedY = localPosition.dy + scrollOffset - padding;
    final adjustedX = localPosition.dx - padding;

    final line = (adjustedY / lineHeight).floor() + 1;

    // First pass: try to find error matching by column position
    for (final error in widget.errors) {
      if (error.line != line) continue;

      final startX = (error.column - 1) * charWidth;
      final endX = startX + math.max(error.length, 1) * charWidth;

      if (adjustedX >= startX - 8 && adjustedX <= endX + 8) {
        return error;
      }
    }

    // Second pass: fall back to line-level match (more forgiving)
    // Show the first error on the hovered line regardless of column
    for (final error in widget.errors) {
      if (error.line == line) return error;
    }

    return null;
  }

  void _showTooltip(CodeError error, Offset globalPosition) {
    _hideTooltip();

    _tooltipOverlay = OverlayEntry(
      builder: (context) => _ErrorTooltip(
        error: error,
        position: globalPosition,
        theme: widget.theme,
      ),
    );

    Overlay.of(context).insert(_tooltipOverlay!);
  }

  void _hideTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  // --- Completion handling ---

  /// Check if cursor is right after opening bracket in function call.
  /// Returns function name if in parameter context, null otherwise.
  String? _getParameterContextFunctionName(String code, int cursorOffset) {
    if (cursorOffset <= 0) return null;

    // Look backwards from cursor to find opening bracket
    final textBeforeCursor = code.substring(0, cursorOffset);

    // Check if we're right after '(' with optional spaces
    final match = RegExp(
      r'([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\s*$',
    ).firstMatch(textBeforeCursor);
    if (match != null) {
      return match.group(1);
    }

    return null;
  }

  void _triggerCompletion() async {
    final code = _textController.text;
    final cursorOffset = _textController.selection.baseOffset;

    if (cursorOffset < 0 || cursorOffset > code.length) {
      return;
    }

    // Check if we're in parameter context (cursor after opening bracket)
    final functionName = _getParameterContextFunctionName(code, cursorOffset);
    if (functionName != null) {
      _showParameterHelp(functionName, cursorOffset);
      return;
    }

    // Get the word prefix being typed
    _completionPrefix = _getWordAtCursor(code, cursorOffset);

    // Get completions solely from the analyzer
    _completionItems = [];
    if (widget.onCompletionRequest != null) {
      try {
        _completionItems = await widget.onCompletionRequest!(
          code,
          cursorOffset,
          _completionPrefix,
        );
        // Guard: widget may have been disposed during async gap
        if (!mounted) return;
        _completionItems.sort((a, b) {
          final orderCompare = (a.sortOrder ?? 99).compareTo(b.sortOrder ?? 99);
          if (orderCompare != 0) return orderCompare;
          return a.label.compareTo(b.label);
        });
      } catch (e) {
        debugPrint('Analyzer completion error: $e');
        if (!mounted) return;
      }
    }

    if (_completionItems.isEmpty) {
      _hideCompletion();
      return;
    }

    _selectedCompletionIndex = 0;

    // Calculate popup position
    _completionPosition = _calculateCompletionPosition(cursorOffset);

    _showCompletion();
  }

  String _getWordAtCursor(String code, int cursorOffset) {
    if (cursorOffset <= 0 || cursorOffset > code.length) return '';

    int start = cursorOffset - 1;
    while (start >= 0 && _isIdentifierChar(code[start])) {
      start--;
    }
    start++;

    if (start >= cursorOffset) return '';
    return code.substring(start, cursorOffset);
  }

  bool _isIdentifierChar(String char) {
    final c = char.codeUnitAt(0);
    return (c >= 65 && c <= 90) || // A-Z
        (c >= 97 && c <= 122) || // a-z
        (c >= 48 && c <= 57) || // 0-9
        c == 95; // _
  }

  double get _lineHeight {
    final fontSize = widget.theme.font.fontSize;
    return fontSize * widget.theme.font.lineHeight;
  }

  double get _scrollOffset =>
      _scrollController.hasClients ? _scrollController.offset : 0.0;

  Offset _calculateCompletionPosition(int cursorOffset) {
    final lineHeight = _lineHeight;
    final fontSize = widget.theme.font.fontSize;
    final charWidth = fontSize * widget.theme.font.charWidthRatio;
    final padding = widget.theme.editor.contentPadding;

    final code = _textController.text;
    final textBeforeCursor = code.substring(0, cursorOffset);
    final lines = textBeforeCursor.split('\n');
    final currentLine = lines.length - 1;
    final currentColumn = lines.last.length;

    // Adjust for the word being typed
    final adjustedColumn = currentColumn - _completionPrefix.length;

    final x = padding + adjustedColumn * charWidth;
    final scrollOffset = _scrollOffset;
    final y = padding + currentLine * lineHeight - scrollOffset + lineHeight;

    return Offset(x, y);
  }

  void _showParameterHelp(String functionName, int cursorOffset) async {
    _hideParameterHelp();
    _hideCompletion();

    // Try to find the function signature from completions
    String signature = '$functionName(...)';

    // Get completions to look up the function signature
    if (widget.onCompletionRequest != null) {
      try {
        // Detect whether this is a dot-access call: something.method(
        // e.g. "name.startsWith(" — we need to query member completions of "name"
        final fullCode = _textController.text;
        final textBeforeCursor =
            fullCode.substring(0, cursorOffset).trimRight();
        final dotMethodMatch = RegExp(
          r'(.*\.)[a-zA-Z_][a-zA-Z0-9_]*\s*\(\s*$',
          dotAll: true,
        ).firstMatch(textBeforeCursor);

        List<CompletionItem> completions;
        if (dotMethodMatch != null) {
          // Cursor right after the dot so that isDotCompletion is true in
          // the analyzer callback, triggering _getMemberCompletions.
          final dotCode = dotMethodMatch.group(
            1,
          )!; // full code up to + incl. dot
          final dotOffset = dotCode.length;
          completions = await widget.onCompletionRequest!(
            fullCode, // full code for type-inference context
            dotOffset, // cursor right after the dot
            functionName, // method name prefix for filtering
          );
        } else {
          completions = await widget.onCompletionRequest!(
            fullCode,
            cursorOffset,
            functionName,
          );
        }

        // Find matching function/method
        for (final item in completions) {
          if (item.label == functionName && item.signature != null) {
            signature = item.signature!;
            break;
          }
        }
      } catch (e) {
        debugPrint('Error looking up function signature: $e');
      }
    }

    // Calculate position for the tooltip (convert to global for overlay).
    // Use _editorKey to get the render box of the text area only.
    final editorRenderBox =
        _editorKey.currentContext?.findRenderObject() as RenderBox?;
    final localPos = _calculateCompletionPosition(cursorOffset);
    final anchorBelow = editorRenderBox != null
        ? editorRenderBox.localToGlobal(localPos)
        : localPos;
    final lineH = _lineHeight;
    final preferBelow = _settings.popupPreferBelow;

    _parameterHelpOverlay = OverlayEntry(
      builder: (ctx) {
        const estHeight = 90.0;
        final screenH = MediaQuery.of(ctx).size.height;
        final spaceBelow = screenH - anchorBelow.dy;
        final spaceAbove = anchorBelow.dy - lineH;
        final placeBelow = preferBelow
            ? (spaceBelow >= estHeight || spaceAbove < estHeight)
            : (spaceAbove < estHeight);
        final top =
            placeBelow ? anchorBelow.dy : anchorBelow.dy - lineH - estHeight;
        return Positioned(
          left: anchorBelow.dx,
          top: top,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(
              widget.theme.editor.borderRadius,
            ),
            color: widget.theme.tooltip.background,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.functions,
                        size: 16,
                        color: widget.theme.syntax.function,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: SelectableText(
                          signature,
                          style: TextStyle(
                            fontFamily: widget.theme.font.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: widget.theme.syntax.function,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Press Esc to close, or continue typing for completions',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.theme.tooltip.text.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    Overlay.of(context).insert(_parameterHelpOverlay!);
  }

  void _hideParameterHelp() {
    _parameterHelpOverlay?.remove();
    _parameterHelpOverlay = null;
  }

  void _showApiReference() async {
    _hideApiReference();
    _hideCompletion();
    _hideParameterHelp();

    // Get all completions for searching
    final allCompletions = <CompletionItem>[];

    // Add analyzer completions (they have richer data like members)
    if (widget.onCompletionRequest != null) {
      try {
        final analyzerCompletions = await widget.onCompletionRequest!(
          '',
          0,
          '',
        );
        allCompletions.addAll(analyzerCompletions);
      } catch (e) {
        debugPrint('API reference completion error: $e');
      }
    }

    // Sort by label
    allCompletions.sort((a, b) => a.label.compareTo(b.label));

    // Guard context use after async gap
    if (!mounted) return;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) => _ApiReferencePopup(
        items: allCompletions,
        theme: widget.theme,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _hideApiReference() {
    // No longer needed for overlay cleanup, but keep for compatibility
  }

  void _showCompletion() {
    // Remove old overlay without clearing items
    _completionOverlay?.remove();
    _completionOverlay = null;

    // Convert local editor-area position to global screen position for overlay.
    // Use _editorKey (on the Expanded text area, below toolbar and right of gutter)
    // so local (0,0) matches the top-left of the text content area.
    final editorRenderBox =
        _editorKey.currentContext?.findRenderObject() as RenderBox?;
    final globalPos = editorRenderBox != null
        ? editorRenderBox.localToGlobal(_completionPosition)
        : _completionPosition;

    // Make a copy of items for the overlay builder
    final items = List<CompletionItem>.from(_completionItems);
    final lineH = _lineHeight;
    final preferBelow = _settings.popupPreferBelow;

    _completionOverlay = OverlayEntry(
      builder: (context) => _CompletionPopup(
        items: items,
        selectedIndex: _selectedCompletionIndex, // Read directly for reactivity
        anchorBelow: globalPos,
        lineHeight: lineH,
        preferBelow: preferBelow,
        theme: widget.theme,
        maxItems: _settings.maxCompletionItems,
        onSelect: _insertCompletion,
      ),
    );

    Overlay.of(context).insert(_completionOverlay!);
  }

  void _updateCompletionOverlay() {
    if (_completionOverlay == null || _completionItems.isEmpty) return;

    // Mark overlay for rebuild with updated selection index
    _completionOverlay!.markNeedsBuild();
  }

  void _hideCompletion() {
    _completionOverlay?.remove();
    _completionOverlay = null;
    _completionItems = [];
  }

  void _insertCompletion(CompletionItem item) {
    final code = _textController.text;
    final cursorOffset = _textController.selection.baseOffset;

    // Find the start of the word being replaced
    int start = cursorOffset - _completionPrefix.length;
    if (start < 0) start = 0;

    // Build the new text
    String insertText = item.insertText;

    // Handle snippets with $0, $1, etc. - just remove the markers for now
    insertText = insertText.replaceAll(RegExp(r'\$\d'), '');

    // Smart overwrite: handle identifier followed by delimiters with space handling
    // - ')' - single space if there was one or more, no space if there wasn't
    // - '(' - no space
    // - '.' - no space
    // - '=' - single space if there was any space, no space if there wasn't
    int endOffset = cursorOffset;
    final textAfterCursor = code.substring(cursorOffset);

    // Match identifier, optional spaces, then delimiter
    final overwriteMatch = RegExp(
      r'^([a-zA-Z_][a-zA-Z0-9_]*)( *)([()=.])',
    ).firstMatch(textAfterCursor);
    if (overwriteMatch != null) {
      final identifier = overwriteMatch.group(1)!;
      final spaces = overwriteMatch.group(2)!;
      final delimiter = overwriteMatch.group(3)!;

      if (delimiter == ')') {
        // Single space before ) if there was any space, no space if there wasn't
        endOffset = cursorOffset + identifier.length + spaces.length;
        if (spaces.isNotEmpty) {
          insertText = '$insertText ';
        }
      } else if (delimiter == '(' || delimiter == '.') {
        // No space before ( or .
        endOffset = cursorOffset + identifier.length + spaces.length;
      } else if (delimiter == '=') {
        // Single space if there was any space, no space if there wasn't
        endOffset = cursorOffset + identifier.length + spaces.length;
        if (spaces.isNotEmpty) {
          insertText = '$insertText ';
        }
      }
    }

    final newText =
        code.substring(0, start) + insertText + code.substring(endOffset);

    // Calculate new cursor position
    final newCursorOffset = start + insertText.length;

    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: newCursorOffset,
    );

    widget.controller.userCode = newText;
    widget.onChanged?.call(newText);

    _hideCompletion();
    _hideParameterHelp();
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Ctrl+Space to trigger completion (NOTE: may conflict with macOS input switcher)
    if (_settings.autoCompleteEnabled &&
        event.logicalKey == LogicalKeyboardKey.space &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      _triggerCompletion();
      return KeyEventResult.handled;
    }

    // Option/Alt+Space — macOS-safe completion shortcut
    if (_settings.autoCompleteEnabled &&
        event.logicalKey == LogicalKeyboardKey.space &&
        HardwareKeyboard.instance.isAltPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !HardwareKeyboard.instance.isControlPressed) {
      _triggerCompletion();
      return KeyEventResult.handled;
    }

    // Ctrl+I for completion (alternative)
    if (_settings.autoCompleteEnabled &&
        event.logicalKey == LogicalKeyboardKey.keyI &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      _triggerCompletion();
      return KeyEventResult.handled;
    }

    // Ctrl+R to open API Reference popup
    if (event.logicalKey == LogicalKeyboardKey.keyR &&
        HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      _showApiReference();
      return KeyEventResult.handled;
    }

    // Undo: Cmd+Z (macOS) or Ctrl+Z (other)
    if (event.logicalKey == LogicalKeyboardKey.keyZ &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _undo();
      return KeyEventResult.handled;
    }

    // Redo: Cmd+Shift+Z (macOS) or Ctrl+Y or Ctrl+Shift+Z (other)
    if ((event.logicalKey == LogicalKeyboardKey.keyZ &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) &&
            HardwareKeyboard.instance.isShiftPressed) ||
        (event.logicalKey == LogicalKeyboardKey.keyY &&
            HardwareKeyboard.instance.isControlPressed)) {
      _redo();
      return KeyEventResult.handled;
    }

    // Handle completion navigation when popup is open
    if (_completionOverlay != null) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedCompletionIndex =
              (_selectedCompletionIndex + 1) % _completionItems.length;
        });
        _updateCompletionOverlay();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedCompletionIndex =
              (_selectedCompletionIndex - 1 + _completionItems.length) %
                  _completionItems.length;
        });
        _updateCompletionOverlay();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.tab) {
        if (_completionItems.isNotEmpty) {
          _insertCompletion(_completionItems[_selectedCompletionIndex]);
          return KeyEventResult.handled;
        }
      }

      // Any cursor-navigation key closes the popup
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.home ||
          event.logicalKey == LogicalKeyboardKey.end ||
          event.logicalKey == LogicalKeyboardKey.pageUp ||
          event.logicalKey == LogicalKeyboardKey.pageDown) {
        _hideCompletion();
        // let the event fall through so cursor actually moves
      }
    }

    // Handle parameter help overlay
    if (_parameterHelpOverlay != null) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.home ||
          event.logicalKey == LogicalKeyboardKey.end ||
          event.logicalKey == LogicalKeyboardKey.pageUp ||
          event.logicalKey == LogicalKeyboardKey.pageDown) {
        _hideParameterHelp();
        // let the event fall through so cursor actually moves
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return Container(
      decoration: BoxDecoration(
        color: theme.editor.background,
        borderRadius: BorderRadius.circular(theme.editor.borderRadius),
        border: Border.all(
          color: theme.editor.border,
          width: theme.editor.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_settings.showToolbar) _buildToolbar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_settings.showLineNumbers) _buildGutter(),
                Expanded(key: _editorKey, child: _buildEditor()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Compact settings toolbar rendered at the top of the editor.
  Widget _buildToolbar() {
    final theme = widget.theme;
    final bg = theme.editor.background;
    final border = theme.editor.border;

    // Use theme-based colors for labels
    final labelColor = theme.editor.text.withValues(alpha: 0.7);
    final activeColor = theme.isDark ? Colors.lightBlueAccent : Colors.blue;

    Widget toggle(
      String label,
      bool value,
      ValueChanged<bool> onChanged, {
      String? tooltip,
    }) {
      return Tooltip(
        message: tooltip ?? label,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  value ? Icons.toggle_on : Icons.toggle_off,
                  size: 18,
                  color: value ? activeColor : labelColor,
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: value ? activeColor : labelColor,
                    fontFamily: theme.font.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(theme.editor.borderRadius - 1),
          topRight: Radius.circular(theme.editor.borderRadius - 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          // Auto-complete
          if (_settings.showAutoCompleteToggle) ...[
            toggle(
              'Auto-complete',
              _settings.autoCompleteEnabled,
              (v) =>
                  _updateSettings(_settings.copyWith(autoCompleteEnabled: v)),
              tooltip: 'Toggle auto-completion while typing',
            ),
            const SizedBox(width: 4),
          ],
          // Error group
          if (_settings.showErrorToggles) ...[
            toggle(
              'Err',
              _settings.showErrorMarkers,
              (v) => _updateSettings(_settings.copyWith(showErrorMarkers: v)),
              tooltip: 'Show/hide error markers & underlines',
            ),
            toggle(
              'Err tip',
              _settings.showErrorTooltips,
              (v) => _updateSettings(_settings.copyWith(showErrorTooltips: v)),
              tooltip: 'Show/hide error hover tooltips',
            ),
            const SizedBox(width: 4),
          ],
          // Warning group
          if (_settings.showWarningToggles) ...[
            toggle(
              'Warn',
              _settings.showWarningMarkers,
              (v) => _updateSettings(_settings.copyWith(showWarningMarkers: v)),
              tooltip: 'Show/hide warning markers & underlines',
            ),
            toggle(
              'Warn tip',
              _settings.showWarningTooltips,
              (v) =>
                  _updateSettings(_settings.copyWith(showWarningTooltips: v)),
              tooltip: 'Show/hide warning hover tooltips',
            ),
            const SizedBox(width: 4),
          ],
          // Info group
          if (_settings.showInfoToggles) ...[
            toggle(
              'Info',
              _settings.showInfoMarkers,
              (v) => _updateSettings(_settings.copyWith(showInfoMarkers: v)),
              tooltip: 'Show/hide info markers & underlines',
            ),
            toggle(
              'Info tip',
              _settings.showInfoTooltips,
              (v) => _updateSettings(_settings.copyWith(showInfoTooltips: v)),
              tooltip: 'Show/hide info hover tooltips',
            ),
            const SizedBox(width: 4),
          ],
          // Popup position preference
          if (_settings.showPopupPositionToggle)
            toggle(
              _settings.popupPreferBelow ? 'Pop ↓' : 'Pop ↑',
              _settings.popupPreferBelow,
              (v) => _updateSettings(_settings.copyWith(popupPreferBelow: v)),
              tooltip:
                  'Toggle whether completion popups prefer to appear below or above the cursor',
            ),
          const Spacer(),
          // Open Reference button
          if (_settings.showOpenReferenceButton &&
              widget.onCompletionRequest != null)
            Tooltip(
              message: 'Open API Reference (Ctrl+R)',
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: _showApiReference,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 15,
                        color: labelColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Open Reference',
                        style: TextStyle(
                          fontSize: 11,
                          color: labelColor,
                          fontFamily: theme.font.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGutter() {
    final theme = widget.theme;
    final lineCount = widget.controller.lineCount;
    final filtered = _filteredErrors;
    final errorLines =
        filtered.where((e) => e.isError).map((e) => e.line).toSet();
    final warningLines =
        filtered.where((e) => e.isWarning).map((e) => e.line).toSet();
    final fontSize = theme.font.fontSize;
    final lineHeight = _lineHeight;

    return Container(
      width: theme.editor.gutterWidth,
      decoration: BoxDecoration(
        color: theme.editor.gutter,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(theme.editor.borderRadius - 1),
          bottomLeft: Radius.circular(theme.editor.borderRadius - 1),
        ),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          controller: _gutterScrollController,
          itemCount: lineCount,
          padding: const EdgeInsets.only(
            top: 7,
          ), // Adjusted to align with TextField
          itemBuilder: (context, index) {
            final lineNum = index + 1;
            final hasError = errorLines.contains(lineNum);
            final hasWarning = warningLines.contains(lineNum) && !hasError;

            return Material(
              color: hasError
                  ? theme.diagnostics.errorBackground
                  : hasWarning
                      ? theme.diagnostics.warningBackground
                      : theme.editor.gutter,
              child: InkWell(
                onTap: () {
                  final error = _filteredErrors.firstWhere(
                    (e) => e.line == lineNum,
                    orElse: () => const CodeError(
                      message: '',
                      line: 0,
                      column: 0,
                      offset: 0,
                      length: 0,
                      severity: '',
                      code: '',
                    ),
                  );
                  if (error.line > 0) {
                    widget.onErrorTap?.call(error);
                  }
                },
                child: Container(
                  height: lineHeight,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasError)
                        Icon(
                          Icons.error,
                          size: 12,
                          color: theme.diagnostics.error,
                        )
                      else if (hasWarning)
                        Icon(
                          Icons.warning,
                          size: 12,
                          color: theme.diagnostics.warning,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        '$lineNum',
                        style: TextStyle(
                          fontFamily: theme.font.fontFamily,
                          fontSize: fontSize - 2,
                          color: hasError
                              ? theme.diagnostics.error
                              : hasWarning
                                  ? theme.diagnostics.warning
                                  : theme.editor.lineNumber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditor() {
    final theme = widget.theme;
    final fontSize = theme.font.fontSize;
    final lineHeight = _lineHeight;

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: MouseRegion(
        onHover: _onHover,
        onExit: _onExit,
        child: Stack(
          children: [
            // Main text field
            TextField(
              controller: _textController,
              focusNode: _focusNode,
              scrollController: _scrollController,
              maxLines: null,
              expands: true,
              readOnly: widget.readOnly,
              style: TextStyle(
                fontFamily: theme.font.fontFamily,
                fontSize: fontSize,
                color: theme.editor.text,
                height: theme.font.lineHeight,
              ),
              cursorColor: theme.editor.cursor,
              decoration: InputDecoration(
                hintText: widget.placeholder ?? 'Enter Dart code...',
                hintStyle: TextStyle(color: theme.editor.placeholder),
                contentPadding: EdgeInsets.all(theme.editor.contentPadding),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: _handleTextChange,
              inputFormatters: [_SmartIndentFormatter()],
            ),

            // Error underlines overlay
            if (_filteredErrors.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ErrorUnderlinePainter(
                      errors: _filteredErrors,
                      code: widget.controller.userCode,
                      fontSize: fontSize,
                      lineHeight: lineHeight,
                      errorColor: theme.diagnostics.error,
                      warningColor: theme.diagnostics.warning,
                      infoColor: theme.diagnostics.info,
                      padding: EdgeInsets.all(theme.editor.contentPadding),
                      charWidthRatio: theme.font.charWidthRatio,
                      scrollOffset: _scrollOffset,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Code completion popup widget.
class _CompletionPopup extends StatefulWidget {
  final List<CompletionItem> items;
  final int selectedIndex;

  /// Global screen coordinates of the bottom of the cursor line.
  final Offset anchorBelow;

  /// Height of one editor line (used to flip popup above when needed).
  final double lineHeight;

  /// Whether the popup prefers to appear below the cursor.
  final bool preferBelow;
  final DartEditorTheme theme;
  final int maxItems;
  final Function(CompletionItem) onSelect;

  const _CompletionPopup({
    required this.items,
    required this.selectedIndex,
    required this.anchorBelow,
    required this.lineHeight,
    required this.preferBelow,
    required this.theme,
    required this.maxItems,
    required this.onSelect,
  });

  @override
  State<_CompletionPopup> createState() => _CompletionPopupState();
}

class _CompletionPopupState extends State<_CompletionPopup> {
  final ScrollController _scrollController = ScrollController();

  double get _itemHeight => widget.theme.tooltip.completionItemHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(_CompletionPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;

    final visibleCount = math.min(widget.items.length, widget.maxItems);
    final viewportHeight = visibleCount * _itemHeight;
    final selectedTop = widget.selectedIndex * _itemHeight;
    final selectedBottom = selectedTop + _itemHeight;

    final currentScroll = _scrollController.offset;
    final currentBottom = currentScroll + viewportHeight;

    if (selectedTop < currentScroll) {
      _scrollController.animateTo(
        selectedTop,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (selectedBottom > currentBottom) {
      _scrollController.animateTo(
        selectedBottom - viewportHeight,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooltipStyle = widget.theme.tooltip;
    final visibleCount = math.min(widget.items.length, widget.maxItems);
    final popupHeight = visibleCount * _itemHeight + 8.0;

    // Smart adaptive positioning: prefer one side, flip if not enough room.
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - widget.anchorBelow.dy;
    final spaceAbove = widget.anchorBelow.dy - widget.lineHeight;
    final placeBelow = widget.preferBelow
        ? (spaceBelow >= popupHeight || spaceAbove < popupHeight)
        : (spaceAbove < popupHeight);
    final popupTop = placeBelow
        ? widget.anchorBelow.dy
        : widget.anchorBelow.dy - widget.lineHeight - popupHeight;

    return Positioned(
      left: widget.anchorBelow.dx,
      top: popupTop,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: tooltipStyle.completionWidth,
          height: popupHeight,
          decoration: BoxDecoration(
            color: tooltipStyle.background,
            border: Border.all(color: tooltipStyle.border),
            borderRadius: BorderRadius.circular(tooltipStyle.borderRadius),
            boxShadow: tooltipStyle.shadow != null
                ? [tooltipStyle.shadow!]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tooltipStyle.borderRadius),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.items.length,
              itemExtent: _itemHeight,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = index == widget.selectedIndex;

                return _CompletionItemWidget(
                  item: item,
                  isSelected: isSelected,
                  theme: widget.theme,
                  onTap: () => widget.onSelect(item),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Individual completion item widget.
class _CompletionItemWidget extends StatelessWidget {
  final CompletionItem item;
  final bool isSelected;
  final DartEditorTheme theme;
  final VoidCallback onTap;

  const _CompletionItemWidget({
    required this.item,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDark;
    // Use theme selection color directly; it already differs per dark/light theme.
    final backgroundColor =
        isSelected ? theme.editor.selection : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: theme.tooltip.completionItemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: backgroundColor,
        child: Row(
          children: [
            Icon(item.icon, size: 16, color: item.colorFor(isDark)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.editor.text,
                  fontFamily: theme.font.fontFamily,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.detail != null)
              Text(
                item.detail!,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.editor.text.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// Error tooltip widget shown on hover.
class _ErrorTooltip extends StatelessWidget {
  final CodeError error;
  final Offset position;
  final DartEditorTheme theme;

  const _ErrorTooltip({
    required this.error,
    required this.position,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final tooltipStyle = theme.tooltip;
    final diagColors = theme.diagnostics;

    final severityColor = error.isError
        ? diagColors.error
        : error.isWarning
            ? diagColors.warning
            : diagColors.info;

    final severityIcon = error.isError
        ? Icons.error
        : error.isWarning
            ? Icons.warning
            : Icons.info;

    return Positioned(
      left: position.dx,
      top: position.dy + 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: tooltipStyle.maxWidth),
          decoration: BoxDecoration(
            color: tooltipStyle.background,
            border: Border.all(color: tooltipStyle.border),
            borderRadius: BorderRadius.circular(tooltipStyle.borderRadius),
            boxShadow:
                tooltipStyle.shadow != null ? [tooltipStyle.shadow!] : [],
          ),
          padding: tooltipStyle.padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(severityIcon, size: 16, color: severityColor),
                  const SizedBox(width: 6),
                  Text(
                    error.code,
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Line ${error.line}:${error.column}',
                    style: TextStyle(
                      color: tooltipStyle.text.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                error.message,
                style: TextStyle(color: tooltipStyle.text, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom formatter for smart indentation.
class _SmartIndentFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length == oldValue.text.length + 1) {
      final insertedChar = newValue.text[newValue.selection.start - 1];
      if (insertedChar == '\n') {
        return _handleNewline(oldValue, newValue);
      }
    }
    return newValue;
  }

  TextEditingValue _handleNewline(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursorPos = newValue.selection.start;
    final textBefore = newValue.text.substring(0, cursorPos);

    final lastNewline = textBefore.lastIndexOf('\n', cursorPos - 2);
    final previousLineStart = lastNewline + 1;
    final previousLine = textBefore.substring(previousLineStart, cursorPos - 1);

    final indent = _getIndent(previousLine);
    final extraIndent = previousLine.trimRight().endsWith('{') ? '  ' : '';

    final newText = newValue.text.substring(0, cursorPos) +
        indent +
        extraIndent +
        newValue.text.substring(cursorPos);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: cursorPos + indent.length + extraIndent.length,
      ),
    );
  }

  String _getIndent(String line) {
    final match = RegExp(r'^(\s*)').firstMatch(line);
    return match?.group(1) ?? '';
  }
}

/// Painter for error underlines (squiggly lines).
class _ErrorUnderlinePainter extends CustomPainter {
  final List<CodeError> errors;
  final String code;
  final double fontSize;
  final double lineHeight;
  final Color errorColor;
  final Color warningColor;
  final Color infoColor;
  final EdgeInsets padding;
  final double charWidthRatio;
  final double scrollOffset;

  _ErrorUnderlinePainter({
    required this.errors,
    required this.code,
    required this.fontSize,
    required this.lineHeight,
    required this.errorColor,
    required this.warningColor,
    required this.infoColor,
    required this.padding,
    this.charWidthRatio = 0.6,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (errors.isEmpty || code.isEmpty) return;

    final charWidth = fontSize * charWidthRatio;

    for (final error in errors) {
      if (error.line < 1) continue;

      final color = error.isError
          ? errorColor
          : error.isWarning
              ? warningColor
              : infoColor;

      final y = padding.top +
          (error.line - 1) * lineHeight +
          lineHeight -
          4 -
          scrollOffset;

      if (y < -10 || y > size.height + 10) continue;

      final startX = padding.left + (error.column - 1) * charWidth;
      final endX = startX + math.max(error.length, 1) * charWidth;

      _drawSquigglyLine(canvas, startX, endX, y, color);
    }
  }

  void _drawSquigglyLine(
    Canvas canvas,
    double startX,
    double endX,
    double y,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(startX, y);

    const wavelength = 4.0;
    const amplitude = 2.0;
    var x = startX;
    var up = true;

    while (x < endX) {
      x += wavelength / 2;
      final nextY = y + (up ? -amplitude : amplitude);
      path.lineTo(math.min(x, endX), nextY);
      up = !up;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ErrorUnderlinePainter oldDelegate) {
    return errors != oldDelegate.errors ||
        code != oldDelegate.code ||
        scrollOffset != oldDelegate.scrollOffset;
  }
}

/// Represents a state in the undo/redo history.
class _UndoState {
  final String text;
  final TextSelection selection;

  const _UndoState({required this.text, required this.selection});
}

/// API Reference popup widget that covers 90% of the editor.
class _ApiReferencePopup extends StatefulWidget {
  final List<CompletionItem> items;
  final DartEditorTheme theme;
  final VoidCallback onClose;

  const _ApiReferencePopup({
    required this.items,
    required this.theme,
    required this.onClose,
  });

  @override
  State<_ApiReferencePopup> createState() => _ApiReferencePopupState();
}

class _ApiReferencePopupState extends State<_ApiReferencePopup> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<CompletionItem> _filteredItems = [];
  CompletionItem? _selectedItem;
  MemberInfo? _selectedMember;
  List<String> _packages = [];
  String? _selectedPackage;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
    _searchController.addListener(_onSearchChanged);
    // Extract unique packages from items - only real packages (dart: or package:), excluding private (with _)
    final packageSet = <String>{};
    for (final item in widget.items) {
      final detail = item.detail;
      if (detail != null &&
          detail.isNotEmpty &&
          (detail.startsWith('dart:') || detail.startsWith('package:')) &&
          !detail.contains(':_')) {
        packageSet.add(detail);
      }
    }
    _packages = packageSet.toList()..sort();
    // Focus search field after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    final queryLower = query.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
        // Don't change _selectedPackage from dropdown interaction
      } else if (query.startsWith('package:') || query.startsWith('dart:')) {
        // Filter by package/dart: prefix in detail field
        // Support "dart:core map" to filter "map" within dart:core
        final parts = query.split(RegExp(r'\s+'));
        final packageFilter = parts[0].toLowerCase();
        final nameFilter =
            parts.length > 1 ? parts.sublist(1).join(' ').toLowerCase() : '';

        // Update selectedPackage only if it's an exact match in our packages list
        final exactMatch = _packages.firstWhere(
          (p) => p.toLowerCase() == packageFilter,
          orElse: () => '',
        );
        _selectedPackage = exactMatch.isNotEmpty ? exactMatch : null;

        var filtered = widget.items
            .where(
              (item) =>
                  item.detail != null &&
                  item.detail!.toLowerCase().startsWith(packageFilter),
            )
            .toList();

        // If there's a second word, filter by name within the package
        if (nameFilter.isNotEmpty) {
          final startsWithItems = <CompletionItem>[];
          final containsItems = <CompletionItem>[];

          for (final item in filtered) {
            final labelLower = item.label.toLowerCase();
            if (labelLower.startsWith(nameFilter)) {
              startsWithItems.add(item);
            } else if (labelLower.contains(nameFilter)) {
              containsItems.add(item);
            }
          }

          filtered = [...startsWithItems, ...containsItems];
        }

        _filteredItems = filtered;
      } else {
        // Normal search: prioritize startsWith, then contains
        _selectedPackage = null;
        final startsWithItems = <CompletionItem>[];
        final containsItems = <CompletionItem>[];

        for (final item in widget.items) {
          final labelLower = item.label.toLowerCase();
          if (labelLower.startsWith(queryLower)) {
            startsWithItems.add(item);
          } else if (labelLower.contains(queryLower)) {
            containsItems.add(item);
          }
        }

        _filteredItems = [...startsWithItems, ...containsItems];
      }
      // Clear selection if selected item is filtered out
      if (_selectedItem != null && !_filteredItems.contains(_selectedItem)) {
        _selectedItem = null;
        _selectedMember = null;
      }
    });
  }

  void _selectItem(CompletionItem item) {
    debugPrint(
      '[API REF] Selecting: ${item.label}, kind: ${item.kind}, isComposite: ${item.isCompositeType}, members: ${item.members?.length ?? 0}',
    );
    setState(() {
      _selectedItem = item;
      _selectedMember = null;
    });
  }

  void _selectMember(MemberInfo member) {
    setState(() {
      _selectedMember = member;
    });
  }

  void _selectPackage(String? package) {
    setState(() {
      _selectedPackage = package;
      if (package != null) {
        _searchController.text = '$package ';
        _searchController.selection = TextSelection.collapsed(
          offset: _searchController.text.length,
        );
      } else {
        _searchController.text = '';
      }
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _showPackageDialog(BuildContext context) async {
    // Capture theme before entering the async dialog builder.
    final theme = widget.theme;
    final selected = await showDialog<String?>(
      context: context,
      useRootNavigator: true, // Ensures dialog appears above all overlays
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: theme.editor.gutter,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.editor.borderRadius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.editor.border),
                  ),
                ),
                child: Text(
                  'Select Package',
                  style: TextStyle(
                    color: theme.editor.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(
                        'All packages',
                        style: TextStyle(
                          color: theme.editor.text.withValues(alpha: 0.7),
                        ),
                      ),
                      selected: _selectedPackage == null,
                      selectedTileColor: theme.editor.selection,
                      onTap: () => Navigator.of(dialogContext).pop(null),
                    ),
                    ..._packages.map(
                      (pkg) => ListTile(
                        dense: true,
                        title: Text(
                          pkg,
                          style: TextStyle(
                            color: theme.editor.text,
                            fontFamily: theme.font.fontFamily,
                            fontSize: 13,
                          ),
                        ),
                        selected: _selectedPackage == pkg,
                        selectedTileColor: theme.editor.selection,
                        onTap: () => Navigator.of(dialogContext).pop(pkg),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != _selectedPackage) {
      _selectPackage(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width * 0.9;
    final height = size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          elevation: 16,
          borderRadius: BorderRadius.circular(12),
          color: widget.theme.editor.background,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                widget.onClose();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              children: [
                // Header with search, package dropdown and close button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.theme.editor.gutter,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Package dropdown using Dialog (proper z-ordering)
                      InkWell(
                        onTap: () => _showPackageDialog(context),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: widget.theme.editor.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedPackage ?? 'All packages',
                                style: TextStyle(
                                  color: _selectedPackage != null
                                      ? widget.theme.editor.text
                                      : widget.theme.editor.text.withValues(
                                          alpha: 0.7,
                                        ),
                                  fontSize: 13,
                                  fontFamily: _selectedPackage != null
                                      ? widget.theme.font.fontFamily
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: widget.theme.editor.text.withValues(
                                  alpha: 0.7,
                                ),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.search,
                        color: widget.theme.editor.text.withValues(alpha: 0.7),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: TextStyle(
                            color: widget.theme.editor.text,
                            fontFamily: widget.theme.font.fontFamily,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search API...',
                            hintStyle: TextStyle(
                              color: widget.theme.editor.text.withValues(
                                alpha: 0.5,
                              ),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_filteredItems.length} items',
                        style: TextStyle(
                          color: widget.theme.tooltip.text.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: widget.theme.editor.text.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        iconSize: 24,
                        onPressed: widget.onClose,
                        tooltip: 'Close (Esc)',
                      ),
                    ],
                  ),
                ),
                // Results as badges
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: widget.theme.editor.border),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _filteredItems.take(200).map((item) {
                        final isSelected = item == _selectedItem;
                        return InkWell(
                          onTap: () => _selectItem(item),
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.theme.editor.selection
                                  : widget.theme.editor.border,
                              borderRadius: BorderRadius.circular(3),
                              border: isSelected
                                  ? Border.all(
                                      color: widget.theme.editor.selection
                                          .withValues(alpha: 0.7),
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 10,
                                  color: item.colorFor(true),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: item.colorFor(true),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                // Details panel
                Expanded(
                  child: _selectedItem == null
                      ? Center(
                          child: Text(
                            'Select an item to view details',
                            style: TextStyle(
                              color: widget.theme.tooltip.text.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : _buildDetailsPanel(_selectedItem!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(CompletionItem item) {
    // Debug logging
    debugPrint(
      '[API REF] Selected: ${item.label}, kind: ${item.kind}, isComposite: ${item.isCompositeType}, members: ${item.members?.length ?? 0}',
    );
    // For composite types (class, enum, mixin, extension), show members panel + detail panel
    if (item.isCompositeType &&
        item.members != null &&
        item.members!.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left panel: Members list
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: widget.theme.editor.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: widget.theme.editor.gutter),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 16,
                        color: item.colorFor(widget.theme.isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: item.colorFor(widget.theme.isDark),
                            fontSize: 14,
                            fontFamily: widget.theme.font.fontFamily,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.signature != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      item.signature!,
                      style: TextStyle(
                        color: widget.theme.editor.text.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontFamily: widget.theme.font.fontFamily,
                      ),
                    ),
                  ),
                if (item.detail != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      item.detail!,
                      style: TextStyle(
                        color: widget.theme.tooltip.text.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ),
                Divider(color: widget.theme.editor.border, height: 1),
                // Members list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(4),
                    itemCount: item.members!.length,
                    itemBuilder: (context, index) {
                      final member = item.members![index];
                      final isSelected = member == _selectedMember;
                      return InkWell(
                        onTap: () => _selectMember(member),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.theme.editor.selection
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getMemberIcon(member.kind),
                                size: 14,
                                color: _getMemberColor(member.kind),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  member.name,
                                  style: TextStyle(
                                    color: _getMemberColor(member.kind),
                                    fontSize: 12,
                                    fontFamily: widget.theme.font.fontFamily,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Right panel: Member details
          Expanded(
            child: _selectedMember == null
                ? Center(
                    child: Text(
                      'Select a member to view details',
                      style: TextStyle(
                        color: widget.theme.tooltip.text.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  )
                : _buildMemberDetailsPanel(_selectedMember!),
          ),
        ],
      );
    }

    // For non-composite types, show single detail panel with signature
    return _buildSignaturePanel(item);
  }

  Widget _buildSignaturePanel(CompletionItem item) {
    final isDark = widget.theme.isDark;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header
          Row(
            children: [
              Icon(item.icon, size: 24, color: item.colorFor(isDark)),
              const SizedBox(width: 12),
              Expanded(
                child: SelectableText(
                  item.label,
                  style: TextStyle(
                    color: item.colorFor(isDark),
                    fontSize: 20,
                    fontFamily: widget.theme.font.fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Kind badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.theme.editor.border,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.kind.name.toUpperCase(),
              style: TextStyle(
                color: widget.theme.editor.text.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Signature
          if (item.signature != null) ...[
            const SizedBox(height: 16),
            Text(
              'Signature:',
              style: TextStyle(
                color: widget.theme.editor.text.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.theme.editor.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: widget.theme.editor.border),
              ),
              child: SelectableText(
                item.signature!,
                style: TextStyle(
                  color: widget.theme.syntax.function,
                  fontSize: 14,
                  fontFamily: widget.theme.font.fontFamily,
                ),
              ),
            ),
          ],
          if (item.detail != null) ...[
            const SizedBox(height: 16),
            SelectableText(
              'Source: ${item.detail}',
              style: TextStyle(
                color: widget.theme.tooltip.text.withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
          ],
          if (item.documentation != null) ...[
            const SizedBox(height: 16),
            Text(
              'Documentation:',
              style: TextStyle(
                color: widget.theme.editor.text.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  item.documentation!,
                  style: TextStyle(
                    color: widget.theme.editor.text,
                    fontSize: 13,
                    fontFamily: widget.theme.font.fontFamily,
                  ),
                ),
              ),
            ),
          ],
          if (item.signature == null && item.documentation == null)
            Expanded(
              child: Center(
                child: Text(
                  'No additional information available',
                  style: TextStyle(
                    color: widget.theme.tooltip.text.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberDetailsPanel(MemberInfo member) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Member header
          Row(
            children: [
              Icon(
                _getMemberIcon(member.kind),
                size: 24,
                color: _getMemberColor(member.kind),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SelectableText(
                  member.name,
                  style: TextStyle(
                    color: _getMemberColor(member.kind),
                    fontSize: 20,
                    fontFamily: widget.theme.font.fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Kind badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.theme.editor.border,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              member.kind.name.toUpperCase(),
              style: TextStyle(
                color: widget.theme.editor.text.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Signature
          const SizedBox(height: 16),
          Text(
            'Signature:',
            style: TextStyle(
              color: widget.theme.editor.text.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.theme.editor.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: widget.theme.editor.border),
            ),
            child: SelectableText(
              member.signature,
              style: TextStyle(
                color: widget.theme.syntax.function,
                fontSize: 14,
                fontFamily: widget.theme.font.fontFamily,
              ),
            ),
          ),
          if (member.documentation != null) ...[
            const SizedBox(height: 16),
            Text(
              'Documentation:',
              style: TextStyle(
                color: widget.theme.editor.text.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  member.documentation!,
                  style: TextStyle(
                    color: widget.theme.editor.text,
                    fontSize: 13,
                    fontFamily: widget.theme.font.fontFamily,
                  ),
                ),
              ),
            ),
          ],
          if (member.documentation == null) const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  IconData _getMemberIcon(CompletionKind kind) {
    return switch (kind) {
      CompletionKind.constructor => Icons.add_box,
      CompletionKind.method => Icons.functions_outlined,
      CompletionKind.getter => Icons.output,
      CompletionKind.setter => Icons.input,
      CompletionKind.property => Icons.account_tree,
      CompletionKind.constant => Icons.lock,
      CompletionKind.enumValue => Icons.tag,
      _ => Icons.code,
    };
  }

  Color _getMemberColor(CompletionKind kind) {
    return switch (kind) {
      CompletionKind.constructor ||
      CompletionKind.method =>
        widget.theme.syntax.function,
      CompletionKind.getter ||
      CompletionKind.setter ||
      CompletionKind.property =>
        widget.theme.syntax.variable,
      CompletionKind.constant ||
      CompletionKind.enumValue =>
        widget.theme.syntax.constant,
      _ => widget.theme.editor.text.withValues(alpha: 0.7),
    };
  }
}

// Legacy compatibility
typedef DartCodeTheme = DartEditorTheme;
