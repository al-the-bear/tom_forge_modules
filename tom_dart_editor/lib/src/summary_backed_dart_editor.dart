import 'dart:async';

import 'package:flutter/widgets.dart';

import 'dart_code_editor.dart';
import 'summary_analysis_adapter.dart';
import 'summary_scope_registry.dart';

/// High-level Dart editor widget with built-in summary-backed analysis.
///
/// This wrapper keeps analyzer integration inside `tom_dart_editor` so host
/// applications only provide configuration and regular editor callbacks.
class SummaryBackedDartCodeEditor extends StatefulWidget {
  final DartCodeController controller;

  /// Registry scope (bundle) name. When set, analysis/completion resolve the
  /// shared parsed store from [SummaryScopeRegistry] and the editor defaults
  /// (implicit imports, completion filters) are inherited from the registered
  /// scope unless overridden by the params below. When null, the editor loads
  /// the [sdkSummaryAsset] / [packageSummaryAsset] bytes directly (escape hatch).
  final String? scope;

  final String sdkSummaryAsset;
  final String packageSummaryAsset;
  final List<String>? implicitImports;
  final bool includeAllPackageCompletions;
  final List<String>? allowedPackagePrefixes;

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
    this.scope,
    this.sdkSummaryAsset = 'assets/sdk_summary.sum',
    this.packageSummaryAsset = 'assets/packages.sum',
    this.implicitImports,
    this.includeAllPackageCompletions = false,
    this.allowedPackagePrefixes,
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

    // Both sides with the same fallback: an editor given no imports uses the
    // controller's, and comparing that with the old widget's bare null made
    // every rebuild a change — a host that rebuilds when the findings arrive
    // then re-analysed for ever.
    final importsChanged = !_listEquals(
        oldWidget.implicitImports ?? oldWidget.controller.implicitImports,
        widget.implicitImports ?? widget.controller.implicitImports);
    final scopeChanged = oldWidget.scope != widget.scope;
    final assetsChanged = oldWidget.sdkSummaryAsset != widget.sdkSummaryAsset ||
        oldWidget.packageSummaryAsset != widget.packageSummaryAsset;
    final completionScopeChanged = oldWidget.includeAllPackageCompletions !=
            widget.includeAllPackageCompletions ||
        !_listEquals(
          oldWidget.allowedPackagePrefixes,
          widget.allowedPackagePrefixes,
        );

    if (importsChanged ||
        scopeChanged ||
        assetsChanged ||
        completionScopeChanged) {
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
    final scope = widget.scope;
    if (scope != null) {
      // Scope mode: inherit the registered scope's editor defaults; a null
      // widget param means "inherit", a set one overrides. `includeAll` is a
      // non-nullable bool, so only its `true` value is forwarded as an override
      // (a default `false` lets the scope's setting stand).
      return SummaryBackedDartAnalysisAdapter.scope(
        scope,
        implicitImports: widget.implicitImports,
        includeAllPackageCompletions:
            widget.includeAllPackageCompletions ? true : null,
        allowedPackagePrefixes: widget.allowedPackagePrefixes,
      );
    }
    return SummaryBackedDartAnalysisAdapter(
      sdkSummaryAsset: widget.sdkSummaryAsset,
      packageSummaryAsset: widget.packageSummaryAsset,
      implicitImports:
          widget.implicitImports ?? widget.controller.implicitImports,
      includeAllPackageCompletions: widget.includeAllPackageCompletions,
      allowedPackagePrefixes: widget.allowedPackagePrefixes,
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
