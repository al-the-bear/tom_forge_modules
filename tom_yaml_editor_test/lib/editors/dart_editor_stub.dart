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
  late DartCodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DartCodeController(initialCode: widget.code);
  }

  @override
  void didUpdateWidget(DartEditorStub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code && widget.code != _controller.userCode) {
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
        showAutoCompleteToggle: false,
        showErrorToggles: false,
        showWarningToggles: false,
        showInfoToggles: false,
        showPopupPositionToggle: false,
        showOpenReferenceButton: false,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: widget.fullUi
          ? const BoxConstraints(minHeight: 200)
          : const BoxConstraints(minHeight: 80, maxHeight: 240),
      decoration: BoxDecoration(
        color: widget.theme.colors.background,
        border: Border.all(color: widget.theme.colors.hintColor.withAlpha(60)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SummaryBackedDartCodeEditor(
        controller: _controller,
        sdkSummaryAsset: 'assets/sdk_summary.sum',
        packageSummaryAsset: 'assets/packages.sum',
        readOnly: widget.onChanged == null,
        theme: _dartThemeFromYaml(widget.theme),
        settings:
            widget.fullUi ? const DartEditorSettings() : _embeddedSettings,
        onChanged: widget.onChanged == null
            ? null
            : (code) {
                widget.onChanged!(code);
              },
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
