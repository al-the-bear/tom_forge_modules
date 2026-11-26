import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart'
    show
        TomFunctionObserver,
        TomObservable,
        TomObservableObservation,
        TomTextResourceProvider;
import 'package:tom_flutter_ui/tom_flutter_ui.dart' show TomFormStyleScope;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_forge_kit/tom_forge_kit.dart'
    show ForgeConfigurationValues, ForgeTextScope, ForgeTextScopeWidget;
import 'package:tom_forge_shared_ui/tom_forge_shared_ui.dart'
    show ForgeShellTheme;

import 'configuration_ui_trail.dart';
import 'editors/hook_widgets.dart';
import 'forge_configuration_icons.dart';
import 'forge_configuration_labels.dart';
import 'forge_configuration_tile_style.dart';
import 'forge_configuration_ui_texts.dart';
import 'forge_setting_editor_registry.dart';

/// What the tiles below it share: the values service, the editors, the tile
/// style and the application's path picker. A tile takes what it is not
/// given from the nearest scope.
class ForgeConfigurationScope extends InheritedWidget {
  const ForgeConfigurationScope({
    super.key,
    required this.values,
    required super.child,
    this.registry,
    this.style = const ForgeConfigurationTileStyle(),
    this.pickPath,
    this.iconResolver,
    this.buildHelpPanel,
  });

  /// The values the tiles show and write.
  final ForgeConfigurationValues values;

  /// The editors (default: the standard ones).
  final ForgeSettingEditorRegistry? registry;

  /// The look of every tile.
  final ForgeConfigurationTileStyle style;

  /// The application's path picker, or null.
  final ForgePathPicker? pickPath;

  /// Makes a section's icon (default: [forgeMaterialIconFor]).
  final ForgeConfigurationIconResolver? iconResolver;

  /// The application's help panels (a tool path's `helpPanel`), or null.
  final ForgeHelpPanelBuilder? buildHelpPanel;

  /// The nearest scope, or null.
  static ForgeConfigurationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ForgeConfigurationScope>();

  @override
  bool updateShouldNotify(ForgeConfigurationScope oldWidget) =>
      values != oldWidget.values ||
      registry != oldWidget.registry ||
      style != oldWidget.style ||
      pickPath != oldWidget.pickPath ||
      iconResolver != oldWidget.iconResolver ||
      buildHelpPanel != oldWidget.buildHelpPanel;
}

/// One section of a configuration description as a tile: its title (with
/// its icon and help), then each visible entry — a setting with its label,
/// its editor (the registry's for its kind), the buttons of its own actions
/// (`ForgeSetting.actions`), a reset-to-default button (for a setting that
/// keeps a value), its help on request and the reason a value was refused;
/// a group (`ForgeSettingsGroup`) as a header that folds the settings below
/// it.
///
/// Every tile looks the same: the [style] decides spacing and density, the
/// theme the colours (`ForgeShellTheme` when installed, else the colour
/// scheme). Where tiles go is the application's decision — a side panel, a
/// page of tiles, a layout of its own.
///
/// Values are read from and written through [values] (the kit's state-store
/// port); labels are resolved through Tom Core's text resources and follow
/// them when they change.
class ForgeConfigurationTile extends StatefulWidget {
  const ForgeConfigurationTile({
    super.key,
    required this.section,
    this.values,
    this.registry,
    this.style,
    this.pickPath,
    this.iconResolver,
    this.buildHelpPanel,
    this.descriptionId,
    this.textScope,
  });

  /// The tile of [ref]'s section.
  ForgeConfigurationTile.of(
    ForgeConfigurationSectionRef ref, {
    Key? key,
    ForgeConfigurationValues? values,
    ForgeSettingEditorRegistry? registry,
    ForgeConfigurationTileStyle? style,
    ForgePathPicker? pickPath,
    ForgeConfigurationIconResolver? iconResolver,
    ForgeHelpPanelBuilder? buildHelpPanel,
    ForgeTextScope? textScope,
  }) : this(
         key: key ?? ValueKey('forge.configuration.tile.${ref.id}'),
         section: ref.section,
         values: values,
         registry: registry,
         style: style,
         pickPath: pickPath,
         iconResolver: iconResolver,
         buildHelpPanel: buildHelpPanel,
         descriptionId: ref.description.id,
         textScope: textScope,
       );

  /// The section shown.
  final ForgeSettingsSection section;

  /// The id of the description the section is part of: its texts are read
  /// under the values' text scope of it
  /// (`ForgeConfigurationValues.textScopeOf`), the scope of the module that
  /// contributed it.
  final String? descriptionId;

  /// The scope the section's texts are read under, in place of the one the
  /// values name for [descriptionId]; null: that one, else the root.
  final ForgeTextScope? textScope;

  /// The values (default: the scope's).
  final ForgeConfigurationValues? values;

  /// The editors (default: the scope's, else the standard ones).
  final ForgeSettingEditorRegistry? registry;

  /// The look (default: the scope's).
  final ForgeConfigurationTileStyle? style;

  /// The path picker (default: the scope's).
  final ForgePathPicker? pickPath;

  /// The icon resolver (default: the scope's, else [forgeMaterialIconFor]).
  final ForgeConfigurationIconResolver? iconResolver;

  /// The help panels (default: the scope's).
  final ForgeHelpPanelBuilder? buildHelpPanel;

  @override
  State<ForgeConfigurationTile> createState() => _ForgeConfigurationTileState();
}

/// The tiles alive, for the trail's heartbeat (one for all of them).
int _liveTiles = 0;
Timer? _heartbeat;
FlutterExceptionHandler? _previousOnError;

final ForgeSettingEditorRegistry _standardRegistry =
    ForgeSettingEditorRegistry.standard();

class _ForgeConfigurationTileState extends State<ForgeConfigurationTile> {
  ForgeConfigurationValues? _values;
  late final TomFunctionObserver<TomObservable> _resourcesObserver;
  final Map<String, ForgeText?> _errors = {};
  final Map<String, int> _generations = {};
  final Set<String> _helpShown = {};
  final Map<String, bool> _folded = {};
  final Map<String, ValueNotifier<int>> _refreshes = {};
  bool _sectionHelpShown = false;
  bool _traced = false;

  @override
  void initState() {
    super.initState();
    ForgeConfigurationLabels.ensureResources();
    _resourcesObserver =
        TomTextResourceProvider.appResourcesRevision >> (_) => _rebuild();
    if (kConfigurationUiDebug) {
      _traced = true;
      if (_liveTiles++ == 0) {
        _previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          configurationUiTrail('FlutterError: ${details.exceptionAsString()}');
          _previousOnError?.call(details);
        };
        _heartbeat = Timer.periodic(
          const Duration(seconds: 1),
          (_) => configurationUiTrail('heartbeat'),
        );
      }
      configurationUiTrail('tile ${widget.section.id} mounted');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindValues();
  }

  @override
  void didUpdateWidget(covariant ForgeConfigurationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindValues();
  }

  void _bindValues() {
    final values =
        widget.values ?? ForgeConfigurationScope.maybeOf(context)?.values;
    if (identical(values, _values)) return;
    _values?.removeListener(_rebuild);
    _values = values;
    _values?.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final notifier in _refreshes.values) {
      notifier.dispose();
    }
    _values?.removeListener(_rebuild);
    TomTextResourceProvider.appResourcesRevision.removeObserver(
      _resourcesObserver,
    );
    if (_traced) {
      configurationUiTrail('tile ${widget.section.id} disposed');
      if (--_liveTiles == 0) {
        _heartbeat?.cancel();
        _heartbeat = null;
        FlutterError.onError = _previousOnError;
      }
    }
    super.dispose();
  }

  /// Validates [value] at once (so the message always belongs to the last
  /// value the user made, however the writes interleave) and writes it
  /// through the values service when it is valid.
  Future<void> _commit(ForgeSetting<Object> setting, Object? value) async {
    final values = _values;
    if (values == null) return;
    final location = forgeSettingEntryKey(setting);
    try {
      final problem = values.validate(setting, value);
      configurationUiTrail('commit $location: ${problem ?? 'valid'}');
      if (mounted) setState(() => _errors[location] = problem);
      if (problem == null) await values.set(setting, value);
    } catch (error, stack) {
      configurationUiTrail('commit $location failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'tom_configuration_ui',
          context: ErrorDescription('while writing $location'),
        ),
      );
    }
  }

  /// Removes the stored value (the default is in effect) and builds the
  /// editor anew, so it drops a refused text it still shows.
  Future<void> _reset(ForgeSetting<Object> setting) async {
    final values = _values;
    if (values == null) return;
    final location = forgeSettingEntryKey(setting);
    configurationUiTrail('reset $location');
    try {
      final done = values.reset(setting);
      setState(() {
        _errors.remove(location);
        _generations[location] = (_generations[location] ?? 0) + 1;
      });
      await done;
    } catch (error, stack) {
      configurationUiTrail('reset $location failed: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'tom_configuration_ui',
          context: ErrorDescription('while resetting $location'),
        ),
      );
    }
  }

  /// The scope the section's texts are read under.
  ForgeTextScope get _textScope {
    final given = widget.textScope;
    if (given != null) return given;
    final id = widget.descriptionId;
    final values = _values;
    return id == null || values == null
        ? ForgeTextScope.root
        : values.textScopeOf(id);
  }

  // The tile's own widgets resolve their texts under the section's text
  // scope too, so the tile is built below it.
  @override
  Widget build(BuildContext context) => ForgeTextScopeWidget(
    textScope: _textScope,
    child: Builder(builder: _buildTile),
  );

  Widget _buildTile(BuildContext context) {
    final scope = ForgeConfigurationScope.maybeOf(context);
    final style =
        widget.style ?? scope?.style ?? const ForgeConfigurationTileStyle();
    final registry = widget.registry ?? scope?.registry ?? _standardRegistry;
    final pickPath = widget.pickPath ?? scope?.pickPath;
    final iconResolver =
        widget.iconResolver ?? scope?.iconResolver ?? forgeMaterialIconFor;
    final buildHelpPanel = widget.buildHelpPanel ?? scope?.buildHelpPanel;
    final values = _values;
    final theme = Theme.of(context);
    final shell = theme.extension<ForgeShellTheme>();
    final surface = shell?.panelSurface ?? theme.colorScheme.surface;
    final border = shell?.panelDivider ?? theme.colorScheme.outlineVariant;
    final section = widget.section;

    final children = <Widget>[];
    if (style.showHeader) {
      children.add(_header(context, style, iconResolver));
      if (_sectionHelpShown && section.help != null) {
        children.add(
          _helpText(
            context,
            ForgeConfigurationLabels.resolveIn(context, section.help!),
          ),
        );
      }
      children.add(SizedBox(height: style.headerSpacing));
    }
    if (values == null) {
      children.add(const SizedBox.shrink());
    } else {
      var first = true;
      void addSetting(ForgeSetting<Object> setting) {
        if (!values.isVisible(setting)) return;
        if (!first) children.add(SizedBox(height: style.spacing));
        first = false;
        children.add(
          _entry(
            context,
            setting,
            values,
            registry,
            style,
            pickPath,
            buildHelpPanel,
          ),
        );
      }

      for (final entry in section.entries) {
        if (entry is ForgeSetting<Object>) {
          addSetting(entry);
        } else if (entry is ForgeSettingsGroup) {
          if (!entry.settings.any(values.isVisible)) continue;
          if (!first) children.add(SizedBox(height: style.spacing));
          first = false;
          children.add(_groupHeader(context, entry));
          if (_folded[entry.id] ?? entry.collapsed) continue;
          for (final setting in entry.settings) {
            addSetting(setting);
          }
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: style.borderWidth > 0
            ? Border.all(color: border, width: style.borderWidth)
            : null,
      ),
      padding: style.padding,
      child: TomFormStyleScope(
        style: style.formStyle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    ForgeConfigurationTileStyle style,
    ForgeConfigurationIconResolver iconResolver,
  ) {
    final theme = Theme.of(context);
    final section = widget.section;
    final ref = section.icon;
    final icon = style.showIcons && ref != null ? iconResolver(ref) : null;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            ForgeConfigurationLabels.resolveIn(context, section.title),
            style: theme.textTheme.titleSmall,
          ),
        ),
        if (section.help != null)
          _iconButton(
            icon: Icons.help_outline,
            tooltip: ForgeConfigurationLabels.resolveIn(
              context,
              ForgeConfigurationUiTexts.help,
            ),
            onPressed: () =>
                setState(() => _sectionHelpShown = !_sectionHelpShown),
          ),
      ],
    );
  }

  /// A group's header: its title, a fold toggle and its help.
  Widget _groupHeader(BuildContext context, ForgeSettingsGroup group) {
    final theme = Theme.of(context);
    final folded = _folded[group.id] ?? group.collapsed;
    final helpKey = 'group:${group.id}';
    return KeyedSubtree(
      key: ValueKey('forge.configuration.group.${group.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _folded[group.id] = !folded),
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Tooltip(
                    message: ForgeConfigurationLabels.resolveIn(
                      context,
                      folded
                          ? ForgeConfigurationUiTexts.showGroup
                          : ForgeConfigurationUiTexts.hideGroup,
                    ),
                    child: Icon(
                      folded ? Icons.chevron_right : Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ForgeConfigurationLabels.resolveIn(context, group.title),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (group.help != null)
                    _iconButton(
                      icon: Icons.help_outline,
                      tooltip: ForgeConfigurationLabels.resolveIn(
                        context,
                        ForgeConfigurationUiTexts.help,
                      ),
                      onPressed: () => setState(() {
                        if (!_helpShown.remove(helpKey)) {
                          _helpShown.add(helpKey);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
          if (_helpShown.contains(helpKey) && group.help != null)
            _helpText(
              context,
              ForgeConfigurationLabels.resolveIn(context, group.help!),
            ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    ForgeSetting<Object> setting,
    ForgeConfigurationValues values,
    ForgeSettingEditorRegistry registry,
    ForgeConfigurationTileStyle style,
    ForgePathPicker? pickPath,
    ForgeHelpPanelBuilder? buildHelpPanel,
  ) {
    final theme = Theme.of(context);
    final location = forgeSettingEntryKey(setting);
    final refresh = _refreshes.putIfAbsent(location, () => ValueNotifier(0));
    final label = ForgeConfigurationLabels.resolveIn(context, setting.label);
    final error = _errors[location] ?? _storedProblem(values, setting);
    final enabled = values.isEnabled(setting);
    final editor = registry.editorFor(setting.kind);
    final request = ForgeSettingEditorRequest(
      setting: setting,
      value: values.valueOf<Object>(setting),
      onChanged: (value) => _commit(setting, value),
      label: label,
      fieldId:
          'forgeConfiguration_${location.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}',
      style: style,
      enabled: enabled,
      errorText: ForgeConfigurationLabels.resolveOrNullIn(context, error),
      pickPath: pickPath,
      values: values,
      refresh: refresh,
      requestRefresh: () {
        configurationUiTrail('refresh $location');
        refresh.value++;
      },
      buildHelpPanel: buildHelpPanel,
    );
    final Widget editorWidget = KeyedSubtree(
      key: ValueKey('$location#${_generations[location] ?? 0}'),
      child: editor == null
          ? Text(
              ForgeConfigurationLabels.resolveIn(
                context,
                ForgeConfigurationUiTexts.unknownKind(setting.kind),
              ),
              style: TextStyle(color: theme.colorScheme.error),
            )
          : Builder(builder: (context) => editor.builder(context, request)),
    );
    final inline = editor?.inline ?? false;
    final labelText = Text(
      label,
      style: enabled
          ? theme.textTheme.bodyMedium
          : theme.textTheme.bodyMedium?.copyWith(color: theme.disabledColor),
    );
    final Widget? inlineEditor = !inline
        ? null
        : editor?.width == null
        ? editorWidget
        : SizedBox(width: editor!.width, child: editorWidget);
    final buttons = <Widget>[
      if (setting.help != null)
        _iconButton(
          icon: Icons.help_outline,
          tooltip: ForgeConfigurationLabels.resolveIn(
            context,
            ForgeConfigurationUiTexts.help,
          ),
          onPressed: () => setState(() {
            if (!_helpShown.remove(location)) _helpShown.add(location);
          }),
        ),
      if (setting.storesValue)
        _iconButton(
          key: ValueKey('forge.configuration.reset.$location'),
          icon: Icons.restart_alt,
          tooltip: ForgeConfigurationLabels.resolveIn(
            context,
            ForgeConfigurationUiTexts.reset,
          ),
          onPressed: enabled && (values.isStored(setting) || error != null)
              ? () => _reset(setting)
              : null,
        ),
    ];
    // Narrower than the style's stacking width, an inline editor and the
    // buttons go on a line of their own below the label, so every control
    // stays inside the tile.
    final labelRow = LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            inlineEditor != null &&
            constraints.maxWidth < style.stackedBelowWidth;
        if (!stacked) {
          return Row(
            children: [
              Expanded(child: labelText),
              ?inlineEditor,
              ...buttons,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            labelText,
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: inlineEditor,
                  ),
                ),
                ...buttons,
              ],
            ),
          ],
        );
      },
    );
    return KeyedSubtree(
      key: ValueKey('forge.configuration.setting.$location'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          labelRow,
          if (!inline) ...[SizedBox(height: style.dense ? 2 : 4), editorWidget],
          if (setting.actions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: style.dense ? 4 : 6),
              child: ForgeSettingActionsBar(request: request),
            ),
          if (_helpShown.contains(location) && setting.help != null)
            _helpText(
              context,
              ForgeConfigurationLabels.resolveIn(context, setting.help!),
            ),
          if (request.errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                request.errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Why the stored value of [setting] was refused (the default is in
  /// effect), or null.
  ForgeText? _storedProblem(
    ForgeConfigurationValues values,
    ForgeSetting<Object> setting,
  ) {
    for (final problem in values.problems) {
      if (problem.setting.storage == setting.storage) return problem.message;
    }
    return null;
  }

  Widget _helpText(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );

  Widget _iconButton({
    Key? key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => IconButton(
    key: key,
    icon: Icon(icon, size: 18),
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
  );
}

/// The tiles of every section of [values]' descriptions (or of
/// [descriptions] when given), ordered as [forgeOrderedSections] orders
/// them, for an application to arrange as it likes (a `Wrap`, a grid, a
/// side panel's list).
List<Widget> forgeConfigurationTiles(
  ForgeConfigurationValues values, {
  Iterable<ForgeConfigurationDescription>? descriptions,
  ForgeSettingEditorRegistry? registry,
  ForgeConfigurationTileStyle? style,
  ForgePathPicker? pickPath,
  ForgeConfigurationIconResolver? iconResolver,
  ForgeHelpPanelBuilder? buildHelpPanel,
}) => [
  for (final ref in forgeOrderedSections(descriptions ?? values.descriptions))
    ForgeConfigurationTile.of(
      ref,
      values: values,
      registry: registry,
      style: style,
      pickPath: pickPath,
      iconResolver: iconResolver,
      buildHelpPanel: buildHelpPanel,
    ),
];

/// The key a tile names a setting's entry by: its storage location, or for
/// a setting that keeps no value (an action, a status line) `#<id>`.
String forgeSettingEntryKey(ForgeSetting<Object> setting) =>
    setting.storesValue ? setting.storage.location : '#${setting.id}';
