import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart';

import 'configuration_values_trail.dart';
import 'forge_coalesced_state_writer.dart';
import 'forge_state_store.dart';

/// A stored value a setting refused: what was stored, why, and that the
/// default is in effect instead. Reported by [ForgeConfigurationValues].
class ForgeSettingProblem {
  const ForgeSettingProblem({
    required this.setting,
    required this.stored,
    required this.message,
  });

  /// The setting.
  final ForgeSetting<Object> setting;

  /// What the store held.
  final Object? stored;

  /// Why it was refused.
  final ForgeText message;

  @override
  String toString() =>
      'ForgeSettingProblem(${setting.storage.location}: $stored — $message)';
}

/// A setting's value in effect changed: written, reset, or read anew.
class ForgeSettingChange {
  const ForgeSettingChange(this.setting, this.value, this.previous);

  final ForgeSetting<Object> setting;

  /// The value in effect now.
  final Object value;

  /// The value in effect before.
  final Object previous;
}

/// The values of the settings the configuration descriptions declare, kept
/// through the kit's state-store port ([ForgeStateStore]) or through the
/// [ForgeSettingBinding] a setting's storage names, and the behaviour the
/// settings name, run through a [ForgeSettingHooks] registry.
///
/// - **Read:** [valueOf] answers the value in effect at once — the stored
///   value when it is valid, else the default. A stored value a setting
///   refuses (wrong type, out of range, not a choice) leaves the default in
///   effect and is reported ([problems], [onProblem]); the store keeps it
///   until the setting is written or reset.
/// - **Write:** [set] validates and answers the reason when the value is
///   refused (nothing written), else stores it; [reset] removes the stored
///   value, so the default is in effect (a setting's companions — a key
///   binding table's deleted bindings — too). A setting with a storage path
///   writes the whole document of its key with the value changed at the
///   path (several settings share one document so).
/// - **Listen:** [listenable] per setting, the [changes] stream, or this
///   [ChangeNotifier] for any change.
/// - **Bindings:** a setting whose storage names a binding
///   (`ForgeSettingStorage(key, binding: id)`) is read from and written to
///   that binding ([bindings], [addBinding]) instead of [store], coalesced
///   alike; the keys a binding's `watch` reports are read again. A setting
///   whose binding is missing keeps its default, and [set] refuses it
///   (`ForgeConfigurationTexts.noBinding`).
/// - **Hooks:** [runAction], [startFlow], [checkToolPath], [detectToolPath],
///   [choicesFor], [statusOf] / [watchStatus], [catalogueOf] and
///   [keyBindingRows] find the hook a setting names in [hooks] and run it
///   with a [ForgeSettingContext] ([contextFor]); a missing hook or a hook
///   that throws is answered as a failure, never thrown.
///
/// **Restore, then write once per gesture**, as every kit user of a store:
/// [load] reads every key the settings name; writes go through a
/// [ForgeCoalescedStateWriter] per store or binding (the writes of one key
/// within a microtask are one write), and a value set before [load] has
/// finished is kept in memory only until the restore reads the stored one
/// over it. [reload] reads keys again after someone else changed them.
///
/// The event trail of reads, writes, binding changes and hook runs is
/// switched on with `kConfigurationValuesDebug`.
class ForgeConfigurationValues extends ChangeNotifier {
  /// The values of [descriptions]' settings, kept in [store] or the
  /// [bindings] their storages name, with the behaviour of [hooks].
  ForgeConfigurationValues(
    this.store, {
    Iterable<ForgeConfigurationDescription> descriptions = const [],
    Iterable<ForgeSettingBinding> bindings = const [],
    ForgeSettingHooks? hooks,
    this.onProblem,
  }) : hooks = hooks ?? ForgeSettingHooks() {
    _writer = ForgeCoalescedStateWriter(store);
    for (final binding in bindings) {
      _bindings[binding.id] = _BoundStore(binding);
    }
    for (final description in descriptions) {
      _register(description);
    }
  }

  /// Where the values of settings without a binding are read from and
  /// written to.
  final ForgeStateStore store;

  /// The behaviour the settings name; an application or its modules add to
  /// it (`ForgeConfigurationHooksExtra`, [ForgeSettingHooks.addAll]).
  final ForgeSettingHooks hooks;

  /// Called for every stored value a setting refuses (at [load], [reload]
  /// and when a description is added).
  final void Function(ForgeSettingProblem problem)? onProblem;

  late final ForgeCoalescedStateWriter _writer;

  final Map<String, _BoundStore> _bindings = {};
  final List<ForgeConfigurationDescription> _descriptions = [];
  final Map<String, ForgeSetting<Object>> _settings = {};
  final Map<String, ForgeConfigurationDescription> _descriptionOf = {};
  final Map<String, Object?> _documents = {};
  final Map<String, ValueNotifier<Object>> _notifiers = {};
  final Map<String, Object> _values = {};
  final Map<String, ForgeSettingProblem> _problems = {};
  final StreamController<ForgeSettingChange> _changes =
      StreamController<ForgeSettingChange>.broadcast();
  bool _loaded = false;
  bool _disposed = false;

  /// The descriptions whose settings are kept, in the order added.
  List<ForgeConfigurationDescription> get descriptions =>
      List.unmodifiable(_descriptions);

  /// The bindings supplied, by id.
  Map<String, ForgeSettingBinding> get bindings => {
    for (final entry in _bindings.entries) entry.key: entry.value.binding,
  };

  /// Whether [load] has finished.
  bool get isLoaded => _loaded;

  /// The stored values refused, by setting, as last read.
  List<ForgeSettingProblem> get problems => List.unmodifiable(_problems.values);

  /// Every change of a value in effect.
  Stream<ForgeSettingChange> get changes => _changes.stream;

  /// Adds [description]'s settings; once loaded, reads their keys.
  ///
  /// A setting at a storage location another description's setting has is
  /// left out (the first added wins); a description id added before is
  /// ignored. Settings that keep no value (actions, status lines) are not
  /// kept; a setting's companions are.
  Future<void> addDescription(ForgeConfigurationDescription description) async {
    final documents = _register(description);
    if (_loaded && documents.isNotEmpty) await reload(keys: documents);
  }

  /// Adds [binding] (one of the same id is replaced); once loaded, reads the
  /// documents of its settings and follows its changes.
  Future<void> addBinding(ForgeSettingBinding binding) async {
    final old = _bindings.remove(binding.id);
    await old?.dispose();
    final bound = _bindings[binding.id] = _BoundStore(binding);
    configurationValuesTrail('binding ${binding.id} added');
    if (!_loaded) return;
    bound.open();
    _follow(bound);
    await reload(keys: _documentIdsOf(binding.id));
  }

  Set<String> _register(ForgeConfigurationDescription description) {
    final documents = <String>{};
    if (_descriptions.any((d) => d.id == description.id)) return documents;
    _descriptions.add(description);
    void add(ForgeSetting<Object> setting) {
      if (!setting.storesValue) return;
      final location = setting.storage.location;
      if (_settings.containsKey(location)) return;
      _settings[location] = setting;
      _descriptionOf[location] = description;
      documents.add(setting.storage.documentId);
    }

    for (final setting in description.settings) {
      add(setting);
      setting.companions.forEach(add);
    }
    return documents;
  }

  Set<String> _documentIdsOf(String? binding) => {
    for (final s in _settings.values)
      if (s.storage.binding == binding) s.storage.documentId,
  };

  /// Reads every key the settings name (the start's restore) and lets
  /// writes through from then on; follows the bindings' changes.
  Future<void> load() async {
    await _readDocuments({for (final s in _settings.values) s.storage});
    _loaded = true;
    _writer.open();
    for (final bound in _bindings.values) {
      bound.open();
      _follow(bound);
    }
  }

  void _follow(_BoundStore bound) {
    final stream = bound.binding.watch();
    if (stream == null || bound.subscription != null) return;
    bound.subscription = stream.listen((key) {
      if (_disposed) return;
      configurationValuesTrail('binding ${bound.binding.id} changed $key');
      unawaited(reload(keys: ['${bound.binding.id}:$key']));
    });
  }

  /// Reads [keys] again (default: every document the settings name), after
  /// someone else changed them, and announces the values that changed. A key
  /// is a state-store key, or `<binding>:<key>` for a binding's document
  /// (`ForgeSettingStorage.documentId`).
  Future<void> reload({Iterable<String>? keys}) {
    final wanted = keys?.toSet();
    return _readDocuments({
      for (final s in _settings.values)
        if (wanted == null || wanted.contains(s.storage.documentId)) s.storage,
    });
  }

  Future<void> _readDocuments(Set<ForgeSettingStorage> storages) async {
    final read = <String>{};
    for (final storage in storages) {
      final id = storage.documentId;
      if (!read.add(id)) continue;
      Object? document;
      final binding = storage.binding;
      if (binding == null) {
        document = await _writer.read(storage.key);
      } else {
        final bound = _bindings[binding];
        if (bound == null) {
          configurationValuesTrail('read $id: binding $binding missing');
        } else {
          try {
            document = await bound.writer.read(storage.key);
            configurationValuesTrail('read $id from binding $binding');
          } on Object catch (error) {
            configurationValuesTrail('read $id failed: $error');
          }
        }
      }
      if (_disposed) return;
      _documents[id] = document;
    }
    _refresh(read, report: true);
  }

  /// The setting registered at [setting]'s storage location — [setting]
  /// itself unless another description's setting took the location first.
  ForgeSetting<Object>? registered(ForgeSetting<Object> setting) =>
      _settings[setting.storage.location];

  /// The description [setting] was registered with, or null.
  ForgeConfigurationDescription? descriptionOf(ForgeSetting<Object> setting) {
    final location = setting.storage.location;
    if (setting.storesValue) return _descriptionOf[location];
    for (final description in _descriptions) {
      if (description.contains(setting)) return description;
    }
    return null;
  }

  /// The value in effect for [setting]: the stored one when valid, else the
  /// default (before [load]: the default, or what was set since).
  T valueOf<T extends Object>(ForgeSetting<T> setting) =>
      setting.read(_storedAt(setting)).value;

  /// Whether a valid value of [setting] is stored (false: the default is in
  /// effect).
  bool isStored(ForgeSetting<Object> setting) =>
      setting.read(_storedAt(setting)).stored;

  /// The value of [setting] in effect, as it changes.
  ValueListenable<T> listenable<T extends Object>(ForgeSetting<T> setting) {
    final notifier = _notifiers.putIfAbsent(
      setting.storage.location,
      () => ValueNotifier<Object>(valueOf<Object>(setting)),
    );
    return _TypedListenable<T>(notifier);
  }

  /// Whether [setting] is shown: its `visibleWhen` holds (or it has none).
  bool isVisible(ForgeSetting<Object> setting) =>
      _holds(setting, setting.visibleWhen);

  /// Whether [setting] can be changed: its `enabledWhen` holds (or it has
  /// none).
  bool isEnabled(ForgeSetting<Object> setting) =>
      _holds(setting, setting.enabledWhen);

  bool _holds(ForgeSetting<Object> setting, ForgeSettingCondition? condition) {
    if (condition == null) return true;
    final other = descriptionOf(setting)?.settingById(condition.settingId);
    if (other == null) return true;
    return condition.holds(valueOf<Object>(other));
  }

  /// Why [value] is not a valid value of [setting], or null when it is.
  ForgeText? validate(ForgeSetting<Object> setting, Object? value) =>
      setting.check(value);

  /// Why [setting] cannot be kept: its storage names a binding that is not
  /// supplied; null when it can (or keeps no value).
  ForgeText? storageProblem(ForgeSetting<Object> setting) {
    final binding = setting.storage.binding;
    if (!setting.storesValue || binding == null) return null;
    return _bindings.containsKey(binding)
        ? null
        : ForgeConfigurationTexts.noBinding(binding);
  }

  /// Stores [value] for [setting] when it is valid and answers null; else
  /// answers why and writes nothing. A setting that keeps no value answers
  /// null and writes nothing.
  Future<ForgeText?> set(ForgeSetting<Object> setting, Object? value) async {
    if (!setting.storesValue) return null;
    final problem = setting.check(value) ?? storageProblem(setting);
    if (problem != null) {
      configurationValuesTrail('set ${setting.storage.location} refused');
      return problem;
    }
    final typed = setting.decode(value)!;
    _storeAt(setting, setting.encode(typed));
    await _write(setting.storage);
    return null;
  }

  /// Removes [setting]'s stored value and its companions': the defaults are
  /// in effect (a key binding table's *Reset all*).
  Future<void> reset(ForgeSetting<Object> setting) async {
    final writes = <Future<void>>[];
    for (final target in [setting, ...setting.companions]) {
      if (!target.storesValue || storageProblem(target) != null) continue;
      _storeAt(target, null);
      writes.add(_write(target.storage));
    }
    await Future.wait(writes);
  }

  /// Completes when every write made before is stored.
  Future<void> flushed() async {
    await _writer.flushed();
    for (final bound in _bindings.values.toList()) {
      await bound.writer.flushed();
    }
  }

  Future<void> _write(ForgeSettingStorage storage) {
    final document = _documents[storage.documentId];
    final binding = storage.binding;
    if (binding == null) return _writer.write(storage.key, document);
    final bound = _bindings[binding];
    if (bound == null) return Future<void>.value();
    if (_loaded) {
      configurationValuesTrail('write ${storage.documentId} to binding');
    }
    return bound.writer.write(storage.key, document);
  }

  Object? _storedAt(ForgeSetting<Object> setting) {
    final storage = setting.storage;
    if (!storage.stores) return null;
    Object? node = _documents[storage.documentId];
    if (storage.path.isEmpty) return node;
    node = _asMap(node);
    for (final segment in storage.path) {
      if (node is! Map) return null;
      node = node[segment];
    }
    return node;
  }

  void _storeAt(ForgeSetting<Object> setting, Object? value) {
    final storage = setting.storage;
    final id = storage.documentId;
    if (storage.path.isEmpty) {
      _documents[id] = value;
    } else {
      final root = _copyMap(_asMap(_documents[id]));
      var node = root;
      for (final segment in storage.path.take(storage.path.length - 1)) {
        final child = node[segment];
        final copy = _copyMap(child is Map ? child : null);
        node[segment] = copy;
        node = copy;
      }
      if (value == null) {
        node.remove(storage.path.last);
      } else {
        node[storage.path.last] = value;
      }
      _documents[id] = root;
    }
    _refresh({id}, report: false);
  }

  /// Announces the values in effect of the settings of the documents [ids]
  /// that changed; with [report], records the stored values refused.
  void _refresh(Set<String> ids, {required bool report}) {
    var changed = false;
    for (final entry in _settings.entries) {
      final setting = entry.value;
      if (!ids.contains(setting.storage.documentId)) continue;
      final stored = _storedAt(setting);
      final read = setting.read(stored);
      if (report) {
        final problem = read.problem;
        if (problem == null) {
          _problems.remove(entry.key);
        } else {
          final reported = ForgeSettingProblem(
            setting: setting,
            stored: stored,
            message: problem,
          );
          _problems[entry.key] = reported;
          onProblem?.call(reported);
        }
      } else if (read.problem == null) {
        _problems.remove(entry.key);
      }
      final previous = _values[entry.key] ?? setting.defaultValue;
      _values[entry.key] = read.value;
      if (setting.sameValue(previous, read.value)) continue;
      _notifiers[entry.key]?.value = read.value;
      _changes.add(ForgeSettingChange(setting, read.value, previous));
      changed = true;
    }
    if (changed && !_disposed) notifyListeners();
  }

  // ── Hooks ──

  /// The context a hook of [setting] runs with: its value in effect, the
  /// other settings of its description, a write of its own value, and the
  /// run's [cancellation] and [onProgress]; [key] names the entry asked
  /// about (a map's key, a table's row).
  ForgeSettingContext contextFor(
    ForgeSetting<Object> setting, {
    String? key,
    ForgeHookCancellation? cancellation,
    void Function(ForgeHookProgress progress)? onProgress,
  }) {
    final description = descriptionOf(setting);
    return ForgeSettingContext(
      setting: setting,
      value: valueOf<Object>(setting),
      hooks: hooks,
      readSetting: (id) {
        final other = description?.settingById(id);
        return other == null ? null : valueOf<Object>(other);
      },
      writeValue: (value) => set(setting, value),
      onProgress: onProgress,
      cancellation: cancellation,
      key: key,
    );
  }

  /// Runs the action [actionId] for [setting] and answers how it ended: a
  /// missing action or one that throws is a failure; a result with a value
  /// writes it (a refused value turns the result into a failure).
  Future<ForgeActionResult> runAction(
    ForgeSetting<Object> setting,
    String actionId, {
    String? key,
    ForgeHookCancellation? cancellation,
    void Function(ForgeHookProgress progress)? onProgress,
  }) async {
    final action = hooks.action(actionId);
    if (action == null) {
      configurationValuesTrail('action $actionId for ${setting.id}: missing');
      return ForgeActionResult.failure(
        ForgeConfigurationTexts.hookMissing(actionId),
      );
    }
    configurationValuesTrail('action $actionId for ${setting.id}: run');
    ForgeActionResult result;
    try {
      result = await action.run(
        contextFor(
          setting,
          key: key,
          cancellation: cancellation,
          onProgress: onProgress,
        ),
      );
    } on Object catch (error) {
      configurationValuesTrail('action $actionId failed: $error');
      return ForgeActionResult.failure(
        ForgeConfigurationTexts.hookFailed('$error'),
      );
    }
    result = await _take(setting, result);
    configurationValuesTrail('action $actionId: ${result.outcome.name}');
    return result;
  }

  Future<ForgeActionResult> _take(
    ForgeSetting<Object> setting,
    ForgeActionResult result,
  ) async {
    if (!result.succeeded || !result.hasValue || !setting.storesValue) {
      return result;
    }
    final problem = await set(setting, result.value);
    return problem == null
        ? result
        : ForgeActionResult.failure(problem, refresh: result.refresh);
  }

  /// A run of the flow [flowId] for [setting], for the UI to drive; null
  /// when the flow is missing. Its done step's value is written as an
  /// action's is.
  ForgeFlowSession? startFlow(
    ForgeSetting<Object> setting,
    String flowId, {
    ForgeHookCancellation? cancellation,
    void Function(ForgeHookProgress progress)? onProgress,
  }) {
    final flow = hooks.flow(flowId);
    if (flow == null) {
      configurationValuesTrail('flow $flowId for ${setting.id}: missing');
      return null;
    }
    configurationValuesTrail('flow $flowId for ${setting.id}: start');
    final session = flow.start(
      contextFor(setting, cancellation: cancellation, onProgress: onProgress),
    );
    return _TakingFlowSession(
      session,
      flowId,
      (result) => _take(setting, result),
    );
  }

  /// The state of [setting]'s path (its value in effect, or [value]) as its
  /// detector reports it, with the application's [hints] added to the
  /// setting's; missing when the detector is.
  Future<ForgeDetectedCandidate> checkToolPath(
    ForgeToolPathSetting setting, {
    String? value,
    ForgeDetectionHints? hints,
  }) async {
    final detector = hooks.detector(setting.detector);
    if (detector == null) {
      configurationValuesTrail('detector ${setting.detector}: missing');
      return ForgeDetectedCandidate.missing(
        message: ForgeConfigurationTexts.hookMissing(setting.detector),
      );
    }
    final path = value ?? valueOf(setting);
    try {
      final found = await detector.check(
        contextFor(setting),
        path,
        hints == null ? setting.hints : setting.hints.merge(hints),
      );
      configurationValuesTrail(
        'detector ${setting.detector} check "$path": ${found.level.name}',
      );
      return found;
    } on Object catch (error) {
      configurationValuesTrail('detector ${setting.detector} failed: $error');
      return ForgeDetectedCandidate.missing(
        reason: '$error',
        message: ForgeConfigurationTexts.hookFailed('$error'),
      );
    }
  }

  /// Every candidate [setting]'s detector finds in a wide search, best
  /// first; empty when the detector is missing or fails.
  Future<List<ForgeDetectedCandidate>> detectToolPath(
    ForgeToolPathSetting setting, {
    ForgeDetectionHints? hints,
    ForgeHookCancellation? cancellation,
    void Function(ForgeHookProgress progress)? onProgress,
  }) async {
    final detector = hooks.detector(setting.detector);
    if (detector == null) {
      configurationValuesTrail('detector ${setting.detector}: missing');
      return const [];
    }
    try {
      final found = await detector.detect(
        contextFor(setting, cancellation: cancellation, onProgress: onProgress),
        hints == null ? setting.hints : setting.hints.merge(hints),
      );
      configurationValuesTrail(
        'detector ${setting.detector} detect: ${found.length} candidates',
      );
      return found;
    } on Object catch (error) {
      configurationValuesTrail('detector ${setting.detector} failed: $error');
      return const [];
    }
  }

  /// The choices [setting] offers: a choice's fixed choices then its
  /// provider's; a string map's value choices then its provider's for
  /// [key]; a font family's suggestions, its provider's fonts (asked with
  /// the key `monospace` for a code font) and the generic families. Each
  /// value once, the first kept; a missing or failing provider adds
  /// nothing.
  Future<List<ForgeSettingChoice>> choicesFor(
    ForgeSetting<Object> setting, {
    String? key,
  }) async {
    final fixed = <ForgeSettingChoice>[];
    final tail = <ForgeSettingChoice>[];
    String? providerId;
    var askKey = key;
    switch (setting) {
      case ForgeChoiceSetting():
        fixed.addAll(setting.choices);
        providerId = setting.choicesProvider;
      case ForgeStringMapSetting():
        fixed.addAll(setting.valueChoices ?? const []);
        providerId = setting.valueChoicesProvider;
      case ForgeFontFamilySetting():
        fixed.addAll([
          for (final name in setting.suggestions)
            ForgeSettingChoice(name, ForgeText.literal(name)),
        ]);
        tail.addAll([
          for (final name in ForgeFontFamilySetting.genericFamilies)
            ForgeSettingChoice(name, ForgeText.literal(name)),
        ]);
        providerId = setting.fontsProvider;
        if (setting.monospace) askKey ??= 'monospace';
      default:
        return const [];
    }
    final provided = <ForgeSettingChoice>[];
    if (providerId != null) {
      final provider = hooks.choices(providerId);
      if (provider == null) {
        configurationValuesTrail('choices $providerId: missing');
      } else {
        try {
          provided.addAll(
            await provider.choices(contextFor(setting, key: askKey)),
          );
          configurationValuesTrail(
            'choices $providerId${askKey == null ? '' : ' [$askKey]'}: '
            '${provided.length}',
          );
        } on Object catch (error) {
          configurationValuesTrail('choices $providerId failed: $error');
        }
      }
    }
    final seen = <String>{};
    return [
      for (final choice in [...fixed, ...provided, ...tail])
        if (seen.add(choice.value)) choice,
    ];
  }

  /// The status [setting]'s provider answers now; unknown (with the reason)
  /// when the provider is missing or fails.
  Future<ForgeStatusInfo> statusOf(ForgeStatusSetting setting) async {
    final provider = hooks.status(setting.status);
    if (provider == null) {
      configurationValuesTrail('status ${setting.status}: missing');
      return ForgeStatusInfo(
        level: ForgeStatusLevel.unknown,
        message: ForgeConfigurationTexts.hookMissing(setting.status),
      );
    }
    try {
      final status = await provider.current(contextFor(setting));
      configurationValuesTrail(
        'status ${setting.status}: ${status.level.name}',
      );
      return status;
    } on Object catch (error) {
      configurationValuesTrail('status ${setting.status} failed: $error');
      return ForgeStatusInfo(
        level: ForgeStatusLevel.error,
        message: ForgeConfigurationTexts.hookFailed('$error'),
      );
    }
  }

  /// The status of [setting] as it changes, or null when its provider does
  /// not stream it (or is missing): the UI reads [statusOf] then.
  Stream<ForgeStatusInfo>? watchStatus(ForgeStatusSetting setting) =>
      hooks.status(setting.status)?.watch(contextFor(setting));

  /// The actions [setting]'s catalogue lists; empty when it is missing or
  /// fails.
  Future<List<ForgeCatalogueAction>> catalogueOf(
    ForgeKeyBindingTableSetting setting,
  ) async {
    final catalogue = hooks.catalogue(setting.catalogue);
    if (catalogue == null) {
      configurationValuesTrail('catalogue ${setting.catalogue}: missing');
      return const [];
    }
    try {
      final actions = await catalogue.actions(contextFor(setting));
      configurationValuesTrail(
        'catalogue ${setting.catalogue}: ${actions.length} actions',
      );
      return actions;
    } on Object catch (error) {
      configurationValuesTrail('catalogue ${setting.catalogue} failed: $error');
      return const [];
    }
  }

  /// The rows of [setting]'s table: its catalogue's actions with the
  /// overrides in effect and its deleted bindings (`forgeKeyBindingRows`).
  Future<List<ForgeKeyBindingRow>> keyBindingRows(
    ForgeKeyBindingTableSetting setting,
  ) async {
    final deleted = setting.deletedBindings;
    return forgeKeyBindingRows(
      await catalogueOf(setting),
      valueOf(setting),
      deleted: deleted == null ? const {} : valueOf(deleted).toSet(),
      chords: setting.chords,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    for (final bound in _bindings.values) {
      unawaited(bound.dispose());
    }
    for (final notifier in _notifiers.values) {
      notifier.dispose();
    }
    _changes.close();
    super.dispose();
  }

  static Map? _asMap(Object? document) {
    if (document is Map) return document;
    if (document is String) {
      try {
        final decoded = jsonDecode(document);
        if (decoded is Map) return decoded;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static Map<String, Object?> _copyMap(Map? source) => {
    if (source != null)
      for (final entry in source.entries) '${entry.key}': entry.value,
  };
}

/// A binding as a [ForgeStateStore], so its writes are coalesced and held
/// back until the restore like the store's.
class _BoundStore implements ForgeStateStore {
  _BoundStore(this.binding);

  final ForgeSettingBinding binding;
  late final ForgeCoalescedStateWriter writer = ForgeCoalescedStateWriter(this);
  StreamSubscription<String>? subscription;

  void open() => writer.open();

  Future<void> dispose() async {
    await subscription?.cancel();
    subscription = null;
  }

  @override
  Future<Object?> read(String key) => binding.read(key);

  @override
  Future<void> write(String key, Object? document) =>
      binding.write(key, document);

  @override
  Future<List<String>> keys({String prefix = ''}) async => const [];

  @override
  Future<void> flushed() => binding.flushed();
}

/// A flow session whose done step's value is written for the setting.
class _TakingFlowSession implements ForgeFlowSession {
  _TakingFlowSession(this._inner, this._flowId, this._take);

  final ForgeFlowSession _inner;
  final String _flowId;
  final Future<ForgeActionResult> Function(ForgeActionResult result) _take;

  Future<ForgeFlowStep> _after(Future<ForgeFlowStep> next) async {
    ForgeFlowStep step;
    try {
      step = await next;
    } on Object catch (error) {
      configurationValuesTrail('flow $_flowId failed: $error');
      return ForgeFlowStep.done(
        ForgeActionResult.failure(ForgeConfigurationTexts.hookFailed('$error')),
      );
    }
    configurationValuesTrail('flow $_flowId step: ${step.kind.name}');
    final result = step.result;
    if (step.kind != ForgeFlowStepKind.done || result == null) return step;
    return ForgeFlowStep.done(await _take(result));
  }

  @override
  Future<ForgeFlowStep> start() => _after(_inner.start());

  @override
  Future<ForgeFlowStep> respond(ForgeFlowResponse response) =>
      _after(_inner.respond(response));

  @override
  Future<ForgeFlowStep> poll() => _after(_inner.poll());

  @override
  void cancel() {
    configurationValuesTrail('flow $_flowId cancelled');
    _inner.cancel();
  }
}

/// A [ValueListenable] of one type over the untyped notifier of a setting.
class _TypedListenable<T extends Object> implements ValueListenable<T> {
  const _TypedListenable(this._notifier);

  final ValueNotifier<Object> _notifier;

  @override
  T get value => _notifier.value as T;

  @override
  void addListener(VoidCallback listener) => _notifier.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _notifier.removeListener(listener);

  @override
  bool operator ==(Object other) =>
      other is _TypedListenable && identical(other._notifier, _notifier);

  @override
  int get hashCode => identityHashCode(_notifier);
}
