/// Keyed documents a host persists for the kit: the workspace state, the
/// layouts an application keeps, the preferences — one interface the host
/// implements.
///
/// A document is a JSON-compatible value (null, bool, num, String, a List or
/// a Map with String keys of such values). The kit's implementations:
///
/// - `ForgeMemoryStateStore`: in memory, for tests and for hosts that
///   persist elsewhere;
/// - `ForgeSharedPreferencesStateStore`: the default for the preferences,
///   over `shared_preferences`, each value encoded as the Forge preferences
///   always were;
/// - `ForgeFileStateStore`: the default for the workspace state, the files
///   under a workspace's `.forge/` folder.
///
/// **Written once per gesture, never before the start's restore.** The
/// kit's users of a store — the preferences (`ForgeKitPreferences`) and the
/// workspace state (`DefaultWorkspaceStateManager`) — write through a
/// `ForgeCoalescedStateWriter`: the writes of one key within a microtask
/// become one [write] of the last value, and nothing is written before the
/// restore (`load()` / `initialize()`) has finished. A store itself writes
/// what it is given, when it is given.
abstract class ForgeStateStore {
  /// The document stored under [key], or null.
  Future<Object?> read(String key);

  /// Stores [document] under [key], atomically per key (a reader sees the
  /// old document or the new one, never a part); null removes it. Writes of
  /// one key are stored in the order they were started.
  Future<void> write(String key, Object? document);

  /// The keys stored, those starting with [prefix] when given, sorted.
  Future<List<String>> keys({String prefix = ''});

  /// Completes when every write started before is stored.
  Future<void> flushed();
}
