import 'dart:async';

/// Where the documents of settings whose storage names this binding
/// (`ForgeSettingStorage(key, binding: id)`) are read, written and watched,
/// instead of the kit's state-store port.
///
/// The application supplies one per place it keeps settings of its own: a
/// configuration file (`.tom/editor_preferences.yaml`), a service that owns
/// its values (Forge's `ForgeConfig` auto-save), a remote profile. A
/// document is what the binding keeps under a key — a value, or a map the
/// settings reach into with their storage paths; it is JSON-compatible
/// (null, bool, num, String, List, Map with String keys), as the settings'
/// `encode` makes it.
///
/// The values service (`tom_forge_kit`'s `ForgeConfigurationValues`) reads a
/// binding's keys at its load, writes a key when a setting under it changes
/// (the whole document, with the value changed at the setting's path) and
/// reads the keys [watch] reports again.
abstract class ForgeSettingBinding {
  const ForgeSettingBinding();

  /// The id storages name it by.
  String get id;

  /// The document under [key], or null when there is none.
  Future<Object?> read(String key);

  /// Stores [document] under [key]; null removes it.
  Future<void> write(String key, Object? document);

  /// The keys changed by someone else (the file edited, the service told),
  /// for the values service to read again; null when nothing changes them
  /// from outside.
  Stream<String>? watch() => null;

  /// Completes when every write started before is stored.
  Future<void> flushed() async {}
}

/// A [ForgeSettingBinding] over a map in memory: for tests, and for values an
/// application keeps for the session only. [change] sets a document from
/// outside and reports it through [watch].
class ForgeMemorySettingBinding extends ForgeSettingBinding {
  ForgeMemorySettingBinding(this.id, {Map<String, Object?> initial = const {}})
    : _documents = {...initial};

  @override
  final String id;

  final Map<String, Object?> _documents;
  final StreamController<String> _changes = StreamController.broadcast();

  /// Every document, as stored.
  Map<String, Object?> snapshot() => Map.unmodifiable(_documents);

  @override
  Future<Object?> read(String key) async => _documents[key];

  @override
  Future<void> write(String key, Object? document) async {
    if (document == null) {
      _documents.remove(key);
    } else {
      _documents[key] = document;
    }
  }

  /// Sets [document] under [key] as someone else would, and reports it.
  void change(String key, Object? document) {
    if (document == null) {
      _documents.remove(key);
    } else {
      _documents[key] = document;
    }
    _changes.add(key);
  }

  @override
  Stream<String> watch() => _changes.stream;

  /// Ends [watch].
  Future<void> close() => _changes.close();
}

/// A [ForgeSettingBinding] made of functions: an application adapts what it
/// already has (a service's getter and setter, a file's reader and writer)
/// without a class of its own.
class ForgeCallbackSettingBinding extends ForgeSettingBinding {
  const ForgeCallbackSettingBinding({
    required this.id,
    required this.onRead,
    required this.onWrite,
    this.onWatch,
    this.onFlushed,
  });

  @override
  final String id;

  /// Reads the document under a key.
  final FutureOr<Object?> Function(String key) onRead;

  /// Writes the document under a key (null: remove).
  final FutureOr<void> Function(String key, Object? document) onWrite;

  /// The keys changed from outside, or null.
  final Stream<String> Function()? onWatch;

  /// Waits for the writes, or null.
  final Future<void> Function()? onFlushed;

  @override
  Future<Object?> read(String key) async => onRead(key);

  @override
  Future<void> write(String key, Object? document) async =>
      onWrite(key, document);

  @override
  Stream<String>? watch() => onWatch?.call();

  @override
  Future<void> flushed() => onFlushed?.call() ?? Future.value();
}
