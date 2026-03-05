import 'package:flutter/material.dart';
import 'package:tom_dart_editor/tom_dart_editor.dart';
import 'package:tom_yaml_editor/tom_yaml_editor.dart';

/// Dart editor adapter backed by `tom_dart_editor`.
///
/// Supports two presentation modes:
/// - Embedded: compact mode without toolbar/header and without line numbers.
/// - Pop-out: full editor UI.
class DartEditorStub extends StatefulWidget {
  final String code;
  final ValueChanged<Object?>? onChanged;
  final YamlEditorTheme theme;
  final bool fullUi;

  const DartEditorStub({
    super.key,
    required this.code,
    required this.onChanged,
    required this.theme,
    this.fullUi = false,
  });

  @override
  State<DartEditorStub> createState() => _DartEditorStubState();
}

class _DartEditorStubState extends State<DartEditorStub> {
  static const List<String> _d4rtDcliBridgedPackagePrefixes = [
    'package:dcli/',
    'package:path/',
    'package:tom_chattools/',
    'package:tom_vscode_scripting_api/',
    'package:tom_d4rt_dcli/',
  ];

  static const List<String> _d4rtDcliImplicitImports = [
    'dart:async',
    'dart:collection',
    'dart:convert',
    'dart:io',
    'dart:math',
    'package:dcli/dcli.dart',
    'package:path/path.dart',
    'package:tom_chattools/tom_chattools.dart',
    'package:tom_vscode_scripting_api/script_globals.dart',
    'package:tom_d4rt_dcli/tom_d4rt_cli_api.dart',
  ];

  late DartCodeController _controller;
  List<CodeError> _lastErrors = const [];
  bool _hasEditorFocus = false;
  String? _lastLocallyEmittedCode;

  @override
  void initState() {
    super.initState();
    _controller = DartCodeController(initialCode: widget.code);
  }

  @override
  void didUpdateWidget(DartEditorStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code == widget.code) return;

    if (_lastLocallyEmittedCode != null &&
        widget.code == _lastLocallyEmittedCode) {
      return;
    }

    if (!_hasEditorFocus && widget.code != _controller.userCode) {
      _controller.userCode = widget.code;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DartEditorTheme _dartThemeFromYaml(YamlEditorTheme theme) {
    var isDark = theme.colors.background.computeLuminance() < 0.5;
    return isDark ? DartEditorTheme.dark() : DartEditorTheme.light();
  }

  DartEditorSettings get _embeddedSettings => const DartEditorSettings(
        showToolbar: false,
        showLineNumbers: false,
        showErrorMarkers: true,
        showWarningMarkers: true,
        showInfoMarkers: true,
        showErrorTooltips: true,
        showWarningTooltips: true,
        showInfoTooltips: true,
        showAutoCompleteToggle: false,
        showErrorToggles: false,
        showWarningToggles: false,
        showInfoToggles: false,
        showPopupPositionToggle: false,
        showOpenReferenceButton: false,
      );

  int get _errorCount => _lastErrors.where((e) => e.isError).length;
  int get _warningCount => _lastErrors.where((e) => e.isWarning).length;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        if (!mounted) return;
        setState(() {
          _hasEditorFocus = hasFocus;
        });
      },
      child: Container(
        constraints: widget.fullUi
            ? const BoxConstraints(minHeight: 200)
            : const BoxConstraints(minHeight: 80, maxHeight: 240),
        decoration: BoxDecoration(
          color: widget.theme.colors.background,
          border:
              Border.all(color: widget.theme.colors.hintColor.withAlpha(60)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SummaryBackedDartCodeEditor(
                controller: _controller,
                sdkSummaryAsset: 'assets/sdk_summary.sum',
                packageSummaryAsset: 'assets/packages.sum',
                implicitImports: _d4rtDcliImplicitImports,
                includeAllPackageCompletions: true,
                allowedPackagePrefixes: _d4rtDcliBridgedPackagePrefixes,
                readOnly: widget.onChanged == null,
                theme: _dartThemeFromYaml(widget.theme),
                settings: widget.fullUi
                    ? const DartEditorSettings()
                    : _embeddedSettings,
                onErrorsChanged: (errors) {
                  if (!mounted) return;
                  setState(() {
                    _lastErrors = errors;
                  });
                },
                onChanged: widget.onChanged == null
                    ? null
                    : (code) {
                        _lastLocallyEmittedCode = code;
                        widget.onChanged!(code);
                      },
              ),
            ),
            if (!widget.fullUi)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Text(
                  'Diagnostics: $_errorCount error(s), $_warningCount warning(s)',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.theme.colors.hintColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Creates the [EditorSuffix] registration for the Dart editor.
EditorSuffix dartEditorSuffix() {
  return EditorSuffix(
    suffix: 'dart',
    label: 'Dart Code',
    icon: Icons.code,
    factory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return DartEditorStub(
        code: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
      );
    },
    supportsPopout: true,
    popoutTitle: 'Dart Editor',
    popoutFactory: ({
      required String key,
      required Object? value,
      required ValueChanged<Object?> onChanged,
      required YamlEditorTheme theme,
      required bool readOnly,
    }) {
      return DartEditorStub(
        code: value as String? ?? '',
        onChanged: readOnly ? null : onChanged,
        theme: theme,
        fullUi: true,
      );
    },
  );
}
