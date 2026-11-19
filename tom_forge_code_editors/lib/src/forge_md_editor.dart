import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_md_editor/tom_md_editor.dart';

import 'package:tom_forge_shell/tom_forge_shell.dart';

/// Adapter that wraps [MdEditorController] as a [ForgeTextEditor].
class ForgeMdEditor extends ForgeTextEditor implements ForgeEditorOfType {
  @override
  String get editorTypeId => 'md';

  final MdEditorController controller;
  final ForgeModule _module;
  final _stateStreamController = StreamController<void>.broadcast();
  final _title = ValueNotifier<String>('Markdown');
  final _titleExtension = ValueNotifier<String?>(null);
  final _cursorPos = ValueNotifier<ForgeTextPosition>(
    const ForgeTextPosition.zero(),
  );
  final _selection = ValueNotifier<ForgeTextRange?>(null);
  final _selections = ValueNotifier<List<ForgeTextRange>>([]);
  final _visibleRange = ValueNotifier<ForgeTextRange>(
    const ForgeTextRange.empty(),
  );

  late PositionConverter _positionConverter;
  late final _MdForgeDocument _document;
  ForgeTextEditorOptions _options;
  ShellEditorIntegration? _integration;
  ForgeDiagnosticCollection? _diagnosticCollection;

  /// Optional path to the directory containing docspec schema files.
  ///
  /// When set, the adapter can resolve schemas from this location.
  /// Falls back to the editor-specific config map key `docspecSchemasPath`
  /// when not set via constructor.
  late final String? docspecSchemasPath;

  /// Decoration state.
  final Map<String, List<ForgeDecorationRange>> _decorationMap = {};

  ForgeMdEditor({
    required this.controller,
    required ForgeModule module,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(),
    String? docspecSchemasPath,
  }) : _module = module,
       _options = options {
    // Resolve docspec schemas path: constructor arg > editor config.
    // Guard: shell may not be activated yet during tests.
    String? configPath;
    if (module case final TomForgeShellModule m when m.isActivated) {
      configPath =
          m.shellApi.getEditorSpecificConfig('md')['docspecSchemasPath']
              as String?;
    }
    this.docspecSchemasPath = docspecSchemasPath ?? configPath;
    _positionConverter = PositionConverter(controller.markdown);
    _document = _MdForgeDocument(
      controller.uri ?? Uri.parse('untitled:markdown'),
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

    // Wire validation changes to the diagnostic manager.
    _wireValidationDiagnostics();

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
      _integration ??=
          ShellEditorIntegration(
              shellApi: shellModule.shellApi,
              editorId: 'md-editor-${uri.hashCode}',
              editorTypeId: 'md',
            )
            ..descriptors = [
              ...MdEditorActions.descriptors,
              ...StandardEditingActions.descriptors,
            ];
    }
    // Build theme with applied options.
    final theme = _buildThemeFromOptions();
    final settings = _buildSettingsFromConfig();
    return MdEditor(
      controller: controller,
      integration: _integration,
      theme: theme,
      settings: settings,
    );
  }

  /// Builds an [MdEditorTheme] applying current [_options] to the base theme.
  MdEditorTheme _buildThemeFromOptions() {
    const baseTheme = MdBasicTheme();
    final basic = MdBasicTheme(
      fontFamily: _options.fontFamily ?? baseTheme.fontFamily,
      monoFontFamily: _options.fontFamily ?? baseTheme.monoFontFamily,
      baseFontSize: _options.fontSize ?? baseTheme.baseFontSize,
      lineHeight: _options.lineHeight ?? baseTheme.lineHeight,
    );
    return MdEditorTheme(basic: basic);
  }

  /// Builds [MdEditorSettings] from the editor-specific config map.
  MdEditorSettings _buildSettingsFromConfig() {
    final shellApi = switch (_module) {
      final TomForgeShellModule m => m.shellApi,
      _ => null,
    };
    final c =
        shellApi?.getEditorSpecificConfig('md') ?? const <String, dynamic>{};
    // Start from standard defaults and overlay user config.
    return MdEditorSettings.standard().copyWith(
      autoHideEditor: (c['autoHideEditor'] as bool?) ?? false,
      rawEditorPosition: RawEditorPosition.below,
      showTree: c['showTree'] as bool?,
      showToolbar: c['showToolbar'] as bool?,
      showStatusBar: c['showStatusBar'] as bool?,
      showSearchBox: c['showSearchBox'] as bool?,
      allowEditorPositionChange: c['allowEditorPositionChange'] as bool?,
      livePreview: c['livePreview'] as bool?,
      showLineNumbers: c['showLineNumbers'] as bool?,
      showSectionBorders: c['showSectionBorders'] as bool?,
      highlightCurrentSection: c['highlightCurrentSection'] as bool?,
      enableSmoothScrolling: c['enableSmoothScrolling'] as bool?,
      expandAllByDefault: c['expandAllByDefault'] as bool?,
      showValidationMarkers: c['showValidationMarkers'] as bool?,
      enableDragAndDrop: c['enableDragAndDrop'] as bool?,
      showSectionIcons: c['showSectionIcons'] as bool?,
      enableSearch: c['enableSearch'] as bool?,
      enableReplace: c['enableReplace'] as bool?,
      enableRegexSearch: c['enableRegexSearch'] as bool?,
      enableMermaid: c['enableMermaid'] as bool?,
      enableMath: c['enableMath'] as bool?,
      enableFootnotes: c['enableFootnotes'] as bool?,
      enableTaskLists: c['enableTaskLists'] as bool?,
      enableInteractiveTaskLists: c['enableInteractiveTaskLists'] as bool?,
      enableTables: c['enableTables'] as bool?,
      enableSyntaxHighlighting: c['enableSyntaxHighlighting'] as bool?,
      showCodeBlockLanguage: c['showCodeBlockLanguage'] as bool?,
      showCopyCodeButton: c['showCopyCodeButton'] as bool?,
      showCodeEditButton: c['showCodeEditButton'] as bool?,
      enableCodeEditing: c['enableCodeEditing'] as bool?,
      showTableEditButton: c['showTableEditButton'] as bool?,
      enableTableEditing: c['enableTableEditing'] as bool?,
      readOnly: c['readOnly'] as bool?,
      confirmDelete: c['confirmDelete'] as bool?,
      autoSave: c['autoSave'] as bool?,
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
  ValueListenable<bool> get isDirty => controller.isDirty;

  @override
  void markClean() => controller.markSaved();

  @override
  bool replaceContent(String content) {
    controller.replaceContent(content);
    return true;
  }

  @override
  String? getContent() {
    // A save writes what is typed: typing not handed over yet goes first.
    controller.flush();
    return controller.markdown;
  }

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

  // ── EditorActionProvider ──

  @override
  Set<String> get supportedActionIds =>
      StandardEditingActions.standardActionIds;

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
    hasTextBuffer: true,
    supportsUndoRedo: true,
    supportsClipboard: true,
    supportsLineEditing: true,
    supportsSelection: true,
  );

  @override
  EditorStateSnapshot get stateSnapshot => EditorStateSnapshot(
    hasSelection: hasSelection,
    hasContent: controller.markdown.isNotEmpty,
    isEditable: true,
    canUndo: controller.canUndo,
    canRedo: controller.canRedo,
    isTextMode: true,
  );

  @override
  bool executeAction(String actionId) {
    final integration = _integration;
    if (integration == null) return false;
    return integration.executeAction(actionId);
  }

  @override
  Stream<void> get onStateChanged => _stateStreamController.stream;

  @override
  ValueListenable<ForgeTextRange> get visibleRange => _visibleRange;

  @override
  void insertText(String text) {
    final code = controller.markdown;
    final offset = _positionConverter.positionToOffset(_cursorPos.value);
    controller.applyEdit(
      code.substring(0, offset) + text + code.substring(offset),
      cursor: offset + text.length,
    );
  }

  @override
  void replaceRange(ForgeTextRange range, String replacement) {
    final startOffset = _positionConverter.positionToOffset(range.start);
    final endOffset = _positionConverter.positionToOffset(range.end);
    final current = controller.markdown;
    final newText =
        current.substring(0, startOffset) +
        replacement +
        current.substring(endOffset);
    controller.applyEdit(newText, cursor: startOffset + replacement.length);
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
    // so we position the cursor and update the ValueNotifier.
    setCursorPosition(range.start);
    _selection.value = range;
    _selections.value = [range];
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
    controller.applyEdit(result);
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
    // Also update controller-level decorations.
    controller.setDecorations(
      type.key,
      ranges
          .map(
            (r) => (
              start: _positionConverter.positionToOffset(r.range.start),
              end: _positionConverter.positionToOffset(r.range.end),
            ),
          )
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
    _stateStreamController.add(null);
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
    _document.updateConverter(_positionConverter);
    _document.notifyContentChanged();
    _stateStreamController.add(null);
    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
    // Update schema title extension when schema changes.
    if (controller.schema != null) {
      _titleExtension.value = controller.schema!.fullId;
    }
  }

  /// Wires the controller's validation events to the forge diagnostic system.
  void _wireValidationDiagnostics() {
    final existingHandlers = controller.eventHandlers;
    controller.eventHandlers = MdEditorEventHandlers(
      onBeforeSectionCreate: existingHandlers?.onBeforeSectionCreate,
      onSectionCreated: existingHandlers?.onSectionCreated,
      onBeforeSectionDelete: existingHandlers?.onBeforeSectionDelete,
      onSectionDeleted: existingHandlers?.onSectionDeleted,
      onBeforeSectionMove: existingHandlers?.onBeforeSectionMove,
      onSectionMoved: existingHandlers?.onSectionMoved,
      onBeforeHeadlineChange: existingHandlers?.onBeforeHeadlineChange,
      onHeadlineChanged: existingHandlers?.onHeadlineChanged,
      onBeforeTextChange: existingHandlers?.onBeforeTextChange,
      onTextChanged: existingHandlers?.onTextChanged,
      onSectionSelected: existingHandlers?.onSectionSelected,
      onBeforeSave: existingHandlers?.onBeforeSave,
      onSaved: existingHandlers?.onSaved,
      onLoaded: existingHandlers?.onLoaded,
      onValidationChanged: (event) {
        existingHandlers?.onValidationChanged?.call(event);
        _updateDiagnostics(event.errors);
      },
    );

    // Push initial diagnostics if schema is already set and has errors.
    if (controller.validationErrors.isNotEmpty) {
      _updateDiagnostics(controller.validationErrors);
    }
  }

  /// Converts validation errors to [ForgeDiagnostic] entries and pushes
  /// them to the diagnostic manager.
  void _updateDiagnostics(List<ValidationError> errors) {
    final module = _module;
    final shell = module is TomForgeShellModule ? module.shellApi : null;
    if (shell == null) return;

    final fileUri = controller.uri;
    if (fileUri == null) return;

    _diagnosticCollection ??= shell.diagnostics.createCollection('md-editor');

    if (errors.isEmpty) {
      _diagnosticCollection!.set(fileUri, const []);
      return;
    }

    final diagnostics = ForgeValidationBridge.convert(
      errors,
      fileUri,
      (path) => _pathToRange(path),
    );

    _diagnosticCollection!.set(fileUri, diagnostics);
  }

  /// Maps a validation error path to a text range in the document.
  ///
  /// The path typically contains a section ID or headline as first element.
  /// Walks the document tree to find the matching section and returns
  /// a range pointing at its source line.
  ForgeTextRange _pathToRange(List<Object> path) {
    if (path.isEmpty) return const ForgeTextRange.empty();

    final sectionKey = path.first.toString();
    final section = _findSectionByKey(controller.document.sections, sectionKey);

    if (section != null && section.sourceLineStart != null) {
      final line = section.sourceLineStart!; // 0-based
      return ForgeTextRange(
        start: ForgeTextPosition(line: line, column: 0),
        end: ForgeTextPosition(line: line, column: 1),
      );
    }

    return const ForgeTextRange.empty();
  }

  /// Recursively searches for a section matching by ID or headline.
  MdSection? _findSectionByKey(List<MdSection> sections, String key) {
    for (final section in sections) {
      if (section.id == key || section.headline == key) {
        return section;
      }
      final found = _findSectionByKey(section.subsections, key);
      if (found != null) return found;
    }
    return null;
  }

  /// Release listeners.
  void dispose() {
    _stateStreamController.close();
    if (_diagnosticCollection != null && controller.uri != null) {
      _diagnosticCollection!.set(controller.uri!, const []);
    }
    _integration?.dispose();
    _document.dispose();
    controller.cursorPositionNotifier.removeListener(_onCursorChanged);
    controller.selectionNotifier.removeListener(_onSelectionChanged);
    controller.visibleRangeNotifier.removeListener(_onVisibleRangeChanged);
    controller.removeListener(_onContentChanged);
    _title.dispose();
    _titleExtension.dispose();
    _cursorPos.dispose();
    _selection.dispose();
    _selections.dispose();
    _visibleRange.dispose();
  }
}

/// [ForgeDocument] backed by [MdEditorController] using [ForgeDocumentAdapter]
/// for version tracking, dirty state, and change event broadcasting.
class _MdForgeDocument extends ForgeDocumentAdapter {
  final MdEditorController _controller;
  PositionConverter _converter;

  _MdForgeDocument(super.uri, this._controller, this._converter);

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
  String get languageId => 'markdown';

  @override
  Encoding get encoding => utf8;

  @override
  bool get isUntitled => _controller.uri == null;
}
