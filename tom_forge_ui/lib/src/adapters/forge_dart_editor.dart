import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

import '../components/forge_text_editor.dart';
import '../components/forge_component.dart';
import '../integrations/shell_editor_integration.dart';
import '../module/forge_module.dart';
import 'tom_forge_shell_module.dart';

/// Adapter that wraps [DartCodeController] + [DartCodeEditor] as a
/// [ForgeTextEditor].
class ForgeDartEditor extends ForgeTextEditor {
  final DartCodeController controller;
  final ForgeModule _module;
  final List<CodeError> Function()? errorsProvider;

  final _title = ValueNotifier<String>('Dart');
  final _titleExtension = ValueNotifier<String?>(null);
  final _isDirty = ValueNotifier<bool>(false);
  final _cursorPos = ValueNotifier<ForgeTextPosition>(const ForgeTextPosition.zero());
  final _selection = ValueNotifier<ForgeTextRange?>(null);
  final _selections = ValueNotifier<List<ForgeTextRange>>([]);
  final _visibleRange = ValueNotifier<ForgeTextRange>(const ForgeTextRange.empty());

  late PositionConverter _positionConverter;
  late final _DartForgeDocument _document;
  ForgeTextEditorOptions _options;
  String _lastCode = '';
  ShellEditorIntegration? _integration;

  /// Decoration state.
  final Map<String, List<ForgeDecorationRange>> _decorationMap = {};

  ForgeDartEditor({
    required this.controller,
    required ForgeModule module,
    this.errorsProvider,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(),
  })  : _module = module,
        _options = options {
    _lastCode = controller.userCode;
    _positionConverter = PositionConverter(_lastCode);
    _document = _DartForgeDocument(
      controller.uri ?? Uri.parse('untitled:dart'),
      controller,
      _positionConverter,
    );

    controller.addListener(_onControllerChanged);

    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
  }

  // ── ForgeComponent ──

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon =>
      const IconData(0xe86f, fontFamily: 'MaterialIcons'); // code

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  ForgeModule get module => _module;

  @override
  Widget buildMain(BuildContext context) {
    if (_module case final TomForgeShellModule shellModule) {
      _integration ??= ShellEditorIntegration(
        shellApi: shellModule.shellApi,
        editorId: 'dart-editor-${uri.hashCode}',
        editorTypeId: 'dart',
      );
    }
    // Build theme with applied options.
    final theme = _buildThemeFromOptions();
    return DartCodeEditor(
      controller: controller,
      integration: _integration,
      theme: theme,
      errors: errorsProvider?.call() ?? const [],
      onCursorChanged: _onCursorOffset,
      onSelectionChanged: _onSelectionRange,
      onVisibleRangeChanged: _onVisibleRangeLines,
    );
  }

  /// Builds a [DartEditorTheme] applying current [_options] to the base theme.
  DartEditorTheme _buildThemeFromOptions() {
    final base = DartEditorTheme.dark();
    final font = base.font.copyWith(
      fontFamily: _options.fontFamily ?? base.font.fontFamily,
      fontSize: _options.fontSize ?? base.font.fontSize,
      lineHeight: _options.lineHeight ?? base.font.lineHeight,
    );
    return base.copyWith(font: font);
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  // ── ForgeEditor ──

  @override
  Uri get uri => controller.uri ?? Uri.parse('untitled:dart');

  @override
  FileHandlingResult canHandle(Uri uri) {
    final ext = uri.path.split('.').last.toLowerCase();
    if (ext == 'dart') return FileHandlingResult.accept;
    return FileHandlingResult.reject;
  }

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  @override
  void markClean() {
    _isDirty.value = false;
  }

  @override
  String? getContent() => controller.userCode;

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
      // Set primary selection without calling setSelection (which would overwrite selections).
      _selection.value = ranges.first;
    } else {
      _selection.value = null;
    }
  }

  @override
  String get selectedText {
    final sel = _selection.value;
    if (sel == null || sel.isEmpty) return '';
    final text = controller.userCode;
    final start = _positionConverter.positionToOffset(sel.start);
    final end = _positionConverter.positionToOffset(sel.end);
    if (start < 0 || end > text.length) return '';
    return text.substring(start, end);
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
    final code = controller.userCode;
    final offset = _positionConverter.positionToOffset(_cursorPos.value);
    controller.userCode =
        code.substring(0, offset) + text + code.substring(offset);
  }

  @override
  void replaceRange(ForgeTextRange range, String replacement) {
    final code = controller.userCode;
    final start = _positionConverter.positionToOffset(range.start);
    final end = _positionConverter.positionToOffset(range.end);
    controller.userCode =
        code.substring(0, start) + replacement + code.substring(end);
  }

  @override
  void deleteRange(ForgeTextRange range) => replaceRange(range, '');

  @override
  void setCursorPosition(ForgeTextPosition position) {
    _cursorPos.value = position;
  }

  @override
  void setSelection(ForgeTextRange range) {
    _selection.value = range;
    _selections.value = [range];
  }

  @override
  void selectAll() {
    final text = controller.userCode;
    _selection.value = ForgeTextRange(
      start: const ForgeTextPosition.zero(),
      end: _positionConverter.offsetToPosition(text.length),
    );
  }

  @override
  void revealPosition(ForgeTextPosition position) {
    setCursorPosition(position);
  }

  @override
  void revealRange(ForgeTextRange range) {
    setCursorPosition(range.start);
  }

  @override
  List<ForgeTextRange> findAll(Pattern pattern) {
    final text = controller.userCode;
    return pattern.allMatches(text).map((m) {
      return ForgeTextRange(
        start: _positionConverter.offsetToPosition(m.start),
        end: _positionConverter.offsetToPosition(m.end),
      );
    }).toList();
  }

  @override
  int replaceAll(Pattern pattern, String replacement) {
    final text = controller.userCode;
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) return 0;
    var result = text;
    for (final m in matches.reversed) {
      result =
          result.substring(0, m.start) + replacement + result.substring(m.end);
    }
    controller.userCode = result;
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

  // ── DartCodeEditor callback handlers ──

  void _onCursorOffset(int offset) {
    _positionConverter = PositionConverter(controller.userCode);
    _cursorPos.value = _positionConverter.offsetToPosition(offset);
  }

  void _onSelectionRange(({int start, int end}) sel) {
    _positionConverter = PositionConverter(controller.userCode);
    final range = ForgeTextRange(
      start: _positionConverter.offsetToPosition(sel.start),
      end: _positionConverter.offsetToPosition(sel.end),
    );
    _selection.value = range;
    _selections.value = [range];
  }

  void _onVisibleRangeLines(({int startLine, int endLine}) vr) {
    _visibleRange.value = ForgeTextRange(
      start: ForgeTextPosition(line: vr.startLine, column: 0),
      end: ForgeTextPosition(line: vr.endLine, column: 0),
    );
  }

  void _onControllerChanged() {
    final code = controller.userCode;
    if (code != _lastCode) {
      _lastCode = code;
      _positionConverter = PositionConverter(code);
      _isDirty.value = true;
      _document.updateConverter(_positionConverter);
      _document.notifyContentChanged();
    }
    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
  }

  /// Release listeners.
  void dispose() {
    _integration?.dispose();
    _document.dispose();
    controller.removeListener(_onControllerChanged);
    _title.dispose();
    _titleExtension.dispose();
    _isDirty.dispose();
    _cursorPos.dispose();
    _selection.dispose();
    _selections.dispose();
    _visibleRange.dispose();
  }
}

/// [ForgeDocument] backed by [DartCodeController] using [ForgeDocumentAdapter]
/// for version tracking, dirty state, and change event broadcasting.
class _DartForgeDocument extends ForgeDocumentAdapter {
  final DartCodeController _controller;
  PositionConverter _converter;

  _DartForgeDocument(super.uri, this._controller, this._converter);

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
  String get text => _controller.userCode;

  @override
  int get lineCount => _converter.lineCount;

  @override
  String lineAt(int line) => _converter.lineAt(line);

  @override
  String textInRange(ForgeTextRange range) => _converter.textInRange(range);

  @override
  String get languageId => 'dart';

  @override
  Encoding get encoding => utf8;

  @override
  bool get isUntitled => _controller.uri == null;
}
