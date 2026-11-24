import 'package:flutter/foundation.dart' show ValueListenable;

import '../components/forge_editor.dart';

/// A state that reports every change of its active editor, also the ones no
/// event stream of `ForgeKitState` carries (an editor activated without a
/// focus change, the last editor closed).
///
/// Both kit states implement it (`DefaultKitState`, the panel shell's
/// `DefaultSystemState`); a component that follows the active editor asks
/// `state is ForgeActiveEditorListenable` and listens to the focus and
/// editor streams otherwise.
abstract interface class ForgeActiveEditorListenable {
  /// The active editor, notifying whenever it changes.
  ValueListenable<ForgeEditor?> get activeEditorListenable;
}
