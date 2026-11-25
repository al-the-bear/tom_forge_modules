import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../configuration_ui_trail.dart';
import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';

/// Whether the primary modifier is Command on [platform] (default: the
/// platform running): macOS and iOS; else it is Control.
bool forgePrimaryIsMeta([TargetPlatform? platform]) {
  final p = platform ?? defaultTargetPlatform;
  return p == TargetPlatform.macOS || p == TargetPlatform.iOS;
}

/// The keys that are only modifiers: pressing one alone captures nothing.
final Set<LogicalKeyboardKey> _modifierKeys = {
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
  LogicalKeyboardKey.fnLock,
};

/// The name of the key [keyId] (`LogicalKeyboardKey.keyId`): its label
/// (`K`, `F5`, `Enter`), else its debug name.
String forgeKeyName(int keyId) {
  final key = LogicalKeyboardKey.findKeyByKeyId(keyId);
  if (key == null) return '0x${keyId.toRadixString(16)}';
  final label = key.keyLabel;
  if (label.trim().isNotEmpty) {
    return label.length == 1 ? label.toUpperCase() : label;
  }
  return key.debugName ?? '0x${keyId.toRadixString(16)}';
}

/// [stroke] as the user reads it: `⌃⌥⇧⌘K` where the primary modifier is
/// Command ([primaryIsMeta], default: the platform's), `Ctrl+Alt+Shift+K`
/// elsewhere; `""` for no key.
String forgeKeyStrokeLabel(ForgeKeyStroke stroke, {bool? primaryIsMeta}) {
  if (stroke.isNone) return '';
  final meta = primaryIsMeta ?? forgePrimaryIsMeta();
  final key = forgeKeyName(stroke.keyId);
  if (meta) {
    return [
      if (stroke.control) '⌃',
      if (stroke.alt) '⌥',
      if (stroke.shift) '⇧',
      if (stroke.primaryModifier) '⌘',
      key,
    ].join();
  }
  return [
    if (stroke.primaryModifier || stroke.control) 'Ctrl',
    if (stroke.alt) 'Alt',
    if (stroke.shift) 'Shift',
    key,
  ].join('+');
}

/// [binding]'s strokes as the user reads them, one after the other
/// (`Ctrl+K Ctrl+S`); `""` when unbound.
String forgeKeyChordLabel(ForgeKeyChord binding, {bool? primaryIsMeta}) => [
  for (final stroke in binding.strokes)
    forgeKeyStrokeLabel(stroke, primaryIsMeta: primaryIsMeta),
].join(' ');

/// The stroke [event] presses with the modifiers held now
/// (`HardwareKeyboard`), or null for a modifier alone. Where the primary
/// modifier is Command ([primaryIsMeta]), Command is the primary modifier and
/// Control the Control flag; elsewhere Control is the primary modifier.
ForgeKeyStroke? forgeKeyStrokeOf(KeyEvent event, {bool? primaryIsMeta}) {
  if (_modifierKeys.contains(event.logicalKey)) return null;
  final meta = primaryIsMeta ?? forgePrimaryIsMeta();
  final keyboard = HardwareKeyboard.instance;
  return ForgeKeyStroke(
    event.logicalKey.keyId,
    primaryModifier: meta ? keyboard.isMetaPressed : keyboard.isControlPressed,
    control: meta && keyboard.isControlPressed,
    shift: keyboard.isShiftPressed,
    alt: keyboard.isAltPressed,
  );
}

/// A field that captures a key binding from the keyboard: it shows the
/// binding (or *Not bound*); a click (or *Change*) starts capturing, the next
/// combination pressed is taken (a chord: up to [maxStrokes] one after the
/// other, ended by *Done*, by reaching [maxStrokes] or by leaving the field),
/// *Escape* or *Cancel* stops capturing and keeps the binding; *Clear*
/// ([onCleared]) unbinds it.
class ForgeKeyCaptureField extends StatefulWidget {
  const ForgeKeyCaptureField({
    super.key,
    required this.strokes,
    required this.onCaptured,
    this.maxStrokes = 1,
    this.onCleared,
    this.enabled = true,
    this.dense = false,
    this.semanticLabel,
    this.highlight,
    this.trailName = 'key',
  });

  /// The binding shown.
  final List<ForgeKeyStroke> strokes;

  /// Takes the strokes captured.
  final ValueChanged<List<ForgeKeyStroke>> onCaptured;

  /// The most strokes captured (1: a single combination).
  final int maxStrokes;

  /// Unbinds; null: no *Clear*.
  final VoidCallback? onCleared;

  final bool enabled;
  final bool dense;
  final String? semanticLabel;

  /// A colour for the binding's text (a conflict), or null.
  final Color? highlight;

  /// How the trail names the field.
  final String trailName;

  @override
  State<ForgeKeyCaptureField> createState() => _ForgeKeyCaptureFieldState();
}

class _ForgeKeyCaptureFieldState extends State<ForgeKeyCaptureField> {
  final FocusNode _focus = FocusNode(debugLabel: 'ForgeKeyCaptureField');
  bool _capturing = false;
  final List<ForgeKeyStroke> _pending = [];

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    configurationUiTrail('${widget.trailName}: capture');
    setState(() {
      _capturing = true;
      _pending.clear();
    });
    _focus.requestFocus();
  }

  void _cancel() {
    if (!_capturing) return;
    configurationUiTrail('${widget.trailName}: capture cancelled');
    setState(() {
      _capturing = false;
      _pending.clear();
    });
  }

  void _finish() {
    if (!_capturing) return;
    final strokes = List<ForgeKeyStroke>.unmodifiable(_pending);
    setState(() {
      _capturing = false;
      _pending.clear();
    });
    if (strokes.isEmpty) return;
    configurationUiTrail(
      '${widget.trailName}: captured '
      '${forgeKeyChordLabel(ForgeKeyChord(strokes))}',
    );
    widget.onCaptured(strokes);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_capturing) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isShiftPressed) {
      _cancel();
      return KeyEventResult.handled;
    }
    final stroke = forgeKeyStrokeOf(event);
    if (stroke == null) return KeyEventResult.handled;
    setState(() => _pending.add(stroke));
    if (_pending.length >= widget.maxStrokes) _finish();
    return KeyEventResult.handled;
  }

  void _onFocusChange(bool focused) {
    if (focused || !_capturing) return;
    if (widget.maxStrokes > 1 && _pending.isNotEmpty) {
      _finish();
    } else {
      _cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = _capturing ? _pending : widget.strokes;
    final binding = forgeKeyChordLabel(ForgeKeyChord(shown));
    final String text;
    TextStyle? style = theme.textTheme.bodyMedium;
    if (_capturing && _pending.isEmpty) {
      text = ForgeConfigurationLabels.resolve(
        widget.maxStrokes > 1
            ? ForgeConfigurationUiTexts.pressChord
            : ForgeConfigurationUiTexts.pressKeys,
      );
      style = style?.copyWith(color: theme.hintColor);
    } else if (_capturing) {
      text = '$binding …';
    } else if (binding.isEmpty) {
      text = ForgeConfigurationLabels.resolve(
        ForgeConfigurationUiTexts.unbound,
      );
      style = style?.copyWith(color: theme.hintColor);
    } else {
      text = binding;
      if (widget.highlight != null) {
        style = style?.copyWith(color: widget.highlight);
      }
    }
    final box = Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      onFocusChange: _onFocusChange,
      child: InkWell(
        onTap: widget.enabled ? _start : null,
        child: InputDecorator(
          isFocused: _capturing,
          isEmpty: false,
          decoration: InputDecoration(
            isDense: widget.dense,
            enabled: widget.enabled,
            border: const OutlineInputBorder(),
            contentPadding: widget.dense
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
                : null,
          ),
          child: Text(text, style: style, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
    final cancel = ForgeConfigurationLabels.resolve(
      ForgeConfigurationUiTexts.cancel,
    );
    return Semantics(
      label: widget.semanticLabel,
      value: binding,
      child: Row(
        children: [
          Expanded(child: box),
          if (_capturing && widget.maxStrokes > 1)
            IconButton(
              tooltip: ForgeConfigurationLabels.resolve(
                ForgeConfigurationUiTexts.done,
              ),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.check, size: 18),
              onPressed: _pending.isEmpty ? null : _finish,
            ),
          if (_capturing)
            IconButton(
              tooltip: cancel,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18),
              onPressed: _cancel,
            )
          else ...[
            IconButton(
              tooltip: ForgeConfigurationLabels.resolve(
                ForgeConfigurationUiTexts.change,
              ),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.keyboard, size: 18),
              onPressed: widget.enabled ? _start : null,
            ),
            if (widget.onCleared != null)
              IconButton(
                tooltip: ForgeConfigurationLabels.resolve(
                  ForgeConfigurationUiTexts.clear,
                ),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.backspace_outlined, size: 18),
                onPressed: widget.enabled && widget.strokes.isNotEmpty
                    ? widget.onCleared
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}
