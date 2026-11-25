import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_flutter_ui/tom_flutter_ui.dart'
    show TomSelectableItem, TomStaticSelectableSource;
import 'package:tom_forge_core/tom_forge_core.dart';

import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';
import '../forge_setting_editor_registry.dart';
import 'setting_tom_field.dart';

/// The standard editor of every kind `tom_forge_core` defines
/// (`ForgeSettingKinds`), by kind:
///
/// | Kind | Editor |
/// | --- | --- |
/// | `bool` | a switch (`TomFormFieldFamily.boolSwitch`), beside the label |
/// | `int` | a number field (`intInput`) |
/// | `double` | a number field (`doubleInput`) |
/// | `string` | a text field (`stringInput`); several lines for a multiline setting |
/// | `choice` | the choices side by side (`stringSegmented`) or a list (`stringPicker`) |
/// | `stringList` | with choices, chips to pick (`stringMultiSelect`); else the items as chips with a field to add one |
/// | `path` | a text field with a button that opens the application's picker |
/// | `color` | a swatch with the hex value, beside the label |
/// | `stringMap` | one row per entry (key, value), with a row to add one |
Map<String, ForgeSettingEditor> forgeStandardSettingEditors() => {
  ForgeSettingKinds.boolean: const ForgeSettingEditor(
    _bool,
    inline: true,
    width: 64,
  ),
  ForgeSettingKinds.integer: const ForgeSettingEditor(_int),
  ForgeSettingKinds.decimal: const ForgeSettingEditor(_double),
  ForgeSettingKinds.string: const ForgeSettingEditor(_string),
  ForgeSettingKinds.choice: const ForgeSettingEditor(_choice),
  ForgeSettingKinds.stringList: const ForgeSettingEditor(_stringList),
  ForgeSettingKinds.path: const ForgeSettingEditor(_path),
  ForgeSettingKinds.color: const ForgeSettingEditor(_color, inline: true),
  ForgeSettingKinds.stringMap: const ForgeSettingEditor(_stringMap),
};

Widget _bool(BuildContext context, ForgeSettingEditorRequest r) =>
    ForgeSettingTomField<bool>(
      request: r,
      create: (id, value) =>
          r.style.fieldFamily.boolSwitch(id, value, autoValidate: false),
    );

Widget _int(BuildContext context, ForgeSettingEditorRequest r) {
  final setting = r.setting as ForgeIntSetting;
  return _withUnit(
    context,
    setting.unit,
    ForgeSettingTomField<int>(
      request: r,
      create: (id, value) =>
          r.style.fieldFamily.intInput(id, value, autoValidate: false),
    ),
  );
}

Widget _double(BuildContext context, ForgeSettingEditorRequest r) {
  final setting = r.setting as ForgeDoubleSetting;
  return _withUnit(
    context,
    setting.unit,
    ForgeSettingTomField<double>(
      request: r,
      create: (id, value) => r.style.fieldFamily.doubleInput(
        id,
        value,
        decimals: setting.decimals,
        autoValidate: false,
      ),
    ),
  );
}

/// [editor] with [unit] after it, when the setting names one.
Widget _withUnit(BuildContext context, ForgeText? unit, Widget editor) {
  if (unit == null) return editor;
  return Row(
    children: [
      Expanded(child: editor),
      const SizedBox(width: 8),
      Text(
        ForgeConfigurationLabels.resolve(unit),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

Widget _string(BuildContext context, ForgeSettingEditorRequest r) {
  final setting = r.setting as ForgeStringSetting;
  if (setting.multiline) {
    return ForgeSettingTextField(
      request: r,
      hint: ForgeConfigurationLabels.resolveOrNull(setting.hint),
      maxLines: null,
      minLines: 3,
    );
  }
  return ForgeSettingTomField<String>(
    request: r,
    create: (id, value) => r.style.fieldFamily.stringInput(
      id,
      value,
      hintTextOverride: ForgeConfigurationLabels.resolveOrNull(setting.hint),
      maxLength: setting.maxLength,
      autoValidate: false,
    ),
  );
}

TomStaticSelectableSource<String> _source(List<ForgeSettingChoice> choices) =>
    TomStaticSelectableSource([
      for (final choice in choices)
        TomSelectableItem(
          value: choice.value,
          label: ForgeConfigurationLabels.resolve(choice.label),
        ),
    ]);

Widget _choice(BuildContext context, ForgeSettingEditorRequest r) {
  final setting = r.setting as ForgeChoiceSetting;
  final segmented = switch (setting.display) {
    ForgeChoiceDisplay.segmented => true,
    ForgeChoiceDisplay.dropdown => false,
    ForgeChoiceDisplay.auto => setting.choices.length <= 3,
  };
  return ForgeSettingTomField<String>(
    request: r,
    create: (id, value) => segmented
        ? r.style.fieldFamily.stringSegmented(
            id,
            value,
            source: _source(setting.choices),
            autoValidate: false,
          )
        : r.style.fieldFamily.stringPicker(
            id,
            value,
            source: _source(setting.choices),
            autoValidate: false,
          ),
  );
}

Widget _stringList(BuildContext context, ForgeSettingEditorRequest r) {
  final setting = r.setting as ForgeStringListSetting;
  final choices = setting.choices;
  if (choices != null) {
    return ForgeSettingTomField<List<String>>(
      request: r,
      create: (id, value) => r.style.fieldFamily.stringMultiSelect(
        id,
        value,
        source: _source(choices),
        autoValidate: false,
      ),
    );
  }
  return ForgeSettingStringListField(request: r);
}

Widget _path(BuildContext context, ForgeSettingEditorRequest r) {
  final setting = r.setting as ForgePathSetting;
  final pick = r.pickPath;
  return ForgeSettingTextField(
    request: r,
    hint: ForgeConfigurationLabels.resolveOrNull(setting.hint),
    trailing: pick == null
        ? null
        : (controller) => TextButton(
            onPressed: r.enabled
                ? () async {
                    final chosen = await pick(setting, controller.text);
                    if (chosen != null) {
                      controller.text = chosen;
                      r.onChanged(chosen);
                    }
                  }
                : null,
            child: Text(
              ForgeConfigurationLabels.resolve(
                ForgeConfigurationUiTexts.browse,
              ),
            ),
          ),
  );
}

Widget _color(BuildContext context, ForgeSettingEditorRequest r) =>
    ForgeSettingColorField(request: r);

Widget _stringMap(BuildContext context, ForgeSettingEditorRequest r) =>
    ForgeSettingStringMapField(request: r);

/// A text field over a string value, for the editors that are not a
/// `tom_flutter_ui` field (multiline text, paths): what is typed goes to
/// `onChanged`; a value changed from outside replaces the text.
class ForgeSettingTextField extends StatefulWidget {
  const ForgeSettingTextField({
    super.key,
    required this.request,
    this.hint,
    this.maxLines = 1,
    this.minLines,
    this.trailing,
  });

  final ForgeSettingEditorRequest request;
  final String? hint;
  final int? maxLines;
  final int? minLines;

  /// A widget after the field (a browse button), given the field's
  /// controller.
  final Widget Function(TextEditingController controller)? trailing;

  @override
  State<ForgeSettingTextField> createState() => _ForgeSettingTextFieldState();
}

class _ForgeSettingTextFieldState extends State<ForgeSettingTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.request.value as String,
  );

  @override
  void didUpdateWidget(covariant ForgeSettingTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.request.value as String;
    if (value != oldWidget.request.value && value != _controller.text) {
      _controller.text = value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final field = TextField(
      controller: _controller,
      enabled: r.enabled,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: widget.maxLines == 1
          ? TextInputType.text
          : TextInputType.multiline,
      decoration: InputDecoration(
        isDense: r.style.dense,
        hintText: widget.hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: r.onChanged,
    );
    final trailing = widget.trailing;
    if (trailing == null) return Semantics(label: r.label, child: field);
    return Semantics(
      label: r.label,
      child: Row(
        children: [
          Expanded(child: field),
          const SizedBox(width: 8),
          trailing(_controller),
        ],
      ),
    );
  }
}

/// The items of a free string list as chips, each with a remove button, and
/// a field to add one.
class ForgeSettingStringListField extends StatefulWidget {
  const ForgeSettingStringListField({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  State<ForgeSettingStringListField> createState() =>
      _ForgeSettingStringListFieldState();
}

class _ForgeSettingStringListFieldState
    extends State<ForgeSettingStringListField> {
  final TextEditingController _controller = TextEditingController();

  List<String> get _items => widget.request.value as List<String>;

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.request.onChanged([..._items, text]);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final setting = r.setting as ForgeStringListSetting;
    final remove = ForgeConfigurationLabels.resolve(
      ForgeConfigurationUiTexts.remove,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _items.length; i++)
                InputChip(
                  label: Text(_items[i]),
                  isEnabled: r.enabled,
                  visualDensity: r.style.dense ? VisualDensity.compact : null,
                  deleteButtonTooltipMessage: remove,
                  onDeleted: () => r.onChanged([..._items]..removeAt(i)),
                ),
            ],
          ),
        if (_items.isNotEmpty) const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: r.enabled,
                decoration: InputDecoration(
                  isDense: r.style.dense,
                  hintText: ForgeConfigurationLabels.resolve(
                    setting.hint ?? ForgeConfigurationUiTexts.newItem,
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: ForgeConfigurationLabels.resolve(
                ForgeConfigurationUiTexts.add,
              ),
              icon: const Icon(Icons.add),
              onPressed: r.enabled ? _add : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// A colour: its swatch and its hex value (`#RRGGBB`, `#AARRGGBB`) to type.
class ForgeSettingColorField extends StatefulWidget {
  const ForgeSettingColorField({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  State<ForgeSettingColorField> createState() => _ForgeSettingColorFieldState();
}

class _ForgeSettingColorFieldState extends State<ForgeSettingColorField> {
  late final TextEditingController _controller = TextEditingController(
    text: ForgeColorSetting.toHex(widget.request.value as int),
  );

  @override
  void didUpdateWidget(covariant ForgeSettingColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.request.value as int;
    if (value != oldWidget.request.value &&
        ForgeColorSetting.parseHex(_controller.text) != value) {
      _controller.text = ForgeColorSetting.toHex(value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Color(r.value as int),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: scheme.outline),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _controller,
            enabled: r.enabled,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              semanticCounterText: r.label,
            ),
            // A text that is no colour is handed over as text: the setting
            // refuses it and the tile says why.
            onChanged: (text) =>
                r.onChanged(ForgeColorSetting.parseHex(text) ?? text),
          ),
        ),
      ],
    );
  }
}

/// A map from texts to texts: one row per entry (its key, its value — free
/// or one of the setting's choices — and a remove button), and a row to add
/// an entry.
class ForgeSettingStringMapField extends StatefulWidget {
  const ForgeSettingStringMapField({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  State<ForgeSettingStringMapField> createState() =>
      _ForgeSettingStringMapFieldState();
}

class _ForgeSettingStringMapFieldState
    extends State<ForgeSettingStringMapField> {
  final TextEditingController _newKey = TextEditingController();

  Map<String, String> get _entries =>
      widget.request.value as Map<String, String>;

  @override
  void dispose() {
    _newKey.dispose();
    super.dispose();
  }

  void _add(ForgeStringMapSetting setting) {
    final key = _newKey.text.trim();
    if (key.isEmpty) return;
    final initial = setting.valueChoices?.firstOrNull?.value ?? '';
    widget.request.onChanged({..._entries, key: _entries[key] ?? initial});
    _newKey.clear();
  }

  Widget _valueEditor(ForgeStringMapSetting setting, String key, String value) {
    final r = widget.request;
    final choices = setting.valueChoices;
    if (choices != null) {
      final known = choices.any((c) => c.value == value);
      return DropdownButton<String>(
        isExpanded: true,
        isDense: r.style.dense,
        value: known ? value : null,
        items: [
          for (final choice in choices)
            DropdownMenuItem(
              value: choice.value,
              child: Text(ForgeConfigurationLabels.resolve(choice.label)),
            ),
        ],
        onChanged: r.enabled
            ? (chosen) {
                if (chosen != null) r.onChanged({..._entries, key: chosen});
              }
            : null,
      );
    }
    return TextFormField(
      key: ValueKey('$key=$value'),
      initialValue: value,
      enabled: r.enabled,
      decoration: InputDecoration(
        isDense: r.style.dense,
        border: const OutlineInputBorder(),
      ),
      onChanged: (text) => r.onChanged({..._entries, key: text}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final setting = r.setting as ForgeStringMapSetting;
    final theme = Theme.of(context);
    final remove = ForgeConfigurationLabels.resolve(
      ForgeConfigurationUiTexts.remove,
    );
    final keyLabel = ForgeConfigurationLabels.resolve(
      setting.keyLabel ?? ForgeConfigurationUiTexts.key,
    );
    final valueLabel = ForgeConfigurationLabels.resolve(
      setting.valueLabel ?? ForgeConfigurationUiTexts.value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(keyLabel, style: theme.textTheme.labelSmall)),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(valueLabel, style: theme.textTheme.labelSmall),
            ),
            const SizedBox(width: 40),
          ],
        ),
        for (final entry in _entries.entries)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(child: Text(entry.key)),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _valueEditor(setting, entry.key, entry.value),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    tooltip: remove,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: r.enabled
                        ? () => r.onChanged({..._entries}..remove(entry.key))
                        : null,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newKey,
                enabled: r.enabled,
                decoration: InputDecoration(
                  isDense: r.style.dense,
                  hintText: keyLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _add(setting),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: ForgeConfigurationLabels.resolve(
                ForgeConfigurationUiTexts.add,
              ),
              icon: const Icon(Icons.add),
              onPressed: r.enabled ? () => _add(setting) : null,
            ),
          ],
        ),
      ],
    );
  }
}
