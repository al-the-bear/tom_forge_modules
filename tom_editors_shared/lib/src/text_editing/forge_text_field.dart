import 'package:flutter/material.dart';

import 'forge_editor_integration.dart';
import 'forge_text_settings.dart';
import 'history/forge_editor_owns_undo.dart';
import 'integrations/base_standalone_integration.dart';

/// Debug flag for ForgeTextField.
bool kForgeTextFieldDebug = false;

void _log(String message) {
  if (kForgeTextFieldDebug) {
    // ignore: avoid_print
    print('[ForgeTextField] $message');
  }
}

/// A text field widget that integrates with the Forge shell.
///
/// Wraps a Flutter [TextField] and provides a [ForgeEditorIntegration]
/// for shell interactions (actions, settings, state queries).
///
/// Example:
/// ```dart
/// ForgeTextField(
///   initialText: 'Hello',
///   textSettings: ForgeTextSettings(fontSize: 14),
///   onTextChanged: (text) => print('Text: $text'),
///   onIntegrationReady: (integration) {
///     // Register with shell
///   },
/// )
/// ```
class ForgeTextField extends StatefulWidget {
  /// Initial text content.
  final String? initialText;

  /// Text settings (font, indentation, etc.).
  final ForgeTextSettings? textSettings;

  /// Called when text content changes.
  final ValueChanged<String>? onTextChanged;

  /// Called when selection changes.
  final ValueChanged<TextSelection>? onSelectionChanged;

  /// Called when the integration is ready for registration with the shell.
  final ValueChanged<ForgeEditorIntegration>? onIntegrationReady;

  /// Whether to expand to fill available space.
  final bool expands;

  /// Maximum lines (null for no limit).
  final int? maxLines;

  /// Minimum lines.
  final int minLines;

  /// Text input decoration.
  final InputDecoration? decoration;

  /// Whether to autofocus.
  final bool autofocus;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Text input action.
  final TextInputAction? textInputAction;

  /// Called when editing is complete.
  final VoidCallback? onEditingComplete;

  /// Called when submitted.
  final ValueChanged<String>? onSubmitted;

  /// Whether read-only.
  final bool readOnly;

  /// Whether to show cursor.
  final bool? showCursor;

  /// Cursor color.
  final Color? cursorColor;

  /// Selection controls.
  final TextSelectionControls? selectionControls;

  /// Scroll controller.
  final ScrollController? scrollController;

  /// Text align.
  final TextAlign textAlign;

  /// Text color override (applied to the text style from [textSettings]).
  final Color? textColor;

  /// Focus node (if not provided, one will be created).
  final FocusNode? focusNode;

  /// Text editing controller (if not provided, one will be created).
  final TextEditingController? controller;

  /// Whether the host keeps the history of what this field edits — a field
  /// inside a document editor, whose edits go into the document's history.
  /// The field then keeps none: its integration records no undo entries and
  /// Flutter's own text undo is off ([ForgeEditorOwnsUndo]), so the field has
  /// one history, the document's, instead of three.
  final bool undoOwnedByHost;

  const ForgeTextField({
    super.key,
    this.initialText,
    this.textSettings,
    this.onTextChanged,
    this.onSelectionChanged,
    this.onIntegrationReady,
    this.expands = false,
    this.maxLines,
    this.minLines = 1,
    this.decoration,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onEditingComplete,
    this.onSubmitted,
    this.readOnly = false,
    this.showCursor,
    this.cursorColor,
    this.selectionControls,
    this.scrollController,
    this.textAlign = TextAlign.start,
    this.textColor,
    this.focusNode,
    this.controller,
    this.undoOwnedByHost = false,
  });

  @override
  State<ForgeTextField> createState() => ForgeTextFieldState();
}

/// State for [ForgeTextField] providing editor integration access.
class ForgeTextFieldState extends State<ForgeTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late BaseStandaloneIntegration _integration;
  late ForgeTextSettings _textSettings;

  bool _ownsController = false;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _log('initState');

    // Controller
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialText ?? '');
      _ownsController = true;
    }

    // Focus node
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    // Text settings
    _textSettings = widget.textSettings ?? const ForgeTextSettings();

    // Create integration
    _integration = BaseStandaloneIntegration(
      controller: _controller,
      focusNode: _focusNode,
      textSettings: _textSettings,
      enableAutoUndoTracking: !widget.undoOwnedByHost,
    );

    // Register callbacks
    if (widget.onTextChanged != null) {
      _integration.addTextChangeListener(widget.onTextChanged!);
    }
    if (widget.onSelectionChanged != null) {
      _integration.addSelectionChangeListener(widget.onSelectionChanged!);
    }

    // Notify ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onIntegrationReady?.call(_integration);
    });
  }

  @override
  void didUpdateWidget(ForgeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update text settings if changed
    if (widget.textSettings != oldWidget.textSettings &&
        widget.textSettings != null) {
      _textSettings = widget.textSettings!;
      _integration.textSettings = _textSettings;
    }

    // Update callbacks
    if (widget.onTextChanged != oldWidget.onTextChanged) {
      if (oldWidget.onTextChanged != null) {
        _integration.removeTextChangeListener(oldWidget.onTextChanged!);
      }
      if (widget.onTextChanged != null) {
        _integration.addTextChangeListener(widget.onTextChanged!);
      }
    }
    if (widget.onSelectionChanged != oldWidget.onSelectionChanged) {
      if (oldWidget.onSelectionChanged != null) {
        _integration.removeSelectionChangeListener(oldWidget.onSelectionChanged!);
      }
      if (widget.onSelectionChanged != null) {
        _integration.addSelectionChangeListener(widget.onSelectionChanged!);
      }
    }
  }

  @override
  void dispose() {
    _log('dispose');
    _integration.dispose();

    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log('build');

    final effectiveDecoration = widget.decoration ??
        const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        );

    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      style: _textSettings.toTextStyle(color: widget.textColor),
      decoration: effectiveDecoration,
      expands: widget.expands,
      maxLines: widget.expands ? null : widget.maxLines,
      minLines: widget.expands ? null : widget.minLines,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: widget.onSubmitted,
      readOnly: widget.readOnly,
      showCursor: widget.showCursor,
      cursorColor: widget.cursorColor,
      selectionControls: widget.selectionControls,
      scrollController: widget.scrollController,
      textAlign: widget.textAlign,
    );
    return widget.undoOwnedByHost ? ForgeEditorOwnsUndo(child: field) : field;
  }

  /// Gets the integration for external access.
  ForgeEditorIntegration get integration => _integration;
}

/// Extension to get integration from a GlobalKey.
extension ForgeTextFieldExtension on GlobalKey<ForgeTextFieldState> {
  /// Gets the integration from a ForgeTextField with this key.
  ForgeEditorIntegration? get integration => currentState?.integration;
}
