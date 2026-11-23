import 'package:tom_file_system/tom_file_system.dart' show TomFileSystem;
import 'package:tom_forge_kit/tom_forge_kit.dart';

import 'default_system_state.dart';

/// Uniform autosave controller for all open editors.
///
/// Listens to dirty-state changes on all open editors and schedules
/// a debounced save after [debounce] of inactivity. Also saves on
/// window focus loss when [saveOnFocusLoss] is true.
///
/// The kit's [ForgeAutosaveController] does the work; the shell feeds its
/// `saveNow` from the loss of the window's focus.
class ShellAutosaveController {
  final DefaultSystemState systemState;
  final TomFileSystem fileSystem;
  final Duration debounce;
  final bool saveOnFocusLoss;

  late final ForgeAutosaveController _controller;

  ShellAutosaveController({
    required this.systemState,
    required this.fileSystem,
    this.debounce = const Duration(milliseconds: 1000),
    this.saveOnFocusLoss = true,
  }) {
    _controller = ForgeAutosaveController(
      state: systemState,
      fileSystem: fileSystem,
      debounce: debounce,
      saveNow: saveOnFocusLoss
          ? systemState.onWindowFocusChanged
                .where((event) => !event.focused)
                .map((_) {})
          : null,
    );
  }

  void dispose() => _controller.dispose();
}
