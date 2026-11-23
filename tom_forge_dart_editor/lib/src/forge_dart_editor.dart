import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';

import 'package:tom_forge_kit/tom_forge_kit.dart';

/// Where the Dart editor's analysis summaries are in the asset bundle: the
/// SDK summary and the summary of the packages it resolves.
///
/// An application that carries the summaries itself reads them under its own
/// keys ([ForgeDartSummaryAssets.root]); an application built on a package
/// that carries them reads them under that package's prefix
/// ([ForgeDartSummaryAssets.ofPackage]), since Flutter keys a dependency's
/// assets `packages/<package>/<path>`.
class ForgeDartSummaryAssets {
  const ForgeDartSummaryAssets({
    required this.sdkSummary,
    required this.packageSummary,
  });

  /// The pair's place in an app, as tom_dart_editor_bundler lays it out: the
  /// shared SDK summary and the `dart-editor` scope's package summary.
  static const sdkSummaryPath = 'assets/summaries/sdk_summary.sum';
  static const packageSummaryPath = 'assets/summaries/dart-editor/packages.sum';

  /// The pair of the running app.
  static const root = ForgeDartSummaryAssets(
    sdkSummary: sdkSummaryPath,
    packageSummary: packageSummaryPath,
  );

  /// The same two files, carried by the dependency [package].
  ForgeDartSummaryAssets.ofPackage(String package)
    : sdkSummary = 'packages/$package/$sdkSummaryPath',
      packageSummary = 'packages/$package/$packageSummaryPath';

  final String sdkSummary;
  final String packageSummary;
}

/// Adapter that wraps [DartCodeController] + [DartCodeEditor] as a
/// [ForgeTextEditor].
class ForgeDartEditor extends ForgeTextEditor implements ForgeEditorOfType {
  @override
  String get editorTypeId => 'dart';

  final DartCodeController controller;
  final ForgeKitModule _module;
  final ForgeKitApi? _api;
  final _stateStreamController = StreamController<void>.broadcast();
  final List<CodeError> Function()? errorsProvider;

  final _title = ValueNotifier<String>('Dart');
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
  late final _DartForgeDocument _document;
  ForgeTextEditorOptions _options;
  String _lastCode = '';
  ShellEditorIntegration? _integration;

  /// Summary-backed analysis adapter for autocompletion and diagnostics.
  final SummaryBackedDartAnalysisAdapter _analysisAdapter;
  final _analysisErrors = ValueNotifier<List<CodeError>>(const []);
  Timer? _analysisDebounce;
  ForgeDiagnosticCollection? _diagnosticCollection;

  /// Decoration state.
  final Map<String, List<ForgeDecorationRange>> _decorationMap = {};

  ForgeDartEditor({
    required this.controller,
    required ForgeKitModule module,
    ForgeKitApi? api,
    this.errorsProvider,
    ForgeTextEditorOptions options = const ForgeTextEditorOptions(),
    ForgeDartSummaryAssets summaries = ForgeDartSummaryAssets.root,
  }) : _module = module,
       _api = api,
       _options = options,
       _analysisAdapter = SummaryBackedDartAnalysisAdapter(
         sdkSummaryAsset: summaries.sdkSummary,
         packageSummaryAsset: summaries.packageSummary,
       ) {
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

    // Run initial analysis.
    _scheduleAnalysis(immediate: true);
  }

  // ── ForgeComponent ──

  @override
  ValueListenable<String> get title => _title;

  @override
  ValueListenable<String?> get titleExtension => _titleExtension;

  @override
  IconData get icon => const IconData(0xe86f, fontFamily: 'MaterialIcons'); // code

  @override
  ForgeComponentSizeHints get sizeHints => const ForgeComponentSizeHints();

  ForgeKitModule get module => _module;

  /// The API of the application this editor runs in: the one it was given,
  /// else the one its module was activated with ([forgeKitApiOf]); null
  /// while there is none, and the editor then works on its own (no
  /// application actions, settings or diagnostics).
  ForgeKitApi? get kitApi => _api ?? forgeKitApiOf(_module);

  @override
  Widget buildMain(BuildContext context) {
    if (kitApi case final api?) {
      _integration ??=
          ShellEditorIntegration(
              shellApi: api,
              editorId: 'dart-editor-${uri.hashCode}',
              editorTypeId: 'dart',
            )
            ..descriptors = [
              ...DartEditorActions.descriptors,
              ...StandardEditingActions.descriptors,
            ];
    }
    // Build theme with applied options.
    final theme = _buildThemeFromOptions();
    final settings = _buildSettingsFromConfig();
    return ValueListenableBuilder<List<CodeError>>(
      valueListenable: _analysisErrors,
      builder: (context, analysisErrors, _) {
        final errors = errorsProvider?.call() ?? analysisErrors;
        return DartCodeEditor(
          controller: controller,
          integration: _integration,
          theme: theme,
          settings: settings,
          errors: errors,
          onCompletionRequest: _analysisAdapter.completions,
          onCursorChanged: _onCursorOffset,
          onSelectionChanged: _onSelectionRange,
          onVisibleRangeChanged: _onVisibleRangeLines,
        );
      },
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

  /// Builds [DartEditorSettings] from the editor-specific config map.
  DartEditorSettings _buildSettingsFromConfig() {
    final shellApi = kitApi;
    final config =
        shellApi?.getEditorSpecificConfig('dart') ?? const <String, dynamic>{};
    if (config.isEmpty) return const DartEditorSettings(showToolbar: false);
    return DartEditorSettings(
      showToolbar: (config['showToolbar'] as bool?) ?? false,
      showLineNumbers: (config['showLineNumbers'] as bool?) ?? true,
      autoCompleteEnabled: (config['autoCompleteEnabled'] as bool?) ?? true,
      maxCompletionItems: (config['maxCompletionItems'] as num?)?.toInt() ?? 8,
      showErrorTooltips: (config['showErrorTooltips'] as bool?) ?? true,
      showErrorMarkers: (config['showErrorMarkers'] as bool?) ?? true,
      showWarningTooltips: (config['showWarningTooltips'] as bool?) ?? true,
      showWarningMarkers: (config['showWarningMarkers'] as bool?) ?? true,
      showInfoTooltips: (config['showInfoTooltips'] as bool?) ?? false,
      showInfoMarkers: (config['showInfoMarkers'] as bool?) ?? false,
      popupPreferBelow: (config['popupPreferBelow'] as bool?) ?? true,
      showAutoCompleteToggle:
          (config['showAutoCompleteToggle'] as bool?) ?? true,
      showErrorToggles: (config['showErrorToggles'] as bool?) ?? true,
      showWarningToggles: (config['showWarningToggles'] as bool?) ?? true,
      showInfoToggles: (config['showInfoToggles'] as bool?) ?? true,
      showPopupPositionToggle:
          (config['showPopupPositionToggle'] as bool?) ?? true,
      showOpenReferenceButton:
          (config['showOpenReferenceButton'] as bool?) ?? true,
    );
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
  /// Dirty is the document's: its code against the saved code.
  @override
  ValueListenable<bool> get isDirty => controller.isDirty;

  @override
  void markClean() => controller.markSaved();

  @override
  bool replaceContent(String content) {
    controller.replaceCode(content);
    return true;
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

  // ── EditorActionProvider ──

  @override
  Set<String> get supportedActionIds => const {
    ...StandardEditingActions.standardActionIds,
    DartEditorActions.triggerCompletionActionId,
    DartEditorActions.openReferenceActionId,
  };

  @override
  EditorCapabilities get capabilities => const EditorCapabilities(
    hasTextBuffer: true,
    supportsUndoRedo: true,
    supportsClipboard: true,
    supportsLineEditing: true,
    supportsSelection: true,
  );

  @override
  EditorStateSnapshot get stateSnapshot {
    return EditorStateSnapshot(
      hasSelection: hasSelection,
      hasContent: controller.userCode.isNotEmpty,
      isEditable: true,
      canUndo: controller.canUndo,
      canRedo: controller.canRedo,
      isTextMode: true,
    );
  }

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
    final code = controller.userCode;
    final offset = _positionConverter.positionToOffset(_cursorPos.value);
    controller.applyEdit(
      code.substring(0, offset) + text + code.substring(offset),
      selection: TextSelection.collapsed(offset: offset + text.length),
    );
  }

  @override
  void replaceRange(ForgeTextRange range, String replacement) {
    final code = controller.userCode;
    final start = _positionConverter.positionToOffset(range.start);
    final end = _positionConverter.positionToOffset(range.end);
    controller.applyEdit(
      code.substring(0, start) + replacement + code.substring(end),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
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
    controller.revealLine(position.line);
  }

  @override
  void revealRange(ForgeTextRange range) {
    setCursorPosition(range.start);
    controller.revealLine(range.start.line);
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
    _stateStreamController.add(null);
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
      _document.updateConverter(_positionConverter);
      _document.notifyContentChanged();
      _scheduleAnalysis();
      _stateStreamController.add(null);
    }
    if (controller.uri != null) {
      _title.value = controller.uri!.pathSegments.last;
    }
  }

  void _scheduleAnalysis({bool immediate = false}) {
    _analysisDebounce?.cancel();
    if (immediate) {
      unawaited(_runAnalysis());
      return;
    }
    _analysisDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_runAnalysis());
    });
  }

  Future<void> _runAnalysis() async {
    try {
      final errors = await _analysisAdapter.analyzeCode(controller.userCode);
      _analysisErrors.value = errors;
      _updateDiagnostics();
    } catch (_) {
      // Analysis may fail if assets are unavailable (e.g. in unit tests).
    }
  }

  /// Pushes current analysis errors to the diagnostic manager.
  void _updateDiagnostics() {
    final shell = kitApi;
    if (shell == null) return;

    final fileUri = controller.uri;
    if (fileUri == null) return;

    _diagnosticCollection ??= shell.diagnostics.createCollection('dart-editor');

    final diagnostics = _analysisErrors.value.map((e) {
      final severity = switch (e.severity.toUpperCase()) {
        'ERROR' => ForgeSeverity.error,
        'WARNING' => ForgeSeverity.warning,
        _ => ForgeSeverity.info,
      };
      return ForgeDiagnostic(
        uri: fileUri,
        range: ForgeTextRange(
          start: ForgeTextPosition(line: e.line, column: e.column),
          end: ForgeTextPosition(
            line: e.line,
            column: e.column + (e.length > 0 ? e.length : 1),
          ),
        ),
        message: e.message,
        severity: severity,
        source: 'dart',
        code: e.code,
      );
    }).toList();

    _diagnosticCollection!.set(fileUri, diagnostics);
  }

  /// Release listeners.
  void dispose() {
    _stateStreamController.close();
    _analysisDebounce?.cancel();
    _analysisErrors.dispose();
    if (_diagnosticCollection != null && controller.uri != null) {
      _diagnosticCollection!.set(controller.uri!, const []);
    }
    _integration?.dispose();
    _document.dispose();
    controller.removeListener(_onControllerChanged);
    _title.dispose();
    _titleExtension.dispose();
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
