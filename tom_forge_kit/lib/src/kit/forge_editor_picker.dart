import 'package:flutter/foundation.dart';

import '../components/forge_editor_choice.dart';
import '../components/forge_kit_editor_type.dart';
import '../files/forge_content_item.dart';
import '../module/forge_kit_module.dart';

/// Where the default editors are kept: an editor choice id per file
/// extension (`.md` → `md`) and per content type (`text/markdown` → `md`).
///
/// [ForgeKitPreferences] is one (`forge.files.typeDefaults` and
/// `forge.files.contentTypeDefaults`, JSON maps); it notifies when a default
/// changes.
abstract interface class ForgeEditorDefaults implements Listenable {
  /// The default editor ids by file extension, lower case with the dot.
  Map<String, String> get fileTypeDefaultEditors;

  /// Sets the default editor id for a file extension.
  void setFileTypeDefaultEditor(String extension, String editorTypeId);

  /// Clears the default editor id for a file extension.
  void clearFileTypeDefaultEditor(String extension);

  /// The default editor ids by content type, lower case without parameters.
  Map<String, String> get contentTypeDefaultEditors;

  /// Sets the default editor id for a content type.
  void setContentTypeDefaultEditor(String contentType, String editorTypeId);

  /// Clears the default editor id for a content type.
  void clearContentTypeDefaultEditor(String contentType);
}

/// What a default is kept by.
enum ForgeEditorDefaultScope {
  /// By the item's content type (`text/markdown`).
  contentType,

  /// By the item's file extension (`.md`).
  extension,
}

/// The editors one content item can be opened in, as [ForgeEditorPicker]
/// answers them: the choices in the order offered, the default among them,
/// and whether the only choice is the application's fallback.
@immutable
class ForgeEditorChoices {
  const ForgeEditorChoices({
    required this.item,
    required this.choices,
    this.defaultChoice,
    this.defaultScope,
    this.storedDefaultId,
    this.isFallback = false,
  });

  /// The item the choices are for.
  final ForgeContentItem item;

  /// Every editor offered, each id once, in the order gathered.
  final List<ForgeKitEditorChoice> choices;

  /// The default among [choices], or null when no default is set or the one
  /// set is not offered.
  final ForgeKitEditorChoice? defaultChoice;

  /// What the default set for the item is kept by; null when none is set.
  final ForgeEditorDefaultScope? defaultScope;

  /// The editor id the default set for the item names (even when it is not
  /// among [choices]); null when none is set.
  final String? storedDefaultId;

  /// Whether no module and no editor type takes the item and [choices] is
  /// the application's fallback alone ([ForgeEditorPicker.fallback]).
  final bool isFallback;

  /// Whether nothing can open the item.
  bool get isEmpty => choices.isEmpty;

  /// Whether [choice] is the default (the checkmark of **Open With**).
  bool isDefault(ForgeKitEditorChoice choice) =>
      defaultChoice != null && defaultChoice!.id == choice.id;

  /// The editor the item opens in without asking: the default, else the
  /// only choice; null when there are several and none is the default.
  ForgeKitEditorChoice? get preferred =>
      defaultChoice ?? (choices.length == 1 ? choices.single : null);
}

/// The editor picker: for a content item (a file, or content of a type),
/// the editors every module and every editor type offers, the default kept
/// per content type and per file extension, opening once in a choice and
/// setting the default — the model behind **Open With**, with no widget,
/// panel, tab or window in it. An application draws it as it decides (the
/// panel shell: an **Open With ▸** submenu with the default's checkmark).
///
/// **Gathering.** [choicesFor] asks every module
/// ([ForgeKitModule.editorChoicesForContent]: by URI and by content type),
/// then takes every editor type that opens the item
/// ([ForgeKitEditorType.opensByDefault], [ForgeKitEditorType.opensContentType])
/// as a choice ([choiceForType]), then the host's own ([moreChoices]); each
/// id once, the first kept. When nothing takes the item, the application's
/// [fallback] is the one choice (Webwork: the attachment view, *Open
/// externally* and *Save as*).
///
/// **Defaults.** Kept in [defaults]: by content type when the item has one
/// and a default is set for it, else by extension. [setDefault] and
/// [clearDefault] write by content type when the item has one, else by
/// extension (or the scope given). The extension keys are the file-type
/// defaults applications kept before (`forge.files.typeDefaults`).
class ForgeEditorPicker {
  ForgeEditorPicker({
    required Iterable<ForgeKitModule> Function() modules,
    required this.defaults,
    List<ForgeKitEditorType> Function()? editorTypes,
    ForgeKitEditorChoice Function(ForgeKitEditorType type)? choiceForType,
    this.fallback,
  }) : _modules = modules,
       _editorTypes = editorTypes,
       _choiceForType = choiceForType;

  final Iterable<ForgeKitModule> Function() _modules;
  final List<ForgeKitEditorType> Function()? _editorTypes;
  final ForgeKitEditorChoice Function(ForgeKitEditorType type)? _choiceForType;

  /// Where the defaults are kept.
  final ForgeEditorDefaults defaults;

  /// The editor offered when nothing else takes an item, as the application
  /// supplies it; null: such an item has no choice.
  ForgeKitEditorChoice? fallback;

  /// Notifies when a default changes.
  Listenable get defaultsChanged => defaults;

  /// The modules asked for choices.
  @protected
  Iterable<ForgeKitModule> get modules => _modules();

  /// The editor types offered as choices.
  @protected
  List<ForgeKitEditorType> get editorTypes => _editorTypes?.call() ?? const [];

  /// [type] as a choice; null when the host cannot open editors of a type
  /// (then types are not offered).
  @protected
  ForgeKitEditorChoice? choiceForType(ForgeKitEditorType type) =>
      _choiceForType?.call(type);

  /// A module's [choice] as the host offers it (the panel shell: as its own
  /// choice type); the choice itself by default.
  @protected
  ForgeKitEditorChoice adaptChoice(ForgeKitEditorChoice choice) => choice;

  /// Choices of the host's own beyond the modules' and the editor types'
  /// (the panel shell: the editors already open on the file); none by
  /// default.
  @protected
  Future<List<ForgeKitEditorChoice>> moreChoices(ForgeContentItem item) async =>
      const [];

  /// The editors [item] can be opened in, with the default marked.
  Future<ForgeEditorChoices> choicesFor(ForgeContentItem item) async {
    final byId = <String, ForgeKitEditorChoice>{};
    void add(ForgeKitEditorChoice choice) =>
        byId.putIfAbsent(choice.id, () => choice);

    for (final module in modules.toList(growable: false)) {
      for (final choice in module.editorChoicesForContent(item)) {
        add(adaptChoice(choice));
      }
    }
    for (final type in editorTypes) {
      if (!type.opensByDefault(item.uri) &&
          !type.opensContentType(item.contentType)) {
        continue;
      }
      final choice = choiceForType(type);
      if (choice != null) add(choice);
    }
    for (final choice in await moreChoices(item)) {
      add(choice);
    }

    var choices = byId.values.toList(growable: false);
    var isFallback = false;
    final fallbackChoice = fallback;
    if (choices.isEmpty && fallbackChoice != null) {
      choices = [fallbackChoice];
      isFallback = true;
    }
    final (storedId, scope) = defaultIdFor(item);
    final defaultChoice = storedId == null
        ? null
        : choices.where((c) => c.id == storedId).firstOrNull;
    return ForgeEditorChoices(
      item: item,
      choices: List.unmodifiable(choices),
      defaultChoice: defaultChoice,
      defaultScope: scope,
      storedDefaultId: storedId,
      isFallback: isFallback,
    );
  }

  /// The default editor id set for [item] and what it is kept by: by its
  /// content type when one is set for it, else by its extension; `(null,
  /// null)` when none is.
  (String?, ForgeEditorDefaultScope?) defaultIdFor(ForgeContentItem item) {
    final type = item.contentType;
    if (type != null) {
      final id = defaults.contentTypeDefaultEditors[type];
      if (id != null) return (id, ForgeEditorDefaultScope.contentType);
    }
    final extension = item.extension;
    if (extension.isNotEmpty) {
      final id = defaults.fileTypeDefaultEditors[extension];
      if (id != null) return (id, ForgeEditorDefaultScope.extension);
    }
    return (null, null);
  }

  /// What a default for [item] is kept by when none is named: its content
  /// type when it has one, else its extension; null when it has neither.
  ForgeEditorDefaultScope? scopeFor(ForgeContentItem item) {
    if (item.contentType != null) return ForgeEditorDefaultScope.contentType;
    if (item.extension.isNotEmpty) return ForgeEditorDefaultScope.extension;
    return null;
  }

  /// Opens [item] in [choice] once, leaving the default as it is.
  void openOnce(ForgeContentItem item, ForgeKitEditorChoice choice) {
    choice.open(item.uri);
  }

  /// Opens [item] in its default editor, else its only choice, else the
  /// first one; answers the choice it opened in, or null when nothing can
  /// open it.
  Future<ForgeKitEditorChoice?> open(ForgeContentItem item) async {
    final answer = await choicesFor(item);
    final choice = answer.preferred ?? answer.choices.firstOrNull;
    if (choice != null) openOnce(item, choice);
    return choice;
  }

  /// Makes [choice] the default for [item], kept by [scope] (default:
  /// [scopeFor]); answers false when the item has no key of that scope.
  bool setDefault(
    ForgeContentItem item,
    ForgeKitEditorChoice choice, {
    ForgeEditorDefaultScope? scope,
  }) => setDefaultId(item, choice.id, scope: scope);

  /// [setDefault] by editor id.
  bool setDefaultId(
    ForgeContentItem item,
    String editorId, {
    ForgeEditorDefaultScope? scope,
  }) {
    switch (scope ?? scopeFor(item)) {
      case ForgeEditorDefaultScope.contentType:
        final type = item.contentType;
        if (type == null) return false;
        defaults.setContentTypeDefaultEditor(type, editorId);
        return true;
      case ForgeEditorDefaultScope.extension:
        final extension = item.extension;
        if (extension.isEmpty) return false;
        defaults.setFileTypeDefaultEditor(extension, editorId);
        return true;
      case null:
        return false;
    }
  }

  /// Clears the default for [item] kept by [scope] (default: [scopeFor]);
  /// answers false when the item has no key of that scope. A default kept
  /// by the other scope stays (clearing a content type's default leaves its
  /// extension's in force).
  bool clearDefault(ForgeContentItem item, {ForgeEditorDefaultScope? scope}) {
    switch (scope ?? scopeFor(item)) {
      case ForgeEditorDefaultScope.contentType:
        final type = item.contentType;
        if (type == null) return false;
        defaults.clearContentTypeDefaultEditor(type);
        return true;
      case ForgeEditorDefaultScope.extension:
        final extension = item.extension;
        if (extension.isEmpty) return false;
        defaults.clearFileTypeDefaultEditor(extension);
        return true;
      case null:
        return false;
    }
  }
}
