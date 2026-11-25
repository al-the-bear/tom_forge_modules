import 'dart:async';

import 'package:flutter/foundation.dart' show Listenable;
import 'package:flutter/material.dart' show Icons;
import 'package:tom_forge_core/tom_forge_core.dart';
import 'package:tom_website_editor_core/tom_website_editor_core.dart';

import 'website_editor_controller.dart';

/// The website editor's settings (§9.2) as a configuration description: the
/// active website (which drives every other view), *Edit configuration* and
/// *Reload configuration* for `tom.website-editor.yaml`, and the state of the
/// last load with its issues.
///
/// The active website is the registry's selection, not a stored preference:
/// [WebsiteSelectionBinding] reads it from and writes it to the controller.
/// The hooks ([hooks]) list the registered websites, run the two actions and
/// answer the status, following the controller while shown.
abstract final class WebsiteEditorConfiguration {
  /// The description's id.
  static const descriptionId = 'tom_website_editor';

  /// The section's id.
  static const sectionId = 'websiteEditor';

  /// The choices provider of the registered websites.
  static const websitesProvider = 'tom_website_editor.websites';

  /// The action opening the configuration file in its editor.
  static const editAction = 'tom_website_editor.editConfiguration';

  /// The action reloading the configuration file.
  static const reloadAction = 'tom_website_editor.reloadConfiguration';

  /// The status of the last load.
  static const statusProvider = 'tom_website_editor.status';

  static ForgeText _text(String id, String fallback) =>
      ForgeText('tom_website_editor.config.$id', fallback);

  /// The active website.
  static final activeWebsite = ForgeChoiceSetting(
    id: 'activeWebsite',
    storage: const ForgeSettingStorage(
      WebsiteSelectionBinding.activeWebsiteKey,
      binding: WebsiteSelectionBinding.bindingId,
    ),
    label: _text('activeWebsite', 'Active website'),
    help: _text(
      'activeWebsite.help',
      'The website every other view of the website editor works on.',
    ),
    defaultValue: '',
    allowNone: true,
    noneLabel: _text('activeWebsite.none', 'No website loaded'),
    choicesProvider: websitesProvider,
  );

  /// *Edit configuration*: `tom.website-editor.yaml` in its editor.
  static final editConfiguration = ForgeActionSetting(
    id: 'editConfiguration',
    label: _text('editConfiguration', 'Configuration file'),
    action: editAction,
  );

  /// *Reload configuration*.
  static final reloadConfiguration = ForgeActionSetting(
    id: 'reloadConfiguration',
    label: _text('reloadConfiguration', 'Reload'),
    help: _text(
      'reloadConfiguration.help',
      'Reads the configuration file again; an invalid file keeps the last '
          'valid configuration.',
    ),
    action: reloadAction,
  );

  /// The state of the last load, with its issues.
  static final status = ForgeStatusSetting(
    id: 'status',
    label: _text('status', 'Configuration'),
    status: statusProvider,
  );

  /// The description.
  static final description = ForgeConfigurationDescription(
    id: descriptionId,
    title: _text('description', 'Website Editor'),
    sections: [
      ForgeSettingsSection(
        id: sectionId,
        title: _text('title', 'Website Editor'),
        icon: ForgeIconRef(Icons.public.codePoint),
        order: 120,
        settings: [
          activeWebsite,
          status,
          editConfiguration,
          reloadConfiguration,
        ],
      ),
    ],
  );

  /// The hooks over the controller [controllerOf] answers (null before the
  /// module is activated, and asked again each time, so a controller made
  /// later is found); [onEditConfiguration] opens the configuration file
  /// (null: *Edit configuration* is disabled).
  static ForgeSettingHooks hooks(
    WebsiteEditorController? Function() controllerOf, {
    void Function()? onEditConfiguration,
  }) => ForgeSettingHooks(
    choices: [
      ForgeCallbackChoicesProvider(
        id: websitesProvider,
        onChoices: (_) async => [
          for (final website
              in controllerOf()?.websites ?? const <WebsiteEntry>[])
            ForgeSettingChoice(
              website.id,
              ForgeText.literal(website.label ?? website.id),
            ),
        ],
        changes: _changesOf(controllerOf),
      ),
    ],
    actions: [
      ForgeCallbackAction(
        id: editAction,
        label: _text('editConfiguration.button', 'Edit configuration'),
        icon: ForgeIconRef(Icons.edit_note.codePoint),
        enabledWhen: (_) =>
            onEditConfiguration != null && controllerOf() != null,
        onRun: (_) async {
          onEditConfiguration?.call();
          return const ForgeActionResult.success();
        },
      ),
      ForgeCallbackAction(
        id: reloadAction,
        label: _text('reloadConfiguration.button', 'Reload configuration'),
        icon: ForgeIconRef(Icons.refresh.codePoint),
        enabledWhen: (_) {
          final controller = controllerOf();
          return controller != null && !controller.isLoading;
        },
        onRun: (_) async {
          final controller = controllerOf();
          if (controller == null) {
            return ForgeActionResult.failure(_notLoaded);
          }
          final applied = await controller.reload();
          return applied
              ? const ForgeActionResult.success(refresh: true)
              : ForgeActionResult.failure(
                  _text(
                    'reloadConfiguration.failed',
                    'The configuration was not applied; see its issues.',
                  ),
                  refresh: true,
                );
        },
      ),
    ],
    statuses: [
      ForgeCallbackStatusProvider(
        id: statusProvider,
        onCurrent: (_) async => statusOf(controllerOf()),
        onWatch: (_) =>
            _changesOf(controllerOf).map((_) => statusOf(controllerOf())),
      ),
    ],
  );

  static final _notLoaded = _text(
    'status.notLoaded',
    'No valid configuration loaded.',
  );

  /// The status of [controller]: loading, not loaded, or the websites
  /// registered; the issues of the last load as items.
  static ForgeStatusInfo statusOf(WebsiteEditorController? controller) {
    if (controller == null) return ForgeStatusInfo.unknown;
    final items = [
      for (final issue in controller.issues)
        ForgeStatusItem(
          level: issue.severity == ConfigSeverity.error
              ? ForgeStatusLevel.error
              : ForgeStatusLevel.warning,
          text: '${issue.path}: ${issue.message}',
        ),
    ];
    if (controller.isLoading) {
      return ForgeStatusInfo(
        level: ForgeStatusLevel.busy,
        message: _text('status.loading', 'Loading the configuration …'),
        items: items,
      );
    }
    if (!controller.isLoaded) {
      return ForgeStatusInfo(
        level: ForgeStatusLevel.error,
        message: _notLoaded,
        items: items,
      );
    }
    final count = controller.websites.length;
    return ForgeStatusInfo(
      level: items.any((i) => i.level == ForgeStatusLevel.error)
          ? ForgeStatusLevel.warning
          : ForgeStatusLevel.ok,
      message: _text(
        'status.loaded',
        '{count} website(s) registered',
      ).withParams({'count': count}),
      items: items,
    );
  }

  /// The notifications of the controller [controllerOf] answers when the
  /// stream is listened to (none without one).
  static Stream<void> _changesOf(
    WebsiteEditorController? Function() controllerOf,
  ) => listenableChanges(controllerOf);
}

/// Every notification of the listenable [listenableOf] answers when the
/// stream is listened to, as a stream event; nothing while it answers null.
Stream<void> listenableChanges(Listenable? Function() listenableOf) {
  late final StreamController<void> changes;
  Listenable? listened;
  void notify() => changes.add(null);
  changes = StreamController<void>.broadcast(
    onListen: () => (listened = listenableOf())?.addListener(notify),
    onCancel: () {
      listened?.removeListener(notify);
      listened = null;
    },
  );
  return changes.stream;
}

/// The active website as a storage binding: the document [activeWebsiteKey]
/// is the controller's selection (`""` while nothing is loaded); a write
/// selects a registered website. Reported again when the controller changes
/// it (a reload that drops the active website).
class WebsiteSelectionBinding extends ForgeSettingBinding {
  WebsiteSelectionBinding(this.controllerOf);

  /// The binding's id.
  static const bindingId = 'tom_website_editor.selection';

  /// The one document.
  static const activeWebsiteKey = 'activeWebsite';

  /// The controller (null before the module is activated).
  final WebsiteEditorController? Function() controllerOf;

  @override
  String get id => bindingId;

  /// The selection last read or written: a change from it is reported.
  String _reported = '';

  @override
  Future<Object?> read(String key) async {
    if (key != activeWebsiteKey) return null;
    return _reported = controllerOf()?.activeWebsiteId ?? '';
  }

  @override
  Future<void> write(String key, Object? document) async {
    final controller = controllerOf();
    if (key != activeWebsiteKey || controller == null) return;
    if (document is! String) return;
    if (!controller.websites.any((w) => w.id == document)) return;
    if (controller.activeWebsiteId != document) {
      controller.selectWebsite(document);
    }
    _reported = controller.activeWebsiteId ?? '';
  }

  @override
  Stream<String> watch() => listenableChanges(controllerOf)
      .where((_) => (controllerOf()?.activeWebsiteId ?? '') != _reported)
      .map((_) => activeWebsiteKey);
}
