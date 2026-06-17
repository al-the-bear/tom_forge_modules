import 'package:flutter/material.dart';

/// A single editable field in a configuration detail form (§12).
///
/// Each config editor (profiles, templates, chat variables, …) declares its
/// detail form as a `List<ConfigField<T>>` rather than hand-writing a bespoke
/// form widget per type. The scaffold ([ConfigListEditor] / [ConfigObjectEditor])
/// renders each field's [builder] and surfaces its [validate] result, so the
/// editors stay declarative and share one validation/raw-file/list-management
/// implementation.
///
/// `T` is the immutable config model (e.g. `AgentProfile`). A field reads from
/// the current value and produces a new value on edit via a copy — the model
/// objects are immutable value types, so edits replace rather than mutate.
class ConfigField<T> {
  ConfigField._({
    required this.label,
    required this.builder,
    this.validate,
  });

  /// The field's display label.
  final String label;

  /// Builds the field's editor widget for [value], calling [onChanged] with a
  /// new model value when the user edits it.
  final Widget Function(T value, ValueChanged<T> onChanged) builder;

  /// Optional validation; returns an error message or null when [value] is
  /// acceptable for this field.
  final String? Function(T value)? validate;

  /// A single-line (or [multiline]) text field.
  factory ConfigField.text({
    required String label,
    required String Function(T value) get,
    required T Function(T value, String text) set,
    bool multiline = false,
    bool readOnly = false,
    bool required = false,
  }) {
    return ConfigField._(
      label: label,
      validate: required
          ? (v) => get(v).trim().isEmpty ? '$label must not be empty' : null
          : null,
      builder: (value, onChanged) => _ConfigTextField(
        key: ValueKey('cfg-text-$label'),
        label: label,
        initial: get(value),
        multiline: multiline,
        readOnly: readOnly,
        onChanged: (text) => onChanged(set(value, text)),
      ),
    );
  }

  /// A boolean toggle.
  factory ConfigField.boolean({
    required String label,
    required bool Function(T value) get,
    required T Function(T value, bool flag) set,
  }) {
    return ConfigField._(
      label: label,
      builder: (value, onChanged) => SwitchListTile(
        key: ValueKey('cfg-bool-$label'),
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: get(value),
        onChanged: (flag) => onChanged(set(value, flag)),
      ),
    );
  }

  /// An optional integer field. An empty string clears the value to null.
  ///
  /// [validate] runs in addition to the [positive] check; the positive check
  /// takes precedence so callers can layer a cross-field rule (e.g. a valid
  /// port range) on top without re-checking the basic constraint.
  factory ConfigField.integer({
    required String label,
    required int? Function(T value) get,
    required T Function(T value, int? number) set,
    bool positive = false,
    String? Function(T value)? validate,
  }) {
    return ConfigField._(
      label: label,
      validate: (v) {
        final n = get(v);
        if (positive && n != null && n <= 0) return '$label must be positive';
        return validate?.call(v);
      },
      builder: (value, onChanged) => _ConfigTextField(
        key: ValueKey('cfg-int-$label'),
        label: label,
        initial: get(value)?.toString() ?? '',
        keyboardType: TextInputType.number,
        onChanged: (text) {
          final trimmed = text.trim();
          onChanged(set(value, trimmed.isEmpty ? null : int.tryParse(trimmed)));
        },
      ),
    );
  }

  /// A dropdown over the enum-like [values].
  static ConfigField<T> enumeration<T, E>({
    required String label,
    required E Function(T value) get,
    required T Function(T value, E choice) set,
    required List<E> values,
    required String Function(E choice) labelOf,
  }) {
    return ConfigField._(
      label: label,
      builder: (value, onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<E>(
              key: ValueKey('cfg-enum-$label'),
              isDense: true,
              value: get(value),
              items: [
                for (final choice in values)
                  DropdownMenuItem<E>(
                    value: choice,
                    child: Text(labelOf(choice)),
                  ),
              ],
              onChanged: (choice) {
                if (choice != null) onChanged(set(value, choice));
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A debounced-free text field that seeds from [initial] and reports edits.
class _ConfigTextField extends StatefulWidget {
  const _ConfigTextField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.multiline = false,
    this.readOnly = false,
    this.keyboardType,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final bool multiline;
  final bool readOnly;
  final TextInputType? keyboardType;

  @override
  State<_ConfigTextField> createState() => _ConfigTextFieldState();
}

class _ConfigTextFieldState extends State<_ConfigTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void didUpdateWidget(_ConfigTextField old) {
    super.didUpdateWidget(old);
    // Re-seed when the selected item changes (initial differs) but not on every
    // keystroke (the controller already holds the user's text).
    if (widget.initial != old.initial && widget.initial != _controller.text) {
      _controller.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextField(
        controller: _controller,
        readOnly: widget.readOnly,
        keyboardType: widget.keyboardType,
        maxLines: widget.multiline ? 4 : 1,
        minLines: widget.multiline ? 3 : 1,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
