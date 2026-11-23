import 'package:flutter/foundation.dart';

/// A place the user was: an editor's document, and the line and column of
/// its caret when the editor reports one (0-based, as
/// `ForgeTextPosition`), in the application it was shown in and where the
/// application placed it ([placement]).
@immutable
class ForgeNavigationLocation {
  const ForgeNavigationLocation({
    required this.uri,
    this.line,
    this.column,
    this.applicationId,
    this.placement,
  });

  /// The document (a file, or a surface's own URI).
  final Uri uri;

  /// The caret's line, or null when the editor reports no caret.
  final int? line;

  /// The caret's column, or null when the editor reports no caret.
  final int? column;

  /// The application the editor was shown in, or null outside one.
  final String? applicationId;

  /// Where the application showed the editor, as it records it (the panel
  /// shell: the index of the middle panel), or null when unknown.
  final Object? placement;

  /// Whether this is the same place as [other]: the same document at the
  /// same line. A caret moved along a line is no new place.
  bool samePlaceAs(ForgeNavigationLocation other) =>
      uri == other.uri &&
      line == other.line &&
      applicationId == other.applicationId;

  @override
  bool operator ==(Object other) =>
      other is ForgeNavigationLocation &&
      uri == other.uri &&
      line == other.line &&
      column == other.column &&
      applicationId == other.applicationId &&
      placement == other.placement;

  @override
  int get hashCode => Object.hash(uri, line, column, applicationId, placement);

  @override
  String toString() =>
      'ForgeNavigationLocation($uri'
      '${line == null ? '' : ':$line:${column ?? 0}'}'
      '${applicationId == null ? '' : ' in $applicationId'})';
}

/// The application's navigation history, as VS Code's Go Back / Go Forward: every
/// move between documents, or jump within one, records the place left;
/// [goBack] returns there (reopening a closed file) and [goForward] undoes a
/// [goBack].
///
/// An editor with its own history (`ForgeEditor.historyManager`) is the
/// editor's part of the same chain: while it is active, Back and Forward go
/// through its history first.
abstract class ForgeNavigationHistory {
  /// Whether [goBack] has somewhere to go.
  ValueListenable<bool> get canGoBack;

  /// Whether [goForward] has somewhere to go.
  ValueListenable<bool> get canGoForward;

  /// The places [goBack] returns to, the next one last.
  List<ForgeNavigationLocation> get backLocations;

  /// The places [goForward] returns to, the next one last.
  List<ForgeNavigationLocation> get forwardLocations;

  /// Goes back to the place left last; false when there is none.
  bool goBack();

  /// Goes forward to the place the last [goBack] left; false when there is
  /// none.
  bool goForward();

  /// Records where the user is now, before a jump that does not change the
  /// active editor (opening the active file at another line). A move to
  /// another editor is recorded without being asked.
  void recordCurrentLocation();

  /// Runs [action] without recording the moves it makes: a layout opening
  /// its declared editors, a saved layout being restored.
  void withoutRecording(void Function() action);
}
