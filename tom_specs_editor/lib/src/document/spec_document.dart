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
}
