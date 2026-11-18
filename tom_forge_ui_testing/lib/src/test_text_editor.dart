import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import 'package:tom_forge_ui/tom_forge_ui.dart';

import 'test_document.dart';

/// Minimal [ForgeTextEditor] implementation for unit and integration tests.
class ForgeTestTextEditor extends ForgeTextEditor {
  /// The module this editor belongs to.
  final ForgeModule module;
  final ForgeTestDocument _document;
  final _title = ValueNotifier<String>('Test');
  final _titleExtension = ValueNotifier<String?>(null);
  final _cursorPosition = ValueNotifier<ForgeTextPosition>(
    const ForgeTextPosition.zero(),
  );
  final _selection = ValueNotifier<ForgeTextRange?>(null);
  final _selections = ValueNotifier<List<ForgeTextRange>>([]);
  final _visibleRange = ValueNotifier<ForgeTextRange>(
    ForgeTextRange(
      start: const ForgeTextPosition.zero(),
      end: const ForgeTextPosition(line: 20, column: 0),
    ),
  );
  final _isDirty = ValueNotifier<bool>(false);
  final Map<String, List<ForgeDecorationRange>> _decorations = {};
  ForgeTextEditorOptions _options;

  ForgeTestTextEditor(
    this.module, {
    ForgeTestDocument? document,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(),
  }) : _document = document ?? ForgeTestDocument(),
       _options = options {
    _title.value = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'Test';
  }

  // ── ForgeComponent ──

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => const IconData(0xe8e0, fontFamily: 'MaterialIcons'); // text_fields

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  @override
  Widget buildMain(BuildContext context) {
    return const SizedBox.shrink();
  }

  @override
  Widget buildCopy(BuildContext context) => buildMain(context);

  // ── ForgeEditor ──

  @override
  Uri get uri => _document.uri;

  @override
  FileHandlingResult canHandle(Uri uri) {
    return uri.path.endsWith('.test')
        ? FileHandlingResult.accept
        : FileHandlingResult.reject;
  }

  @override
  ValueListenable<bool> get isDirty => _isDirty;

  // ── ForgeTextEditor ──

  @override
  ForgeDocument get document => _document;

  @override
  ValueListenable<ForgeTextPosition> get cursorPosition => _cursorPosition;

  @override
  ValueListenable<ForgeTextRange?> get selection => _selection;

  @override
  ValueListenable<List<ForgeTextRange>> get selections => _selections;

  @override
  void setSelections(List<ForgeTextRange> ranges) {
    _selections.value = ranges;
    if (ranges.isNotEmpty) {
      _selection.value = ranges.first;
    }
  }

  @override
  String get selectedText {
    final sel = _selection.value;
    if (sel == null || sel.isEmpty) return '';
    return _document.textInRange(sel);
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
    _document.insert(_cursorPosition.value, text);
    _isDirty.value = true;
  }

  @override
  void replaceRange(ForgeTextRange range, String replacement) {
    _document.replace(range, replacement);
    _isDirty.value = true;
  }

  @override
  void deleteRange(ForgeTextRange range) {
    _document.replace(range, '');
    _isDirty.value = true;
  }

  @override
  void setCursorPosition(ForgeTextPosition position) {
    _cursorPosition.value = position;
  }

  @override
  void setSelection(ForgeTextRange range) {
    _selection.value = range;
    _selections.value = [range];
  }

  @override
  void selectAll() {
    final lastLine = _document.lineCount - 1;
    setSelection(
      ForgeTextRange(
        start: const ForgeTextPosition.zero(),
        end: ForgeTextPosition(
          line: lastLine,
          column: _document.lineAt(lastLine).length,
        ),
      ),
    );
  }

  @override
  void revealPosition(ForgeTextPosition position) {
    _visibleRange.value = ForgeTextRange(
      start: ForgeTextPosition(line: max(0, position.line - 10), column: 0),
      end: ForgeTextPosition(line: position.line + 10, column: 0),
    );
  }

  @override
  void revealRange(ForgeTextRange range) {
    revealPosition(range.start);
  }

  @override
  List<ForgeTextRange> findAll(Pattern pattern) {
    return _document.findAll(pattern);
  }

  @override
  int replaceAll(Pattern pattern, String replacement) {
    final count = _document.replaceAll(pattern, replacement);
    if (count > 0) _isDirty.value = true;
    return count;
  }

  @override
  ForgeTextEditorOptions get options => _options;

  @override
  void updateOptions(ForgeTextEditorOptions newOptions) {
    _options = newOptions;
  }

  @override
  void setDecorations(
    ForgeDecorationType type,
    List<ForgeDecorationRange> ranges,
  ) {
    _decorations[type.key] = ranges;
  }

  @override
  void clearDecorations(ForgeDecorationType type) {
    _decorations.remove(type.key);
  }

  /// Read decorations applied by test — not part of the public interface.
  Map<String, List<ForgeDecorationRange>> get appliedDecorations =>
      Map.unmodifiable(_decorations);

  @override
  String? getContent() => _document.text;

  @override
  void markClean() {
    _isDirty.value = false;
  }

  /// Dispose value notifiers.
  void dispose() {
    _title.dispose();
    _titleExtension.dispose();
    _cursorPosition.dispose();
    _selection.dispose();
    _selections.dispose();
    _visibleRange.dispose();
    _isDirty.dispose();
    _document.dispose();
  }
}
