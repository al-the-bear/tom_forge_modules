import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../configuration_ui_trail.dart';
import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';
import '../forge_setting_editor_registry.dart';
import 'hook_widgets.dart';

// Editors of values that need more than a plain field: dates and times with
// Material's pickers, numbers shown in another unit, and choices a provider
// answers at run time.

/// Which of the time kinds a [ForgeDateTimeEditor] edits.
enum ForgeDateTimeMode { date, time, dateTime }

/// A date (`ForgeDateSetting`), a time of day (`ForgeTimeSetting`) or a
/// point in time (`ForgeDateTimeSetting`): the value as the locale writes it
/// (*No date* when none), a button that opens Material's date picker (within
/// the setting's bounds), its time picker, or both one after the other, and
/// *Clear* when none is a value.
class ForgeDateTimeEditor extends StatelessWidget {
  const ForgeDateTimeEditor({
    super.key,
    required this.request,
    required this.mode,
  });

  final ForgeSettingEditorRequest request;
  final ForgeDateTimeMode mode;

  String _text(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final h24 = MediaQuery.maybeAlwaysUse24HourFormatOf(context) ?? false;
    String time(ForgeTimeOfDay t) => l10n.formatTimeOfDay(
      TimeOfDay(hour: t.hour, minute: t.minute),
      alwaysUse24HourFormat: h24,
    );
    final none = ForgeConfigurationLabels.resolveIn(
      context,
      ForgeConfigurationUiTexts.noDate,
    );
    final value = request.value;
    switch (mode) {
      case ForgeDateTimeMode.date:
        final date = value as ForgeDate;
        return date.isNone ? none : l10n.formatShortDate(date.toDateTime());
      case ForgeDateTimeMode.time:
        return time(value as ForgeTimeOfDay);
      case ForgeDateTimeMode.dateTime:
        final moment = value as ForgeDateTime;
        if (moment.isNone) return none;
        final text =
            '${l10n.formatShortDate(moment.date.toDateTime())} '
            '${time(moment.time)}';
        return moment.utc
            ? '$text ${ForgeConfigurationLabels.resolveIn(context, ForgeConfigurationUiTexts.utc)}'
            : text;
    }
  }

  bool get _isNone => switch (request.value) {
    final ForgeDate d => d.isNone,
    final ForgeDateTime d => d.isNone,
    _ => false,
  };

  bool get _allowsNone => switch (request.setting) {
    final ForgeDateSetting s => s.allowNone,
    final ForgeDateTimeSetting s => s.allowNone,
    _ => false,
  };

  Future<ForgeDate?> _pickDate(
    BuildContext context,
    ForgeDate current,
    ForgeDate? first,
    ForgeDate? last,
  ) async {
    final lo = first?.toDateTime() ?? DateTime(1900);
    final hi = last?.toDateTime() ?? DateTime(2100, 12, 31);
    var initial = current.isNone || !current.isValid
        ? DateTime.now()
        : current.toDateTime();
    if (initial.isBefore(lo)) initial = lo;
    if (initial.isAfter(hi)) initial = hi;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: lo,
      lastDate: hi,
    );
    return picked == null ? null : ForgeDate.fromDateTime(picked);
  }

  Future<ForgeTimeOfDay?> _pickTime(
    BuildContext context,
    ForgeTimeOfDay current,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    return picked == null ? null : ForgeTimeOfDay(picked.hour, picked.minute);
  }

  Future<void> _pick(BuildContext context) async {
    configurationUiTrail('pick ${mode.name} for ${request.setting.id}');
    switch (request.setting) {
      case final ForgeDateSetting s:
        final date = await _pickDate(
          context,
          request.value as ForgeDate,
          s.first,
          s.last,
        );
        if (date != null) request.onChanged(date);
      case ForgeTimeSetting():
        final time = await _pickTime(context, request.value as ForgeTimeOfDay);
        if (time != null) request.onChanged(time);
      case final ForgeDateTimeSetting s:
        final current = request.value as ForgeDateTime;
        final date = await _pickDate(
          context,
          current.date,
          s.first?.date,
          s.last?.date,
        );
        if (date == null || !context.mounted) return;
        final time = await _pickTime(
          context,
          current.isNone ? const ForgeTimeOfDay(9, 0) : current.time,
        );
        if (time == null) return;
        request.onChanged(ForgeDateTime(date, time, utc: s.utc));
    }
  }

  void _clear() {
    request.onChanged(switch (mode) {
      ForgeDateTimeMode.date => ForgeDate.none,
      ForgeDateTimeMode.dateTime => ForgeDateTime.none,
      ForgeDateTimeMode.time => request.value,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = request.enabled;
    final icon = mode == ForgeDateTimeMode.time
        ? Icons.schedule
        : Icons.calendar_today;
    return Semantics(
      label: request.label,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: enabled ? () => _pick(context) : null,
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: request.style.dense,
                  enabled: enabled,
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  _text(context),
                  style: _isNone
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        )
                      : theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('forge.configuration.pick.${request.setting.id}'),
            tooltip: ForgeConfigurationLabels.resolveIn(
              context,
              mode == ForgeDateTimeMode.time
                  ? ForgeConfigurationUiTexts.pickTime
                  : ForgeConfigurationUiTexts.pickDate,
            ),
            icon: Icon(icon, size: 18),
            onPressed: enabled ? () => _pick(context) : null,
          ),
          if (_allowsNone)
            IconButton(
              tooltip: ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.clear,
              ),
              icon: const Icon(Icons.backspace_outlined, size: 18),
              onPressed: enabled && !_isNone ? _clear : null,
            ),
        ],
      ),
    );
  }
}

/// A number shown in another unit than it is kept in (`ForgeIntSetting` /
/// `ForgeDoubleSetting` with a `scale`): the field shows `value / scale`
/// (with the setting's shown decimals) and [unit] after it; what is typed is
/// stored as `typed * scale` (rounded for a whole number). A text that is no
/// number is handed over as it is, so the setting refuses it and the tile
/// says why.
class ForgeScaledNumberField extends StatefulWidget {
  const ForgeScaledNumberField({super.key, required this.request});

  final ForgeSettingEditorRequest request;

  @override
  State<ForgeScaledNumberField> createState() => _ForgeScaledNumberFieldState();
}

class _ForgeScaledNumberFieldState extends State<ForgeScaledNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.request.value),
  );

  String _format(Object value) {
    final setting = widget.request.setting;
    switch (setting) {
      case final ForgeIntSetting s:
        final shown = s.toShown(value as int);
        return shown.toStringAsFixed(s.shownDecimals);
      case final ForgeDoubleSetting s:
        final shown = s.toShown(value as double);
        final decimals = s.decimals;
        if (decimals != null) return shown.toStringAsFixed(decimals);
        return shown == shown.roundToDouble()
            ? shown.toStringAsFixed(0)
            : '$shown';
      default:
        return '$value';
    }
  }

  /// [text] as a stored value, or null when it is no number.
  Object? _stored(String text) {
    final shown = num.tryParse(text.trim().replaceAll(',', '.'));
    if (shown == null) return null;
    return switch (widget.request.setting) {
      final ForgeIntSetting s => s.fromShown(shown),
      final ForgeDoubleSetting s => s.fromShown(shown),
      _ => shown,
    };
  }

  @override
  void didUpdateWidget(covariant ForgeScaledNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.request.value;
    if (value != oldWidget.request.value &&
        _stored(_controller.text) != value) {
      _controller.text = _format(value);
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
    final unit = switch (r.setting) {
      final ForgeIntSetting s => s.unit,
      final ForgeDoubleSetting s => s.unit,
      _ => null,
    };
    return Semantics(
      label: r.label,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: r.enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
              ],
              decoration: InputDecoration(
                isDense: r.style.dense,
                border: const OutlineInputBorder(),
              ),
              onChanged: (text) => r.onChanged(_stored(text) ?? text),
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: 8),
            Text(
              ForgeConfigurationLabels.resolveIn(context, unit),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// A choice among choices read at run time: [load] answers them (a
/// `ForgeChoicesProvider` through the values service's `choicesFor`); while
/// it reads, the list says *Loading…*; it reads again when [changes] fires
/// or [refresh] does. With [allowNone] *None* ([noneLabel]) chooses `""`.
/// A value the choices lack is kept and shown as it is.
class ForgeDynamicChoiceField extends StatefulWidget {
  const ForgeDynamicChoiceField({
    super.key,
    required this.value,
    required this.load,
    required this.onChanged,
    this.allowNone = false,
    this.noneLabel,
    this.changes,
    this.refresh,
    this.enabled = true,
    this.dense = false,
    this.semanticLabel,
    this.trailName = 'choices',
  });

  final String value;
  final Future<List<ForgeSettingChoice>> Function() load;
  final ValueChanged<String> onChanged;
  final bool allowNone;
  final ForgeText? noneLabel;
  final Stream<void>? changes;
  final Listenable? refresh;
  final bool enabled;
  final bool dense;
  final String? semanticLabel;
  final String trailName;

  @override
  State<ForgeDynamicChoiceField> createState() =>
      _ForgeDynamicChoiceFieldState();
}

class _ForgeDynamicChoiceFieldState extends State<ForgeDynamicChoiceField>
    with ForgeRefreshListener<ForgeDynamicChoiceField> {
  final ForgeLatestLoad _load = ForgeLatestLoad();
  final ForgeSubscriptionSlot _changes = ForgeSubscriptionSlot();
  List<ForgeSettingChoice>? _choices;

  @override
  Listenable? get refreshListenable => widget.refresh;

  @override
  void initState() {
    super.initState();
    followRefresh();
    _changes.listen<void>(widget.changes, (_) => _reload());
    _reload();
  }

  @override
  void didUpdateWidget(covariant ForgeDynamicChoiceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    followRefresh();
    if (!identical(widget.changes, oldWidget.changes)) {
      _changes.listen<void>(widget.changes, (_) => _reload());
    }
  }

  @override
  void onRefresh() => _reload();

  @override
  void dispose() {
    _changes.cancel();
    _load.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _choices = null);
    configurationUiTrail('${widget.trailName}: read');
    await _load.run(widget.load, (choices) {
      configurationUiTrail('${widget.trailName}: ${choices.length}');
      if (mounted) setState(() => _choices = choices);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final choices = _choices;
    if (choices == null) {
      return Semantics(
        label: widget.semanticLabel,
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: widget.dense,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: [
              const ForgeStatusLevelIcon(ForgeStatusLevel.busy, size: 14),
              const SizedBox(width: 8),
              Text(
                ForgeConfigurationLabels.resolveIn(
                  context,
                  ForgeConfigurationUiTexts.loading,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final seen = <String>{};
    final items = <DropdownMenuItem<String>>[
      if (widget.allowNone)
        DropdownMenuItem(
          value: '',
          child: Text(
            ForgeConfigurationLabels.resolveIn(
              context,
              widget.noneLabel ?? ForgeConfigurationUiTexts.none,
            ),
          ),
        ),
      for (final choice in choices)
        if (choice.value.isNotEmpty && seen.add(choice.value))
          DropdownMenuItem(
            value: choice.value,
            child: Text(
              ForgeConfigurationLabels.resolveIn(context, choice.label),
            ),
          ),
    ];
    final known =
        (widget.allowNone && widget.value.isEmpty) ||
        seen.contains(widget.value);
    if (!known && widget.value.isNotEmpty) {
      items.add(
        DropdownMenuItem(value: widget.value, child: Text(widget.value)),
      );
    }
    return Semantics(
      label: widget.semanticLabel,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${widget.trailName}=${widget.value}'),
        initialValue: known || widget.value.isNotEmpty ? widget.value : null,
        isExpanded: true,
        isDense: true,
        decoration: InputDecoration(
          isDense: widget.dense,
          border: const OutlineInputBorder(),
        ),
        items: items,
        onChanged: widget.enabled
            ? (chosen) {
                if (chosen != null) widget.onChanged(chosen);
              }
            : null,
      ),
    );
  }
}
