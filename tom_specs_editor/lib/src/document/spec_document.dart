/// A sparse, live instance of a TomSpecs document (§8, §13).
///
/// The structure is defined by the `SpecModel` class graph; this holds only the
/// *values* the user/agent has actually set, keyed by the globally-unique
/// section-ID path (D3). Nothing is materialised until written, so an untouched
/// document is empty (matching the "empty = no value" rule, D4).
///
/// Three sparse stores cover the writable field kinds:
///   * [_content] — `content`/`scalar` leaves: path → string value.
///   * [_form] — `@Form` sections: path → (form-field name → value).
///   * [_listItems] — lists: list path → ordered item paths.
///
/// List item paths are `"$listPath-$seq"` where `seq` is a per-list monotonic
/// counter ([_listSeq]). The counter never reuses a number, so a path is stable
/// for the item's lifetime and never silently re-points after a removal — the
/// `-1`, `-2` suffixes in the spec are these sequence numbers (D3).
class SpecDocument {
  final Map<String, String> _content = {};
  final Map<String, Map<String, String>> _form = {};
  final Map<String, List<String>> _listItems = {};
  final Map<String, int> _listSeq = {};

  /// The content string at [path], or `null` if unset.
  String? content(String path) => _content[path];

  /// Sets the content string at [path]. An empty value clears it (D4).
  void setContent(String path, String value) {
    if (value.isEmpty) {
      _content.remove(path);
    } else {
      _content[path] = value;
    }
  }

  /// The value of form [field] at [path], or `null` if unset.
  String? formField(String path, String field) => _form[path]?[field];

  /// Sets form [field] at [path]. An empty value clears that field (and the
  /// whole form entry once its last field is gone).
  void setFormField(String path, String field, String value) {
    final fields = _form.putIfAbsent(path, () => {});
    if (value.isEmpty) {
      fields.remove(field);
      if (fields.isEmpty) _form.remove(path);
    } else {
      fields[field] = value;
    }
  }

  /// The ordered item paths of the list at [listPath] (empty if none).
  List<String> listItems(String listPath) =>
      List.unmodifiable(_listItems[listPath] ?? const []);

  /// Appends a new item to the list at [listPath] and returns its stable path.
  String addListItem(String listPath) {
    final seq = (_listSeq[listPath] ?? 0) + 1;
    _listSeq[listPath] = seq;
    final itemPath = '$listPath-$seq';
    _listItems.putIfAbsent(listPath, () => []).add(itemPath);
    return itemPath;
  }

  /// Removes the list item at [itemPath] along with every value nested beneath
  /// it. Returns `true` if an item was found and removed.
  ///
  /// The owning list is the entry in [_listItems] that contains [itemPath]; the
  /// counter is deliberately left untouched so future items keep getting fresh
  /// sequence numbers (no renumbering — D3).
  bool removeListItem(String itemPath) {
    String? owningList;
    for (final entry in _listItems.entries) {
      if (entry.value.contains(itemPath)) {
        owningList = entry.key;
        break;
      }
    }
    if (owningList == null) return false;
    _listItems[owningList]!.remove(itemPath);
    if (_listItems[owningList]!.isEmpty) _listItems.remove(owningList);
    _purgeUnder(itemPath);
    return true;
  }

  /// Drops every content/form/list value at [prefix] or nested under it
  /// (`"$prefix/…"` for descendants, `"$prefix-…"` for the item's own lists).
  void _purgeUnder(String prefix) {
    bool isUnder(String key) =>
        key == prefix ||
        key.startsWith('$prefix/') ||
        key.startsWith('$prefix-');
    _content.removeWhere((k, _) => isUnder(k));
    _form.removeWhere((k, _) => isUnder(k));
    _listItems.removeWhere((k, _) => isUnder(k));
    _listSeq.removeWhere((k, _) => isUnder(k));
  }

  /// Whether the document holds no values at all.
  bool get isEmpty =>
      _content.isEmpty && _form.isEmpty && _listItems.isEmpty;

  /// A deep-copied snapshot of the whole document, for the undo stack (§10).
  ///
  /// Every map is copied so the returned state is independent of subsequent
  /// edits — restoring it returns the document to exactly this picture.
  SpecDocumentState captureState() => SpecDocumentState._(
        content: Map.of(_content),
        form: {for (final e in _form.entries) e.key: Map.of(e.value)},
        listItems: {for (final e in _listItems.entries) e.key: List.of(e.value)},
        listSeq: Map.of(_listSeq),
      );

  /// Replaces the document's contents with a previously [captureState]d
  /// snapshot (§10). The restore is absolute: every store is overwritten, so a
  /// snapshot can be applied regardless of intervening edits.
  void restoreState(SpecDocumentState state) {
    _content
      ..clear()
      ..addAll(state._content);
    _form
      ..clear()
      ..addAll({for (final e in state._form.entries) e.key: Map.of(e.value)});
    _listItems
      ..clear()
      ..addAll(
          {for (final e in state._listItems.entries) e.key: List.of(e.value)});
    _listSeq
      ..clear()
      ..addAll(state._listSeq);
  }
}

/// An immutable deep-copied snapshot of a [SpecDocument] (§10 undo stack).
///
/// Produced by [SpecDocument.captureState] and consumed by
/// [SpecDocument.restoreState]; the maps are private so a state can only be
/// applied wholesale, never mutated in place.
class SpecDocumentState {
  final Map<String, String> _content;
  final Map<String, Map<String, String>> _form;
  final Map<String, List<String>> _listItems;
  final Map<String, int> _listSeq;

  SpecDocumentState._({
    required Map<String, String> content,
    required Map<String, Map<String, String>> form,
    required Map<String, List<String>> listItems,
    required Map<String, int> listSeq,
  })  : _content = content,
        _form = form,
        _listItems = listItems,
        _listSeq = listSeq;

  /// The content value at [path] as of this snapshot (the review's base pane).
  String? contentAt(String path) => _content[path];

  /// The form [field] value at [path] as of this snapshot.
  String? formFieldAt(String path, String field) => _form[path]?[field];

  /// A stable fingerprint of the snapshot's values, used to tell whether an
  /// edit actually changed anything (no-op edits must not snapshot, §10).
  String get fingerprint {
    String enc(Map<String, Object?> m) {
      final keys = m.keys.toList()..sort();
      return [for (final k in keys) '$k=${m[k]}'].join('\u0001');
    }

    final formFlat = <String, Object?>{
      for (final e in _form.entries) e.key: enc(e.value),
    };
    final listFlat = <String, Object?>{
      for (final e in _listItems.entries) e.key: e.value.join(','),
    };
    return [enc(_content), enc(formFlat), enc(listFlat)].join('\u0002');
  }
}
