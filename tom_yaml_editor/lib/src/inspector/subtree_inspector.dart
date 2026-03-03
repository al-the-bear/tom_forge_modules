import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tom_editors_shared/tom_editors_shared.dart';
import 'package:yaml/yaml.dart';

import '../schema/schema_marker_generator.dart';
import '../text_editor/yaml_syntax_highlighter.dart';
import '../yaml_editor_controller.dart';
import '../yaml_editor_theme.dart';

/// The layout mode for the subtree inspector.
enum SubtreeInspectorMode {
  /// Inspector appears to the side of the tree view.
  sidePanel,

  /// Inspector appears below the tree view.
  bottomSheet,

  /// Inspector appears as a modal dialog overlay.
  dialog,
}

/// A text-based inspector for editing a YAML subtree as raw text.
///
/// Wraps [TextEditorCore] with YAML syntax highlighting and schema-based
/// error markers. Includes a header with path breadcrumb, and Apply/Cancel
/// buttons. Provides live preview with debounced parsing and validation.
///
/// ```dart
/// SubtreeInspector(
///   controller: myController,
///   path: ['prompt', 'meta-data'],
///   theme: YamlEditorTheme.dark(),
///   onApply: () { /* handle apply */ },
///   onCancel: () { /* handle cancel */ },
/// )
/// ```
class SubtreeInspector extends StatefulWidget {
  /// The YAML editor controller.
  final YamlEditorController controller;

  /// The path to the subtree being inspected.
  ///
  /// e.g. `['prompt', 'meta-data']` for the meta-data section.
  final List<String> path;

  /// Visual theme for the editor.
  final YamlEditorTheme theme;

  /// Called when the user applies the edited subtree.
  final VoidCallback? onApply;

  /// Called when the user cancels editing.
  final VoidCallback? onCancel;

  /// Whether the inspector is read-only.
  final bool readOnly;

  /// Debounce duration for live preview validation.
  final Duration debounceDuration;

  const SubtreeInspector({
    super.key,
    required this.controller,
    required this.path,
    this.theme = const YamlEditorTheme(),
    this.onApply,
    this.onCancel,
    this.readOnly = false,
    this.debounceDuration = const Duration(milliseconds: 300),
  });

  @override
  State<SubtreeInspector> createState() => SubtreeInspectorState();
}

/// State for [SubtreeInspector].
///
/// Exposed as public so that parent widgets can call [apply] and [cancel]
/// programmatically.
class SubtreeInspectorState extends State<SubtreeInspector> {
  late String _originalText;
  late String _currentText;
  late YamlSyntaxHighlighter _highlighter;

  /// Live preview errors for the current text.
  List<ValidationError> _previewErrors = [];

  /// Text markers for underlines from schema validation.
  List<TextMarker> _markers = [];

  /// Whether the current text has parse errors.
  bool _hasParseErrors = false;

  /// Human-readable parse error message.
  String? _parseErrorMessage;

  /// Whether the text has been modified.
  bool get isDirty => _currentText != _originalText;

  /// Whether the Apply button should be enabled.
  bool get canApply => isDirty && !_hasParseErrors && !widget.readOnly;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _highlighter = YamlSyntaxHighlighter(
      colors: YamlHighlightColors(
        key: widget.theme.colors.keyColor,
        string: widget.theme.colors.valueColor,
        number: widget.theme.colors.numberColor,
        boolean: widget.theme.colors.boolColor,
        nullValue: widget.theme.colors.nullColor,
        comment: widget.theme.colors.commentColor,
      ),
    );
    _initializeText();
  }

  @override
  void didUpdateWidget(SubtreeInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.controller != widget.controller) {
      _initializeText();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _initializeText() {
    var subtree = widget.controller.document.subtreeYamlAt(
      widget.path.cast<Object>(),
    );
    _originalText = subtree ?? '';
    _currentText = _originalText;
    _hasParseErrors = false;
    _parseErrorMessage = null;
    _validatePreview();
  }

  /// Handles text changes from the editor, with debounced live preview.
  void _onTextChanged(String newText) {
    setState(() {
      _currentText = newText;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, _validatePreview);
  }

  /// Parse and validate the current text as a YAML subtree.
  void _validatePreview() {
    // Try to parse the YAML fragment
    try {
      loadYaml(_currentText);
      _hasParseErrors = false;
      _parseErrorMessage = null;
    } catch (e) {
      _hasParseErrors = true;
      _parseErrorMessage = e.toString();
      setState(() {
        _previewErrors = [
          ValidationError(
            path: widget.path.cast<Object>(),
            message: 'YAML parse error: $_parseErrorMessage',
            severity: ValidationSeverity.error,
          ),
        ];
        _markers = SchemaMarkerGenerator.generate(
          yamlText: _currentText,
          errors: _previewErrors,
        );
      });
      return;
    }

    // If we have a schema, validate the subtree in context
    var schema = widget.controller.schema;
    if (schema != null) {
      // Create a temporary document with the subtree replaced
      var tempDoc = widget.controller.document.replaceSubtreeAt(
        widget.path.cast<Object>(),
        _currentText,
      );
      // Validate the full document
      var allErrors = schema.validate(tempDoc);
      // Filter errors to only those at or below our path
      _previewErrors = allErrors.where((e) {
        if (e.path.length < widget.path.length) return false;
        for (var i = 0; i < widget.path.length; i++) {
          if (e.path[i].toString() != widget.path[i]) return false;
        }
        return true;
      }).toList();
    } else {
      _previewErrors = [];
    }

    if (mounted) {
      setState(() {
        _markers = SchemaMarkerGenerator.generate(
          yamlText: _currentText,
          errors: _previewErrors,
        );
      });
    }
  }

  /// Apply the current text back to the controller.
  ///
  /// Returns `true` if the apply was successful, `false` if blocked by errors.
  bool apply() {
    if (!canApply) return false;

    // Parse the fragment
    Object? parsed;
    try {
      parsed = loadYaml(_currentText);
    } catch (_) {
      return false;
    }

    // Apply to the controller
    widget.controller.setValue(widget.path, parsed);
    _originalText = _currentText;
    widget.onApply?.call();
    return true;
  }

  /// Cancel editing, discarding any changes.
  void cancel() {
    setState(() {
      _currentText = _originalText;
      _hasParseErrors = false;
      _parseErrorMessage = null;
      _previewErrors = [];
      _markers = [];
    });
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(
          child: _buildEditor(),
        ),
        if (_hasParseErrors && _parseErrorMessage != null)
          _buildParseErrorBar(),
      ],
    );
  }

  /// Header with path breadcrumb and Apply/Cancel buttons.
  Widget _buildHeader() {
    var theme = widget.theme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colors.separatorColor.withAlpha(80),
          ),
        ),
      ),
      child: Row(
        children: [
          // Path breadcrumb
          Expanded(child: _buildBreadcrumb()),

          // Status indicator
          if (_previewErrors.isNotEmpty && !_hasParseErrors)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ValidationBadge(
                errorCount: _previewErrors
                    .where((e) => e.severity == ValidationSeverity.error)
                    .length,
                warningCount: _previewErrors
                    .where((e) => e.severity == ValidationSeverity.warning)
                    .length,
              ),
            ),

          // Cancel button
          TextButton(
            onPressed: widget.onCancel ?? cancel,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colors.hintColor,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Apply button
          FilledButton(
            onPressed: canApply ? apply : null,
            style: FilledButton.styleFrom(
              backgroundColor: theme.structureColors.addButton,
              disabledBackgroundColor:
                  theme.structureColors.addButton.withAlpha(80),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Path breadcrumb showing the inspected path.
  Widget _buildBreadcrumb() {
    var theme = widget.theme;
    var segments = widget.path;

    if (segments.isEmpty) {
      return Text(
        '(root)',
        style: TextStyle(
          color: theme.colors.hintColor,
          fontFamily: theme.fonts.keyFontFamily,
          fontSize: 12,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: theme.colors.hintColor,
                ),
              ),
            Text(
              segments[i],
              style: TextStyle(
                color: i == segments.length - 1
                    ? theme.colors.keyColor
                    : theme.colors.hintColor,
                fontFamily: theme.fonts.keyFontFamily,
                fontSize: 12,
                fontWeight: i == segments.length - 1
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The main text editor.
  Widget _buildEditor() {
    var textEditorTheme = TextEditorTheme(
      background: widget.theme.colors.background,
      textStyle: TextStyle(
        fontFamily: widget.theme.fonts.valueFontFamily,
        fontSize: widget.theme.fonts.valueFontSize,
        color: widget.theme.colors.valueColor,
        height: 1.4,
      ),
      lineNumberStyle: TextStyle(
        fontFamily: widget.theme.fonts.valueFontFamily,
        fontSize: widget.theme.fonts.valueFontSize,
        color: widget.theme.colors.hintColor,
        height: 1.4,
      ),
      gutterBackground: widget.theme.colors.surface,
      gutterBorderColor: widget.theme.colors.separatorColor.withAlpha(80),
    );

    return TextEditorCore(
      text: _currentText,
      highlighter: _highlighter,
      markers: _markers,
      onTextChanged: widget.readOnly ? null : _onTextChanged,
      readOnly: widget.readOnly,
      theme: textEditorTheme,
    );
  }

  /// Error bar shown when YAML parse errors exist.
  Widget _buildParseErrorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.theme.colors.errorColor.withAlpha(30),
        border: Border(
          top: BorderSide(
            color: widget.theme.colors.errorColor.withAlpha(120),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 14,
            color: widget.theme.colors.errorColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'YAML parse error — fix before applying',
              style: TextStyle(
                color: widget.theme.colors.errorColor,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
