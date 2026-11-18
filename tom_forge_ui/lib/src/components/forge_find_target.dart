import 'package:flutter/foundation.dart';

/// Where a [ForgeFindTarget]'s search stands, as the shell's find bar shows
/// it.
@immutable
class ForgeFindStatus {
  const ForgeFindStatus({
    this.current = 0,
    this.total = 0,
    this.searching = false,
  });

  /// The current match, from 1; 0 when there is none.
  final int current;

  /// The matches found so far.
  final int total;

  /// Whether the search is still running (matches stream in).
  final bool searching;

  /// No search.
  static const none = ForgeFindStatus();

  @override
  bool operator ==(Object other) =>
      other is ForgeFindStatus &&
      other.current == current &&
      other.total == total &&
      other.searching == searching;

  @override
  int get hashCode => Object.hash(current, total, searching);

  @override
  String toString() =>
      'ForgeFindStatus($current/$total${searching ? ', searching' : ''})';
}

/// An editor without a text buffer that the shell's find bar searches (a
/// PDF, a rendered document): the shell hands it the query and the
/// next/previous moves, the editor searches and shows its matches itself,
/// and reports where it stands through [findStatus]. The shell's Find
/// (`editor.find`, Cmd+F) is enabled for it; Replace is not offered.
///
/// A `ForgeTextEditor` is searched through its text ranges instead and does
/// not implement this.
abstract interface class ForgeFindTarget {
  /// Searches for [query] (a new search; an empty query clears it).
  void find(String query, {bool caseSensitive = false, bool wholeWord = false});

  /// Moves to the next match (wrapping).
  void findNext();

  /// Moves to the previous match (wrapping).
  void findPrevious();

  /// Ends the search and its highlights (the find bar closed).
  void clearFind();

  /// The search's state.
  ValueListenable<ForgeFindStatus> get findStatus;
}
