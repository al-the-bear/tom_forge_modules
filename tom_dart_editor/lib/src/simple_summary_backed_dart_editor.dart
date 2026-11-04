import 'package:flutter/widgets.dart';

import 'dart_code_editor.dart';
import 'summary_backed_dart_editor.dart';

/// Easy-to-embed Dart editor with built-in summary-backed analysis.
///
/// This widget manages its own [DartCodeController], so host code can stay
/// minimal when controller-level access is not required.
class SimpleSummaryBackedDartCodeEditor extends StatefulWidget {
  final String initialCode;
  final List<String> implicitImports;

  /// Registry scope (bundle) name. When set, analysis/completion resolve the
  /// shared parsed store from the registry instead of loading the
  /// [sdkSummaryAsset] / [packageSummaryAsset] bytes. [implicitImports] still
  /// drives this editor's display offset and is forwarded as the analysis
  /// override; the scope supplies the bridged surface + completion config.
  final String? scope;

  final String sdkSummaryAsset;
  final String packageSummaryAsset;
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

  const SimpleSummaryBackedDartCodeEditor({
    super.key,
    this.initialCode = '',
    this.implicitImports = const [
      'dart:async',
      'dart:collection',
      'dart:math',
    ],
    this.scope,
    this.sdkSummaryAsset = 'assets/sdk_summary.sum',
    this.packageSummaryAsset = 'assets/packages.sum',
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
  State<SimpleSummaryBackedDartCodeEditor> createState() =>
      _SimpleSummaryBackedDartCodeEditorState();
}

class _SimpleSummaryBackedDartCodeEditorState
    extends State<SimpleSummaryBackedDartCodeEditor> {
  late DartCodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DartCodeController(
      initialCode: widget.initialCode,
      implicitImports: widget.implicitImports,
    );
  }

  @override
  void didUpdateWidget(SimpleSummaryBackedDartCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialCode != widget.initialCode &&
        widget.initialCode != _controller.userCode) {
      _controller.replaceCode(widget.initialCode);
    }

    final importsChanged =
        !_listEquals(oldWidget.implicitImports, widget.implicitImports);
    if (importsChanged) {
      _controller.implicitImports = widget.implicitImports;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SummaryBackedDartCodeEditor(
      controller: _controller,
      scope: widget.scope,
      sdkSummaryAsset: widget.sdkSummaryAsset,
      packageSummaryAsset: widget.packageSummaryAsset,
      implicitImports: widget.implicitImports,
      includeAllPackageCompletions: widget.includeAllPackageCompletions,
      allowedPackagePrefixes: widget.allowedPackagePrefixes,
      readOnly: widget.readOnly,
      placeholder: widget.placeholder,
      onErrorTap: widget.onErrorTap,
      theme: widget.theme,
      settings: widget.settings,
      onSettingsChanged: widget.onSettingsChanged,
      analysisDebounce: widget.analysisDebounce,
      onErrorsChanged: widget.onErrorsChanged,
      onChanged: widget.onChanged,
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
