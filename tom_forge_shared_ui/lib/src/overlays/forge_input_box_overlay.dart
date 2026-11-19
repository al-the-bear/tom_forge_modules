import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A VS Code-style input box overlay for text-based user input.
///
/// Shown as a modal overlay at the top center of the shell.
/// Supports optional validation and placeholder text.
class ForgeInputBoxOverlay extends StatefulWidget {
  final String? prompt;
  final String? value;
  final String? placeholder;
  final String? Function(String)? validateInput;
  final Completer<String?> completer;

  const ForgeInputBoxOverlay({
    super.key,
    this.prompt,
    this.value,
    this.placeholder,
    this.validateInput,
    required this.completer,
  });

  @override
  State<ForgeInputBoxOverlay> createState() => _ForgeInputBoxOverlayState();
}

class _ForgeInputBoxOverlayState extends State<ForgeInputBoxOverlay> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.value?.length ?? 0,
    );
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (!widget.completer.isCompleted) {
      widget.completer.complete(null);
    }
  }

  void _submit() {
    final text = _controller.text;
    if (widget.validateInput != null) {
      final error = widget.validateInput!(text);
      if (error != null) {
        setState(() => _errorText = error);
        return;
      }
    }
    if (!widget.completer.isCompleted) {
      widget.completer.complete(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black26,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: GestureDetector(
              onTap: () {},
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(6),
                color: theme.colorScheme.surface,
                child: SizedBox(
                  width: 480,
                  child: FocusScope(
                    autofocus: true,
                    child: Focus(
                      onKeyEvent: (_, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.escape) {
                          _dismiss();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          _submit();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.prompt != null) ...[
                              Text(
                                widget.prompt!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            TextField(
                              key: const Key('forge-input-box-field'),
                              controller: _controller,
                              focusNode: _focusNode,
                              // A focused single-line TextField consumes the
                              // Enter KeyDownEvent, so it never reaches the
                              // ancestor Focus.onKeyEvent below. Submit from the
                              // field's own onSubmitted (the idiomatic path).
                              onSubmitted: (_) => _submit(),
                              onChanged: (text) {
                                if (widget.validateInput != null) {
                                  setState(() {
                                    _errorText =
                                        widget.validateInput!(text);
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: widget.placeholder,
                                errorText: _errorText,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _dismiss,
                                  child: const Text('Cancel'),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed:
                                      _errorText == null ? _submit : null,
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
