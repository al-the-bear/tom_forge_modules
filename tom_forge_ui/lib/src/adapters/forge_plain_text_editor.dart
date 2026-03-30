import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
      );
    }
    // Build theme with monospace font for plain text.
    final theme = _buildThemeFromOptions();
    return MdEditor(
      controller: controller,
      integration: _integration,
      theme: theme,
      // Raw-only mode: disable markdown preview by using 'below' position
      // and making autoHideEditor false. The preview will show raw text.
      settings: MdEditorSettings.standard().copyWith(
        autoHideEditor: false,
        rawEditorPosition: RawEditorPosition.below,
      ),
    );
  }

  /// Builds an [MdEditorTheme] applying current [_options] with mono font.
  MdEditorTheme _buildThemeFromOptions() {
    const baseTheme = MdBasicTheme();
    final fontFamily = _options.fontFamily ?? 'monospace';
    final basic = MdBasicTheme(
      fontFamily: fontFamily,
      monoFontFamily: fontFamily,
      baseFontSize: _options.fontSize ?? baseTheme.baseFontSize,
      lineHeight: _options.lineHeight ?? baseTheme.lineHeight,
    );
    return MdEditorTheme(basic: basic);
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
  }

  @override
  void revealRange(ForgeTextRange range) {
    setCursorPosition(range.start);
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
