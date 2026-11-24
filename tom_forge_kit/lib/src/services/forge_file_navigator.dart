import 'dart:async' show unawaited;

import '../kit/forge_kit_api.dart';

/// Opens a file the user picked in a view, at a position when one is given:
/// a match of the Search view, a diagnostic of the Problems view, a row of
/// the file explorer.
typedef ForgeOpenFileAt = void Function(Uri uri, {int? line, int? column});

/// Opens a file at a position the way the application opens what the user
/// picks (the panel shell: in the active middle panel, recorded in the
/// navigation history, the editor moved to [line] and [column]).
///
/// An application offers it by implementing it on its `ForgeKitApi` (the
/// panel shell's `DefaultShellApi` does); [forgeOpenFileAtOf] falls back to
/// `ForgeKitApi.openFile`, which opens the file without a position.
abstract interface class ForgeFileNavigator {
  /// Opens [uri], at [line] and [column] (0-based) when given.
  void openFileAt(Uri uri, {int? line, int? column});
}

/// How a view opens a file in the application of [api]: its
/// [ForgeFileNavigator] when it is one, else `ForgeKitApi.openFile` (no
/// position).
ForgeOpenFileAt forgeOpenFileAtOf(ForgeKitApi api) {
  if (api case final ForgeFileNavigator navigator) {
    return navigator.openFileAt;
  }
  return (uri, {line, column}) => unawaited(api.openFile(uri));
}
