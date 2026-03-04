import 'dart:async';

import 'package:flutter/widgets.dart';

import 'dart_code_editor.dart';
import 'summary_analysis_adapter.dart';

/// High-level Dart editor widget with built-in summary-backed analysis.
///
/// This wrapper keeps analyzer integration inside `tom_dart_editor` so host
/// applications only provide configuration and regular editor callbacks.
class SummaryBackedDartCodeEditor extends StatefulWidget {
  final DartCodeController controller;
  final String sdkSummaryAsset;
  final String packageSummaryAsset;
  final List<String>? implicitImports;

  final bool readOnly;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final Function(CodeError)? onErrorTap;
  final DartEditorTheme? theme;
  final DartEditorSettings settings;
  final ValueChanged<DartEditorSettings>? onSettingsChanged;

  final Duration analysisDebounce;
  final ValueChanged<List<CodeError>>? onErrorsChanged;

  const SummaryBackedDartCodeEditor({
    super.key,
    required this.controller,
    this.sdkSummaryAsset = 'assets/sdk_summary.sum',
    this.packageSummaryAsset = 'assets/packages.sum',
    this.implicitImports,
    this.readOnly = false,
    this.placeholder,
    this.onChanged,
    this.onErrorTap,
    this.theme,
    this.settings = const DartEditorSettings(),
    this.onSettingsChanged,
    this.analysisDebounce = const Duration(milliseconds: 500),
    this.onErrorsChanged,
  });

  @override
  State<SummaryBackedDartCodeEditor> createState() =>
      _SummaryBackedDartCodeEditorState();
}

class _SummaryBackedDartCodeEditorState
  extends State<SummaryBackedDartCodeEditor> {
  late SummaryBackedDartAnalysisAdapter _adapter;
  List<CodeError> _errors = const [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _adapter = _createAdapter();
    _scheduleAnalysis(immediate: true);
  }

  @override
  void didUpdateWidget(SummaryBackedDartCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    final importsChanged = !_listEquals(oldWidget.implicitImports,
        widget.implicitImports ?? widget.controller.implicitImports);
    final assetsChanged = oldWidget.sdkSummaryAsset != widget.sdkSummaryAsset ||
        oldWidget.packageSummaryAsset != widget.packageSummaryAsset;

    if (importsChanged || assetsChanged) {
      _adapter = _createAdapter();
      _scheduleAnalysis(immediate: true);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  SummaryBackedDartAnalysisAdapter _createAdapter() {
    return SummaryBackedDartAnalysisAdapter(
      sdkSummaryAsset: widget.sdkSummaryAsset,
      packageSummaryAsset: widget.packageSummaryAsset,
      implicitImports: widget.implicitImports ?? widget.controller.implicitImports,
    );
  }

  void _scheduleAnalysis({bool immediate = false}) {
    _debounceTimer?.cancel();
    if (immediate) {
      unawaited(_runAnalysis());
      return;
    }
    _debounceTimer = Timer(widget.analysisDebounce, () {
      unawaited(_runAnalysis());
    });
  }

  Future<void> _runAnalysis() async {
    final errors = await _adapter.analyzeCode(widget.controller.userCode);
    if (!mounted) return;
    setState(() {
      _errors = errors;
    });
    widget.onErrorsChanged?.call(errors);
  }

  @override
  Widget build(BuildContext context) {
    return DartCodeEditor(
      controller: widget.controller,
      errors: _errors,
      readOnly: widget.readOnly,
      placeholder: widget.placeholder,
      onErrorTap: widget.onErrorTap,
      theme: widget.theme,
      settings: widget.settings,
      onSettingsChanged: widget.onSettingsChanged,
      onCompletionRequest: _adapter.completions,
      onChanged: (code) {
        widget.onChanged?.call(code);
        _scheduleAnalysis();
      },
    );
  }

  bool _listEquals(List<String>? a, List<String>? b) {
    final left = a ?? const <String>[];
    final right = b ?? const <String>[];
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }
}
