import 'package:flutter/material.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import '../configuration_ui_trail.dart';
import '../forge_configuration_labels.dart';
import '../forge_configuration_ui_texts.dart';
import '../forge_setting_editor_registry.dart';
import 'hook_widgets.dart';
import 'key_capture.dart';

/// A key binding table (`ForgeKeyBindingTableSetting`): the actions of its
/// catalogue (the `ForgeActionCatalogue` hook, read through the values
/// service, again when it reports changes or a refresh is asked for) with
/// their bindings in effect (`forgeKeyBindingRows`), grouped by the
/// catalogue's groups, filtered by a search box (label, id, scope,
/// binding).
///
/// Each row shows its action, its scope, whether it binds for every editor
/// (a wildcard row), its conflicts (`forgeKeyBindingConflicts`: bound alike
/// in overlapping scopes, or beginning another's chord) and its binding,
/// captured from the keyboard; its buttons bind the key for every editor
/// (`withWildcard`, for the setting's wildcard prefixes), remove the binding
/// (the deleted bindings companion, when the setting keeps one) and reset
/// it to the default. *Reset all* removes every override and deletion.
class ForgeKeyBindingTableEditor extends StatefulWidget {
  const ForgeKeyBindingTableEditor({
    super.key,
    required this.request,
    this.maxHeight = 420,
  });

  final ForgeSettingEditorRequest request;

  /// The most height the rows take (they scroll beyond it).
  final double maxHeight;

  @override
  State<ForgeKeyBindingTableEditor> createState() =>
      _ForgeKeyBindingTableEditorState();
}

class _ForgeKeyBindingTableEditorState extends State<ForgeKeyBindingTableEditor>
    with ForgeRefreshListener<ForgeKeyBindingTableEditor> {
  final TextEditingController _search = TextEditingController();
  final ForgeLatestLoad _load = ForgeLatestLoad();
  final ForgeSubscriptionSlot _changes = ForgeSubscriptionSlot();
  List<ForgeCatalogueAction>? _actions;

  ForgeKeyBindingTableSetting get _setting =>
      widget.request.setting as ForgeKeyBindingTableSetting;

  ForgeKeyBindingTable get _table =>
      widget.request.value as ForgeKeyBindingTable;

  @override
  Listenable? get refreshListenable => widget.request.refresh;

  @override
  void initState() {
    super.initState();
    followRefresh();
    _changes.listen<void>(
      widget.request.values?.hooks.catalogue(_setting.catalogue)?.changes,
      (_) => _reload(),
    );
    _reload();
  }

  @override
  void didUpdateWidget(covariant ForgeKeyBindingTableEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    followRefresh();
  }

  @override
  void onRefresh() => _reload();

  @override
  void dispose() {
    _changes.cancel();
    _load.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final values = widget.request.values;
    if (values == null) {
      setState(() => _actions = const []);
      return;
    }
    configurationUiTrail('catalogue ${_setting.catalogue}: read');
    await _load.run(() => values.catalogueOf(_setting), (actions) {
      configurationUiTrail(
        'catalogue ${_setting.catalogue}: ${actions.length} actions',
      );
      if (mounted) setState(() => _actions = actions);
    });
  }

  Set<String> get _deleted {
    final companion = _setting.deletedBindings;
    final values = widget.request.values;
    if (companion == null || values == null) return const {};
    return values.valueOf(companion).toSet();
  }

  Future<void> _writeDeleted(Set<String> deleted) async {
    final companion = _setting.deletedBindings;
    final values = widget.request.values;
    if (companion == null || values == null) return;
    configurationUiTrail('deleted bindings: ${deleted.length}');
    await values.set(companion, deleted.toList()..sort());
  }

  void _bind(ForgeKeyBindingRow row, List<ForgeKeyStroke> strokes) {
    final id = row.action.id;
    configurationUiTrail('bind $id');
    widget.request.onChanged(
      _table.withOverride(id, ForgeKeyChord(List.unmodifiable(strokes))),
    );
    if (row.deleted) _writeDeleted(_deleted..remove(id));
  }

  void _resetRow(ForgeKeyBindingRow row) {
    final id = row.action.id;
    configurationUiTrail('reset binding $id');
    if (row.overridden) widget.request.onChanged(_table.withoutOverride(id));
    if (row.deleted) _writeDeleted(_deleted..remove(id));
  }

  void _deleteRow(ForgeKeyBindingRow row) {
    final id = row.action.id;
    configurationUiTrail('remove binding $id');
    if (row.overridden) widget.request.onChanged(_table.withoutOverride(id));
    _writeDeleted(_deleted..add(id));
  }

  void _wildcardRow(ForgeKeyBindingRow row) {
    configurationUiTrail('bind ${row.action.id} for every editor');
    widget.request.onChanged(_table.withWildcard(row.action.id, row.binding));
  }

  Future<void> _resetAll() async {
    configurationUiTrail('reset all bindings of ${_setting.id}');
    final values = widget.request.values;
    if (values != null) {
      await values.reset(_setting);
    } else {
      widget.request.onChanged(_table.resetAll());
    }
  }

  bool _matches(ForgeKeyBindingRow row, String query, bool primaryIsMeta) {
    if (query.isEmpty) return true;
    final action = row.action;
    return [
      action.label,
      action.id,
      action.scope ?? '',
      action.group ?? '',
      forgeKeyChordLabel(row.binding, primaryIsMeta: primaryIsMeta),
    ].any((text) => text.toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.request;
    final setting = _setting;
    final actions = _actions;
    final primaryIsMeta = forgePrimaryIsMeta();
    final header = Row(
      children: [
        Expanded(
          child: TextField(
            key: ValueKey('forge.configuration.keyTable.search.${setting.id}'),
            controller: _search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.search,
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (setting.allowReset) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            key: ValueKey(
              'forge.configuration.keyTable.resetAll.${setting.id}',
            ),
            onPressed:
                r.enabled &&
                    (_table.overrides.isNotEmpty || _deleted.isNotEmpty)
                ? _resetAll
                : null,
            child: Text(
              ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.resetAll,
              ),
            ),
          ),
        ],
      ],
    );
    if (actions == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: 8),
          const ForgeStatusView(status: ForgeStatusInfo.busy),
        ],
      );
    }
    final rows = forgeKeyBindingRows(
      actions,
      _table,
      deleted: _deleted,
      chords: setting.chords,
    );
    final conflicts = forgeKeyBindingConflicts(
      rows,
      primaryIsMeta: primaryIsMeta,
    );
    final labels = {for (final row in rows) row.action.id: row.action.label};
    final conflictsOf = <String, List<String>>{};
    for (final conflict in conflicts) {
      for (final id in conflict.actionIds) {
        final others = [
          for (final other in conflict.actionIds)
            if (other != id) labels[other] ?? other,
        ];
        final text = ForgeConfigurationLabels.resolveIn(
          context,
          conflict.kind == ForgeKeyConflictKind.same
              ? ForgeConfigurationUiTexts.conflict(others.join(', '))
              : ForgeConfigurationUiTexts.prefixConflict(others.join(', ')),
        );
        (conflictsOf[id] ??= []).add(text);
      }
    }
    final query = _search.text.trim().toLowerCase();
    final shown = [
      for (final row in rows)
        if (_matches(row, query, primaryIsMeta)) row,
    ];
    final items = <Widget>[];
    String? group;
    for (final row in shown) {
      final rowGroup = row.action.group;
      if (rowGroup != null && rowGroup != group) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              rowGroup,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      }
      group = rowGroup;
      items.add(_row(context, row, conflictsOf[row.action.id]));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const SizedBox(height: 6),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.noMatches,
              ),
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: items,
            ),
          ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    ForgeKeyBindingRow row,
    List<String>? conflicts,
  ) {
    final theme = Theme.of(context);
    final r = widget.request;
    final setting = _setting;
    final action = row.action;
    final small = theme.textTheme.bodySmall;
    final error = theme.colorScheme.error;
    return Padding(
      key: ValueKey('forge.configuration.keyTable.row.${action.id}'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (conflicts != null) ...[
                      Tooltip(
                        message: conflicts.join('\n'),
                        child: Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: error,
                          semanticLabel: conflicts.join(' '),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        action.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: row.overridden || row.deleted
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    Text(action.id, style: small),
                    if (action.scope != null)
                      Text(
                        ForgeConfigurationLabels.resolveIn(
                          context,
                          ForgeConfigurationUiTexts.scope(action.scope!),
                        ),
                        style: small,
                      ),
                    if (row.wildcard)
                      Text(
                        ForgeConfigurationLabels.resolveIn(
                          context,
                          ForgeConfigurationUiTexts.allEditors,
                        ),
                        style: small?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                if (conflicts != null)
                  for (final text in conflicts)
                    Text(text, style: small?.copyWith(color: error)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: setting.chords ? 220 : 170,
            child: ForgeKeyCaptureField(
              key: ValueKey(
                'forge.configuration.keyTable.capture.${action.id}',
              ),
              strokes: row.binding.strokes,
              maxStrokes: setting.chords ? 4 : 1,
              enabled: r.enabled,
              dense: true,
              semanticLabel: action.label,
              highlight: conflicts == null ? null : error,
              trailName: 'binding ${action.id}',
              onCaptured: (strokes) => _bind(row, strokes),
            ),
          ),
          if (setting.offersWildcard(action.id) &&
              !row.wildcard &&
              !row.binding.isNone)
            IconButton(
              tooltip: ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.bindForAll,
              ),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.select_all, size: 18),
              onPressed: r.enabled ? () => _wildcardRow(row) : null,
            ),
          if (setting.deletedBindings != null &&
              !row.deleted &&
              !row.binding.isNone)
            IconButton(
              tooltip: ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.removeBinding,
              ),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: r.enabled ? () => _deleteRow(row) : null,
            ),
          IconButton(
            key: ValueKey('forge.configuration.keyTable.reset.${action.id}'),
            tooltip: ForgeConfigurationLabels.resolveIn(
              context,
              ForgeConfigurationUiTexts.resetBinding,
            ),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.restart_alt, size: 18),
            onPressed: r.enabled && (row.overridden || row.deleted)
                ? () => _resetRow(row)
                : null,
          ),
        ],
      ),
    );
  }
}
