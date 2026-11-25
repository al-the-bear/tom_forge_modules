import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tom_forge_core/tom_forge_core.dart'
    show
        ForgeConfigurationDescription,
        ForgeSetting,
        ForgeSettingCondition,
        ForgeText;

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
/// through the kit's state-store port ([ForgeStateStore]).
///
/// - **Read:** [valueOf] answers the value in effect at once — the stored
///   value when it is valid, else the default. A stored value a setting
///   refuses (wrong type, out of range, not a choice) leaves the default in
///   effect and is reported ([problems], [onProblem]); the store keeps it
///   until the setting is written or reset.
/// - **Write:** [set] validates and answers the reason when the value is
///   refused (nothing written), else stores it; [reset] removes the stored
///   value, so the default is in effect. A setting with a storage path writes
///   the whole document of its key with the value changed at the path
///   (several settings share one document so).
/// - **Listen:** [listenable] per setting, the [changes] stream, or this
///   [ChangeNotifier] for any change.
///
/// **Restore, then write once per gesture**, as every kit user of a store:
/// [load] reads every key the settings name; writes go through a
/// [ForgeCoalescedStateWriter] (the writes of one key within a microtask are
/// one store write), and a value set before [load] has finished is kept in
/// memory only until the restore reads the stored one over it. [reload]
/// reads keys again after someone else changed them.
class ForgeConfigurationValues extends ChangeNotifier {
  /// The values of [descriptions]' settings, kept in [store].
  ForgeConfigurationValues(
    this.store, {
    Iterable<ForgeConfigurationDescription> descriptions = const [],
    this.onProblem,
  }) {
    _writer = ForgeCoalescedStateWriter(store);
    for (final description in descriptions) {
      _register(description);
    }
  }

  /// Where the values are read from and written to.
  final ForgeStateStore store;

  /// Called for every stored value a setting refuses (at [load], [reload]
  /// and when a description is added).
  final void Function(ForgeSettingProblem problem)? onProblem;

  late final ForgeCoalescedStateWriter _writer;

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
  /// ignored.
  Future<void> addDescription(ForgeConfigurationDescription description) async {
    final keys = _register(description);
    if (_loaded && keys.isNotEmpty) await reload(keys: keys);
  }

  Set<String> _register(ForgeConfigurationDescription description) {
    final keys = <String>{};
    if (_descriptions.any((d) => d.id == description.id)) return keys;
    _descriptions.add(description);
    for (final setting in description.settings) {
      final location = setting.storage.location;
      if (_settings.containsKey(location)) continue;
      _settings[location] = setting;
      _descriptionOf[location] = description;
      keys.add(setting.storage.key);
    }
    return keys;
  }

  /// Reads every key the settings name (the start's restore) and lets
  /// writes through from then on.
  Future<void> load() async {
    await _readKeys({for (final s in _settings.values) s.storage.key});
    _loaded = true;
    _writer.open();
  }

  /// Reads [keys] (default: every key the settings name) again, after
  /// someone else changed them, and announces the values that changed.
  Future<void> reload({Iterable<String>? keys}) => _readKeys(
    keys?.toSet() ?? {for (final s in _settings.values) s.storage.key},
  );

  Future<void> _readKeys(Set<String> keys) async {
    for (final key in keys) {
      final document = await _writer.read(key);
      if (_disposed) return;
      _documents[key] = document;
    }
    _refresh(keys, report: true);
  }

  /// The setting registered at [setting]'s storage location — [setting]
  /// itself unless another description's setting took the location first.
  ForgeSetting<Object>? registered(ForgeSetting<Object> setting) =>
      _settings[setting.storage.location];

  /// The description [setting] was registered with, or null.
  ForgeConfigurationDescription? descriptionOf(ForgeSetting<Object> setting) =>
      _descriptionOf[setting.storage.location];

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

  /// Stores [value] for [setting] when it is valid and answers null; else
  /// answers why and writes nothing.
  Future<ForgeText?> set(ForgeSetting<Object> setting, Object? value) async {
    final problem = setting.check(value);
    if (problem != null) return problem;
    final typed = setting.decode(value)!;
    _storeAt(setting, setting.encode(typed));
    await _write(setting.storage.key);
    return null;
  }

  /// Removes [setting]'s stored value: the default is in effect.
  Future<void> reset(ForgeSetting<Object> setting) async {
    _storeAt(setting, null);
    await _write(setting.storage.key);
  }

  /// Completes when every write made before is stored.
  Future<void> flushed() => _writer.flushed();

  Future<void> _write(String key) => _writer.write(key, _documents[key]);

  Object? _storedAt(ForgeSetting<Object> setting) {
    final storage = setting.storage;
    Object? node = _documents[storage.key];
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
    final key = storage.key;
    if (storage.path.isEmpty) {
      _documents[key] = value;
    } else {
      final root = _copyMap(_asMap(_documents[key]));
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
      _documents[key] = root;
    }
    _refresh({key}, report: false);
  }

  /// Announces the values in effect of the settings of [keys] that changed;
  /// with [report], records the stored values refused.
  void _refresh(Set<String> keys, {required bool report}) {
    var changed = false;
    for (final entry in _settings.entries) {
      final setting = entry.value;
      if (!keys.contains(setting.storage.key)) continue;
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

  @override
  void dispose() {
    _disposed = true;
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
