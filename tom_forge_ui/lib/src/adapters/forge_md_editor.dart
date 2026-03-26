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

/// Adapter that wraps [MdEditorController] as a [ForgeTextEditor].
class ForgeMdEditor extends ForgeTextEditor {
  final MdEditorController controller;
  final ForgeModule _module;
  final _title = ValueNotifier<String>('Markdown');
  final _titleExtension = ValueNotifier<String?>(null);
  final _isDirty = ValueNotifier<bool>(false);
  final _cursorPos = ValueNotifier<ForgeTextPosition>(const ForgeTextPosition.zero());
  final _selection = ValueNotifier<ForgeTextRange?>(null);
  final _selections = ValueNotifier<List<ForgeTextRange>>([]);
  final _visibleRange =
      ValueNotifier<ForgeTextRange>(const ForgeTextRange.empty());

  late final PositionConverter _positionConverter;
  ForgeTextEditorOptions _options;
  ShellEditorIntegration? _integration;

  /// Decoration state.
  final Map<String, List<ForgeDecorationRange>> _decorationMap = {};

  ForgeMdEditor({
    required this.controller,
    required ForgeModule module,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(),
  })  : _module = module,
        _options = options {
    _positionConverter = PositionConverter(controller.markdown);

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

  // ── ForgeComponent ──

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => const IconData(0xe24d, fontFamily: 'MaterialIcons'); // description

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  ForgeModule get module => _module;

  @override
  Widget buildMain(BuildContext context) {
    if (_module case final TomForgeShellModule shellModule) {
      _integration ??= ShellEditorIntegration(
        shellApi: shellModule.shellApi,
        editorId: 'md-editor-${uri.hashCode}',
        editorTypeId: 'md',
      );
    }
    return MdEditor(
      controller: controller,
      integration: _integration,
    );
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  // ── ForgeEditor ──

  @override
  Uri get uri => controller.uri ?? Uri.parse('untitled:markdown');

  @override
  FileHandlingResult canHandle(Uri uri) {
    final ext = uri.path.split('.').last.toLowerCase();
    if (ext == 'md' || ext == 'markdown') return FileHandlingResult.accept;
    return FileHandlingResult.reject;
  }

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  // ── ForgeTextEditor ──

  @override
  ForgeDocument get document => _MdForgeDocument(controller, _positionConverter);

  @override
  ValueListenable<ForgeTextPosition> get cursorPosition => _cursorPos;

  @override
  ValueListenable<ForgeTextRange?> get selection => _selection;

  @override
  ValueListenable<List<ForgeTextRange>> get selections => _selections;

  @override
  void setSelections(List<ForgeTextRange> ranges) {
    if (ranges.isNotEmpty) {
      setSelection(ranges.first);
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
    // MdEditorController doesn't have native selection API,
    // so we set cursor to selection start.
    setCursorPosition(range.start);
  }

  @override
  void selectAll() {
    final text = controller.markdown;
    controller.setCursorOffset(0);
    // Notify selection covering entire document.
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
    // Also update controller-level decorations.
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
    final sel = controller.selectionNotifier.value;
    if (sel == null) {
      _selection.value = null;
      _selections.value = [];
    } else {
      _positionConverter = PositionConverter(controller.markdown);
      final range = ForgeTextRange(
        start: _positionConverter.offsetToPosition(sel.start),
        end: _positionConverter.offsetToPosition(sel.end),
      );
      _selection.value = range;
      _selections.value = [range];
    }
  }

  void _onVisibleRangeChanged() {
    final vr = controller.visibleRangeNotifier.value;
    _visibleRange.value = ForgeTextRange(
      start: ForgeTextPosition(line: vr.firstLine, column: 0),
      end: ForgeTextPosition(line: vr.lastLine, column: 0),
    );
  }

  void _onContentChanged() {
    _positionConverter = PositionConverter(controller.markdown);
    _isDirty.value = controller.canUndo;
    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
  }

  /// Release listeners.
  void dispose() {
    _integration?.dispose();
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

/// Lightweight [ForgeDocument] backed by [MdEditorController].
class _MdForgeDocument implements ForgeDocument {
  final MdEditorController _controller;
  final PositionConverter _converter;

  _MdForgeDocument(this._controller, this._converter);

  @override
  Uri get uri => _controller.uri ?? Uri.parse('untitled:markdown');

  @override
  String get text => _controller.markdown;

  @override
  int get lineCount => _converter.lineCount;

  @override
  String lineAt(int line) => _converter.lineAt(line);

  @override
  String textInRange(ForgeTextRange range) => _converter.textInRange(range);

  @override
  String get languageId => 'markdown';

  @override
  Encoding get encoding => utf8;

  @override
  int get version => 0;

  @override
  bool get isUntitled => _controller.uri == null;

  @override
  Stream<DocumentChangeEvent> get onDidChange => const Stream.empty();
}
