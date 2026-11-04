/// A browser's navigation history: the documents visited, with where the
/// reader was in each, so going back returns to the same place. The VS Code
/// extension's `mdBrowserHistory.ts`.
library;

/// Where the reader was: the source line of the block at the top of the view
/// and that block's offset from the top, plus the raw scroll offset for when
/// no block was found. A line survives re-rendering, where a scroll offset of
/// a lazily laid-out document does not.
class MdReadingPosition {
  const MdReadingPosition({this.line, this.delta = 0, this.scrollTop = 0});

  final int? line;
  final double delta;
  final double scrollTop;
}

/// One visited document.
class MdHistoryEntry {
  MdHistoryEntry({required this.filePath, this.group = '', this.position});

  final String filePath;

  /// The picker group it was opened from.
  final String group;

  /// Where the reader was when they left it.
  MdReadingPosition? position;
}

/// The visited documents of one browser.
class MdNavigationHistory {
  MdNavigationHistory({this.maxEntries = 100});

  /// The most entries kept; the oldest go first.
  final int maxEntries;

  final _entries = <MdHistoryEntry>[];
  var _index = -1;

  bool get canGoBack => _index > 0;
  bool get canGoForward => _index < _entries.length - 1;
  MdHistoryEntry? get current => _index < 0 ? null : _entries[_index];

  /// A new document: the forward entries are dropped.
  void push(MdHistoryEntry entry) {
    _entries.removeRange(_index + 1, _entries.length);
    _entries.add(entry);
    if (_entries.length > maxEntries) _entries.removeAt(0);
    _index = _entries.length - 1;
  }

  MdHistoryEntry? goBack() => canGoBack ? _entries[--_index] : null;

  MdHistoryEntry? goForward() => canGoForward ? _entries[++_index] : null;

  /// Remembers where the reader is in [filePath]; a report for another file
  /// (one arriving after the browser moved on) is ignored.
  void recordPosition(String filePath, MdReadingPosition position) {
    final entry = current;
    if (entry != null && entry.filePath == filePath) entry.position = position;
  }
}
