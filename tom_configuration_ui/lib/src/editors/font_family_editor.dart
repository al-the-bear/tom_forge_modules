import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart' show ForgeConfigurationValues;

import '../configuration_ui_trail.dart';
import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';
import '../forge_setting_editor_registry.dart';
import 'hook_widgets.dart';

/// A font family (`ForgeFontFamilySetting`): the name in a text field (typed
/// when the setting allows a custom name, else chosen only) and a button
/// that opens [showForgeFontPicker] — the setting's suggestions, the fonts
/// its provider answers (the choices hook, through the values service's
/// `choicesFor`) and the generic families, searchable, each drawn in its
/// own font.
class ForgeFontFamilyEditor extends StatefulWidget {
  const ForgeFontFamilyEditor({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  State<ForgeFontFamilyEditor> createState() => _ForgeFontFamilyEditorState();
}

class _ForgeFontFamilyEditorState extends State<ForgeFontFamilyEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.request.value as String,
  );

  ForgeFontFamilySetting get _setting =>
      widget.request.setting as ForgeFontFamilySetting;

  @override
  void didUpdateWidget(covariant ForgeFontFamilyEditor oldWidget) {
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

  Future<void> _pick() async {
    final chosen = await showForgeFontPicker(
      context,
      setting: _setting,
      values: widget.request.values,
      current: _controller.text,
    );
    if (chosen == null || !mounted) return;
    _controller.text = chosen;
    widget.request.onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final setting = _setting;
    final value = _controller.text;
    return Semantics(
      label: r.label,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: r.enabled,
              readOnly: !setting.allowCustom,
              onTap: setting.allowCustom ? null : _pick,
              style: value.trim().isEmpty
                  ? null
                  : TextStyle(fontFamily: value.trim()),
              decoration: InputDecoration(
                isDense: r.style.dense,
                hintText: ForgeConfigurationLabels.resolve(
                  setting.hint ??
                      (setting.allowEmpty
                          ? ForgeConfigurationUiTexts.defaultFont
                          : ForgeConfigurationUiTexts.chooseFont),
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) {
                setState(() {});
                r.onChanged(text);
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: ValueKey('forge.configuration.font.pick.${setting.id}'),
            tooltip: ForgeConfigurationLabels.resolve(
              ForgeConfigurationUiTexts.chooseFont,
            ),
            icon: const Icon(Icons.font_download_outlined, size: 20),
            onPressed: r.enabled ? _pick : null,
          ),
        ],
      ),
    );
  }
}

/// [setting] asking its provider for every font (no `monospace` key).
ForgeFontFamilySetting _everyFont(ForgeFontFamilySetting setting) =>
    ForgeFontFamilySetting(
      id: setting.id,
      storage: setting.storage,
      label: setting.label,
      defaultValue: setting.defaultValue,
      fontsProvider: setting.fontsProvider,
      suggestions: setting.suggestions,
      allowEmpty: setting.allowEmpty,
      allowCustom: setting.allowCustom,
    );

/// Lets the user choose a font for [setting]: a searchable list of its
/// fonts (`ForgeConfigurationValues.choicesFor`; without [values] its
/// suggestions and the generic families), *Default font* first when the
/// empty name is a value, a *Fixed-width fonts only* filter for a code font
/// (on: the provider is asked with the key `monospace`; off: for every
/// font), and the typed name itself when a custom name is allowed. Answers
/// the name chosen, or null when the user cancelled.
Future<String?> showForgeFontPicker(
  BuildContext context, {
  required ForgeFontFamilySetting setting,
  required ForgeConfigurationValues? values,
  required String current,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ForgeFontPickerDialog(
    setting: setting,
    values: values,
    current: current,
  ),
);

class _ForgeFontPickerDialog extends StatefulWidget {
  const _ForgeFontPickerDialog({
    required this.setting,
    required this.values,
    required this.current,
  });

  final ForgeFontFamilySetting setting;
  final ForgeConfigurationValues? values;
  final String current;

  @override
  State<_ForgeFontPickerDialog> createState() => _ForgeFontPickerDialogState();
}

class _ForgeFontPickerDialogState extends State<_ForgeFontPickerDialog> {
  final TextEditingController _search = TextEditingController();
  final ForgeLatestLoad _load = ForgeLatestLoad();
  late bool _monospaceOnly = widget.setting.monospace;
  List<ForgeSettingChoice>? _fonts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _load.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _fonts = null);
    final setting = widget.setting;
    final values = widget.values;
    if (values == null) {
      setState(
        () => _fonts = [
          for (final name in [
            ...setting.suggestions,
            ...ForgeFontFamilySetting.genericFamilies,
          ])
            ForgeSettingChoice(name, ForgeText.literal(name)),
        ],
      );
      return;
    }
    final asked = _monospaceOnly || !setting.monospace
        ? setting
        : _everyFont(setting);
    configurationUiTrail(
      'fonts for ${setting.id}: read${_monospaceOnly ? ' (monospace)' : ''}',
    );
    await _load.run(() => values.choicesFor(asked), (fonts) {
      configurationUiTrail('fonts for ${setting.id}: ${fonts.length}');
      if (mounted) setState(() => _fonts = fonts);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final setting = widget.setting;
    final query = _search.text.trim();
    final lower = query.toLowerCase();
    final fonts = _fonts;
    final shown = fonts == null
        ? const <ForgeSettingChoice>[]
        : [
            for (final font in fonts)
              if (lower.isEmpty ||
                  font.value.toLowerCase().contains(lower) ||
                  ForgeConfigurationLabels.resolve(
                    font.label,
                  ).toLowerCase().contains(lower))
                font,
          ];
    final custom =
        setting.allowCustom &&
        query.isNotEmpty &&
        !(fonts ?? const []).any((f) => f.value == query);
    final tiles = <Widget>[
      if (setting.allowEmpty && lower.isEmpty)
        ListTile(
          dense: true,
          selected: widget.current.isEmpty,
          title: Text(
            ForgeConfigurationLabels.resolve(
              ForgeConfigurationUiTexts.defaultFont,
            ),
          ),
          onTap: () => Navigator.of(context).pop(''),
        ),
      if (custom)
        ListTile(
          dense: true,
          leading: const Icon(Icons.edit, size: 18),
          title: Text(
            '${ForgeConfigurationLabels.resolve(ForgeConfigurationUiTexts.use)} '
            '"$query"',
            style: TextStyle(fontFamily: query),
          ),
          onTap: () => Navigator.of(context).pop(query),
        ),
      for (final font in shown)
        ListTile(
          key: ValueKey('forge.configuration.font.${font.value}'),
          dense: true,
          selected: font.value == widget.current,
          title: Text(
            ForgeConfigurationLabels.resolve(font.label),
            style: TextStyle(fontFamily: font.value),
          ),
          onTap: () => Navigator.of(context).pop(font.value),
        ),
    ];
    return AlertDialog(
      title: Text(
        ForgeConfigurationLabels.resolve(ForgeConfigurationUiTexts.chooseFont),
      ),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('forge.configuration.font.search'),
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: ForgeConfigurationLabels.resolve(
                  ForgeConfigurationUiTexts.search,
                ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (setting.monospace)
              CheckboxListTile(
                key: const ValueKey('forge.configuration.font.monospace'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _monospaceOnly,
                title: Text(
                  ForgeConfigurationLabels.resolve(
                    ForgeConfigurationUiTexts.monospaceOnly,
                  ),
                ),
                onChanged: (on) {
                  _monospaceOnly = on ?? false;
                  _reload();
                },
              ),
            const SizedBox(height: 4),
            Expanded(
              child: fonts == null
                  ? const Center(
                      child: ForgeStatusView(status: ForgeStatusInfo.busy),
                    )
                  : tiles.isEmpty
                  ? Center(
                      child: Text(
                        ForgeConfigurationLabels.resolve(
                          ForgeConfigurationUiTexts.noMatches,
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : ListView(children: tiles),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            ForgeConfigurationLabels.resolve(ForgeConfigurationUiTexts.cancel),
          ),
        ),
      ],
    );
  }
}
